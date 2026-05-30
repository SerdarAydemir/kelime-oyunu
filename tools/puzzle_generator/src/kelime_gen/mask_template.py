# tools/puzzle_generator/src/kelime_gen/mask_template.py
"""Mask template loading and geometric transforms (architecture.md §5).

A mask encodes cell types and slot layout without solution letters.
The CSP filler (csp_filler.py) consumes masks to produce filled PuzzleData.
"""

import sys
from pathlib import Path
from typing import Self

from pydantic import BaseModel, Field, model_validator

from kelime_gen.schema import CellType, ClueArrow, GridSize, PuzzleSize, WordCell


class SlotSpec(BaseModel):
    """A word slot — the CSP variable that the filler will assign a word to."""

    slot_id: str
    direction: ClueArrow
    clue_cell: WordCell
    cells: list[WordCell] = Field(min_length=1)
    length: int = Field(ge=1, le=15)

    @model_validator(mode="after")
    def check_length(self) -> Self:
        """length must equal the number of word cells."""
        if self.length != len(self.cells):
            raise ValueError(
                f"slot {self.slot_id!r}: length {self.length} "
                f"!= cell count {len(self.cells)}"
            )
        return self


class TemplateCellSpec(BaseModel):
    """A single grid cell in a mask template — no solution letters stored."""

    row: int = Field(ge=0)
    col: int = Field(ge=0)
    type: CellType
    slot_ids: list[str] = Field(default_factory=list)
    clue_slots: list[str] = Field(default_factory=list)
    image_slot: bool = False


class MaskTemplate(BaseModel):
    """Full mask template: cell layout + slot definitions (architecture.md §5.4)."""

    template_id: str
    size: PuzzleSize
    grid: GridSize
    cells: list[TemplateCellSpec] = Field(min_length=1)
    slots: list[SlotSpec] = Field(default_factory=list)
    transformable: bool = True

    @model_validator(mode="after")
    def check_consistency(self) -> Self:
        """Verify every slot references valid cell types (architecture.md §5.4)."""
        cell_by_pos = {(c.row, c.col): c for c in self.cells}

        slot_ids = [s.slot_id for s in self.slots]
        if len(slot_ids) != len(set(slot_ids)):
            raise ValueError("All slot_ids must be unique within a template")

        for slot in self.slots:
            for wc in slot.cells:
                cell = cell_by_pos.get((wc.row, wc.col))
                if cell is None or cell.type != CellType.LETTER:
                    raise ValueError(
                        f"slot {slot.slot_id!r}: word cell "
                        f"({wc.row},{wc.col}) is not a letter cell"
                    )
            cc = cell_by_pos.get((slot.clue_cell.row, slot.clue_cell.col))
            if cc is None or cc.type != CellType.CLUE:
                raise ValueError(
                    f"slot {slot.slot_id!r}: clue_cell "
                    f"({slot.clue_cell.row},{slot.clue_cell.col}) "
                    f"is not a clue cell"
                )
        return self


# ── File I/O ─────────────────────────────────────────────────────────────────


def load_template(path: Path) -> MaskTemplate:
    """Load a MaskTemplate from a JSON file.

    Raises ValueError if the file cannot be read, parsed, or validated.
    """
    try:
        return MaskTemplate.model_validate_json(path.read_text(encoding="utf-8"))
    except Exception as exc:
        raise ValueError(f"Invalid template at {path}: {exc}") from exc


def load_templates_dir(templates_dir: Path) -> list[MaskTemplate]:
    """Load all *.json templates from a directory.

    Skips files that fail validation (logs a warning to stderr).
    Returns only the valid templates in sorted-filename order.
    """
    results: list[MaskTemplate] = []
    for path in sorted(templates_dir.glob("*.json")):
        try:
            results.append(load_template(path))
        except Exception as exc:
            print(f"[WARN] Skipping {path.name}: {exc}", file=sys.stderr)
    return results


# ── Transforms ───────────────────────────────────────────────────────────────


