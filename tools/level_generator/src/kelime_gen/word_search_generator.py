# tools/level_generator/src/kelime_gen/word_search_generator.py
"""Backtracking word-search grid generator.

Places a list of words into an NxN grid along the requested directions.
Empty cells are left as "" — random filler is the responsibility of
post_fill_safety, not this module (see architecture.md section 7.1).

`generate_grid` returns fully-built `WordPlacement` objects. Since the grid
generator does not know per-word `frequency_score` or `hint_tr` yet, those are
filled with placeholders (0 / "") and enriched later by the orchestrator.
"""

import io
import random
import sys
from dataclasses import dataclass, field

from kelime_gen.schema import Direction, Position, WordPlacement
from kelime_gen.word_pool import tr_upper

Grid = list[list[str]]
Cells = list[tuple[int, int]]

# Row/column step for each direction. DIAGONAL_DOWN goes top-left -> bottom-right,
# DIAGONAL_UP goes bottom-left -> top-right. See architecture.md section 4.1.
_DELTAS: dict[Direction, tuple[int, int]] = {
    Direction.HORIZONTAL: (0, 1),
    Direction.VERTICAL: (1, 0),
    Direction.DIAGONAL_DOWN: (1, 1),
    Direction.DIAGONAL_UP: (-1, 1),
}


class WordSearchGenerationError(Exception):
    """Raised when the words cannot be placed within the attempt budget."""


def _force_utf8_stdout() -> None:
    """Windows console UTF-8 fix (see CLAUDE.md). Called only from main()."""
    if hasattr(sys.stdout, "buffer"):
        sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8")


@dataclass
class _SearchState:
    """Mutable bookkeeping shared across the recursive search."""

    attempts: int = 0
    deepest: int = 0
    placements: list[WordPlacement] = field(default_factory=list)


def _path_cells(start: Position, direction: Direction, length: int) -> Cells:
    """Return the cell coordinates a word would occupy (no bounds check)."""
    delta_row, delta_col = _DELTAS[direction]
    return [
        (start.row + step * delta_row, start.col + step * delta_col)
        for step in range(length)
    ]


def fits_at(grid: Grid, start: Position, direction: Direction, word: str) -> bool:
    """Return True if `word` can occupy the path without conflict.

    A cell is compatible when it is empty ("") or already holds the same
    letter; a differing letter rejects the placement. Out-of-bounds paths are
    rejected.
    """
    rows = len(grid)
    cols = len(grid[0]) if rows else 0
    cells = _path_cells(start, direction, len(word))
    for (row, col), letter in zip(cells, word):
        if not (0 <= row < rows and 0 <= col < cols):
            return False
        existing = grid[row][col]
        if existing != "" and existing != letter:
            return False
    return True


def _candidate_placements(
    grid_size: int,
    directions: list[Direction],
    word: str,
) -> list[tuple[Position, Direction]]:
    """Enumerate every in-bounds (start, direction) pair, shuffled."""
    candidates: list[tuple[Position, Direction]] = []
    for direction in directions:
        for row in range(grid_size):
            for col in range(grid_size):
                start = Position(row=row, col=col)
                cells = _path_cells(start, direction, len(word))
                if all(0 <= r < grid_size and 0 <= c < grid_size for r, c in cells):
                    candidates.append((start, direction))
    random.shuffle(candidates)
    return candidates


def _write(grid: Grid, cells: Cells, word: str) -> Cells:
    """Write `word` along `cells`, returning the cells that were newly filled."""
    newly_filled: Cells = []
    for (row, col), letter in zip(cells, word):
        if grid[row][col] == "":
            newly_filled.append((row, col))
        grid[row][col] = letter
    return newly_filled


def _erase(grid: Grid, cells: Cells) -> None:
    """Reset the given cells back to empty (undo a placement)."""
    for row, col in cells:
        grid[row][col] = ""


def _solve(
    grid: Grid,
    words: list[str],
    index: int,
    grid_size: int,
    directions: list[Direction],
    max_attempts: int,
    state: _SearchState,
) -> bool:
    """Recursively place words[index:] into the grid via backtracking."""
    if index == len(words):
        return True
    state.deepest = max(state.deepest, index)

    word = words[index]
    for start, direction in _candidate_placements(grid_size, directions, word):
        if state.attempts >= max_attempts:
            raise WordSearchGenerationError(
                f"Could not place word '{words[state.deepest]}' "
                f"within {max_attempts} attempts.",
            )
        state.attempts += 1
        if not fits_at(grid, start, direction, word):
            continue

        cells = _path_cells(start, direction, len(word))
        newly_filled = _write(grid, cells, word)
        placement = WordPlacement(
            word=word,
            start=start,
            direction=direction,
            length=len(word),
            frequency_score=0,  # placeholder; enriched by orchestrator
            hint_tr="",  # placeholder; enriched by hint_writer
        )
        state.placements.append(placement)

        if _solve(grid, words, index + 1, grid_size, directions, max_attempts, state):
            return True

        # Backtrack: undo this placement and try the next candidate.
        state.placements.pop()
        _erase(grid, newly_filled)

    return False


def generate_grid(
    words: list[str],
    grid_size: int,
    directions: list[Direction],
    max_attempts: int = 1000,
) -> tuple[Grid, list[WordPlacement]]:
    """Place `words` into a `grid_size` x `grid_size` grid.

    Words are normalized to Turkish upper-case and attempted longest-first.
    Returns the filled grid (empty cells as "") and the placements.

    Raises:
        WordSearchGenerationError: if a valid layout is not found within
            `max_attempts`, naming the word that could not be placed.
    """
    normalized = sorted((tr_upper(w.strip()) for w in words), key=len, reverse=True)
    grid: Grid = [["" for _ in range(grid_size)] for _ in range(grid_size)]
    state = _SearchState()

    if not _solve(grid, normalized, 0, grid_size, directions, max_attempts, state):
        stuck = normalized[state.deepest] if normalized else "<none>"
        raise WordSearchGenerationError(
            f"Could not place word '{stuck}' "
            f"(exhausted layouts after {state.attempts} attempts).",
        )

    return grid, state.placements


def verify_placement(grid: Grid, placement: WordPlacement) -> bool:
    """Return True if `placement.word` reads correctly along its path in `grid`."""
    rows = len(grid)
    cols = len(grid[0]) if rows else 0
    cells = _path_cells(placement.start, placement.direction, placement.length)
    for (row, col), letter in zip(cells, placement.word):
        if not (0 <= row < rows and 0 <= col < cols):
            return False
        if grid[row][col] != letter:
            return False
    return True


def main() -> None:
    """Demo: place a few words into an 8x8 grid and print the result."""
    _force_utf8_stdout()
    words = ["KELİME", "KEDİ", "KUŞ", "ELMA", "DENİZ"]
    grid, placements = generate_grid(
        words,
        grid_size=8,
        directions=[Direction.HORIZONTAL, Direction.VERTICAL],
    )
    for row in grid:
        print(" ".join(cell or "." for cell in row))
    print()
    for placement in placements:
        print(
            f"{placement.word:8s} {placement.direction.value:12s} "
            f"({placement.start.row},{placement.start.col})",
        )


if __name__ == "__main__":
    main()
