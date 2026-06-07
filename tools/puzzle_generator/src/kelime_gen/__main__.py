# tools/puzzle_generator/src/kelime_gen/__main__.py
"""Typer CLI entry point for the v2 puzzle generator."""

import io
import json
import sys
from pathlib import Path
from typing import Annotated

import typer

from kelime_gen.build_manifest import build_manifest
from kelime_gen.generator import generate_pack
from kelime_gen.pools import build_combined_pool_entries
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
_SYMBOLS_PATH = _ROOT / "data" / "symbols.json"
_TWO_LETTER_PATH = _ROOT / "data" / "two_letter.json"

# Words absent from master_clues.json fall back to the bare placeholder
# ("N harfli kelime"); curated len-1/2 clues always take priority (§7).
_DEFAULT_CATEGORY: str | None = None

# Only medium (8×6) is supported in this phase (architecture.md §5.3).
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
    return [
        PoolEntry(word=item["word"], frequency_score=item["frequency_score"])
        for item in raw
    ]


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
    output_dir: Annotated[Path, typer.Option(help="Çıktı klasörü")] = Path(
        "assets/puzzles"
    ),
    size: Annotated[
        str, typer.Option(help="medium  (small/large: Adım 5'e bırakıldı)")
    ] = "medium",
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
    combined_pool, curated_clues = build_combined_pool_entries(
        main_pool, _SYMBOLS_PATH, _TWO_LETTER_PATH
    )
    master_clues = _load_master_clues(_MASTER_CLUES_PATH)
    blacklist = load_blacklist(_BLACKLIST_PATH) if _BLACKLIST_PATH.exists() else set()
    puzzle_size = PuzzleSize(size)

    success, failed = generate_pack(
        word_pool=combined_pool,
        blacklist=blacklist,
        start_puzzle_id=1,
        count=count,
        category=_DEFAULT_CATEGORY,
        output_dir=output_dir,
        size=puzzle_size,
        curated_clues=curated_clues,
        master_clues=master_clues,
    )

    # Rebuild the manifest so it always reflects the puzzle files on disk; this
    # runs even on partial packs so Flutter never reads a stale manifest (§8).
    manifest = build_manifest(output_dir)

    print(f"\nToplam: {success} üretildi, {failed} başarısız")
    print(f"Manifest güncellendi: {manifest['total_puzzles']} bölüm.")
    if failed > 0:
        raise typer.Exit(code=1)


def main() -> None:
    """Console-script entry point: apply the UTF-8 fix before Typer parses args."""
    _force_utf8_stdout()
    app()


if __name__ == "__main__":
    main()
