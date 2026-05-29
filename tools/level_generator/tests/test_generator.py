# tools/level_generator/tests/test_generator.py
"""Unit tests for the level generation orchestrator."""

import random
import re
from pathlib import Path

import pytest

from kelime_gen import generator
from kelime_gen.generator import generate_level, generate_pack
from kelime_gen.schema import Difficulty, Direction, Level
from kelime_gen.validators.post_fill_safety import SafetyGenerationError
from kelime_gen.word_pool import PoolEntry

_HV = [Direction.HORIZONTAL, Direction.VERTICAL]


@pytest.fixture(autouse=True)
def _seed_rng() -> None:
    random.seed(42)


def _sample_words() -> list[PoolEntry]:
    return [
        PoolEntry(word="KEDİ", frequency_score=80),
        PoolEntry(word="KUŞ", frequency_score=75),
        PoolEntry(word="EV", frequency_score=90),
    ]


def test_generate_level_success() -> None:
    level = generate_level(
        level_id=1,
        pack_id="pack_001_test",
        difficulty=Difficulty.EASY,
        category="test",
        category_display_tr="Test",
        words=_sample_words(),
        grid_size=6,
        directions=_HV,
        blacklist=set(),
    )
    assert isinstance(level, Level)
    assert level.safety.post_fill_scanned is True
    assert level.difficulty_score > 0
    assert all(w.frequency_score > 0 for w in level.words)
    for word in level.words:
        assert re.fullmatch(r"\d+ harfli bir test kelimesi", word.hint_tr)


def test_generate_level_impossible_returns_none() -> None:
    # Three 10-letter words cannot fit in a 4x4 grid -> retries exhausted -> None.
    words = [
        PoolEntry(word="ABCDEFGHIJ", frequency_score=10),
        PoolEntry(word="KLMNOPRSTU", frequency_score=10),
        PoolEntry(word="VYZABCDEFG", frequency_score=10),
    ]
    level = generate_level(
        level_id=99,
        pack_id="pack_x",
        difficulty=Difficulty.HARD,
        category="test",
        category_display_tr="Test",
        words=words,
        grid_size=4,
        directions=_HV,
        blacklist=set(),
    )
    assert level is None


def test_generate_pack_writes_files(tmp_path: Path) -> None:
    words_by_level = [_sample_words(), _sample_words()]
    ok, fail = generate_pack(
        pack_id="pack_001_test",
        level_ids=[1, 2],
        words_by_level=words_by_level,
        difficulty=Difficulty.EASY,
        category="test",
        category_display_tr="Test",
        grid_size=6,
        directions=_HV,
        blacklist=set(),
        output_dir=tmp_path,
    )
    assert ok == 2
    assert fail == 0
    files = sorted(tmp_path.glob("*.json"))
    assert len(files) == 2
    assert (tmp_path / "pack_001_test_level_0001.json").exists()
    # Written files parse back into valid Level objects.
    Level.model_validate_json(files[0].read_text(encoding="utf-8"))


def test_retries_after_safety_error(monkeypatch: pytest.MonkeyPatch) -> None:
    calls = {"n": 0}
    real_safe_fill = generator.safe_fill

    def flaky_safe_fill(
        grid: list[list[str]],
        word_cells: set[tuple[int, int]],
        blacklist: set[str],
        word_pool: list[str] | None = None,
    ) -> list[list[str]]:
        calls["n"] += 1
        if calls["n"] == 1:
            raise SafetyGenerationError("forced failure on first attempt")
        return real_safe_fill(grid, word_cells, blacklist, word_pool)

    monkeypatch.setattr(generator, "safe_fill", flaky_safe_fill)

    level = generate_level(
        level_id=1,
        pack_id="pack_001_test",
        difficulty=Difficulty.EASY,
        category="test",
        category_display_tr="Test",
        words=_sample_words(),
        grid_size=6,
        directions=_HV,
        blacklist=set(),
    )
    assert level is not None
    assert calls["n"] == 2  # retried once after the SafetyGenerationError
