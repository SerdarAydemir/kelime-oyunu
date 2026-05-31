# tools/puzzle_generator/tests/test_mask_template.py
"""Unit tests for mask_template loading and geometric transforms."""

import json
from pathlib import Path
from typing import Any

import pytest

from kelime_gen.mask_template import (
    MaskTemplate,
    TemplateCellSpec,
    get_transforms,
    load_template,
    mirror_horizontal,
    rotate_180,
)
from kelime_gen.schema import CellType, ClueArrow, GridSize, PuzzleSize

# ── In-memory fixture helpers ─────────────────────────────────────────────────


def _down_data() -> dict[str, Any]:
    """Minimal valid 4×5 template with one DOWN slot (col 1, rows 0-3)."""
    return {
        "template_id": "t_down",
        "size": "small",
        "grid": {"rows": 4, "cols": 5},
        "cells": [
            {"row": 0, "col": 1, "type": "clue", "clue_slots": ["s1"]},
            {"row": 1, "col": 1, "type": "letter", "slot_ids": ["s1"]},
            {"row": 2, "col": 1, "type": "letter", "slot_ids": ["s1"]},
            {"row": 3, "col": 1, "type": "letter", "slot_ids": ["s1"]},
        ],
        "slots": [
            {
                "slot_id": "s1",
                "direction": "down",
                "clue_cell": {"row": 0, "col": 1},
                "cells": [
                    {"row": 1, "col": 1},
                    {"row": 2, "col": 1},
                    {"row": 3, "col": 1},
                ],
                "length": 3,
            }
        ],
    }


def _right_data() -> dict[str, Any]:
    """4×5 template with one RIGHT slot (row 1, cols 0-3)."""
    return {
        "template_id": "t_right",
        "size": "small",
        "grid": {"rows": 4, "cols": 5},
        "cells": [
            {"row": 1, "col": 0, "type": "clue", "clue_slots": ["s1"]},
            {"row": 1, "col": 1, "type": "letter", "slot_ids": ["s1"]},
            {"row": 1, "col": 2, "type": "letter", "slot_ids": ["s1"]},
            {"row": 1, "col": 3, "type": "letter", "slot_ids": ["s1"]},
            {"row": 0, "col": 0, "type": "blank"},
        ],
        "slots": [
            {
                "slot_id": "s1",
                "direction": "right",
                "clue_cell": {"row": 1, "col": 0},
                "cells": [
                    {"row": 1, "col": 1},
                    {"row": 1, "col": 2},
                    {"row": 1, "col": 3},
                ],
                "length": 3,
            }
        ],
    }


def _write_and_load(data: dict[str, Any], tmp_path: Path) -> MaskTemplate:
    path = tmp_path / "t.json"
    path.write_text(json.dumps(data, ensure_ascii=False), encoding="utf-8")
    return load_template(path)


# ── 1-4: load_template ────────────────────────────────────────────────────────


def test_load_template_valid(tmp_path: Path) -> None:
    """A well-formed JSON file produces a MaskTemplate."""
    template = _write_and_load(_down_data(), tmp_path)
    assert isinstance(template, MaskTemplate)
    assert template.template_id == "t_down"
    assert len(template.slots) == 1


def test_load_template_invalid_json(tmp_path: Path) -> None:
    """Malformed JSON raises ValueError with a descriptive message."""
    path = tmp_path / "bad.json"
    path.write_text("{invalid json", encoding="utf-8")
    with pytest.raises(ValueError, match="Invalid template"):
        load_template(path)


def test_load_template_slot_length_mismatch(tmp_path: Path) -> None:
    """slot.length != len(slot.cells) is rejected."""
    data = _down_data()
    # Keep length=3 but shrink cells to 2 items.
    data["slots"][0]["cells"] = [
        {"row": 1, "col": 1},
        {"row": 2, "col": 1},
    ]
    with pytest.raises(ValueError):
        _write_and_load(data, tmp_path)


def test_load_template_clue_cell_points_to_letter_cell(tmp_path: Path) -> None:
    """slot.clue_cell referencing a letter cell is rejected."""
    data = _down_data()
    # Redirect clue_cell to row 1 which is a letter cell.
    data["slots"][0]["clue_cell"] = {"row": 1, "col": 1}
    with pytest.raises(ValueError):
        _write_and_load(data, tmp_path)


