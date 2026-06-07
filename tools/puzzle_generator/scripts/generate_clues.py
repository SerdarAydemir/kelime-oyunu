# tools/puzzle_generator/scripts/generate_clues.py
"""Gemini-backed çengel clue generator — async full-batch (architecture.md §7).

Reads the main pool (word_pool_cleaned.json), asks Gemini for a short
Cross-Up-style clue per unique len 3-8 word, validates each (clue_engine), and
writes an incremental, resumable master_clues.json. len 1-2 are excluded
(curated symbols/two_letter cover them).

Concurrency model (paid tier):
  * asyncio.Semaphore bounds in-flight requests (--concurrency).
  * A token-bucket limiter caps the per-minute rate (--rpm).
  * Workers push results to an asyncio.Queue; a single writer task owns all file
    I/O and flushes atomically (.tmp -> os.replace) every 50 items / 3 s, so
    parallel writes can never corrupt the JSON.
  * SIGINT (Ctrl+C): set a stop flag, let in-flight requests finish, flush once
    more, exit cleanly. Restart skips words already in cache/review/failed.
"""

from __future__ import annotations

import asyncio
import io
import json
import os
import signal
import sys
import time
from pathlib import Path
from types import FrameType
from typing import Annotated

import typer
from google import genai
from google.genai import types

from clue_engine import Result, TokenBucket, resolve
from kelime_gen.schema import tr_upper
from kelime_gen.word_pool import load_blacklist

# ── Paths ──────────────────────────────────────────────────────────────────────

_ROOT = Path(__file__).resolve().parents[1]
_PROCESSED = _ROOT / "data" / "processed"
_POOL_PATH = _PROCESSED / "word_pool_cleaned.json"
_CACHE_PATH = _PROCESSED / "master_clues.json"
_REVIEW_PATH = _PROCESSED / "review_clues.json"
_FAILED_PATH = _PROCESSED / "failed_clues.json"
_BLACKLIST_PATH = _ROOT / "data" / "raw" / "profanity_blacklist.txt"

_DEFAULT_MODEL = "gemini-2.5-flash-lite"  # thinking off by default + ~27x cheaper
_MIN_LEN, _MAX_LEN = 3, 8  # slot window (mask_synth MAX_SLOT_LEN=8); len 1-2 curated
_DEFAULT_RPM = 500
_DEFAULT_CONCURRENCY = 15
_DEFAULT_PANIC = 20  # consecutive transient faults -> emergency stop (C)
_LATENCY_EST = 1.0  # seconds/call, for the time estimate only
_FLUSH_EVERY = 50
_FLUSH_SECS = 3.0

# Single transient-retry layer: the SDK's own HttpRetryOptions. Configured once
# on the client so EVERY call (smoke + batch) inherits it — no hand-rolled
# backoff stacked on top (avoids the double-retry the smoke crash exposed).
# One exponential policy covers 429 and 5xx; ~1+2+4+8+16s over 5 attempts spans
# both a brief rate-limit (429) window and a 503 "high demand" wave.
_DEFAULT_ATTEMPTS = 5
_RETRY_STATUS = [429, 500, 502, 503, 504]
_RETRY_INITIAL_DELAY = 1.0
_RETRY_MAX_DELAY = 30.0
_RETRY_EXP_BASE = 2.0
_RETRY_JITTER = 1.0


def _make_client(api_key: str, attempts: int) -> genai.Client:
    """Build a client whose SDK retry covers 429/5xx for all calls (DRY)."""
    return genai.Client(
        api_key=api_key,
        http_options=types.HttpOptions(
            retry_options=types.HttpRetryOptions(
                attempts=attempts,
                initial_delay=_RETRY_INITIAL_DELAY,
                max_delay=_RETRY_MAX_DELAY,
                exp_base=_RETRY_EXP_BASE,
                jitter=_RETRY_JITTER,
                http_status_codes=_RETRY_STATUS,
            )
        ),
    )

# Cost model — gemini-2.5-flash (Haziran 2026): $0.30/M in, $2.50/M out.
_PRICE_IN_PER_M, _PRICE_OUT_PER_M = 0.30, 2.50
_EST_IN_TOKENS, _EST_OUT_TOKENS = 400, 40  # per call (system+few-shot+word / JSON)
_EST_RETRY_FACTOR = 1.2

