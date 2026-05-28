# tools/level_generator/src/kelime_gen/__main__.py
"""Typer CLI entry point for the level generator."""

import io
import json
import random
import sys
from pathlib import Path
from typing import Annotated

import typer

from kelime_gen.generator import generate_pack
from kelime_gen.schema import Difficulty, Direction
from kelime_gen.word_pool import PoolEntry, load_blacklist

app = typer.Typer(
    name="kelime-gen",
    help="Türkçe Kelime Bulmaca level generator.",
    no_args_is_help=True,
)

# Generator root (tools/level_generator), resolved from this file's location.
_ROOT = Path(__file__).resolve().parents[2]
_POOL_PATH = _ROOT / "data" / "processed" / "word_pool_cleaned.json"
_BLACKLIST_PATH = _ROOT / "data" / "raw" / "profanity_blacklist.txt"

_NUM_PACKS = 5

# Per-pack: (category slug, Turkish display, min_len, max_len, difficulty).
_CATEGORIES: list[tuple[str, str, int, int, Difficulty]] = [
    ("kisa_kelimeler", "Kısa Kelimeler", 3, 4, Difficulty.EASY),
    ("genel", "Genel", 3, 12, Difficulty.EASY),
    ("orta_kelimeler", "Orta Kelimeler", 5, 7, Difficulty.MEDIUM),
    ("uzun_kelimeler", "Uzun Kelimeler", 8, 12, Difficulty.HARD),
    ("karisik", "Karışık", 3, 12, Difficulty.MEDIUM),
]


def _force_utf8_stdout() -> None:
    """Windows console UTF-8 fix for both stdout and stderr (see CLAUDE.md).

    Both streams are wrapped because the generator writes Turkish error
    messages to stderr.
    """
    if hasattr(sys.stdout, "buffer"):
        sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8")
    if hasattr(sys.stderr, "buffer"):
        sys.stderr = io.TextIOWrapper(sys.stderr.buffer, encoding="utf-8")


def _load_pool(path: Path) -> list[PoolEntry]:
    """Load the cleaned word pool JSON into PoolEntry items."""
    raw = json.loads(path.read_text(encoding="utf-8"))
    return [
        PoolEntry(word=item["word"], frequency_score=item["frequency_score"])
        for item in raw
    ]


def _words_per_level(grid_size: int) -> int:
    """Pick a reasonable word count for the grid size (8x8 -> ~6-8, 10x10 -> ~8-12)."""
    low = max(3, grid_size - 2)
    high = min(25, grid_size + 2)
    return random.randint(low, high)


@app.command()
def generate(
    count: Annotated[int, typer.Option(help="Üretilecek bölüm sayısı")] = 200,
    output_dir: Annotated[Path, typer.Option(help="Çıktı klasörü")] = Path("assets/levels"),
    grid_size: Annotated[int, typer.Option(help="Grid boyutu (NxN)")] = 10,
    include_diagonals: Annotated[
        bool, typer.Option(help="Çapraz yönler eklensin mi")
    ] = False,
) -> None:
    """Bulmaca bölümlerini üretir ve JSON olarak yazar."""
    if not _POOL_PATH.exists():
        print(
            f"Kelime havuzu bulunamadı: {_POOL_PATH}. Önce word_pool çalıştır.",
            file=sys.stderr,
        )
        raise typer.Exit(code=1)

    pool = _load_pool(_POOL_PATH)
    blacklist = load_blacklist(_BLACKLIST_PATH) if _BLACKLIST_PATH.exists() else set()

    directions = [Direction.HORIZONTAL, Direction.VERTICAL]
    if include_diagonals:
        directions += [Direction.DIAGONAL_DOWN, Direction.DIAGONAL_UP]

    pack_size, remainder = divmod(count, _NUM_PACKS)
    next_level_id = 1
    total_success = 0
    total_failed = 0

    for pack_index in range(_NUM_PACKS):
        slug, display, min_len, max_len, difficulty = _CATEGORIES[pack_index]
        n_levels = pack_size + (1 if pack_index < remainder else 0)
        if n_levels == 0:
            continue

        # Only words that can physically fit in this grid.
        cap = min(max_len, grid_size)
        cat_pool = [e for e in pool if min_len <= len(e["word"]) <= cap]

        words_by_level: list[list[PoolEntry]] = []
        for _ in range(n_levels):
            k = min(_words_per_level(grid_size), len(cat_pool))
            words_by_level.append(random.sample(cat_pool, k) if k >= 3 else [])

        level_ids = list(range(next_level_id, next_level_id + n_levels))
        next_level_id += n_levels
        pack_id = f"pack_{pack_index + 1:03d}_{slug}"

        ok, fail = generate_pack(
            pack_id=pack_id,
            level_ids=level_ids,
            words_by_level=words_by_level,
            difficulty=difficulty,
            category=slug,
            category_display_tr=display,
            grid_size=grid_size,
            directions=directions,
            blacklist=blacklist,
            output_dir=output_dir,
        )
        total_success += ok
        total_failed += fail
        print(f"{pack_id}: {ok} üretildi, {fail} başarısız")

    print(f"\nToplam: {total_success} üretildi, {total_failed} başarısız")
    if total_failed > 0:
        raise typer.Exit(code=1)


def main() -> None:
    """Console-script entry point: apply the UTF-8 fix before click parses args.

    Must run before app() so that --help and error text (which contain Turkish
    characters) are written through a UTF-8 stream, not the default cp1252
    console on Windows.
    """
    _force_utf8_stdout()
    app()


if __name__ == "__main__":
    main()
