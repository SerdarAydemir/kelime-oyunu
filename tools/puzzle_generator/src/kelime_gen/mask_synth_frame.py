# tools/puzzle_generator/src/kelime_gen/mask_synth_frame.py
"""Full-frame (Cross Up standard) mask enumeration for 9x7 grids.

Strict full-frame model (approved feasibility spike, 2026-06):
  * Total grid rows x cols (default 9x7). Row 0 and column 0 are clue cells,
    except the (0,0) corner which is BLANK. The interior (rows 1..R, cols 1..C)
    is fully packed with letters plus exactly k interior clue cells (blank=0).
  * Every maximal interior letter run is a clued slot: edge-adjacent runs are
    headed by a frame clue, the rest by the interior clue right before them.
    Frame clues must not be barren, so interior clues never sit in row 1/col 1.
  * Hard gates: len-1 slot count <= 4, len-2 slot count <= 5, slot crossing
    graph has exactly 1 component, k in [5, 7].

Unlike mask_synth.py (stochastic constructive search, kept for reproducing the
old production), this module *exhaustively enumerates* all capped masks per k,
caches a deterministic per-k reservoir sample as the mask library, and picks
from it with seed=puzzle_id. A mask is encoded as an int bitmask over the
interior cells (bit = (row-1)*C + (col-1)).
"""

from __future__ import annotations

import json
import random
from dataclasses import dataclass, field
from itertools import combinations
from pathlib import Path

from kelime_gen.mask_template import MaskTemplate, SlotSpec, TemplateCellSpec
from kelime_gen.schema import CellType, ClueArrow, GridSize, PuzzleSize, WordCell

FRAME_ROWS = 9
FRAME_COLS = 7
# Deterministic reservoir-sampling seed for the library build (never vary it:
# the cached library must be reproducible from source alone).
_SAMPLE_SEED = 20260611
LIBRARY_VERSION = 1

Cell = tuple[int, int]


class FrameSynthError(Exception):
    """Raised when the library cannot be built, loaded, or picked from."""


@dataclass(frozen=True)
class FrameParams:
    """Hard gates of the strict full-frame model (spike-approved defaults)."""

    rows: int = FRAME_ROWS
    cols: int = FRAME_COLS
    k_min: int = 5
    k_max: int = 7
    max_len1_slots: int = 4
    max_len2_slots: int = 5
    # Per-k library cap: if more masks pass the gates, a deterministic uniform
    # reservoir sample of this size is kept (full counts stay in the stats).
    per_k_cap: int = 25_000

    def cache_key(self) -> dict[str, int]:
        """The parameter fingerprint stored in (and checked against) the cache."""
        return {
            "rows": self.rows,
            "cols": self.cols,
            "k_min": self.k_min,
            "k_max": self.k_max,
            "max_len1_slots": self.max_len1_slots,
            "max_len2_slots": self.max_len2_slots,
            "per_k_cap": self.per_k_cap,
        }


def _run_table(line_len: int) -> list[tuple[int, int]]:
    """For every clue pattern over positions 1..line_len-1 of an interior line,
    the (len-1 run count, len-2 run count) of the resulting letter runs.

    Position 0 (interior row/col 1) can never be a clue, so patterns have
    line_len - 1 bits; bit i set means interior position i+1 is a clue.
    """
    table: list[tuple[int, int]] = []
    for pattern in range(1 << (line_len - 1)):
        n1 = n2 = run = 0
        for pos in range(line_len):
            if pos >= 1 and pattern >> (pos - 1) & 1:
                n1 += run == 1
                n2 += run == 2
                run = 0
            else:
                run += 1
        n1 += run == 1
        n2 += run == 2
        table.append((n1, n2))
    return table


