# tools/puzzle_generator/tests/test_curated_clue_budget.py
"""Curated (len-1/2) clues must fit a double-clue half cell on a 49 dp grid.

Measured 2026-09-14 with the real Roboto face: a 9×7 frame on a 360 dp phone
gives 49 dp cells; a double-clue half cell then holds two 9 px lines of about
10 characters each. One- and two-letter answers land in double cells most
often, so their clues are capped at 16 characters (target), with no single
word longer than 10 characters (it could not be hyphenated into two lines
that also leave room for the rest).
"""

from __future__ import annotations

import json
from pathlib import Path

import pytest

_DATA = Path(__file__).resolve().parents[1] / "data"
MAX_CLUE_LEN = 16
MAX_WORD_LEN = 10


@pytest.mark.parametrize("name", ["symbols.json", "two_letter.json"])
def test_curated_clues_fit_the_double_cell_budget(name: str) -> None:
    rows = json.loads((_DATA / name).read_text(encoding="utf-8"))
    too_long = [(r["answer"], r["clue"]) for r in rows if len(r["clue"]) > MAX_CLUE_LEN]
    long_word = [
        (r["answer"], r["clue"])
        for r in rows
        if any(len(w) > MAX_WORD_LEN for w in r["clue"].split())
    ]
    assert too_long == [], f"{name}: clue > {MAX_CLUE_LEN} chars: {too_long}"
    assert long_word == [], f"{name}: word > {MAX_WORD_LEN} chars: {long_word}"
    assert all(r["clue"].strip() for r in rows), f"{name}: empty clue"
