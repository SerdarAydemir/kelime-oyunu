# tools/puzzle_generator/tests/test_mask_synth.py
"""Unit tests for the deterministic crossing-first mask synthesizer.

Loose, min-1 model (architecture.md §5.7): blank=0, interior runs are 1..8 slots,
edge runs are incidental, no orphan/barren. Single/double-letter slots are kept
rare and no 3x3 solid block is allowed (balanced Cross-Up look, not word-search
blocks nor a dotty scatter). A single connected component is infeasible, so the
component count is capped instead.
"""

import time

import pytest

from kelime_gen.mask_synth import (
    SynthParams,
    _component_count,
    _crossing_count,
    _extract_runs,
    _has_solid_block,
    _interior_runs_clean,
    _slot_length_counts,
    MaskSynthError,
    synthesize,
)
from kelime_gen.mask_template import MaskTemplate
from kelime_gen.schema import CellType, ClueArrow, PuzzleSize

MEDIUM_SEEDS = range(8)
ROWS, COLS = 8, 6


def _medium(seed: int) -> MaskTemplate:
    return synthesize(ROWS, COLS, PuzzleSize.MEDIUM, seed)


def _grid(template: MaskTemplate) -> dict[tuple[int, int], CellType]:
    return {(c.row, c.col): c.type for c in template.cells}


def _letter_cells(template: MaskTemplate) -> set[tuple[int, int]]:
    return {(c.row, c.col) for c in template.cells if c.type == CellType.LETTER}


# ── Determinism ───────────────────────────────────────────────────────────────


def test_same_seed_is_identical() -> None:
    assert _medium(42).model_dump_json() == _medium(42).model_dump_json()


def test_different_seeds_differ() -> None:
    dumps = {_medium(s).model_dump_json() for s in MEDIUM_SEEDS}
    assert len(dumps) > 1


# ── Structural invariants (across several seeds) ──────────────────────────────


@pytest.mark.parametrize("seed", MEDIUM_SEEDS)
def test_fully_packed_no_blank(seed: int) -> None:
    template = _medium(seed)
    assert all(c.type != CellType.BLANK for c in template.cells)
    positions = {(c.row, c.col) for c in template.cells}
    assert len(positions) == ROWS * COLS
    assert len(template.cells) == ROWS * COLS


@pytest.mark.parametrize("seed", MEDIUM_SEEDS)
def test_slot_lengths_in_range(seed: int) -> None:
    template = _medium(seed)
    assert template.slots
    for slot in template.slots:
        assert 1 <= slot.length <= 8


@pytest.mark.parametrize("seed", MEDIUM_SEEDS)
def test_interior_runs_are_clean(seed: int) -> None:
    # Every interior run is a valid slot length (1..8); edge runs are incidental.
    assert _interior_runs_clean(_grid(_medium(seed)), ROWS, COLS)


@pytest.mark.parametrize("seed", MEDIUM_SEEDS)
def test_no_solid_block(seed: int) -> None:
    # No 3x3 fully-letter rectangle (word-search block).
    assert not _has_solid_block(_grid(_medium(seed)), ROWS, COLS, 3, 3)


@pytest.mark.parametrize("seed", MEDIUM_SEEDS)
def test_short_slots_are_rare(seed: int) -> None:
    # Single/double-letter slots stay capped so the grid is not a dotty scatter.
    counts = _slot_length_counts(_extract_runs(_grid(_medium(seed)), ROWS, COLS))
    params = SynthParams()
    assert counts[1] <= params.max_len1_slots
    assert counts[2] <= params.max_len2_slots


@pytest.mark.parametrize("seed", MEDIUM_SEEDS)
def test_majority_slots_are_three_to_five(seed: int) -> None:
    # The 3-5 band should dominate over the 1-2 short slots (Cross-Up balance).
    counts = _slot_length_counts(_extract_runs(_grid(_medium(seed)), ROWS, COLS))
    short = counts[1] + counts[2]
    mid = counts[3] + counts[4] + counts[5]
    assert mid > short


@pytest.mark.parametrize("seed", MEDIUM_SEEDS)
def test_every_letter_is_covered(seed: int) -> None:
    template = _medium(seed)
    covered: set[tuple[int, int]] = set()
    for slot in template.slots:
        covered.update((wc.row, wc.col) for wc in slot.cells)
    assert _letter_cells(template) == covered


@pytest.mark.parametrize("seed", MEDIUM_SEEDS)
def test_clue_cells_head_one_or_two_slots(seed: int) -> None:
    template = _medium(seed)
    slot_ids = {s.slot_id for s in template.slots}
    for cell in template.cells:
        if cell.type == CellType.CLUE:
            assert 1 <= len(cell.clue_slots) <= 2
            assert all(sid in slot_ids for sid in cell.clue_slots)


@pytest.mark.parametrize("seed", MEDIUM_SEEDS)
def test_clue_cell_is_on_entry_side(seed: int) -> None:
    template = _medium(seed)
    for slot in template.slots:
        cc, first = slot.clue_cell, slot.cells[0]
        if slot.direction == ClueArrow.RIGHT:
            assert cc.row == first.row and cc.col == first.col - 1
        else:
            assert cc.col == first.col and cc.row == first.row - 1


@pytest.mark.parametrize("seed", MEDIUM_SEEDS)
def test_clue_ratio_within_band(seed: int) -> None:
    template = _medium(seed)
    ratio = sum(1 for c in template.cells if c.type == CellType.CLUE) / (ROWS * COLS)
    params = SynthParams()
    assert params.min_clue_ratio <= ratio <= params.max_clue_ratio


@pytest.mark.parametrize("seed", MEDIUM_SEEDS)
def test_crossings_above_floor(seed: int) -> None:
    runs = _extract_runs(_grid(_medium(seed)), ROWS, COLS)
    assert _crossing_count(runs) >= (len(runs) + 1) // 2


@pytest.mark.parametrize("seed", MEDIUM_SEEDS)
def test_component_count_within_cap(seed: int) -> None:
    runs = _extract_runs(_grid(_medium(seed)), ROWS, COLS)
    assert _component_count(runs) <= SynthParams().max_components


@pytest.mark.parametrize("seed", MEDIUM_SEEDS)
def test_round_trip_revalidates(seed: int) -> None:
    template = _medium(seed)
    reloaded = MaskTemplate.model_validate_json(template.model_dump_json())
    assert reloaded.template_id == f"medium_synth_{seed}"


# ── Performance (single call must stay well under 30s) ────────────────────────


def test_single_call_under_30s() -> None:
    start = time.perf_counter()
    synthesize(ROWS, COLS, PuzzleSize.MEDIUM, seed=7)
    assert time.perf_counter() - start < 30.0


# ── Failure handling ──────────────────────────────────────────────────────────


def test_impossible_budget_raises() -> None:
    params = SynthParams(max_restarts=1, fill_budget=1)
    with pytest.raises(MaskSynthError):
        synthesize(ROWS, COLS, PuzzleSize.MEDIUM, seed=0, params=params)