class _FrameValidator:
    """Validates one interior clue placement against all hard gates."""

    def __init__(self, params: FrameParams) -> None:
        self.p = params
        self.ir = params.rows - 1  # interior row count (rows 1..ir)
        self.ic = params.cols - 1  # interior col count (cols 1..ic)
        self._row_table = _run_table(self.ic)
        self._col_table = _run_table(self.ir)

    def is_valid(self, clues: tuple[Cell, ...]) -> bool:
        clue_set = frozenset(clues)
        # Barren interior clue: needs a letter to its right or below.
        for r, c in clues:
            if (c == self.ic or (r, c + 1) in clue_set) and (
                r == self.ir or (r + 1, c) in clue_set
            ):
                return False
        if not self._caps_ok(clues):
            return False
        return self._connected(clue_set)

    def _caps_ok(self, clues: tuple[Cell, ...]) -> bool:
        """len-1 / len-2 slot caps via per-line pattern lookup tables."""
        row_bits: dict[int, int] = {}
        col_bits: dict[int, int] = {}
        for r, c in clues:
            row_bits[r] = row_bits.get(r, 0) | 1 << (c - 2)
            col_bits[c] = col_bits.get(c, 0) | 1 << (r - 2)
        # Clue-less lines contribute one full-length run (pattern 0); only
        # relevant on tiny test grids, zero for the production 9x7 frame.
        zr1, zr2 = self._row_table[0]
        zc1, zc2 = self._col_table[0]
        n1 = (self.ir - len(row_bits)) * zr1 + (self.ic - len(col_bits)) * zc1
        n2 = (self.ir - len(row_bits)) * zr2 + (self.ic - len(col_bits)) * zc2
        for bits in row_bits.values():
            a, b = self._row_table[bits]
            n1 += a
            n2 += b
        for bits in col_bits.values():
            a, b = self._col_table[bits]
            n1 += a
            n2 += b
        return n1 <= self.p.max_len1_slots and n2 <= self.p.max_len2_slots

    def _connected(self, clue_set: frozenset[Cell]) -> bool:
        """Single slot component <=> interior letter cells are 4-connected."""
        target = self.ir * self.ic - len(clue_set)
        seen = {(1, 1)}  # row 1 / col 1 hold no clues, so (1,1) is a letter
        stack = [(1, 1)]
        while stack:
            r, c = stack.pop()
            for nr, nc in ((r - 1, c), (r + 1, c), (r, c - 1), (r, c + 1)):
                if (
                    1 <= nr <= self.ir
                    and 1 <= nc <= self.ic
                    and (nr, nc) not in seen
                    and (nr, nc) not in clue_set
                ):
                    seen.add((nr, nc))
                    stack.append((nr, nc))
        return len(seen) == target


def _to_bits(clues: tuple[Cell, ...], interior_cols: int) -> int:
    bits = 0
    for r, c in clues:
        bits |= 1 << ((r - 1) * interior_cols + (c - 1))
    return bits