def _direction_valid(
    direction: ClueArrow,
    clue: WordCell,
    cells: list[WordCell],
) -> bool:
    """Return True if clue_cell is on the correct entry side for direction.

    - right: clue must be in the same row, strictly left of all word cells.
    - down:  clue must be in the same column, strictly above all word cells.
    """
    if direction == ClueArrow.RIGHT:
        return (
            all(wc.row == clue.row for wc in cells)
            and clue.col < min(wc.col for wc in cells)
        )
    # ClueArrow.DOWN
    return (
        all(wc.col == clue.col for wc in cells)
        and clue.row < min(wc.row for wc in cells)
    )


def mirror_horizontal(template: MaskTemplate) -> MaskTemplate | None:
    """Flip the template left-to-right (mirror columns).

    Returns None if any slot's clue_cell is no longer on the correct entry
    side after mirroring. In practice, templates that contain `right`-direction
    slots always return None (architecture.md §5.5).
    """
    max_col = template.grid.cols - 1

    def flip_wc(wc: WordCell) -> WordCell:
        return WordCell(row=wc.row, col=max_col - wc.col)

    new_slots: list[SlotSpec] = []
    for slot in template.slots:
        new_clue = flip_wc(slot.clue_cell)
        new_cells = [flip_wc(wc) for wc in slot.cells]
        if not _direction_valid(slot.direction, new_clue, new_cells):
            return None
        new_slots.append(
            SlotSpec(
                slot_id=slot.slot_id,
                direction=slot.direction,
                clue_cell=new_clue,
                cells=new_cells,
                length=slot.length,
            )
        )

    new_template_cells = [
        TemplateCellSpec(
            row=c.row,
            col=max_col - c.col,
            type=c.type,
            slot_ids=c.slot_ids,
            clue_slots=c.clue_slots,
            image_slot=c.image_slot,
        )
        for c in template.cells
    ]
    return MaskTemplate(
        template_id=f"{template.template_id}_mh",
        size=template.size,
        grid=template.grid,
        cells=new_template_cells,
        slots=new_slots,
        transformable=False,
    )


def rotate_180(template: MaskTemplate) -> MaskTemplate | None:
    """Rotate the template 180° (flip both rows and columns).

    Returns None if any slot's clue_cell is no longer on the correct entry
    side after rotation. For standard right/down templates this almost always
    returns None; the function succeeds for specially symmetric templates
    (e.g. zero-slot layout bases) where there are no direction constraints
    to violate (architecture.md §5.5).
    """
    max_row = template.grid.rows - 1
    max_col = template.grid.cols - 1

    def flip_wc(wc: WordCell) -> WordCell:
        return WordCell(row=max_row - wc.row, col=max_col - wc.col)

    new_slots: list[SlotSpec] = []
    for slot in template.slots:
        new_clue = flip_wc(slot.clue_cell)
        new_cells = [flip_wc(wc) for wc in slot.cells]
        if not _direction_valid(slot.direction, new_clue, new_cells):
            return None
        new_slots.append(
            SlotSpec(
                slot_id=slot.slot_id,
                direction=slot.direction,
                clue_cell=new_clue,
                cells=new_cells,
                length=slot.length,
            )
        )

    new_template_cells = [
        TemplateCellSpec(
            row=max_row - c.row,
            col=max_col - c.col,
            type=c.type,
            slot_ids=c.slot_ids,
            clue_slots=c.clue_slots,
            image_slot=c.image_slot,
        )
        for c in template.cells
    ]
    return MaskTemplate(
        template_id=f"{template.template_id}_r180",
        size=template.size,
        grid=template.grid,
        cells=new_template_cells,
        slots=new_slots,
        transformable=False,
    )


def get_transforms(template: MaskTemplate) -> list[MaskTemplate]:
    """Return the original template plus all valid geometric transforms.

    If transformable=False, returns only [template]. Otherwise returns the
    original plus any non-None results from mirror_horizontal and rotate_180.
    """
    if not template.transformable:
        return [template]
    candidates: list[MaskTemplate | None] = [
        template,
        mirror_horizontal(template),
        rotate_180(template),
    ]
    return [t for t in candidates if t is not None]
