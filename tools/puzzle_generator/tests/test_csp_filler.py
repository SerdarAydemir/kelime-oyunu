# tools/puzzle_generator/tests/test_csp_filler.py
"""Unit tests for the CSP filler (AC-3 + backtracking)."""

from typing import TypedDict

import pytest

from kelime_gen.csp_filler import CSPFiller, FillError, compute_intersections
from kelime_gen.mask_template import MaskTemplate, SlotSpec, TemplateCellSpec
from kelime_gen.schema import CellType, ClueArrow, GridSize, PuzzleSize, WordCell
from kelime_gen.validators.post_fill_safety import scan_grid

# ── In-memory template builder ────────────────────────────────────────────────


class _SlotData(TypedDict):
    slot_id: str
    direction: str
    clue_cell: tuple[int, int]
    cells: list[tuple[int, int]]


def _template(
    template_id: str,
    rows: int,
    cols: int,
    slots_data: list[_SlotData],
) -> MaskTemplate:
    """Build a MaskTemplate from compact slot descriptions.

    Clue cells become CLUE cells, word cells become LETTER cells.
    """
    clue_positions: set[tuple[int, int]] = set()
    letter_owners: dict[tuple[int, int], list[str]] = {}
    slots: list[SlotSpec] = []

    for sd in slots_data:
        slot_id = sd["slot_id"]
        cr, cc = sd["clue_cell"]
        clue_positions.add((cr, cc))
        raw_cells = sd["cells"]
        word_cells = [WordCell(row=r, col=c) for r, c in raw_cells]
        for r, c in raw_cells:
            letter_owners.setdefault((r, c), []).append(slot_id)
        slots.append(
            SlotSpec(
                slot_id=slot_id,
                direction=ClueArrow(sd["direction"]),
                clue_cell=WordCell(row=cr, col=cc),
                cells=word_cells,
                length=len(word_cells),
            )
        )

    cells = [TemplateCellSpec(row=r, col=c, type=CellType.CLUE) for r, c in clue_positions]
    cells += [
        TemplateCellSpec(row=r, col=c, type=CellType.LETTER, slot_ids=ids)
        for (r, c), ids in letter_owners.items()
    ]
    return MaskTemplate(
        template_id=template_id,
        size=PuzzleSize.SMALL,
        grid=GridSize(rows=rows, cols=cols),
        cells=cells,
        slots=slots,
    )


def _two_non_crossing() -> MaskTemplate:
    return _template(
        "t_pair",
        4,
        4,
        [
            {"slot_id": "s1", "direction": "right", "clue_cell": (0, 0),
             "cells": [(0, 1), (0, 2), (0, 3)]},
            {"slot_id": "s2", "direction": "right", "clue_cell": (2, 0),
             "cells": [(2, 1), (2, 2), (2, 3)]},
        ],
    )


def _crossing() -> MaskTemplate:
    """s1 (right, row 1) crosses s2 (down, col 2) at cell (1, 2)."""
    return _template(
        "t_cross",
        4,
        4,
        [
            {"slot_id": "s1", "direction": "right", "clue_cell": (1, 0),
             "cells": [(1, 1), (1, 2), (1, 3)]},
            {"slot_id": "s2", "direction": "down", "clue_cell": (0, 2),
             "cells": [(1, 2), (2, 2), (3, 2)]},
        ],
    )


# ── 1: simple fill ──────────────────────────────────────────────────────────


def test_simple_fill_non_crossing() -> None:
    filler = CSPFiller(["KAR", "ARA", "TOP", "SAP"], seed=1)
    result = filler.fill(_two_non_crossing())
    assert set(result.slot_assignments) == {"s1", "s2"}
    assert result.slot_assignments["s1"] != result.slot_assignments["s2"]


# ── 2: crossing fill respects shared letter ───────────────────────────────────


def test_crossing_fill_shares_letter() -> None:
    # KAR[1]='A' must equal the first letter of a down word; ARI starts with 'A'.
    filler = CSPFiller(["KAR", "ARI", "TOP", "SAP"], seed=2)
    result = filler.fill(_crossing())
    s1 = result.slot_assignments["s1"]
    s2 = result.slot_assignments["s2"]
    assert s1[1] == s2[0]


# ── 3: incompatible crossing → FillError ──────────────────────────────────────


def test_crossing_incompatible_raises() -> None:
    # index-1 letters {B, E, H} never appear as any index-0 letter {A, D, G}.
    filler = CSPFiller(["ABC", "DEF", "GHK"], seed=3)
    with pytest.raises(FillError):
        filler.fill(_crossing())