app = typer.Typer(name="generate-clues", help="Gemini çengel ipucu üretici (async).", no_args_is_help=True)

_Cache = dict[str, dict[str, object]]


# ── I/O helpers ────────────────────────────────────────────────────────────────


def _force_utf8_stdout() -> None:
    """Windows console UTF-8 fix (see CLAUDE.md). CLI-entry only."""
    if hasattr(sys.stdout, "buffer"):
        sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8")
    if hasattr(sys.stderr, "buffer"):
        sys.stderr = io.TextIOWrapper(sys.stderr.buffer, encoding="utf-8")


def _load_json(path: Path) -> _Cache:
    if not path.exists():
        return {}
    raw = json.loads(path.read_text(encoding="utf-8"))
    return raw if isinstance(raw, dict) else {}


def _write_json(path: Path, data: _Cache) -> None:
    """Atomic write so a flush interrupted by Ctrl+C never corrupts the file."""
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_suffix(path.suffix + ".tmp")
    tmp.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")
    tmp.replace(path)


def _collect_pool_words(pool_path: Path, min_len: int, max_len: int) -> list[str]:
    """Unique upper-case pool words with min_len <= len <= max_len, sorted."""
    raw = json.loads(pool_path.read_text(encoding="utf-8"))
    words = {tr_upper(str(item["word"])) for item in raw}
    return sorted(w for w in words if min_len <= len(w) <= max_len)


def _smoke_test(client: genai.Client, model: str) -> bool:
    """Confirm key + model access with one tiny call before the batch.

    Uses the same client, so the SDK's HttpRetryOptions already retries a
    transient 503/429 wave here too (no separate backoff). Returns False (and
    explains --skip-smoke) instead of crashing if it still fails after retries.
    """
    try:
        resp = client.models.generate_content(
            model=model, contents="Tek kelimeyle yanıt ver: Türkiye'nin başkenti neresi?"
        )
    except Exception as exc:  # noqa: BLE001 — report cleanly, don't crash pre-batch
        print(f"[smoke] BAŞARISIZ ({type(exc).__name__}): {exc}", file=sys.stderr)
        print("[smoke] Geçici 503/429 dalgası olabilir; --skip-smoke ile atlayabilirsin.", file=sys.stderr)
        return False
    print(f"[smoke] {model} OK -> {(resp.text or '').strip().replace(chr(10), ' ')[:50]}", flush=True)
    return True


def _dashboard(total_pool: int, resolved: int, todo: int, rpm: int, concurrency: int, model: str) -> None:
    """Pre-flight summary: cost + realistic throughput/time estimate."""
    calls = todo * _EST_RETRY_FACTOR
    in_m, out_m = calls * _EST_IN_TOKENS / 1e6, calls * _EST_OUT_TOKENS / 1e6
    cost = in_m * _PRICE_IN_PER_M + out_m * _PRICE_OUT_PER_M
    eff_rps = min(rpm / 60.0, concurrency / _LATENCY_EST)
    minutes = (todo / eff_rps / 60.0) if eff_rps > 0 else 0.0
    tpm = rpm * (_EST_IN_TOKENS + _EST_OUT_TOKENS)
    limited = "rpm" if rpm / 60 < concurrency else "concurrency"
    print("=== PRE-FLIGHT ===")
    print(f"  Model        : {model}")
    print(f"  Havuz        : {total_pool} kelime (len {_MIN_LEN}-{_MAX_LEN})")
    print(f"  Çözülmüş     : {resolved}  |  İşlenecek: {todo}")
    print(f"  Hız          : rpm={rpm} (~{rpm/60:.1f} req/sn), concurrency={concurrency}")
    print(f"  Throughput   : ~{eff_rps:.1f} req/sn ({limited}-sınırlı)")
    print(f"  Süre tahmini : ~{minutes:.0f} dk  (+%20 retry payı)")
    print(f"  Maliyet      : ~${cost:.2f}  (Batch API ile ~${cost/2:.2f})")
    print(f"  TPM          : ~{tpm/1000:.0f}k / ~4M limit  {'✓' if tpm < 4_000_000 else '!!'}")
    print("==================\n", flush=True)


