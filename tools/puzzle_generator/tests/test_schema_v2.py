# tools/puzzle_generator/tests/test_schema_v2.py
"""Unit tests for the schema v2 Pydantic models."""

from typing import Any

import pytest

from kelime_gen.schema import (
    CellSpec,
    CellType,
    ClueArrow,
    ClueSpec,
    PuzzleData,
    WordCell,
    WordSpec,
    tr_upper,
)


def _clue(text: str, arrow: ClueArrow, word_id: str) -> ClueSpec:
    return ClueSpec(text=text, arrow=arrow, word_id=word_id)


def _valid_puzzle() -> dict[str, Any]:
    """A small 2-word intersecting puzzle: KEDİ (right) crosses DAL (down)."""
    return {
        "puzzle_id": 1,
        "size": "small",
        "grid": {"rows": 4, "cols": 5},
        "cells": [
            {
                "row": 1,
                "col": 0,
                "type": "clue",
                "clues": [{"text": "Miyavlayan hayvan", "arrow": "right", "word_id": "w1"}],
            },
            {
                "row": 0,
                "col": 3,
                "type": "clue",
                "clues": [{"text": "Ağaç parçası", "arrow": "down", "word_id": "w2"}],
            },
            {"row": 1, "col": 1, "type": "letter", "solution": "K", "word_ids": ["w1"]},
            {"row": 1, "col": 2, "type": "letter", "solution": "E", "word_ids": ["w1"]},
            {"row": 1, "col": 3, "type": "letter", "solution": "D", "word_ids": ["w1", "w2"]},
            {"row": 1, "col": 4, "type": "letter", "solution": "İ", "word_ids": ["w1"]},
            {"row": 2, "col": 3, "type": "letter", "solution": "A", "word_ids": ["w2"]},
            {"row": 3, "col": 3, "type": "letter", "solution": "L", "word_ids": ["w2"]},
        ],
        "words": [
            {
                "id": "w1",
                "answer": "KEDİ",
                "length": 4,
                "direction": "right",
                "clue_cell": {"row": 1, "col": 0},
                "start_cell": {"row": 1, "col": 1},
                "cells": [
                    {"row": 1, "col": 1},
                    {"row": 1, "col": 2},
                    {"row": 1, "col": 3},
                    {"row": 1, "col": 4},
                ],
                "clue": {"text": "Miyavlayan hayvan", "arrow": "right", "word_id": "w1"},
                "frequency_score": 80,
            },
            {
                "id": "w2",
                "answer": "DAL",
                "length": 3,
                "direction": "down",
                "clue_cell": {"row": 0, "col": 3},
                "start_cell": {"row": 1, "col": 3},
                "cells": [
                    {"row": 1, "col": 3},
                    {"row": 2, "col": 3},
                    {"row": 3, "col": 3},
                ],
                "clue": {"text": "Ağaç parçası", "arrow": "down", "word_id": "w2"},
                "frequency_score": 60,
            },
        ],
        "template_id": "small_01",
        "safety": {"post_fill_scanned": True, "scanner_version": "2.0.0"},
    }


# 1-2 — Turkish-aware uppercase.
def test_tr_upper_kedi() -> None:
    assert tr_upper("kedi") == "KEDİ"


def test_tr_upper_issiz() -> None:
    assert tr_upper("ıssız") == "ISSIZ"


# 3 — letter cell normalizes its solution to Turkish upper-case.
def test_letter_cell_normalizes_solution() -> None:
    cell = CellSpec(row=0, col=0, type=CellType.LETTER, solution="k")
    assert cell.solution == "K"


# 4 — letter cell without a solution is rejected.
def test_letter_cell_requires_solution() -> None:
    with pytest.raises(ValueError):
        CellSpec(row=0, col=0, type=CellType.LETTER)


# 5 — clue cell with zero clues is rejected.
def test_clue_cell_needs_at_least_one_clue() -> None:
    with pytest.raises(ValueError):
        CellSpec(row=0, col=0, type=CellType.CLUE, clues=[])


# 6 — clue cell with three clues is rejected.
def test_clue_cell_rejects_three_clues() -> None:
    clues = [_clue(f"c{i}", ClueArrow.DOWN, f"w{i}") for i in range(3)]
    with pytest.raises(ValueError):
        CellSpec(row=0, col=0, type=CellType.CLUE, clues=clues)


def _word(answer: str, length: int, cell_count: int) -> None:
    WordSpec(
        id="w1",
        answer=answer,
        length=length,
        direction=ClueArrow.RIGHT,
        clue_cell=WordCell(row=0, col=0),
        start_cell=WordCell(row=0, col=1),
        cells=[WordCell(row=0, col=1 + i) for i in range(cell_count)],
        clue=_clue("ipucu", ClueArrow.RIGHT, "w1"),
    )


# 7 — length must equal the answer length.
def test_word_length_mismatch() -> None:
    with pytest.raises(ValueError):
        _word(answer="KEDİ", length=5, cell_count=4)


# 8 — cell count must equal length.
def test_word_cell_count_mismatch() -> None:
    with pytest.raises(ValueError):
        _word(answer="KEDİ", length=4, cell_count=3)


# 9 — an unscanned puzzle can never be persisted.
def test_puzzle_requires_safety_scan() -> None:
    data = _valid_puzzle()
    data["safety"] = {"post_fill_scanned": False, "scanner_version": "2.0.0"}
    with pytest.raises(ValueError):
        PuzzleData.model_validate(data)


# 10 — a fully valid puzzle parses successfully.
def test_valid_puzzle_parses() -> None:
    puzzle = PuzzleData.model_validate(_valid_puzzle())
    assert puzzle.schema_version == 2
    assert len(puzzle.words) == 2
    assert puzzle.safety.post_fill_scanned is True


# 11 — intersection mismatch (cell solution != answer letter) is rejected.
def test_intersection_letter_mismatch() -> None:
    data = _valid_puzzle()
    # Cell (1,3) is shared by KEDİ[2]='D' and DAL[0]='D'; corrupt it.
    for cell in data["cells"]:
        if cell["row"] == 1 and cell["col"] == 3:
            cell["solution"] = "X"
    with pytest.raises(ValueError):
        PuzzleData.model_validate(data)
