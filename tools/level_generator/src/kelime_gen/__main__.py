# tools/level_generator/src/kelime_gen/__main__.py
"""Typer CLI entry point for the level generator."""

import io
import json
import sys
from pathlib import Path
from typing import Annotated, TypedDict

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


class CategoryProfile(TypedDict):
    """Per-pack generation profile.

    grid_size is matched to length_range so the longest word always fits, and
    words_per_level keeps the empty-cell ratio low enough for safe filling.
    """

    length_range: tuple[int, int]
    grid_size: int
    words_per_level: int
    display: str
    difficulty: Difficulty


# Insertion order defines pack order (pack_001, pack_002, ...).
# Words are capped at 7 letters: longer words add no design value and keep the
# empty-cell ratio low enough that whole-grid re-fill stays reliable.
CATEGORY_PROFILES: dict[str, CategoryProfile] = {
    "kisa_kelimeler": {
        "length_range": (3, 4),
        "grid_size": 8,
        "words_per_level": 6,
        "display": "Başlangıç",
        "difficulty": Difficulty.EASY,
    },
    "genel": {
        "length_range": (3, 6),
        "grid_size": 9,
        "words_per_level": 7,
        "display": "Günlük",
        "difficulty": Difficulty.EASY,
    },
    "orta_kelimeler": {
        "length_range": (5, 6),
        "grid_size": 9,
        "words_per_level": 7,
        "display": "Orta",
        "difficulty": Difficulty.MEDIUM,
    },
    "zor_kelimeler": {
        "length_range": (6, 7),
        "grid_size": 10,
        "words_per_level": 6,
        "display": "Zorlayıcı",
        "difficulty": Difficulty.HARD,
    },
    "karisik": {
        "length_range": (4, 7),
        "grid_size": 10,
        "words_per_level": 7,
        "display": "Karışık",
        "difficulty": Difficulty.MEDIUM,
    },
}


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


@app.callback()
def _callback() -> None:
    """Türkçe Kelime Bulmaca level generator."""
    # Empty callback: forces multi-command mode so `generate` stays a named
    # subcommand instead of being collapsed into the root command by Typer.


@app.command()
def generate(
    count: Annotated[int, typer.Option(help="Üretilecek bölüm sayısı")] = 200,
    output_dir: Annotated[Path, typer.Option(help="Çıktı klasörü")] = Path("assets/levels"),
    grid_size: Annotated[
        int | None,
        typer.Option(help="Tüm pack'leri bu boyuta zorla (opsiyonel override)"),
    ] = None,
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

    profiles = list(CATEGORY_PROFILES.items())
    pack_size, remainder = divmod(count, len(profiles))
    next_level_id = 1
    total_success = 0
    total_failed = 0

    for pack_index, (slug, profile) in enumerate(profiles):
        n_levels = pack_size + (1 if pack_index < remainder else 0)
        if n_levels == 0:
            continue

        # --grid-size, when given, overrides every pack's profile grid size.
        pack_grid = grid_size if grid_size is not None else profile["grid_size"]
        min_len, max_len = profile["length_range"]
        # Only words that can physically fit in this grid.
        cap = min(max_len, pack_grid)
        cat_pool = [e for e in pool if min_len <= len(e["word"]) <= cap]

        level_ids = list(range(next_level_id, next_level_id + n_levels))
        next_level_id += n_levels
        pack_id = f"pack_{pack_index + 1:03d}_{slug}"

        # generate_level samples its words from cat_pool (with resampling).
        ok, fail = generate_pack(
            pack_id=pack_id,
            level_ids=level_ids,
            word_pool=cat_pool,
            difficulty=profile["difficulty"],
            category=slug,
            category_display_tr=profile["display"],
            grid_size=pack_grid,
            directions=directions,
            blacklist=blacklist,
            words_per_level=profile["words_per_level"],
            output_dir=output_dir,
        )
        total_success += ok
        total_failed += fail
        print(f"{pack_id}: {ok} üretildi, {fail} başarısız (grid {pack_grid})")

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
