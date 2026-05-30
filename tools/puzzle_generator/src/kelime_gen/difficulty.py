# tools/level_generator/src/kelime_gen/difficulty.py
"""Computes a 0-100 difficulty score for a generated level.

Formula weights (see architecture.md section 7.4):
  grid_factor       0.20  — larger grid = harder
  word_count_factor 0.20  — more words = harder
  len_factor        0.20  — longer words = harder
  rarity_factor     0.30  — rarer words (low frequency) = harder
  diagonal_factor   0.10  — more diagonals = harder
"""

from kelime_gen.schema import Direction, Level


def _is_diagonal(direction: Direction) -> bool:
    return direction in (Direction.DIAGONAL_DOWN, Direction.DIAGONAL_UP)


def difficulty_score(level: Level) -> int:
    """Return a calibrated difficulty score in [0, 100].

    Weights are experimental and can be tuned via Remote Config (see
    architecture.md section 7.4).
    """
    rows = level.grid_size.rows
    cols = level.grid_size.cols
    words = level.words

    grid_factor = (rows * cols) / (18 * 18)
    word_count_factor = len(words) / 25
    avg_length = sum(w.length for w in words) / len(words)
    len_factor = (avg_length - 2) / 13
    avg_freq = sum(w.frequency_score for w in words) / len(words)
    rarity_factor = 1.0 - (avg_freq / 100.0)
    diagonal_count = sum(1 for w in words if _is_diagonal(w.direction))
    diagonal_factor = diagonal_count / len(words)

    raw = (
        0.20 * grid_factor
        + 0.20 * word_count_factor
        + 0.20 * len_factor
        + 0.30 * rarity_factor
        + 0.10 * diagonal_factor
    )
    return round(min(100.0, max(0.0, raw * 100.0)))
