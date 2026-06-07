# tools/puzzle_generator/scripts/clue_engine.py
"""Per-clue engine for generate_clues.py (architecture.md §7).

Schema, prompt, validation, rate limiting and the Gemini call/resolve loop for a
single word. Orchestration (queue/writer/shutdown), file I/O and the CLI live in
generate_clues.py — split out to keep each module under the 300-line limit.
"""

from __future__ import annotations

import asyncio
import re
import time
from dataclasses import dataclass

from google import genai
from google.genai import types
from pydantic import BaseModel

from kelime_gen.schema import tr_lower, tr_upper

_HARD_CHAR_LIMIT = 30  # validator ceiling (Unicode code points; TR chars = 1)
_TR_LOWER_LETTERS = "a-zçğıöşü"

# Log usage_metadata for the first few calls to prove thinking is off (A).
_USAGE_LOG_LIMIT = 5
_usage_logged = 0


class ClueResponse(BaseModel):
    """Exact JSON shape Gemini must return (SDK-enforced via response_schema)."""

    clue: str
    meaning_used: str
    confident: bool


@dataclass
class Result:
    """One resolved word handed from a worker to the writer task."""

    status: str  # "ok" | "review" | "failed"
    word: str
    text: str
    meaning: str
    detail: str
    attempt: int


# ── Prompt ─────────────────────────────────────────────────────────────────────

_SYSTEM = (
    "Sen Türkçe İskandinav (çengel) bulmaca ipucu yazarısın. Verilen Türkçe "
    "kelime için TEK, çok kısa, vurucu bir ipucu üret. Kurallar:\n"
    "- İpucu EN FAZLA 30 karakter; ideal 15-20 karakter arası.\n"
    "- 1-3 kelimelik, öz, çağrıştırıcı Cross Up stili (sözlük tanımı DEĞİL).\n"
    "- İpucu, kelimeyi VEYA aynı kökten türevini ASLA içermesin (ele verme).\n"
    "- En yaygın/bilinen tek anlama keskin odaklan.\n"
    "- Düzgün Türkçe ve doğru karakterler (ç, ş, ğ, ı, İ, ö, ü).\n"
    "- Kelimeyi gerçekten biliyorsan confident=true; nadir/şüpheli/emin "
    "değilsen confident=false.\n"
    "- meaning_used: ipucunu hangi anlama göre yazdığını 1-3 kelimeyle belirt."
)

_FEWSHOT = (
    'KELİME: OK\n{"clue": "Yaydan fırlatılan", "meaning_used": "silah ok", "confident": true}\n\n'
    'KELİME: DENİZ\n{"clue": "Büyük tuzlu su", "meaning_used": "coğrafya", "confident": true}\n\n'
    'KELİME: BALIK\n{"clue": "Solungaçlı omurgalı", "meaning_used": "canlı", "confident": true}\n\n'
    'KELİME: YÜZ\n{"clue": "Çehre, surat", "meaning_used": "anatomi sima", "confident": true}\n\n'
    '# Kötü (YAPMA): BALIK -> "Balık tutmak" (kökü ele verir)\n'
)


def _user_prompt(word: str, attempt: int, reason: str | None) -> str:
    """Per-word prompt; attempt 2 prepends a strict correction with the reason."""
    base = f"{_FEWSHOT}\nKELİME: {word}\nYalnızca şemaya uygun JSON üret."
    if attempt == 1 or reason is None:
        return base
    return (
        f"ÖNCEKİ DENEME GEÇERSİZDİ. Sebep: {reason}.\n"
        f'Düzelt: ipucu en fazla 30 karakter olmalı ve "{word}" kelimesini/kökünü '
        "KESİNLİKLE içermemeli. Tek, çok kısa, çağrıştırıcı bir ipucu ver.\n" + base
    )


# ── Validation ─────────────────────────────────────────────────────────────────


