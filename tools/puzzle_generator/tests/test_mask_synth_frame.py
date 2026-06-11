# tools/puzzle_generator/tests/test_mask_synth_frame.py
"""Unit tests for the strict full-frame mask enumerator (mask_synth_frame).

Production geometry is 9x7 (interior 8x6); exhaustive-enumeration tests use a
small 5x5 frame so the whole space can be brute-force checked in milliseconds.
"""

from itertools import combinations
from pathlib import Path

import pytest

from kelime_gen.mask_synth_frame import (
    FrameLibrary,
    FrameParams,
    FrameSynthError,
    _FrameValidator,
    _from_bits,
    _run_table,
    _to_bits,
    build_template,
    enumerate_masks,
    load_library,
)
from kelime_gen.schema import CellType, ClueArrow, PuzzleSize

PROD = FrameParams()  # 9x7, k in [5,7], len1<=4, len2<=5
SMALL = FrameParams(rows=5, cols=5, k_min=1, k_max=2, per_k_cap=1000)


def _valid_prod_clues() -> tuple[tuple[int, int], ...]:
    """A hand-checked valid k=6 interior clue placement for the 9x7 frame.

    Hand count: len-1 runs (1,3),(3,6),(4,1),(8,6) = 4 (at cap); len-2 runs
    rows 1-2 of col 5, rows 7-8 of col 4, cols 1-2 of rows 2 and 8, cols 5-6
    of row 6 = 5 (at cap); no barren clue; interior stays 4-connected.
    """
    return ((2, 3), (3, 5), (4, 2), (6, 4), (7, 6), (8, 3))


# ── _run_table ────────────────────────────────────────────────────────────────


def test_run_table_no_clues_is_one_full_run() -> None:
    assert _run_table(6)[0] == (0, 0)  # one len-6 run
    assert _run_table(2)[0] == (0, 1)  # one len-2 run
    assert _run_table(1)[0] == (1, 0)  # one len-1 run


def test_run_table_counts_split_runs() -> None:
    # Line of 6, clue at interior position 2 (bit 1): runs of len 2 and len 3.
    assert _run_table(6)[0b00010] == (0, 1)
    # Clues at positions 1 and 3: runs len 1, len 1, len 2.
    assert _run_table(6)[0b00101] == (2, 1)
    # Clue at the last position (5): runs len 5 + len 0 (no trailing run).
    assert _run_table(6)[0b10000] == (0, 0)


# ── validator gates (production 9x7 geometry) ─────────────────────────────────


def test_valid_placement_accepted() -> None:
    assert _FrameValidator(PROD).is_valid(_valid_prod_clues())


def test_barren_corner_clue_rejected() -> None:
    # (8,6) has no cell to its right or below -> always barren.
    clues = ((2, 4), (3, 2), (6, 3), (7, 5), (8, 2), (8, 6))
    assert not _FrameValidator(PROD).is_valid(clues)


def test_barren_boxed_in_clue_rejected() -> None:
    # (7,6): right edge, and (8,6) below is also a clue -> (7,6) heads nothing.
    clues = ((2, 4), (3, 2), (6, 3), (8, 2), (7, 6), (8, 6))
    assert not _FrameValidator(PROD).is_valid(clues)


def test_disconnected_interior_rejected() -> None:
    # (7,6) and (8,5) isolate the letter at (8,6) from the rest.
    clues = ((2, 4), (3, 2), (6, 3), (8, 2), (7, 6), (8, 5))
    assert not _FrameValidator(PROD).is_valid(clues)


def test_len1_cap_enforced() -> None:
    # Clues at (2,c) make the cell (1,c) above a len-1 down slot; five of
    # them (plus the len-1 across runs they create) blow the len1<=4 cap.
    clues = ((2, 2), (2, 3), (2, 4), (2, 5), (2, 6))
    assert not _FrameValidator(PROD).is_valid(clues)


def test_len2_cap_enforced() -> None:
    # Each clue at (3,c) leaves a len-2 down run above it (rows 1-2). Six of
    # them stay connected and len1-clean but exceed len2<=5.
    base = ((3, 2), (3, 3), (3, 4), (3, 5), (3, 6))
    validator = _FrameValidator(PROD)
    assert validator.is_valid(base)  # five len-2 runs: at the cap, still valid
    assert not validator.is_valid(base + ((6, 2),))  # (6,2) adds a sixth len-2


# ── exhaustive small-frame enumeration ───────────────────────────────────────


def test_enumerate_matches_bruteforce_on_small_frame() -> None:
    masks, totals = enumerate_masks(SMALL)
    validator = _FrameValidator(SMALL)
    allowed = [(r, c) for r in range(2, 5) for c in range(2, 5)]
    for k in (1, 2):
        expected = [
            _to_bits(clues, 4) for clues in combinations(allowed, k) if validator.is_valid(clues)
        ]
        assert totals[k] == len(expected)
        assert masks[k] == sorted(expected)  # cap not hit -> full set kept


