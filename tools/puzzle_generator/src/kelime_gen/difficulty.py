# tools/puzzle_generator/src/kelime_gen/difficulty.py
"""Computes a 0-100 difficulty score for a v2 puzzle (architecture.md §6).

Factors and weights:
  grid_factor       0.20  larger board     = harder
  word_count_factor 0.20  more words       = harder
  avg_len_factor    0.20  longer words     = harder
  rarity_factor     0.30  rarer words      = harder (low frequency_score)
  clue_density      0.10  more clue cells  = harder
"""

from kelime_gen.schema import CellType, PuzzleData

# Upper bounds used to normalize each factor into [0, 1]; they mirror the
# field constraints in schema.py (GridSize, words max_length, WordSpec.length).
_MAX_ROWS = 12
_MAX_COLS = 10
_MAX_WORDS = 30
_MAX_WORD_LEN = 15


def difficulty_score(puzzle: PuzzleData) -> int:
    """Return a calibrated difficulty score in [0, 100]."""
    rows = puzzle.grid.rows
    cols = puzzle.grid.cols
    words = puzzle.words

    grid_factor = (rows * cols) / (_MAX_ROWS * _MAX_COLS)
    word_count_factor = len(words) / _MAX_WORDS
    avg_len = sum(w.length for w in words) / len(words)
    avg_len_factor = (avg_len - 1) / (_MAX_WORD_LEN - 1)
    avg_freq = sum(w.frequency_score for w in words) / len(words)
    rarity_factor = 1.0 - (avg_freq / 100.0)
    clue_cells = sum(1 for c in puzzle.cells if c.type == CellType.CLUE)
    clue_density = clue_cells / len(puzzle.cells)

    raw = (
        0.20 * grid_factor
        + 0.20 * word_count_factor
        + 0.20 * avg_len_factor
        + 0.30 * rarity_factor
        + 0.10 * clue_density
    )
    return round(min(100.0, max(0.0, raw * 100.0)))