# ── 4: no length-matched word → FillError ─────────────────────────────────────


def test_empty_domain_raises() -> None:
    filler = CSPFiller(["DORT", "BESS", "ALTI"], seed=4)  # only length-4 words
    with pytest.raises(FillError):
        filler.fill(_two_non_crossing())  # needs length-3 words


# ── 5: MRV picks the smallest-domain slot first ───────────────────────────────


def test_mrv_selects_smallest_domain_first() -> None:
    template = _template(
        "t_mrv",
        4,
        6,
        [
            {"slot_id": "long", "direction": "right", "clue_cell": (0, 0),
             "cells": [(0, 1), (0, 2), (0, 3), (0, 4)]},
            {"slot_id": "short", "direction": "right", "clue_cell": (2, 0),
             "cells": [(2, 1), (2, 2), (2, 3)]},
        ],
    )
    # Four length-4 words, only two length-3 words → "short" has the smaller domain.
    filler = CSPFiller(["ABCD", "EFGH", "IJKL", "MNOP", "ARI", "KOL"], seed=5)
    filler.fill(template)
    assert filler.last_assignment_order[0] == "short"


# ── 6: AC-3 narrows the domains ───────────────────────────────────────────────


def test_ac3_narrows_domains() -> None:
    filler = CSPFiller(["KAR", "ARI", "TOP", "SAP"], seed=6)
    filler.fill(_crossing())
    before = filler.domains_before_ac3
    after = filler.domains_after_ac3
    assert sum(after.values()) < sum(before.values())
    assert after["s2"] < before["s2"]


# ── 7: unsatisfiable all-different → FillError after restarts ──────────────────


def test_max_attempts_exhausted_raises() -> None:
    # Two non-crossing slots but only one length-3 word: the all-different
    # constraint can never be satisfied. Domains stay non-empty (AC-3 passes),
    # so failure surfaces only after exhausting backtracking restarts.
    filler = CSPFiller(["KOL"], max_attempts=3, seed=7)
    with pytest.raises(FillError):
        filler.fill(_two_non_crossing())


# ── 8: same seed → deterministic result ───────────────────────────────────────


def test_seed_determinism() -> None:
    pool = ["KAR", "ARI", "ARA", "SAP", "TOP", "KOL", "RAF"]
    a = CSPFiller(list(pool), seed=99).fill(_crossing())
    b = CSPFiller(list(pool), seed=99).fill(_crossing())
    assert a.slot_assignments == b.slot_assignments


# ── 9: single-letter slot with no symbol in pool → FillError ───────────────────


def test_single_letter_slot_without_symbols_raises() -> None:
    template = _template(
        "t_single",
        4,
        4,
        [
            {"slot_id": "s1", "direction": "right", "clue_cell": (0, 0),
             "cells": [(0, 1)]},
        ],
    )
    filler = CSPFiller(["KAR", "ARI"], seed=9)  # no length-1 entries
    with pytest.raises(FillError):
        filler.fill(template)


# ── 10: realistic 5-slot crossword fills consistently ─────────────────────────


def test_five_slot_crossword_fills() -> None:
    # Designed 3×3 letter block (rows 1-3, cols 1-3):
    #   KAR (row1), ARA (col2), RAF (col3), KOL (col1), LAF (row3).
    template = _template(
        "t_five",
        6,
        6,
        [
            {"slot_id": "a1", "direction": "right", "clue_cell": (1, 0),
             "cells": [(1, 1), (1, 2), (1, 3)]},
            {"slot_id": "a2", "direction": "right", "clue_cell": (3, 0),
             "cells": [(3, 1), (3, 2), (3, 3)]},
            {"slot_id": "d1", "direction": "down", "clue_cell": (0, 1),
             "cells": [(1, 1), (2, 1), (3, 1)]},
            {"slot_id": "d2", "direction": "down", "clue_cell": (0, 2),
             "cells": [(1, 2), (2, 2), (3, 2)]},
            {"slot_id": "d3", "direction": "down", "clue_cell": (0, 3),
             "cells": [(1, 3), (2, 3), (3, 3)]},
        ],
    )
    pool = ["KAR", "LAF", "KOL", "RAF", "ARA", "TOP", "SAP", "YOL", "SES", "GÜL"]
    filler = CSPFiller(pool, seed=10)
    result = filler.fill(template)

    assert set(result.slot_assignments) == {"a1", "a2", "d1", "d2", "d3"}
    assert len(set(result.slot_assignments.values())) == 5  # all-different

    # Every crossing must agree on its shared letter.
    inter = compute_intersections(template.slots)
    for (x_id, y_id), (ix, iy) in inter.items():
        assert result.slot_assignments[x_id][ix] == result.slot_assignments[y_id][iy]


