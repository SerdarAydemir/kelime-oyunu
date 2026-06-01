# tools/level_generator/tests/test_post_fill_safety.py
"""Unit tests for filler generation and profanity scanning.

Blacklist fixtures use nonsense sentinel strings ("BCDFG" etc.), never real
profanity.
"""

import random
from itertools import product

import pytest

from kelime_gen.validators.post_fill_safety import (
    TR_LETTER_FREQUENCY,
    SafetyGenerationError,
    safe_fill,
    scan_grid,
)


@pytest.fixture(autouse=True)
def _seed_rng() -> None:
    """Stable RNG so filler tests never flake."""
    random.seed(42)


def test_scan_clean_full_grid_returns_empty() -> None:
    grid = [["A", "A", "A"] for _ in range(3)]
    assert scan_grid(grid, blacklist={"BCDFG"}) == []


def test_scan_detects_horizontal() -> None:
    grid = [list("BCDFG")]
    assert "BCDFG" in scan_grid(grid, blacklist={"BCDFG"})


def test_scan_detects_horizontal_reversed() -> None:
    grid = [list("GFDCB")]  # reverse reading spells the blacklisted word
    assert "BCDFG" in scan_grid(grid, blacklist={"BCDFG"})


def test_scan_detects_vertical() -> None:
    grid = [["B"], ["C"], ["D"], ["F"], ["G"]]
    assert "BCDFG" in scan_grid(grid, blacklist={"BCDFG"})


def test_scan_does_not_detect_diagonal() -> None:
    """Diagonal patterns must NOT be flagged — crossword, not word-search."""
    word = "BCDFG"
    grid = [["" for _ in range(5)] for _ in range(5)]
    for i, letter in enumerate(word):
        grid[i][i] = letter  # down-right main diagonal — invisible to players
    assert scan_grid(grid, blacklist={"BCDFG"}) == []


def test_scan_empty_cell_breaks_chain() -> None:
    # "BCDFG" is split by an empty cell -> segments "BCD" and "FG" -> no match.
    grid = [["B", "C", "D", "", "F", "G"]]
    assert scan_grid(grid, blacklist={"BCDFG"}) == []


def test_safe_fill_produces_clean_full_grid() -> None:
    grid = [
        ["K", "E", "D"],
        ["", "", ""],
        ["", "", ""],
    ]
    word_cells = {(0, 0), (0, 1), (0, 2)}
    # Default filler alphabet (word_pool omitted).
    result = safe_fill(grid, word_cells=word_cells, blacklist={"BCDFG"})
    # Word cells untouched.
    assert result[0] == ["K", "E", "D"]
    # No empty cells remain.
    assert all(cell != "" for row in result for cell in row)


def test_safe_fill_default_uses_full_alphabet() -> None:
    # No word_pool -> filler drawn from the full Turkish alphabet.
    grid = [["" for _ in range(5)] for _ in range(5)]
    result = safe_fill(grid, word_cells=set(), blacklist=set())
    cells = [cell for row in result for cell in row]
    # Fully filled with valid Turkish letters.
    assert all(cell != "" for cell in cells)
    assert all(cell in TR_LETTER_FREQUENCY for cell in cells)
    # A wide alphabet was used, not a narrow word-derived pool.
    assert len(set(cells)) >= 6


def test_safe_fill_impossible_raises() -> None:
    # Alphabet {A, B}; blacklist every trigram over it -> no clean fill exists.
    all_trigrams = {"".join(combo) for combo in product("AB", repeat=3)}
    grid = [["", "", ""]]
    with pytest.raises(SafetyGenerationError):
        safe_fill(
            grid,
            word_cells=set(),
            blacklist=all_trigrams,
            word_pool=["AB"],
        )