def validate_clue(clue: str, answer: str, blacklist: set[str]) -> str | None:
    """Return a rejection reason, or None when the clue passes every gate.

    len() counts Unicode code points, so ç/ş/ğ/ı/İ/ö/ü each count as 1.
    """
    text = clue.strip()
    if not text:
        return "boş"
    if len(text) > _HARD_CHAR_LIMIT:
        return f"çok uzun ({len(text)})"
    low_clue, low_ans = tr_lower(text), tr_lower(answer)
    if low_ans in low_clue:
        return "cevabı içeriyor"
    stem = low_ans[: min(4, len(low_ans))]
    tokens = re.findall(f"[{_TR_LOWER_LETTERS}]+", low_clue)
    if len(stem) >= 3:
        for token in tokens:
            if token.startswith(stem):
                return f"cevap kökünü içeriyor ({token})"
    # Profanity: WHOLE-TOKEN match, not substring. Clue text is human-readable
    # Turkish, so real profanity is a whole word; substring scanning falsely
    # rejected innocent words (KANAL ⊃ ANAL, ANANE ⊃ ANAN). (D)
    for token in tokens:
        if tr_upper(token) in blacklist:
            return f"küfür/argo ({token})"
    return None


# ── Rate limiting ──────────────────────────────────────────────────────────────


class TokenBucket:
    """Async token bucket: caps the sustained request rate to rpm/60 per second."""

    def __init__(self, rpm: int) -> None:
        self._rate = max(rpm, 1) / 60.0
        self._capacity = max(1.0, self._rate * 2.0)
        self._tokens = self._capacity
        self._updated = time.monotonic()
        self._lock = asyncio.Lock()

    async def acquire(self) -> None:
        while True:
            async with self._lock:
                now = time.monotonic()
                self._tokens = min(self._capacity, self._tokens + (now - self._updated) * self._rate)
                self._updated = now
                if self._tokens >= 1.0:
                    self._tokens -= 1.0
                    return
                wait = (1.0 - self._tokens) / self._rate
            await asyncio.sleep(wait)


# ── Gemini calls ───────────────────────────────────────────────────────────────


def _maybe_log_usage(word: str, resp: object) -> None:
    """Print usage_metadata for the first few calls (proves thoughts == 0)."""
    global _usage_logged
    if _usage_logged >= _USAGE_LOG_LIMIT:
        return
    um = getattr(resp, "usage_metadata", None)
    if um is None:
        return
    _usage_logged += 1
    print(
        f"[usage] {word}: prompt={getattr(um, 'prompt_token_count', None)} "
        f"candidates={getattr(um, 'candidates_token_count', None)} "
        f"thoughts={getattr(um, 'thoughts_token_count', None)}",
        flush=True,
    )


async def _call_gemini(
    client: genai.Client, model: str, word: str, attempt: int, reason: str | None
) -> ClueResponse:
    """One async structured generation.

    Transient (429/5xx) retry is owned by the SDK's HttpRetryOptions configured
    on the client — no second backoff loop here, so the layers never stack.
    thinking_budget=0 disables thinking tokens (billed as output); flash-lite is
    off by default but we set it explicitly as a guarantee (A).
    """
    config = types.GenerateContentConfig(
        system_instruction=_SYSTEM,
        temperature=0.4,
        response_mime_type="application/json",
        response_schema=ClueResponse,
        thinking_config=types.ThinkingConfig(thinking_budget=0),
    )
    resp = await client.aio.models.generate_content(
        model=model, contents=_user_prompt(word, attempt, reason), config=config
    )
    _maybe_log_usage(word, resp)
    parsed = resp.parsed
    if not isinstance(parsed, ClueResponse):
        raise ValueError("boş/biçimsiz yanıt")
    return parsed


async def resolve(client: genai.Client, model: str, word: str, blacklist: set[str]) -> Result:
    """Resolve one word to an ok/review/failed/transient Result.

    Status routing (B): a real validator rejection (küfür/kök/uzun/boş) is the
    ONLY permanent "failed". ANY exception (SDK retry exhausted, parse error) is
    "transient" — NOT persisted, so resume retries it next run. confident=false
    is "review". This keeps a single word from ever crashing the batch AND keeps
    transient API faults out of the permanent failed set.
    """
    last_clue = last_meaning = ""
    reason: str | None = None
    for attempt in (1, 2):
        try:
            parsed = await _call_gemini(client, model, word, attempt, reason)
        except Exception as exc:  # noqa: BLE001 — transient: don't persist, resume retries
            return Result("transient", word, "", "", f"{type(exc).__name__}: {exc}", attempt)
        clue = parsed.clue.strip()
        if not parsed.confident:
            return Result("review", word, clue, parsed.meaning_used, "confident=false", attempt)
        reason = validate_clue(clue, word, blacklist)
        if reason is None:
            return Result("ok", word, clue, parsed.meaning_used, "", attempt)
        last_clue, last_meaning = clue, parsed.meaning_used
    return Result("failed", word, last_clue, last_meaning, reason or "doğrulanamadı", 2)
