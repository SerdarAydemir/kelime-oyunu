# tools/puzzle_generator/src/kelime_gen/__main__.py
"""Typer CLI entry point for the v2 puzzle generator."""

import io
import json
import sys
import time
from datetime import datetime, timezone
from pathlib import Path
from typing import Annotated

import typer

from kelime_gen.build_manifest import build_manifest
from kelime_gen.generator import generate_pack
from kelime_gen.mask_synth_frame import load_library
from kelime_gen.pack_report import build_report, format_report, verify_pack, write_report
from kelime_gen.pools import build_combined_pool_entries, load_excluded_answers
from kelime_gen.schema import PuzzleSize, tr_upper
from kelime_gen.word_pool import PoolEntry, load_blacklist

app = typer.Typer(
    name="kelime-gen",
    help="Türkçe Kelime Bulmaca puzzle generator (v2).",
    no_args_is_help=True,
)

# Generator root (tools/puzzle_generator), resolved from this file's location.
_ROOT = Path(__file__).resolve().parents[2]
_POOL_PATH = _ROOT / "data" / "processed" / "word_pool_cleaned.json"
_MASTER_CLUES_PATH = _ROOT / "data" / "processed" / "master_clues.json"
_BLACKLIST_PATH = _ROOT / "data" / "raw" / "profanity_blacklist.txt"
_SENSITIVE_PATH = _ROOT / "data" / "raw" / "sensitive_answers.txt"
_REJECTED_PATH = _ROOT / "data" / "processed" / "rejected_words.json"
_SYMBOLS_PATH = _ROOT / "data" / "symbols.json"
_TWO_LETTER_PATH = _ROOT / "data" / "two_letter.json"
# Full-frame mask library cache (derived, reproducible -> not committed) and
# the per-run generation reports.
_FRAME_CACHE_PATH = _ROOT / "data" / "cache" / "frame_masks_9x7.json"
_REPORTS_DIR = _ROOT / "reports"

# Category hint for the clue writer's placeholder tier. Kept None: since the
# P0 gate, pool words without a master clue never reach the writer, so the
# placeholder tiers exist only as a guarded fallback (generator skips on them).
_DEFAULT_CATEGORY: str | None = None

# Only medium (9×7 full frame) is supported in this phase.
_VALID_SIZES = ("medium",)


def _force_utf8_stdout() -> None:
    """Windows console UTF-8 fix for stdout and stderr (see CLAUDE.md).

    Both streams are wrapped because the generator writes Turkish messages to
    stderr. Called only from main(), never at import time.
    """
    if hasattr(sys.stdout, "buffer"):
        sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8")
    if hasattr(sys.stderr, "buffer"):
        sys.stderr = io.TextIOWrapper(sys.stderr.buffer, encoding="utf-8")


def _load_main_pool(path: Path) -> list[PoolEntry]:
    """Load the cleaned word pool JSON into PoolEntry items."""
    raw = json.loads(path.read_text(encoding="utf-8"))
    return [PoolEntry(word=item["word"], frequency_score=item["frequency_score"]) for item in raw]


def _load_master_clues(path: Path) -> dict[str, str]:
    """Load master_clues.json into an upper-cased answer -> clue text map.

    Keys are tr_upper-normalised so they match the upper-cased answer strings
    the combined pool produces (architecture.md §7.6).
    """
    raw = json.loads(path.read_text(encoding="utf-8"))
    return {tr_upper(word): entry["text"] for word, entry in raw.items()}


@app.callback()
def _callback() -> None:
    """Türkçe Kelime Bulmaca puzzle generator."""
    # Empty callback forces multi-command mode so `generate` stays a named
    # subcommand instead of collapsing into the root command.


@app.command()
def generate(
    count: Annotated[int, typer.Option(help="Üretilecek bulmaca sayısı")] = 200,
    output_dir: Annotated[Path, typer.Option(help="Çıktı klasörü")] = Path("assets/puzzles"),
    size: Annotated[str, typer.Option(help="medium  (small/large: Adım 5'e bırakıldı)")] = "medium",
) -> None:
    """Bulmaca bölümlerini synth mask ile üretir ve JSON olarak yazar."""
    if size not in _VALID_SIZES:
        print(
            f"Geçersiz size '{size}'. Desteklenen: {', '.join(_VALID_SIZES)}.",
            file=sys.stderr,
        )
        raise typer.Exit(code=1)

    if not _POOL_PATH.exists():
        print(
            f"Kelime havuzu bulunamadı: {_POOL_PATH}. Önce word_pool çalıştır.",
            file=sys.stderr,
        )
        raise typer.Exit(code=1)

    for data_path in (_SYMBOLS_PATH, _TWO_LETTER_PATH, _MASTER_CLUES_PATH):
        if not data_path.exists():
            print(f"Veri dosyası bulunamadı: {data_path}.", file=sys.stderr)
            raise typer.Exit(code=1)

    main_pool = _load_main_pool(_POOL_PATH)
    master_clues = _load_master_clues(_MASTER_CLUES_PATH)
    # P2/P0 pool hygiene: sensitive + audit-rejected answers never enter the
    # pool, and main-pool words without a master clue are held back so the
    # placeholder fallback cannot trigger (prevention half of the gate).
    excluded = load_excluded_answers(_SENSITIVE_PATH, _REJECTED_PATH)
    combined_pool, curated_clues = build_combined_pool_entries(
        main_pool,
        _SYMBOLS_PATH,
        _TWO_LETTER_PATH,
        excluded=excluded,
        master_clue_answers=frozenset(master_clues),
    )
    blacklist = load_blacklist(_BLACKLIST_PATH) if _BLACKLIST_PATH.exists() else set()
    puzzle_size = PuzzleSize(size)

    # Frame mask library: loaded from cache, or enumerated once (~30 s).
    lib_started = time.perf_counter()
    library = load_library(_FRAME_CACHE_PATH)
    print(
        f"Mask kütüphanesi: {len(library)} mask "
        f"({time.perf_counter() - lib_started:.1f} sn, kaynak: {_FRAME_CACHE_PATH.name})"
    )

    pack_started = time.perf_counter()
    result = generate_pack(
        word_pool=combined_pool,
        blacklist=blacklist,
        start_puzzle_id=1,
        count=count,
        category=_DEFAULT_CATEGORY,
        output_dir=output_dir,
        library=library,
        size=puzzle_size,
        curated_clues=curated_clues,
        master_clues=master_clues,
    )
    total_seconds = time.perf_counter() - pack_started

    # Rebuild the manifest so it always reflects the puzzle files on disk; this
    # runs even on partial packs so Flutter never reads a stale manifest (§8).
    manifest = build_manifest(output_dir)

    # Independent post-generation verification + persisted report.
    verification = verify_pack(output_dir, expected_count=count)
    report = build_report(verification, list(result.stats), total_seconds)
    stamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    report_path = _REPORTS_DIR / f"generation_report_{stamp}.json"
    write_report(report, report_path)

    print(f"\nToplam: {result.success} üretildi, {result.failed} başarısız")
    print(f"Manifest güncellendi: {manifest['total_puzzles']} bölüm.")
    print(f"Rapor: {report_path}\n")
    print(format_report(report))
    if result.failed > 0 or not verification["ok"]:
        raise typer.Exit(code=1)


def main() -> None:
    """Console-script entry point: apply the UTF-8 fix before Typer parses args."""
    _force_utf8_stdout()
    app()


if __name__ == "__main__":
    main()