def _from_bits(bits: int, interior_cols: int) -> list[Cell]:
    cells: list[Cell] = []
    index = 0
    while bits >> index:
        if bits >> index & 1:
            cells.append((index // interior_cols + 1, index % interior_cols + 1))
        index += 1
    return cells


def enumerate_masks(params: FrameParams) -> tuple[dict[int, list[int]], dict[int, int]]:
    """Exhaustively scan all C(allowed, k) placements for every k in range.

    Returns (masks_per_k, total_valid_per_k). Each masks_per_k[k] is a sorted
    deterministic reservoir sample of at most params.per_k_cap bitmasks;
    total_valid_per_k[k] is the full pre-sampling valid count.
    """
    validator = _FrameValidator(params)
    # Interior clues only in rows 2..ir, cols 2..ic — a clue in row 1 / col 1
    # would orphan the frame clue heading that column / row (barren frame).
    allowed = [(r, c) for r in range(2, validator.ir + 1) for c in range(2, validator.ic + 1)]
    masks: dict[int, list[int]] = {}
    totals: dict[int, int] = {}
    for k in range(params.k_min, params.k_max + 1):
        rng = random.Random(_SAMPLE_SEED + k)
        sample: list[int] = []
        valid = 0
        for clues in combinations(allowed, k):
            if not validator.is_valid(clues):
                continue
            valid += 1
            if len(sample) < params.per_k_cap:
                sample.append(_to_bits(clues, validator.ic))
            else:  # reservoir sampling, algorithm R
                j = rng.randrange(valid)
                if j < params.per_k_cap:
                    sample[j] = _to_bits(clues, validator.ic)
        masks[k] = sorted(sample)
        totals[k] = valid
    return masks, totals


@dataclass
class FrameLibrary:
    """An ordered, deterministic library of (k, bitmask) frame masks."""

    params: FrameParams
    entries: list[tuple[int, int]]  # (k, bits), ordered k asc then bits asc
    total_valid: dict[int, int] = field(default_factory=dict)

    def __len__(self) -> int:
        return len(self.entries)

    def pick_index(self, seed: int) -> int:
        """Deterministically map a seed (puzzle_id) to a library index."""
        if not self.entries:
            raise FrameSynthError("frame library is empty")
        return random.Random(seed).randrange(len(self.entries))

    def template(self, index: int, size: PuzzleSize) -> MaskTemplate:
        k, bits = self.entries[index % len(self.entries)]
        return build_template(bits, self.params, size)


def build_template(bits: int, params: FrameParams, size: PuzzleSize) -> MaskTemplate:
    """Assemble a validated MaskTemplate from an interior clue bitmask."""
    ir, ic = params.rows - 1, params.cols - 1
    clue_set = set(_from_bits(bits, ic))

    def letter(r: int, c: int) -> bool:
        return 1 <= r <= ir and 1 <= c <= ic and (r, c) not in clue_set

    runs: list[tuple[ClueArrow, Cell, list[Cell]]] = []
    for r in range(1, ir + 1):
        c = 1
        while c <= ic:
            if letter(r, c):
                start = c
                while letter(r, c):
                    c += 1
                runs.append((ClueArrow.RIGHT, (r, start - 1), [(r, x) for x in range(start, c)]))
            else:
                c += 1
    for c in range(1, ic + 1):
        r = 1
        while r <= ir:
            if letter(r, c):
                start = r
                while letter(r, c):
                    r += 1
                runs.append((ClueArrow.DOWN, (start - 1, c), [(x, c) for x in range(start, r)]))
            else:
                r += 1

    rights = sorted((x for x in runs if x[0] == ClueArrow.RIGHT), key=lambda x: x[1])
    downs = sorted((x for x in runs if x[0] == ClueArrow.DOWN), key=lambda x: x[1])
    labeled = [(f"A{i}", x) for i, x in enumerate(rights, 1)]
    labeled += [(f"D{i}", x) for i, x in enumerate(downs, 1)]

    clue_slots: dict[Cell, list[str]] = {}
    cell_slots: dict[Cell, list[str]] = {}
    slots: list[SlotSpec] = []
    for slot_id, (direction, head, cells) in labeled:
        clue_slots.setdefault(head, []).append(slot_id)
        for cell in cells:
            cell_slots.setdefault(cell, []).append(slot_id)
        slots.append(
            SlotSpec(
                slot_id=slot_id,
                direction=direction,
                clue_cell=WordCell(row=head[0], col=head[1]),
                cells=[WordCell(row=r, col=c) for r, c in cells],
                length=len(cells),
            )
        )

    spec: list[TemplateCellSpec] = [TemplateCellSpec(row=0, col=0, type=CellType.BLANK)]
    frame_clues = [(0, c) for c in range(1, ic + 1)] + [(r, 0) for r in range(1, ir + 1)]
    for pos in frame_clues + sorted(clue_set):
        heads = sorted(clue_slots.get(pos, []))
        if not heads:
            raise FrameSynthError(f"barren clue cell {pos} in mask {bits:#x}")
        spec.append(TemplateCellSpec(row=pos[0], col=pos[1], type=CellType.CLUE, clue_slots=heads))
    for r in range(1, ir + 1):
        for c in range(1, ic + 1):
            if (r, c) not in clue_set:
                spec.append(
                    TemplateCellSpec(
                        row=r, col=c, type=CellType.LETTER, slot_ids=sorted(cell_slots[(r, c)])
                    )
                )
    return MaskTemplate(
        template_id=f"{size.value}_frame_{bits:012x}",
        size=size,
        grid=GridSize(rows=params.rows, cols=params.cols),
        cells=spec,
        slots=slots,
        transformable=False,  # the frame is orientation-bound (top/left clues)
    )


def build_library(params: FrameParams | None = None) -> FrameLibrary:
    """Enumerate the mask space and assemble the ordered library (no cache)."""
    p = params or FrameParams()
    masks, totals = enumerate_masks(p)
    entries = [(k, b) for k in sorted(masks) for b in masks[k]]
    return FrameLibrary(params=p, entries=entries, total_valid=totals)


def load_library(cache_path: Path, params: FrameParams | None = None) -> FrameLibrary:
    """Load the mask library from cache, building (and caching) it if needed.

    The cache is invalidated when the parameter fingerprint or library version
    differs, so stale caches can never leak into production silently.
    """
    p = params or FrameParams()
    if cache_path.exists():
        data = json.loads(cache_path.read_text(encoding="utf-8"))
        if data.get("version") == LIBRARY_VERSION and data.get("params") == p.cache_key():
            entries = [
                (int(k), b)
                for k, bs in sorted(data["masks"].items(), key=lambda kv: int(kv[0]))
                for b in bs
            ]
            totals = {int(k): v for k, v in data["total_valid"].items()}
            return FrameLibrary(params=p, entries=entries, total_valid=totals)
    library = build_library(p)
    cache_path.parent.mkdir(parents=True, exist_ok=True)
    by_k: dict[int, list[int]] = {}
    for k, bits in library.entries:
        by_k.setdefault(k, []).append(bits)
    cache_path.write_text(
        json.dumps(
            {
                "version": LIBRARY_VERSION,
                "params": p.cache_key(),
                "total_valid": {str(k): v for k, v in library.total_valid.items()},
                "masks": {str(k): v for k, v in by_k.items()},
            }
        ),
        encoding="utf-8",
    )
    return library
