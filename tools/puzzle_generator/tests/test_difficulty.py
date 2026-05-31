# tools/puzzle_generator/tests/test_difficulty.py
"""Unit tests for the v2 difficulty score formula.

The scenarios use model_copy to fabricate grid / words / cells field values:
difficulty_score only reads counts, lengths, frequencies and cell types, so a
single validated base puzzle can be reshaped without re-running cross-field
schema validation. This keeps the formula tests small and focused.
"""

from kelime_gen.difficulty import difficulty_score
from kelime_gen.schema import (
    CellSpec,
    CellType,
    ClueArrow,
    ClueSpec,
    GridSize,
    PuzzleData,
    PuzzleSize,
    SafetyInfo,
    WordCell,
    WordSpec,
)


def _word(word_id: str, answer: str, freq: int) -> WordSpec:
    n = len(answer)
    return WordSpec(
        id=word_id,
        answer=answer,
        length=n,
        direction=ClueArrow.RIGHT,
        clue_cell=WordCell(row=0, col=0),
        start_cell=WordCell(row=0, col=1),
        cells=[WordCell(row=0, col=1 + i) for i in range(n)],
        clue=ClueSpec(text="ipucu", arrow=ClueArrow.RIGHT, word_id=word_id),
        frequency_score=freq,
    )


def _clue_cell() -> CellSpec:
    return CellSpec(
        row=0,
        col=0,
        type=CellType.CLUE,
        clues=[ClueSpec(text="x", arrow=ClueArrow.RIGHT, word_id="w")],
    )


def _letter_cell() -> CellSpec:
    return CellSpec(row=0, col=0, type=CellType.LETTER, solution="A")


# A single fully valid base puzzle; scenarios reshape it via model_copy.
_BASE = PuzzleData(
    puzzle_id=1,
    size=PuzzleSize.SMALL,
    grid=GridSize(rows=4, cols=5),
    cells=[
        CellSpec(
            row=1,
            col=0,
            type=CellType.CLUE,
            clues=[ClueSpec(text="ipucu", arrow=ClueArrow.RIGHT, word_id="w1")],
        ),
        CellSpec(row=1, col=1, type=CellType.LETTER, solution="A", word_ids=["w1"]),
        CellSpec(row=1, col=2, type=CellType.LETTER, solution="A", word_ids=["w1"]),
        CellSpec(row=1, col=3, type=CellType.LETTER, solution="A", word_ids=["w1"]),
    ],
    words=[
        WordSpec(
            id="w1",
            answer="AAA",
            length=3,
            direction=ClueArrow.RIGHT,
            clue_cell=WordCell(row=1, col=0),
            start_cell=WordCell(row=1, col=1),
            cells=[WordCell(row=1, col=1), WordCell(row=1, col=2), WordCell(row=1, col=3)],
            clue=ClueSpec(text="ipucu", arrow=ClueArrow.RIGHT, word_id="w1"),
            frequency_score=90,
        )
    ],
    template_id="small_01",
    safety=SafetyInfo(post_fill_scanned=True),
)


def _puzzle(
    rows: int,
    cols: int,
    words: list[WordSpec],
    n_clue: int,
    n_letter: int,
) -> PuzzleData:
    cells = [_clue_cell() for _ in range(n_clue)] + [_letter_cell() for _ in range(n_letter)]
    return _BASE.model_copy(
        update={"grid": GridSize(rows=rows, cols=cols), "words": words, "cells": cells}
    )


# ── 1: small/short/common → low score ─────────────────────────────────────────


def test_short_words_small_grid_gives_low_score() -> None:
    words = [_word("w1", "AAA", 90), _word("w2", "BBB", 90)]
    assert difficulty_score(_puzzle(4, 5, words, n_clue=2, n_letter=20)) < 40


# ── 2: large/long/rare → high score ───────────────────────────────────────────


def test_long_words_big_grid_gives_high_score() -> None:
    words = [_word(f"w{i}", "A" * 15, 0) for i in range(20)]
    assert difficulty_score(_puzzle(12, 10, words, n_clue=20, n_letter=20)) > 60


# ── 3: score is always clamped to [0, 100] ────────────────────────────────────


def test_score_always_within_0_to_100() -> None:
    easy = [_word("w1", "AAA", 100), _word("w2", "BBB", 100)]
    assert 0 <= difficulty_score(_puzzle(4, 5, easy, n_clue=1, n_letter=30)) <= 100

    hard = [_word(f"w{i}", "A" * 15, 0) for i in range(30)]
    assert 0 <= difficulty_score(_puzzle(12, 10, hard, n_clue=40, n_letter=1)) <= 100


# ── 4: rarer words (lower frequency) raise the score ──────────────────────────


def test_rarer_words_increase_score() -> None:
    common = [_word("w1", "ELMA", 90), _word("w2", "ARMUT", 90)]
    rare = [_word("w1", "ELMA", 5), _word("w2", "ARMUT", 5)]
    score_common = difficulty_score(_puzzle(8, 6, common, n_clue=4, n_letter=20))
    score_rare = difficulty_score(_puzzle(8, 6, rare, n_clue=4, n_letter=20))
    assert score_rare > score_common


# ── 5: denser clue layout raises the score ────────────────────────────────────


def test_higher_clue_density_increases_score() -> None:
    words = [_word("w1", "ELMA", 50), _word("w2", "ARMUT", 50)]
    sparse = difficulty_score(_puzzle(8, 6, words, n_clue=2, n_letter=40))
    dense = difficulty_score(_puzzle(8, 6, words, n_clue=20, n_letter=10))
    assert dense > sparse