def test_enumeration_is_deterministic() -> None:
    assert enumerate_masks(SMALL) == enumerate_masks(SMALL)


def test_per_k_cap_samples_deterministically() -> None:
    capped = FrameParams(rows=5, cols=5, k_min=2, k_max=2, per_k_cap=5)
    masks, totals = enumerate_masks(capped)
    assert totals[2] > 5
    assert len(masks[2]) == 5
    again, _ = enumerate_masks(capped)
    assert masks == again


# ── template assembly ────────────────────────────────────────────────────────


def test_template_structure_at_9x7() -> None:
    bits = _to_bits(_valid_prod_clues(), 6)
    template = build_template(bits, PROD, PuzzleSize.MEDIUM)
    assert template.grid.rows == 9 and template.grid.cols == 7
    assert len(template.cells) == 63
    assert not template.transformable

    by_type: dict[CellType, list[tuple[int, int]]] = {t: [] for t in CellType}
    for cell in template.cells:
        by_type[cell.type].append((cell.row, cell.col))
    assert by_type[CellType.BLANK] == [(0, 0)]
    # Full frame: top row + left column are clues, plus the 6 interior clues.
    frame = {(0, c) for c in range(1, 7)} | {(r, 0) for r in range(1, 9)}
    assert frame <= set(by_type[CellType.CLUE])
    assert len(by_type[CellType.CLUE]) == 14 + 6
    assert len(by_type[CellType.LETTER]) == 48 - 6


def test_every_letter_crosses_two_slots() -> None:
    bits = _to_bits(_valid_prod_clues(), 6)
    template = build_template(bits, PROD, PuzzleSize.MEDIUM)
    directions = {s.slot_id: s.direction for s in template.slots}
    for cell in template.cells:
        if cell.type == CellType.LETTER:
            assert len(cell.slot_ids) == 2
            assert {directions[s] for s in cell.slot_ids} == {ClueArrow.RIGHT, ClueArrow.DOWN}


def test_template_has_full_row1_and_col1_slots() -> None:
    # Row 1 and column 1 hold no interior clues, so every frame mask contains
    # one full-width (6) across slot and one full-height (8) down slot.
    bits = _to_bits(_valid_prod_clues(), 6)
    template = build_template(bits, PROD, PuzzleSize.MEDIUM)
    lengths = {(s.direction, s.length) for s in template.slots}
    assert (ClueArrow.RIGHT, 6) in lengths
    assert (ClueArrow.DOWN, 8) in lengths
    for slot in template.slots:
        assert 1 <= slot.length <= 8


def test_template_id_encodes_bits() -> None:
    bits = _to_bits(_valid_prod_clues(), 6)
    template = build_template(bits, PROD, PuzzleSize.MEDIUM)
    assert template.template_id == f"medium_frame_{bits:012x}"
    assert _from_bits(bits, 6) == sorted(_valid_prod_clues())


def test_build_template_rejects_barren_mask() -> None:
    bits = _to_bits(((8, 6),), 6)  # corner clue heads nothing
    with pytest.raises(FrameSynthError, match="barren"):
        build_template(bits, PROD, PuzzleSize.MEDIUM)


# ── library cache + deterministic pick ───────────────────────────────────────


def test_load_library_builds_and_caches(tmp_path: Path) -> None:
    cache = tmp_path / "frame_masks.json"
    library = load_library(cache, SMALL)
    assert cache.exists()
    assert len(library) == sum(library.total_valid.values())
    reloaded = load_library(cache, SMALL)
    assert reloaded.entries == library.entries
    assert reloaded.total_valid == library.total_valid


def test_load_library_rebuilds_on_param_change(tmp_path: Path) -> None:
    cache = tmp_path / "frame_masks.json"
    load_library(cache, SMALL)
    changed = FrameParams(rows=5, cols=5, k_min=2, k_max=2, per_k_cap=1000)
    library = load_library(cache, changed)
    assert set(k for k, _ in library.entries) == {2}


def test_pick_index_is_deterministic(tmp_path: Path) -> None:
    library = load_library(tmp_path / "frame_masks.json", SMALL)
    first = library.pick_index(seed=42)
    assert first == library.pick_index(seed=42)
    assert 0 <= first < len(library)
    spread = {library.pick_index(seed=s) for s in range(20)}
    assert len(spread) > 1


def test_empty_library_pick_raises() -> None:
    library = FrameLibrary(params=SMALL, entries=[])
    with pytest.raises(FrameSynthError, match="empty"):
        library.pick_index(seed=1)


def test_library_template_roundtrip(tmp_path: Path) -> None:
    library = load_library(tmp_path / "frame_masks.json", SMALL)
    template = library.template(0, PuzzleSize.SMALL)
    assert template.grid.rows == 5 and template.grid.cols == 5
    assert template.slots