# ── 5-7: transforms ───────────────────────────────────────────────────────────


def test_mirror_horizontal_down_only(tmp_path: Path) -> None:
    """A down-only template mirrors successfully; column positions are correct."""
    template = _write_and_load(_down_data(), tmp_path)
    result = mirror_horizontal(template)
    assert result is not None
    # Original slot col = 1; grid.cols = 5; max_col = 4; mirrored = 4-1 = 3.
    slot = result.slots[0]
    assert slot.clue_cell.col == 3
    assert all(wc.col == 3 for wc in slot.cells)
    assert slot.direction == ClueArrow.DOWN


def test_mirror_horizontal_right_slot_returns_none(tmp_path: Path) -> None:
    """A template with a right-direction slot mirrors to None."""
    template = _write_and_load(_right_data(), tmp_path)
    assert mirror_horizontal(template) is None


def test_rotate_180_empty_slots_returns_valid() -> None:
    """A template with no slots (zero direction constraints) always survives 180°.

    rotate_180 returns None only if a slot's clue_cell ends up on the wrong
    side after rotation. With an empty slot list there is nothing to invalidate,
    so the function must return a non-None MaskTemplate.
    """
    template = MaskTemplate(
        template_id="t_layout",
        size=PuzzleSize.SMALL,
        grid=GridSize(rows=4, cols=5),
        cells=[
            TemplateCellSpec(row=0, col=0, type=CellType.BLANK),
            TemplateCellSpec(row=3, col=4, type=CellType.BLANK),
        ],
        slots=[],
    )
    result = rotate_180(template)
    assert result is not None
    assert result.template_id == "t_layout_r180"
    # Positions must be flipped: (0,0)→(3,4) and (3,4)→(0,0).
    positions = {(c.row, c.col) for c in result.cells}
    assert (3, 4) in positions
    assert (0, 0) in positions


# ── 8-9: get_transforms ───────────────────────────────────────────────────────


def test_get_transforms_transformable_true(tmp_path: Path) -> None:
    """transformable=True returns at least the original plus valid transforms."""
    template = _write_and_load(_down_data(), tmp_path)
    results = get_transforms(template)
    # Original is always first; mirror succeeds for down-only; rotate returns None.
    assert len(results) >= 1
    assert template in results


def test_get_transforms_transformable_false(tmp_path: Path) -> None:
    """transformable=False returns exactly [template] with no extra variants."""
    data = _down_data()
    data["transformable"] = False
    template = _write_and_load(data, tmp_path)
    assert get_transforms(template) == [template]


# ── 10: intersection ──────────────────────────────────────────────────────────


def test_intersection_cell_two_slot_ids(tmp_path: Path) -> None:
    """A letter cell shared by two slots (slot_ids length 2) loads correctly."""
    data: dict[str, Any] = {
        "template_id": "t_cross",
        "size": "small",
        "grid": {"rows": 4, "cols": 5},
        "cells": [
            {"row": 0, "col": 1, "type": "clue", "clue_slots": ["s1"]},
            {"row": 2, "col": 0, "type": "clue", "clue_slots": ["s2"]},
            {"row": 1, "col": 1, "type": "letter", "slot_ids": ["s1"]},
            # Intersection cell — belongs to both s1 (down) and s2 (right).
            {"row": 2, "col": 1, "type": "letter", "slot_ids": ["s1", "s2"]},
            {"row": 2, "col": 2, "type": "letter", "slot_ids": ["s2"]},
            {"row": 3, "col": 1, "type": "letter", "slot_ids": ["s1"]},
        ],
        "slots": [
            {
                "slot_id": "s1",
                "direction": "down",
                "clue_cell": {"row": 0, "col": 1},
                "cells": [
                    {"row": 1, "col": 1},
                    {"row": 2, "col": 1},
                    {"row": 3, "col": 1},
                ],
                "length": 3,
            },
            {
                "slot_id": "s2",
                "direction": "right",
                "clue_cell": {"row": 2, "col": 0},
                "cells": [
                    {"row": 2, "col": 1},
                    {"row": 2, "col": 2},
                ],
                "length": 2,
            },
        ],
    }
    template = _write_and_load(data, tmp_path)
    assert len(template.slots) == 2
    shared = [c for c in template.cells if c.row == 2 and c.col == 1]
    assert len(shared) == 1
    assert shared[0].slot_ids == ["s1", "s2"]
