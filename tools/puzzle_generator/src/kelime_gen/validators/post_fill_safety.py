# tools/level_generator/src/kelime_gen/validators/post_fill_safety.py
"""Filler letter generation and profanity scanning for word-search grids.

After words are placed, the empty cells are filled with weighted-random
Turkish letters. Random filling can accidentally spell a blacklisted word in
any of the eight reading directions, so every filled grid is scanned and
re-randomized until clean (the "Scrabble effect"; see architecture.md 7.3).

Single responsibility: this module only re-randomizes the filler. Higher-level
retries (grid resets, word resampling) live in the orchestrator.
"""

import random

Grid = list[list[str]]

# Turkish letter frequencies (%) used to weight filler letters.
# See architecture.md section 7.5.
TR_LETTER_FREQUENCY: dict[str, float] = {
    "A": 11.92, "E": 8.91, "İ": 8.60, "N": 7.49, "R": 6.95,
    "L": 5.92, "I": 5.20, "K": 4.71, "D": 4.68, "M": 3.75,
    "U": 3.43, "Y": 3.34, "T": 3.14, "S": 3.01, "O": 2.61,
    "Ü": 1.88, "Ş": 1.78, "Z": 1.50, "Ö": 1.33, "B": 1.29,
    "C": 0.90, "Ç": 0.89, "H": 0.88, "G": 0.85, "Ğ": 0.79,
    "F": 0.46, "J": 0.04, "V": 0.91, "P": 0.89,
}

MAX_FILL_ATTEMPTS = 100

# Fallback weight for any letter missing from TR_LETTER_FREQUENCY.
_FALLBACK_WEIGHT = 0.04


class SafetyGenerationError(Exception):
    """Raised when a profanity-free filler cannot be found in time."""


def _lines(grid: Grid) -> list[list[str]]:
    """Return every horizontal and vertical line as a cell list.

    Diagonal directions are intentionally excluded: this is a crossword-style
    puzzle where words only run right or down. Players never read diagonals,
    so diagonal profanity scanning would produce false positives and make CSP
    fill unnecessarily hard. See architecture.md §6.4.
    """
    rows = len(grid)
    cols = len(grid[0]) if rows else 0
    lines: list[list[str]] = []

    # Horizontal (rows) and vertical (columns) only.
    for r in range(rows):
        lines.append(list(grid[r]))
    for c in range(cols):
        lines.append([grid[r][c] for r in range(rows)])

    return lines


def _segments(line: list[str]) -> list[str]:
    """Split a line into maximal runs of non-empty cells (empties break runs)."""
    segments: list[str] = []
    current: list[str] = []
    for cell in line:
        if cell == "":
            if current:
                segments.append("".join(current))
                current = []
        else:
            current.append(cell)
    if current:
        segments.append("".join(current))
    return segments


def scan_segment(
    text: str,
    blacklist: frozenset[str] | set[str],
    min_n: int = 3,
    max_n: int = 6,
) -> list[str]:
    """Scan one contiguous run (forward and reversed) for blacklisted substrings.

    This is the shared primitive used both by scan_grid (full-grid post-fill
    scan) and by the CSP filler's incremental profanity guard, so the two
    layers reject exactly the same strings by construction. Returns every
    matched window of length min_n..max_n (may contain duplicates).
    """
    hits: list[str] = []
    for variant in (text, text[::-1]):
        length = len(variant)
        for n in range(min_n, max_n + 1):
            for i in range(length - n + 1):
                window = variant[i : i + n]
                if window in blacklist:
                    hits.append(window)
    return hits


def scan_grid(
    grid: Grid,
    blacklist: set[str],
    min_n: int = 3,
    max_n: int = 6,
) -> list[str]:
    """Scan horizontal and vertical lines for blacklisted substrings.

    Diagonal directions are not scanned (crossword puzzle, not word-search).
    Each contiguous filled run is checked both forward and reversed, so a
    blacklisted word written backwards is also caught. Empty ("") cells break
    a line into segments. Returns every matched substring (may contain dupes).
    """
    hits: list[str] = []
    for line in _lines(grid):
        for segment in _segments(line):
            hits.extend(scan_segment(segment, blacklist, min_n, max_n))
    return hits


def _randomize_fill(
    grid: Grid,
    word_cells: set[tuple[int, int]],
    letter_pool: list[str],
    weights: list[float],
) -> Grid:
    """Fill every non-word cell with a weighted-random letter.

    Word cells are left untouched. Returns an independent copy of the grid.
    """
    rows = len(grid)
    cols = len(grid[0]) if rows else 0
    new_grid: Grid = [row[:] for row in grid]

    positions = [
        (r, c)
        for r in range(rows)
        for c in range(cols)
        if (r, c) not in word_cells
    ]
    if positions:
        letters = random.choices(letter_pool, weights=weights, k=len(positions))
        for (r, c), letter in zip(positions, letters):
            new_grid[r][c] = letter
    return new_grid


def safe_fill(
    grid: Grid,
    word_cells: set[tuple[int, int]],
    blacklist: set[str],
    word_pool: list[str] | None = None,
) -> Grid:
    """Fill empty cells with safe filler letters and return a clean grid.

    The filler alphabet defaults to the full 29-letter Turkish alphabet. A
    narrow, word-derived alphabet concentrates on common letters and collides
    with the profanity blacklist too often, so the full alphabet (which
    includes rare letters) is used for real generation.

    `word_pool` is optional: when provided, the filler alphabet is restricted
    to the letters present in it (weighted by TR_LETTER_FREQUENCY). This is
    used to make the impossible-fill scenario deterministic in tests; an empty
    pool falls back to the full alphabet. Tries up to MAX_FILL_ATTEMPTS
    re-randomizations.

    Raises:
        SafetyGenerationError: if no profanity-free fill is found in time.
    """
    if word_pool is None:
        letter_pool = sorted(TR_LETTER_FREQUENCY)
    else:
        letter_pool = sorted({letter for word in word_pool for letter in word})
        if not letter_pool:
            letter_pool = sorted(TR_LETTER_FREQUENCY)
    weights = [TR_LETTER_FREQUENCY.get(letter, _FALLBACK_WEIGHT) for letter in letter_pool]

    for _ in range(MAX_FILL_ATTEMPTS):
        candidate = _randomize_fill(grid, word_cells, letter_pool, weights)
        if not scan_grid(candidate, blacklist):
            return candidate

    raise SafetyGenerationError(
        f"Could not produce a profanity-free fill after {MAX_FILL_ATTEMPTS} attempts.",
    )
