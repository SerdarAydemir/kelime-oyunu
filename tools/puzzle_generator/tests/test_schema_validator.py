# tools/puzzle_generator/tests/test_schema_validator.py
"""Unit tests for schema_validator: pydantic integration + grid bounds."""

import json
from pathlib import Path
from typing import Any

import pytest

from kelime_gen.schema import PuzzleData
from kelime_gen.validators.schema_validator import validate_all, validate_puzzle_file


def _valid() -> dict[str, Any]:
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


def _write(data: dict[str, Any], path: Path) -> Path:
    path.write_text(json.dumps(data, ensure_ascii=False), encoding="utf-8")
    return path


# ── 1: a valid file parses successfully ───────────────────────────────────────


def test_valid_puzzle_parses(tmp_path: Path) -> None:
    puzzle = validate_puzzle_file(_write(_valid(), tmp_path / "p.json"))
    assert isinstance(puzzle, PuzzleData)
    assert puzzle.puzzle_id == 1
    assert {w.id for w in puzzle.words} == {"w1", "w2"}


# ── 2: an unscanned puzzle is rejected (pydantic layer) ───────────────────────


def test_safety_false_raises(tmp_path: Path) -> None:
    data = _valid()
    data["safety"]["post_fill_scanned"] = False
    with pytest.raises(ValueError):
        validate_puzzle_file(_write(data, tmp_path / "p.json"))


# ── 3: incompatible intersection is rejected (pydantic layer) ─────────────────


def test_incompatible_intersection_raises(tmp_path: Path) -> None:
    data = _valid()
    # Cell (1,3) is shared by KEDİ[2]='D' and DAL[0]='D'; corrupt it.
    for cell in data["cells"]:
        if cell["row"] == 1 and cell["col"] == 3:
            cell["solution"] = "X"
    with pytest.raises(ValueError):
        validate_puzzle_file(_write(data, tmp_path / "p.json"))


# ── 4: out-of-bounds cell is rejected (bounds layer) ──────────────────────────


def test_out_of_bounds_raises(tmp_path: Path) -> None:
    data = _valid()
    # Shrink cols to 4: KEDİ's last letter sits at col 4, now out of bounds.
    # (cols=4 is still a valid GridSize and passes every pydantic check, so this
    # exercises the bounds layer specifically.)
    data["grid"]["cols"] = 4
    with pytest.raises(ValueError):
        validate_puzzle_file(_write(data, tmp_path / "p.json"))


# ── 5: validate_all counts ok/fail and skips manifest.json ────────────────────


def test_validate_all_counts_and_skips_manifest(tmp_path: Path) -> None:
    _write(_valid(), tmp_path / "puzzle_0001.json")
    invalid = _valid()
    invalid["safety"]["post_fill_scanned"] = False
    _write(invalid, tmp_path / "puzzle_0002.json")
    _write({"version": "1.0.0"}, tmp_path / "manifest.json")  # must be ignored

    ok, fail, errors = validate_all(tmp_path)
    assert ok == 1
    assert fail == 1
    assert len(errors) == 1
    assert "puzzle_0002.json" in errors[0]
