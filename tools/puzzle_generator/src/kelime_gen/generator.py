# tools/puzzle_generator/src/kelime_gen/generator.py
"""Orchestrates the puzzle generation pipeline (architecture.md section 7.1).

NOTE: word_search_generator (backtracking grid placement) has been removed.
The replacement CSP-based engine is pending implementation.
Pipeline: CSP fill → mask template → clue_writer.
"""

import sys
from pathlib import Path

from kelime_gen.schema import Difficulty, Direction, Level
from kelime_gen.word_pool import PoolEntry

# Retry constants — reserved for the incoming CSP pipeline.
MAX_WORD_RESAMPLES: int = 3
MAX_GRID_RESETS: int = 10


def generate_level(
    level_id: int,
    pack_id: str,
    difficulty: Difficulty,
    category: str,
    category_display_tr: str,
    word_pool: list[PoolEntry],
    grid_size: int,
    directions: list[Direction],
    blacklist: set[str],
    words_per_level: int,
    generator_version: str = "1.0.0",
) -> Level | None:
    """Generate a single validated Level, or None on failure.

    TODO: Implement CSP-based puzzle engine.
    Pipeline: CSP fill → mask template → clue_writer (architecture.md §7.1).
    """
    raise NotImplementedError(
        "generate_level: word-search grid placement removed. "
        "CSP pipeline pending implementation."
    )


def generate_pack(
    pack_id: str,
    level_ids: list[int],
    word_pool: list[PoolEntry],
    difficulty: Difficulty,
    category: str,
    category_display_tr: str,
    grid_size: int,
    directions: list[Direction],
    blacklist: set[str],
    words_per_level: int,
    output_dir: Path,
) -> tuple[int, int]:
    """Generate every level in a pack and write each to JSON.

    Returns (success_count, failure_count). Currently returns (0, len(level_ids))
    until the CSP pipeline is implemented.
    """
    output_dir.mkdir(parents=True, exist_ok=True)
    success = 0
    failed = 0

    for level_id in level_ids:
        level = generate_level(
            level_id=level_id,
            pack_id=pack_id,
            difficulty=difficulty,
            category=category,
            category_display_tr=category_display_tr,
            word_pool=word_pool,
            grid_size=grid_size,
            directions=directions,
            blacklist=blacklist,
            words_per_level=words_per_level,
        )
        if level is None:
            failed += 1
            continue
        if not level.safety.post_fill_scanned:
            failed += 1
            print(
                f"[ERROR] level {level_id}: not scanned — refusing to write.",
                file=sys.stderr,
            )
            continue
        path = output_dir / f"{pack_id}_level_{level_id:04d}.json"
        path.write_text(level.model_dump_json(indent=2), encoding="utf-8")
        success += 1

    return success, failed
