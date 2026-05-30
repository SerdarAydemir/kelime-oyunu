# tools/puzzle_generator/tests/test_generator.py
"""Unit tests for the level generation orchestrator.

NOTE: Tests that exercised word_search_generator (generate_grid monkeypatch,
safe_fill monkeypatch) have been removed along with that module. They will be
rewritten for the CSP pipeline.
"""

import random
from pathlib import Path

import pytest

from kelime_gen.generator import generate_level, generate_pack
from kelime_gen.schema import Difficulty, Direction
from kelime_gen.word_pool import PoolEntry

_HV = [Direction.HORIZONTAL, Direction.VERTICAL]


@pytest.fixture(autouse=True)
def _seed_rng() -> None:
    random.seed(42)


def _sample_pool() -> list[PoolEntry]:
    return [
        PoolEntry(word="KEDİ", frequency_score=80),
        PoolEntry(word="KUŞ", frequency_score=75),
        PoolEntry(word="EV", frequency_score=90),
    ]


def test_generate_level_raises_not_implemented() -> None:
    """generate_level must raise NotImplementedError until CSP pipeline lands."""
    with pytest.raises(NotImplementedError):
        generate_level(
            level_id=1,
            pack_id="pack_001_test",
            difficulty=Difficulty.EASY,
            category="test",
            category_display_tr="Test",
            word_pool=_sample_pool(),
            grid_size=6,
            directions=_HV,
            blacklist=set(),
            words_per_level=3,
        )


def test_generate_pack_propagates_not_implemented(tmp_path: Path) -> None:
    """generate_pack propagates NotImplementedError from generate_level."""
    with pytest.raises(NotImplementedError):
        generate_pack(
            pack_id="pack_001_test",
            level_ids=[1, 2],
            word_pool=_sample_pool(),
            difficulty=Difficulty.EASY,
            category="test",
            category_display_tr="Test",
            grid_size=6,
            directions=_HV,
            blacklist=set(),
            words_per_level=3,
            output_dir=tmp_path,
        )