# ── Async orchestration ────────────────────────────────────────────────────────


async def _writer(
    queue: "asyncio.Queue[Result | None]", cache: _Cache, review: _Cache, failed: _Cache,
    model: str, total: int, verbose: bool, stop: asyncio.Event, panic_n: int,
) -> None:
    """Single owner of all file writes; flushes atomically every 50 items / 3 s.

    transient results are NOT persisted (B) so resume retries them. N consecutive
    transient faults trip a panic stop (C): the daily quota / API wall is up, so
    we stop cleanly instead of blindly burning the rest of the daily quota.
    """
    done = ok = rev = fail = trans = recovered = dirty = consec = 0
    last = time.monotonic()

    def flush() -> None:
        _write_json(_CACHE_PATH, cache)
        _write_json(_REVIEW_PATH, review)
        _write_json(_FAILED_PATH, failed)

    while True:
        try:
            item = await asyncio.wait_for(queue.get(), timeout=1.0)
        except asyncio.TimeoutError:
            if dirty and time.monotonic() - last >= _FLUSH_SECS:
                flush()
                dirty, last = 0, time.monotonic()
            continue
        if item is None:
            break
        done += 1
        if item.status == "ok":
            cache[item.word] = {"text": item.text, "source": "gemini", "model": model, "meaning_used": item.meaning}
            ok, consec, dirty = ok + 1, 0, dirty + 1
            recovered += 1 if item.attempt == 2 else 0
        elif item.status == "review":
            review[item.word] = {"text": item.text, "source": "gemini", "model": model, "meaning_used": item.meaning, "reason": item.detail}
            rev, consec, dirty = rev + 1, 0, dirty + 1
        elif item.status == "failed":
            failed[item.word] = {"reason": item.detail, "text": item.text, "model": model}
            fail, consec, dirty = fail + 1, 0, dirty + 1
        else:  # transient — never persisted; resume will retry it
            trans += 1
            consec += 1
            if consec >= panic_n and not stop.is_set():
                print(
                    f"\n[PANIC] {consec} ardışık transient hata — günlük kota / API duvarı. "
                    "Durduruluyor; yarın aynı komutla RESUME et.",
                    flush=True,
                )
                stop.set()
        if verbose:
            if item.status in ("failed", "transient"):
                tag = "FAILED" if item.status == "failed" else "transient"
                print(f"  {item.word:<12} -> [{tag}: {item.detail}]", flush=True)
            else:
                mark = "  [review]" if item.status == "review" else ("  (retry)" if item.attempt == 2 else "")
                print(f'  {item.word:<12} -> "{item.text}" ({len(item.text)}){mark}', flush=True)
        if dirty >= _FLUSH_EVERY or time.monotonic() - last >= _FLUSH_SECS:
            flush()
            dirty, last = 0, time.monotonic()
            if not verbose:
                print(f"  [ilerleme] {done}/{total}  ok={ok} review={rev} failed={fail} transient={trans}", flush=True)
    flush()
    print(f"\nÖZET: ok={ok} (retry-kurtarılan={recovered}) review={rev} failed={fail} "
          f"transient={trans} (tekrar denenecek) / {done} işlendi")


async def _run_async(
    words: list[str], client: genai.Client, model: str, blacklist: set[str],
    rpm: int, concurrency: int, panic_n: int,
    cache: _Cache, review: _Cache, failed: _Cache, verbose: bool,
) -> bool:
    """Run the bounded-concurrency batch; return True if interrupted by Ctrl+C."""
    loop = asyncio.get_running_loop()
    stop = asyncio.Event()
    queue: "asyncio.Queue[Result | None]" = asyncio.Queue()
    sem = asyncio.Semaphore(concurrency)
    bucket = TokenBucket(rpm)

    def _on_sigint(_sig: int, _frame: FrameType | None) -> None:
        loop.call_soon_threadsafe(stop.set)
        print("\n[shutdown] Ctrl+C — yeni istek yok; uçanlar bitiriliyor, son flush...", flush=True)

    prev = signal.getsignal(signal.SIGINT)
    signal.signal(signal.SIGINT, _on_sigint)

    async def _process(word: str) -> None:
        if stop.is_set():
            return
        async with sem:
            if stop.is_set():
                return
            await bucket.acquire()
            if stop.is_set():
                return
            await queue.put(await resolve(client, model, word, blacklist))

    writer = asyncio.create_task(_writer(queue, cache, review, failed, model, len(words), verbose, stop, panic_n))
    try:
        # return_exceptions=True: even a freak error in one task can never cancel
        # the gather / crash the batch (resolve already isolates per-word faults).
        tasks = [asyncio.create_task(_process(w)) for w in words]
        results = await asyncio.gather(*tasks, return_exceptions=True)
        crashes = [r for r in results if isinstance(r, BaseException)]
        if crashes:
            print(f"[uyarı] {len(crashes)} beklenmeyen task hatası yutuldu (örn: {crashes[0]!r})", flush=True)
    finally:
        await queue.put(None)
        await writer
        signal.signal(signal.SIGINT, prev)
    return stop.is_set()


