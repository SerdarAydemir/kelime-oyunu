# tools/level_generator/tests/test_word_search_generator.py
"""Unit tests for the backtracking word-search grid generator."""

import random

import pytest

from kelime_gen.schema import Direction, Position
from kelime_gen.word_search_generator import (
    WordSearchGenerationError,
    fits_at,
    generate_grid,
    verify_placement,
)

_HV = [Direction.HORIZONTAL, Direction.VERTICAL]


@pytest.fixture(autouse=True)
def _seed_rng() -> None:
    """Stable RNG so placement tests never flake."""
    random.seed(42)


def test_places_three_short_words_in_5x5() -> None:
    grid, placements = generate_grid(["KEDİ", "KUŞ", "EV"], grid_size=5, directions=_HV)
    assert len(placements) == 3
    assert len(grid) == 5
    assert all(len(row) == 5 for row in grid)


def test_placed_words_actually_in_grid() -> None:
    grid, placements = generate_grid(["KEDİ", "KUŞ", "EV"], grid_size=5, directions=_HV)
    for placement in placements:
        assert verify_placement(grid, placement)


def test_collision_rejects_differing_letter() -> None:
    grid = [["" for _ in range(3)] for _ in range(3)]
    grid[1][1] = "A"
    # A horizontal word whose middle letter lands on (1,1) as "B" -> conflict.
    assert not fits_at(grid, Position(row=1, col=0), Direction.HORIZONTAL, "XBX")
    # Same letter "A" on (1,1) is compatible.
    assert fits_at(grid, Position(row=1, col=0), Direction.HORIZONTAL, "XAX")


def test_impossible_scenario_raises() -> None:
    with pytest.raises(WordSearchGenerationError) as excinfo:
        generate_grid(["OLAĞANÜSTÜ"], grid_size=4, directions=_HV)
    assert "OLAĞANÜSTÜ" in str(excinfo.value)


def test_placement_fields_are_correct() -> None:
    words = ["KEDİ", "KUŞ", "EV"]
    grid, placements = generate_grid(words, grid_size=6, directions=_HV)
    for placement in placements:
        assert placement.length == len(placement.word)
        assert placement.direction in _HV
        assert 0 <= placement.start.row < 6
        assert 0 <= placement.start.col < 6
        assert verify_placement(grid, placement)