# ── Profanity guard (blacklist-aware CSP) ─────────────────────────────────────


def _three_parallel_downs() -> MaskTemplate:
    """Three non-crossing down slots in cols 1-3, each length 2 (rows 1-2).

    Rows 1 and 2 each form a length-3 horizontal run made of letters from three
    *different* vertical words — exactly the cross-slot adjacency that produces
    incidental profanity but is invisible to the CSP's crossing constraints.
    """
    return _template(
        "t_downs",
        4,
        4,
        [
            {"slot_id": "d1", "direction": "down", "clue_cell": (0, 1),
             "cells": [(1, 1), (2, 1)]},
            {"slot_id": "d2", "direction": "down", "clue_cell": (0, 2),
             "cells": [(1, 2), (2, 2)]},
            {"slot_id": "d3", "direction": "down", "clue_cell": (0, 3),
             "cells": [(1, 3), (2, 3)]},
        ],
    )


def _grid_from(result_assignments: dict[str, str], template: MaskTemplate) -> list[list[str]]:
    """Render slot assignments onto a rows×cols grid (clue cells stay '')."""
    grid = [["" for _ in range(template.grid.cols)] for _ in range(template.grid.rows)]
    slot_by_id = {s.slot_id: s for s in template.slots}
    for slot_id, word in result_assignments.items():
        for idx, wc in enumerate(slot_by_id[slot_id].cells):
            grid[wc.row][wc.col] = word[idx]
    return grid


# ── 11: blacklist steers the fill away from cross-slot profanity ──────────────


def test_blacklist_avoids_cross_slot_profanity() -> None:
    # row1 is a permutation of {A, M, K}; "AMK" (and its reverse "KMA") are
    # blacklisted. A blacklist-aware fill must produce a clean grid.
    template = _three_parallel_downs()
    pool = ["AL", "ME", "KO"]
    for seed in range(10):
        filler = CSPFiller(pool, blacklist={"AMK"}, seed=seed)
        result = filler.fill(template)
        grid = _grid_from(result.slot_assignments, template)
        assert scan_grid(grid, {"AMK"}) == []
        assert len(set(result.slot_assignments.values())) == 3  # all-different


# ── 12: every possible fill is profane → FillError ────────────────────────────


def test_only_profane_fill_raises() -> None:
    # Blacklisting all six permutations of {A, M, K} leaves no clean row1.
    template = _three_parallel_downs()
    every_perm = {"AMK", "AKM", "MAK", "MKA", "KAM", "KMA"}
    filler = CSPFiller(["AL", "ME", "KO"], blacklist=every_perm, max_attempts=5, seed=1)
    with pytest.raises(FillError):
        filler.fill(template)


# ── 13: internal grid is exactly the solution (place/restore correctness) ─────


def test_internal_grid_matches_solution() -> None:
    template = _three_parallel_downs()
    filler = CSPFiller(["AL", "ME", "KO"], blacklist={"AMK"}, seed=3)
    result = filler.fill(template)
    # After a successful fill the partial grid holds the solution and nothing
    # else — no residue from rejected words or backtracked branches.
    expected = {
        (wc.row, wc.col): result.slot_assignments[s.slot_id][idx]
        for s in template.slots
        for idx, wc in enumerate(s.cells)
    }
    assert filler._grid == expected


# ── 14: blacklist-aware fill is deterministic across instances ────────────────


def test_blacklist_determinism_two_instances() -> None:
    template = _three_parallel_downs()
    pool = ["AL", "ME", "KO"]
    a = CSPFiller(list(pool), blacklist={"AMK"}, seed=42).fill(template)
    b = CSPFiller(list(pool), blacklist={"AMK"}, seed=42).fill(template)
    assert a.slot_assignments == b.slot_assignments


# ── 15: same instance, two fill() calls → identical (no state leakage) ────────


def test_same_instance_repeat_fill_identical() -> None:
    # Calling fill() twice on ONE instance must reset RNG + grid so the second
    # result matches the first exactly (critical for P3 seed determinism).
    template = _three_parallel_downs()
    filler = CSPFiller(["AL", "ME", "KO"], blacklist={"AMK"}, seed=7)
    first = filler.fill(template)
    second = filler.fill(template)
    assert first.slot_assignments == second.slot_assignments