# ── CLI ────────────────────────────────────────────────────────────────────────


@app.callback()
def _callback() -> None:
    """Gemini ile çengel ipuçları üretir (async full-batch)."""


@app.command()
def generate(
    limit: Annotated[int, typer.Option(help="Yalnızca ilk N kelime (0=hepsi)")] = 0,
    pool: Annotated[Path, typer.Option(help="Ana havuz JSON")] = _POOL_PATH,
    min_len: Annotated[int, typer.Option(help="En kısa kelime")] = _MIN_LEN,
    max_len: Annotated[int, typer.Option(help="En uzun kelime")] = _MAX_LEN,
    model: Annotated[str, typer.Option(help="Gemini model id")] = _DEFAULT_MODEL,
    rpm: Annotated[int, typer.Option(help="Dakikalık istek tavanı")] = _DEFAULT_RPM,
    concurrency: Annotated[int, typer.Option(help="Eşzamanlı istek")] = _DEFAULT_CONCURRENCY,
    max_retries: Annotated[int, typer.Option(help="SDK transient retry denemesi (429/5xx)")] = _DEFAULT_ATTEMPTS,
    panic: Annotated[int, typer.Option(help="Üst üste N transient → panic stop")] = _DEFAULT_PANIC,
    skip_smoke: Annotated[bool, typer.Option("--skip-smoke", help="Başlangıç smoke testini atla")] = False,
    force: Annotated[bool, typer.Option(help="Cache'i yok say")] = False,
    verbose: Annotated[bool, typer.Option(help="Her kelimeyi yazdır")] = False,
) -> None:
    """Havuzdaki benzersiz len 3-8 kelimeler için ipucu üretir (resumable)."""
    key = os.environ.get("GEMINI_API_KEY")
    if not key:
        print("GEMINI_API_KEY ortam değişkeni yok.", file=sys.stderr)
        raise typer.Exit(code=1)
    if not pool.exists():
        print(f"Havuz bulunamadı: {pool}.", file=sys.stderr)
        raise typer.Exit(code=1)

    client = _make_client(key, max_retries)
    if not skip_smoke and not _smoke_test(client, model):
        raise typer.Exit(code=1)

    blacklist = load_blacklist(_BLACKLIST_PATH) if _BLACKLIST_PATH.exists() else set()
    cache, review, failed = _load_json(_CACHE_PATH), _load_json(_REVIEW_PATH), _load_json(_FAILED_PATH)
    resolved = set() if force else (set(cache) | set(review) | set(failed))
    all_words = _collect_pool_words(pool, min_len, max_len)
    words = [w for w in all_words if w not in resolved]
    if limit > 0:
        words = words[:limit]
    if not words:
        print("İşlenecek yeni kelime yok (hepsi cache/review/failed'de).")
        return

    _dashboard(len(all_words), len(resolved), len(words), rpm, concurrency, model)
    verbose = verbose or (0 < limit <= 100)
    interrupted = asyncio.run(
        _run_async(words, client, model, blacklist, rpm, concurrency, panic, cache, review, failed, verbose)
    )
    if interrupted:
        print("[durduruldu] Ctrl+C veya panic-stop; cache kaydedildi. Aynı komutla RESUME edebilirsin.")


def main() -> None:
    _force_utf8_stdout()
    app()


if __name__ == "__main__":
    main()
