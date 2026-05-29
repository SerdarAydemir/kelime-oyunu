# tools/level_generator/src/kelime_gen/generator.py
"""Orchestrates the level generation pipeline (architecture.md section 7.1).

Ties together grid placement, profanity-safe filling, hint writing, frequency
enrichment and difficulty scoring into a single validated Level. Top-level
retries (grid resets) live here — post_fill_safety deliberately owns only the
filler re-randomization (single responsibility).
"""

import random
import sys
from datetime import datetime, timezone
from pathlib import Path

from kelime_gen.difficulty import difficulty_score
from kelime_gen.hint_writer import write_hints
from kelime_gen.schema import (
    Difficulty,
    Direction,
    GridSize,
    Level,
    Rewards,
    Safety,
    WordPlacement,
)
from kelime_gen.validators.post_fill_safety import SafetyGenerationError, safe_fill
from kelime_gen.word_pool import PoolEntry, tr_upper
from kelime_gen.word_search_generator import (
    WordSearchGenerationError,
    generate_grid,
)

MAX_WORD_RESAMPLES = 3
MAX_GRID_RESETS = 10
SCANNER_VERSION = "1.0.0"
_MIN_WORDS = 3  # Level schema requires at least 3 words.

# Placeholder reward values; tuned later via balancing / Remote Config.
_COINS_BASE = 50
_COINS_PERFECT = 100
_STARS_THRESHOLDS = [60, 120, 180]


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
    """Generate a single validated Level, or None on failure (logged to stderr).

    Three-layer retry (architecture.md section 7.3): up to MAX_WORD_RESAMPLES
    different word samples are drawn from `word_pool`, and each sample gets
    MAX_GRID_RESETS placement+fill attempts with fresh randomness. Resampling
    rescues "cursed" word sets that cannot be filled in any layout.
    """
    sample_size = min(words_per_level, len(word_pool))
    if sample_size < _MIN_WORDS:
        print(
            f"[WARN] level {level_id} skipped: pool too small "
            f"({len(word_pool)} words, need >= {_MIN_WORDS}).",
            file=sys.stderr,
        )
        return None

    for _ in range(MAX_WORD_RESAMPLES):
        words = random.sample(word_pool, sample_size)
        word_strings = [entry["word"] for entry in words]
        freq_by_word = {
            tr_upper(entry["word"]): entry["frequency_score"] for entry in words
        }

        for _ in range(MAX_GRID_RESETS):
            try:
                grid, placements = generate_grid(word_strings, grid_size, directions)
                # Before filling, only word cells are non-empty -> word_cells.
                word_cells = {
                    (r, c)
                    for r, row in enumerate(grid)
                    for c, cell in enumerate(row)
                    if cell != ""
                }
                # word_pool omitted -> filler uses the full Turkish alphabet.
                filled = safe_fill(grid, word_cells, blacklist)
                hints = write_hints([p.word for p in placements], category)
                enriched = [
                    WordPlacement(
                        word=placement.word,
                        start=placement.start,
                        direction=placement.direction,
                        length=placement.length,
                        frequency_score=freq_by_word.get(placement.word, 0),
                        hint_tr=hint,
                    )
                    for placement, hint in zip(placements, hints)
                ]
                level = Level(
                    schema_version=1,
                    level_id=level_id,
                    pack_id=pack_id,
                    difficulty=difficulty,
                    difficulty_score=0,  # replaced below via model_copy
                    category=category,
                    category_display_tr=category_display_tr,
                    grid_size=GridSize(rows=grid_size, cols=grid_size),
                    grid=filled,
                    words=enriched,
                    bonus_words=[],
                    rewards=Rewards(
                        coins_base=_COINS_BASE,
                        coins_perfect=_COINS_PERFECT,
                        stars_threshold_seconds=_STARS_THRESHOLDS,
                    ),
                    safety=Safety(
                        post_fill_scanned=True, scanner_version=SCANNER_VERSION
                    ),
                    generated_at=datetime.now(timezone.utc).isoformat(),
                    generator_version=generator_version,
                )
                score = difficulty_score(level)
                return level.model_copy(update={"difficulty_score": score})
            except (SafetyGenerationError, WordSearchGenerationError):
                continue  # try the next grid layout
            except Exception as exc:  # noqa: BLE001 - report, abandon this sample
                print(f"[ERROR] level {level_id}: {exc}", file=sys.stderr)
                break  # move on to the next word sample

    print(
        f"[WARN] level {level_id} skipped after {MAX_WORD_RESAMPLES} word resamples.",
        file=sys.stderr,
    )
    return None


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

    Every level draws its words from the shared `word_pool` (sampling happens
    inside generate_level). Returns (success_count, failure_count). A level
    whose safety scan flag is not set is never written (defensive double-check).
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
