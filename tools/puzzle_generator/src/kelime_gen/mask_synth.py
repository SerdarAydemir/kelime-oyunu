# tools/puzzle_generator/src/kelime_gen/mask_synth.py
"""Deterministic crossing-first mask synthesis (architecture.md §5.7).

The Boundary Impossibility Theorem (§5.7) rules out "blank=0 + every run clued +
min length 3 + crossings" simultaneously, so we use the *loose* model: interior
runs (start >= 1) are clued slots of length 3..8; runs that begin at the top/left
edge are incidental (unclued) letter sequences whose cells are covered by a
perpendicular interior slot.

Free CLUE/LETTER DFS and reading-order constructive search were both proven
unable to reach connected (crossing-rich) full packings at 8x6. This module
therefore builds *crossing-first*: it first lays an interlocking skeleton of
perpendicular words (deliberate crossings), then completes the grid with a
frontier backtracking filler, and finally validates the whole grid.

Construction invariants (so the result is valid by design, not by luck):
  * Clues are born only as word *heads* -> no barren clue.
  * Letters are created only as word cells -> no orphan letter.
  * A word's terminator may be the grid edge, an existing clue, or left EMPTY;
    it is never auto-converted to a new clue (note 2). The term-is-LETTER case is
    rejected (note 1) so two collinear words never merge at placement.

Output is a validated MaskTemplate; csp_filler.CSPFiller consumes it unchanged.
"""

from __future__ import annotations

import random
from collections import Counter
from dataclasses import dataclass

from kelime_gen.mask_template import MaskTemplate, SlotSpec, TemplateCellSpec
from kelime_gen.schema import CellType, ClueArrow, GridSize, PuzzleSize, WordCell

MIN_SLOT_LEN = 1
MAX_SLOT_LEN = 8
# Skeleton seed words stay >= 3 (real interlocking words, never 1-2 letters).
SKELETON_MIN_LEN = 3

# Per-length placement cost: 3-5 cheapest (preferred majority), 6-8 mild (a few
# long words), 1-2 expensive (rare — single letters/short words only sprinkled
# in). Lower cost is tried first; jitter (short_word_spread) keeps variety.
_LEN_COST: dict[int, float] = {1: 9.0, 2: 7.0, 3: 0.0, 4: 0.0, 5: 0.5, 6: 1.0, 7: 2.0, 8: 3.0}

Cell = tuple[int, int]
Grid = dict[Cell, CellType]


class MaskSynthError(Exception):
    """Raised when no valid grid is found within the restart budget."""


@dataclass
class SynthParams:
    """Tunable knobs. All randomness is derived from a single seeded RNG."""

    # Clue-density band (architecture.md §5.7). Empirically, balanced no-block
    # min-1 grids cluster at ~0.25-0.30 (the 0.30-0.40 reference estimate was
    # high — forcing it yields dottier grids and tanks the yield).
    min_clue_ratio: float = 0.25
    max_clue_ratio: float = 0.40
    slot_target: int = 12  # soft, currently advisory only
    skeleton_words: int = 6
    max_restarts: int = 600
    fill_budget: int = 150_000
    # None -> ceil(slot_count / 2) at validation time.
    min_crossings: int | None = None
    # min-1 fragments more than min-3; 4 keeps a tidy look (visual decision).
    max_components: int = 4
    # Reject any fully-letter rectangle this tall AND this wide (kills the
    # word-search "solid block" look). (3, 3) still allows thin 2xN / Nx2 strips.
    max_solid_block: tuple[int, int] = (3, 3)
    # At least this many clues must sit in the interior (row>=1 and col>=1);
    # zero interior clues means the clues are a mere frame -> a solid block.
    interior_clue_min: int = 1
    # Anti-fragmentation caps: keep single/double-letter slots rare so the grid
    # is not a "dotty" scatter; the majority stay 3-8 (Cross-Up balance).
    max_len1_slots: int = 3
    max_len2_slots: int = 3
    # Length-cost jitter: spread lets occasional longer words through.
    short_word_spread: float = 3.0
    # Cost discount for double-clue placements (one cell heading two words).
    double_clue_bonus: float = 1.5

    # ── Geometry seal (Cross Up standard, GÖREV 1) ──────────────────────────────
    # Crossing-less cell cap: at most this fraction of letter cells may belong to
    # a single slot (no intersection help). 0.35 -> >= ~65% of cells cross two
    # words. Empirically 0.25 was feasible but rare (1000-1500 restarts, 2-4
    # min/seed); 0.35 keeps a healthy yield (median ~56 restarts) while lifting
    # crossing coverage far above the un-gated ~47%.
    max_single_slot_ratio: float = 0.35
    # Incidental-run length cap: a clue-headless edge run (a horizontal run that
    # starts at col 0, or a vertical run that starts at row 0) may not exceed
    # this length. 3 kills the long un-clued "word-search" rows/cols; tighter
    # values are redundant since the single-slot cap already shortens edge runs.
    max_incidental_len: int = 3


@dataclass
class _Run:
    """A clued slot: an interior letter run of length 3..8."""

    direction: ClueArrow
    cells: list[Cell]
    clue: Cell


# ── Run extraction & validation ────────────────────────────────────────────────


def _extract_runs(grid: Grid, rows: int, cols: int) -> list[_Run]:
    """Return every clued slot: an interior (start>=1) letter run of length 3..8."""
    runs: list[_Run] = []
    for r in range(rows):
        c = 0
        while c < cols:
            if grid.get((r, c)) == CellType.LETTER:
                start = c
                while c < cols and grid.get((r, c)) == CellType.LETTER:
                    c += 1
                if start >= 1 and MIN_SLOT_LEN <= c - start <= MAX_SLOT_LEN:
                    runs.append(
                        _Run(ClueArrow.RIGHT, [(r, cc) for cc in range(start, c)], (r, start - 1))
                    )
            else:
                c += 1
    for c in range(cols):
        r = 0
        while r < rows:
            if grid.get((r, c)) == CellType.LETTER:
                start = r
                while r < rows and grid.get((r, c)) == CellType.LETTER:
                    r += 1
                if start >= 1 and MIN_SLOT_LEN <= r - start <= MAX_SLOT_LEN:
                    runs.append(
                        _Run(ClueArrow.DOWN, [(rr, c) for rr in range(start, r)], (start - 1, c))
                    )
            else:
                r += 1
    return runs


def _interior_runs_clean(grid: Grid, rows: int, cols: int) -> bool:
    """True iff every maximal interior run (start>=1) has length in 3..8.

    Edge-start runs (start == 0) are incidental and unconstrained.
    """
    for r in range(rows):
        c = 0
        while c < cols:
            if grid.get((r, c)) == CellType.LETTER:
                start = c
                while c < cols and grid.get((r, c)) == CellType.LETTER:
                    c += 1
                if start >= 1 and not (MIN_SLOT_LEN <= c - start <= MAX_SLOT_LEN):
                    return False
            else:
                c += 1
    for c in range(cols):
        r = 0
        while r < rows:
            if grid.get((r, c)) == CellType.LETTER:
                start = r
                while r < rows and grid.get((r, c)) == CellType.LETTER:
                    r += 1
                if start >= 1 and not (MIN_SLOT_LEN <= r - start <= MAX_SLOT_LEN):
                    return False
            else:
                r += 1
    return True


def _component_count(runs: list[_Run]) -> int:
    """Number of connected components in the slot crossing graph."""
    if not runs:
        return 0
    cell_to_idx: dict[Cell, list[int]] = {}
    for i, run in enumerate(runs):
        for cell in run.cells:
            cell_to_idx.setdefault(cell, []).append(i)
    adj: list[set[int]] = [set() for _ in runs]
    for idxs in cell_to_idx.values():
        for a in idxs:
            for b in idxs:
                if a != b:
                    adj[a].add(b)
    seen: set[int] = set()
    components = 0
    for start in range(len(runs)):
        if start in seen:
            continue
        components += 1
        stack = [start]
        seen.add(start)
        while stack:
            x = stack.pop()
            for y in adj[x]:
                if y not in seen:
                    seen.add(y)
                    stack.append(y)
    return components


def _crossing_count(runs: list[_Run]) -> int:
    """Number of cells shared by two slots (true crossings)."""
    cnt: Counter[Cell] = Counter()
    for run in runs:
        for cell in run.cells:
            cnt[cell] += 1
    return sum(1 for v in cnt.values() if v >= 2)


def _interior_clue_count(grid: Grid) -> int:
    """Clues sitting off the top row and left column (row>=1 and col>=1)."""
    return sum(1 for (r, c), t in grid.items() if t == CellType.CLUE and r >= 1 and c >= 1)


def _has_solid_block(grid: Grid, rows: int, cols: int, min_h: int, min_w: int) -> bool:
    """True if some min_h x min_w rectangle is entirely letter cells."""
    for r in range(rows - min_h + 1):
        for c in range(cols - min_w + 1):
            if all(
                grid.get((r + i, c + j)) == CellType.LETTER
                for i in range(min_h)
                for j in range(min_w)
            ):
                return True
    return False


def _slot_length_counts(runs: list[_Run]) -> Counter[int]:
    """Histogram of slot lengths (1..8)."""
    return Counter(len(run.cells) for run in runs)


def _single_slot_ratio(runs: list[_Run]) -> float:
    """Fraction of letter cells owned by exactly one slot (no crossing).

    The orphan gate guarantees every cell has >= 1 owner, so this is simply
    (cells with exactly one owner) / (all letter cells). Lower is better: a low
    ratio means most letters cross two words and get intersection help.
    """
    cnt: Counter[Cell] = Counter()
    for run in runs:
        for cell in run.cells:
            cnt[cell] += 1
    if not cnt:
        return 0.0
    single = sum(1 for v in cnt.values() if v == 1)
    return single / len(cnt)


def _max_incidental_len(grid: Grid, rows: int, cols: int) -> int:
    """Longest clue-headless (incidental) maximal letter run.

    In the loose model a horizontal run has a clue head iff it starts at col >= 1
    (the cell to its left is then a CLUE); a vertical run is clued iff it starts
    at row >= 1. So runs starting at the top row / left column are incidental.
    Returns the longest such run length, or 0 if there are none.
    """
    longest = 0
    for r in range(rows):
        c = 0
        while c < cols:
            if grid.get((r, c)) == CellType.LETTER:
                start = c
                while c < cols and grid.get((r, c)) == CellType.LETTER:
                    c += 1
                if start == 0:
                    longest = max(longest, c - start)
            else:
                c += 1
    for c in range(cols):
        r = 0
        while r < rows:
            if grid.get((r, c)) == CellType.LETTER:
                start = r
                while r < rows and grid.get((r, c)) == CellType.LETTER:
                    r += 1
                if start == 0:
                    longest = max(longest, r - start)
            else:
                r += 1
    return longest


def _evaluate(grid: Grid, rows: int, cols: int, params: SynthParams) -> list[_Run] | None:
    """Check the always-hard structural gates; return slots or None.

    Hard gates here: fully packed (blank=0), every interior run is a clean 3..8
    slot, no orphan letter, no barren clue. Clue ratio, interior-clue, solid
    block, crossing and component gates are applied by the caller.
    """
    total = rows * cols
    clue_cells = {p for p, t in grid.items() if t == CellType.CLUE}
    letter_cells = {p for p, t in grid.items() if t == CellType.LETTER}
    if len(clue_cells) + len(letter_cells) != total:
        return None  # an EMPTY cell remained -> not fully packed
    if not _interior_runs_clean(grid, rows, cols):
        return None
    runs = _extract_runs(grid, rows, cols)
    covered: set[Cell] = set()
    heads: set[Cell] = set()
    for run in runs:
        covered.update(run.cells)
        heads.add(run.clue)
    if letter_cells - covered:  # orphan letter
        return None
    if clue_cells - heads:  # barren clue
        return None
    return runs


# ── Template assembly ────────────────────────────────────────────────────────


def _assemble(
    grid: Grid, runs: list[_Run], rows: int, cols: int, size: PuzzleSize, seed: int
) -> MaskTemplate:
    """Turn a validated grid into a MaskTemplate (pydantic re-validates it)."""
    rights = sorted((run for run in runs if run.direction == ClueArrow.RIGHT), key=lambda x: x.clue)
    downs = sorted((run for run in runs if run.direction == ClueArrow.DOWN), key=lambda x: x.clue)
    labeled: list[tuple[str, _Run]] = []
    for i, run in enumerate(rights, 1):
        labeled.append((f"A{i}", run))
    for i, run in enumerate(downs, 1):
        labeled.append((f"D{i}", run))

    clue_slots: dict[Cell, list[str]] = {}
    cell_slots: dict[Cell, list[str]] = {}
    slots: list[SlotSpec] = []
    for slot_id, run in labeled:
        clue_slots.setdefault(run.clue, []).append(slot_id)
        for cell in run.cells:
            cell_slots.setdefault(cell, []).append(slot_id)
        slots.append(
            SlotSpec(
                slot_id=slot_id,
                direction=run.direction,
                clue_cell=WordCell(row=run.clue[0], col=run.clue[1]),
                cells=[WordCell(row=r, col=c) for r, c in run.cells],
                length=len(run.cells),
            )
        )

    cells: list[TemplateCellSpec] = []
    for (r, c), cell_type in sorted(grid.items()):
        if cell_type == CellType.CLUE:
            cells.append(
                TemplateCellSpec(
                    row=r, col=c, type=CellType.CLUE, clue_slots=sorted(clue_slots.get((r, c), []))
                )
            )
        else:
            cells.append(
                TemplateCellSpec(
                    row=r, col=c, type=CellType.LETTER, slot_ids=sorted(cell_slots.get((r, c), []))
                )
            )
    return MaskTemplate(
        template_id=f"{size.value}_synth_{seed}",
        size=size,
        grid=GridSize(rows=rows, cols=cols),
        cells=cells,
        slots=slots,
        transformable=True,
    )


# ── Crossing-first builder ──────────────────────────────────────────────────────


class _Builder:
    """One build attempt: skeleton (crossings) + frontier fill (packing)."""

    def __init__(self, rows: int, cols: int, rng: random.Random, params: SynthParams) -> None:
        self.rows = rows
        self.cols = cols
        self.rng = rng
        self.params = params
        self.grid: Grid = {}
        self.budget = params.fill_budget

    # -- geometry helpers --

    def _in(self, p: Cell) -> bool:
        return 0 <= p[0] < self.rows and 0 <= p[1] < self.cols

    def _cells_of(self, orient: ClueArrow, head: Cell, length: int) -> tuple[list[Cell], Cell]:
        r, c = head
        if orient == ClueArrow.RIGHT:
            return [(r, c + 1 + k) for k in range(length)], (r, c + 1 + length)
        return [(r + 1 + k, c) for k in range(length)], (r + 1 + length, c)

    def _can_place(self, orient: ClueArrow, head: Cell, length: int) -> list[Cell] | None:
        if not self._in(head) or self.grid.get(head) == CellType.LETTER:
            return None  # head cannot be a letter
        cells, term = self._cells_of(orient, head, length)
        for cell in cells:
            if not self._in(cell) or self.grid.get(cell) == CellType.CLUE:
                return None  # word cannot run off-grid or through a clue
        if self._in(term) and self.grid.get(term) == CellType.LETTER:
            return None  # note 1: terminator may not be a letter (no merge)
        return cells

    def _place_word(self, orient: ClueArrow, head: Cell, length: int) -> list[Cell] | None:
        """Place a word; return the cells newly written (for undo), or None."""
        if not (MIN_SLOT_LEN <= length <= MAX_SLOT_LEN):
            return None
        cells = self._can_place(orient, head, length)
        if cells is None:
            return None
        changed: list[Cell] = []
        if head not in self.grid:
            self.grid[head] = CellType.CLUE
            changed.append(head)
        for cell in cells:
            if cell not in self.grid:
                self.grid[cell] = CellType.LETTER
                changed.append(cell)
        # With min-1, short slots can break would-be blocks, so we can prune
        # solid blocks *during* construction (forces the fill to stay sparse).
        bh, bw = self.params.max_solid_block
        if not self._closed_interior_ok() or _has_solid_block(self.grid, self.rows, self.cols, bh, bw):
            for cell in changed:
                del self.grid[cell]
            return None
        return changed

    def _closed_interior_ok(self) -> bool:
        """Prune: every *closed* interior run must already be length 3..8.

        A run is closed when both its boundaries are CLUE/edge (it cannot grow).
        Open runs (a side touching EMPTY) may still grow, so they are skipped.
        """
        for r in range(self.rows):
            c = 0
            while c < self.cols:
                if self.grid.get((r, c)) == CellType.LETTER:
                    start = c
                    while c < self.cols and self.grid.get((r, c)) == CellType.LETTER:
                        c += 1
                    if start >= 1 and self.grid.get((r, start - 1)) == CellType.CLUE:
                        closed_right = c >= self.cols or self.grid.get((r, c)) == CellType.CLUE
                        if closed_right and not (MIN_SLOT_LEN <= c - start <= MAX_SLOT_LEN):
                            return False
                else:
                    c += 1
        for c in range(self.cols):
            r = 0
            while r < self.rows:
                if self.grid.get((r, c)) == CellType.LETTER:
                    start = r
                    while r < self.rows and self.grid.get((r, c)) == CellType.LETTER:
                        r += 1
                    if start >= 1 and self.grid.get((start - 1, c)) == CellType.CLUE:
                        closed_down = r >= self.rows or self.grid.get((r, c)) == CellType.CLUE
                        if closed_down and not (MIN_SLOT_LEN <= r - start <= MAX_SLOT_LEN):
                            return False
                else:
                    r += 1
        return True

    def _shuffled(self, items: list[int]) -> list[int]:
        out = list(items)
        self.rng.shuffle(out)
        return out

    # -- phase 1: skeleton --

    def build(self) -> Grid | None:
        if not self._skeleton():
            return None
        if not self._fill():
            return None
        return dict(self.grid)

    # Skeleton words stay short so the seed is a scattered interlocking core
    # rather than one long bar; the filler adds the length variety afterwards.
    _SKELETON_MAX_LEN = 4

    def _skeleton(self) -> bool:
        for r in self._shuffled(list(range(1, self.rows - 1))):
            for hc in self._shuffled(list(range(0, self.cols - SKELETON_MIN_LEN))):
                max_len = min(self._SKELETON_MAX_LEN, self.cols - 1 - hc)
                for length in self._shuffled(list(range(SKELETON_MIN_LEN, max_len + 1))):
                    if self._place_word(ClueArrow.RIGHT, (r, hc), length) is not None:
                        for _ in range(self.params.skeleton_words - 1):
                            self._add_crossing_word()
                        return True
        return False

    def _add_crossing_word(self) -> bool:
        letters = sorted(p for p, t in self.grid.items() if t == CellType.LETTER)
        self.rng.shuffle(letters)
        for xr, xc in letters:
            for perp in (
                [ClueArrow.DOWN, ClueArrow.RIGHT]
                if self.rng.random() < 0.5
                else [ClueArrow.RIGHT, ClueArrow.DOWN]
            ):
                for off in self._shuffled(list(range(self._SKELETON_MAX_LEN))):
                    head = (xr - 1 - off, xc) if perp == ClueArrow.DOWN else (xr, xc - 1 - off)
                    lengths = list(range(max(off + 1, SKELETON_MIN_LEN), self._SKELETON_MAX_LEN + 1))
                    for length in self._shuffled(lengths):
                        if self._place_word(perp, head, length) is not None:
                            return True
        return False

    # -- phase 2: frontier fill --

    def _first_empty(self) -> Cell | None:
        for r in range(self.rows):
            for c in range(self.cols):
                if (r, c) not in self.grid:
                    return (r, c)
        return None

    def _fill(self) -> bool:
        if self.budget <= 0:
            return False
        self.budget -= 1
        cell = self._first_empty()
        if cell is None:
            return True
        r, c = cell
        actions = self._frontier_actions(r, c)
        # Short-word-biased order: shorter placements first (more interior clues
        # and variety), with jitter so 5-8 words still appear; double clues get a
        # small discount. Drawing keys from self.rng keeps the build deterministic.
        keyed = sorted((self._action_cost(a), i, a) for i, a in enumerate(actions))
        for _cost, _i, act in keyed:
            changed = self._apply(act, r, c)
            if changed is not None:
                if self._fill():
                    return True
                for x in changed:
                    del self.grid[x]
        return False

    def _action_cost(self, act: tuple[str, object]) -> float:
        kind, payload = act
        if kind == "A":
            assert isinstance(payload, list)
            total = sum(_LEN_COST[length] for _orient, length in payload)
            if len(payload) == 2:
                total -= self.params.double_clue_bonus
        else:
            assert isinstance(payload, int)
            total = _LEN_COST[payload]
        return total + self.rng.uniform(0.0, self.params.short_word_spread)

    def _frontier_actions(self, r: int, c: int) -> list[tuple[str, object]]:
        rights = [L for L in range(MIN_SLOT_LEN, MAX_SLOT_LEN + 1)
                  if self._can_place(ClueArrow.RIGHT, (r, c), L) is not None]
        downs = [L for L in range(MIN_SLOT_LEN, MAX_SLOT_LEN + 1)
                 if self._can_place(ClueArrow.DOWN, (r, c), L) is not None]
        acts: list[tuple[str, object]] = []
        for length in rights:
            acts.append(("A", [(ClueArrow.RIGHT, length)]))
        for length in downs:
            acts.append(("A", [(ClueArrow.DOWN, length)]))
        for lr in rights:
            for ld in downs:
                acts.append(("A", [(ClueArrow.RIGHT, lr), (ClueArrow.DOWN, ld)]))
        if self.grid.get((r - 1, c)) == CellType.CLUE:
            for length in range(MIN_SLOT_LEN, MAX_SLOT_LEN + 1):
                if self._can_place(ClueArrow.DOWN, (r - 1, c), length) is not None:
                    acts.append(("B", length))
        if self.grid.get((r, c - 1)) == CellType.CLUE:
            for length in range(MIN_SLOT_LEN, MAX_SLOT_LEN + 1):
                if self._can_place(ClueArrow.RIGHT, (r, c - 1), length) is not None:
                    acts.append(("C", length))
        return acts

    def _apply(self, act: tuple[str, object], r: int, c: int) -> list[Cell] | None:
        kind, payload = act
        if kind == "A":
            combo = payload  # list[tuple[ClueArrow, int]]
            assert isinstance(combo, list)
            all_changed: list[Cell] = []
            for orient, length in combo:
                changed = self._place_word(orient, (r, c), length)
                if changed is None:
                    for x in all_changed:
                        del self.grid[x]
                    return None
                all_changed += changed
            return all_changed
        if kind == "B":
            assert isinstance(payload, int)
            return self._place_word(ClueArrow.DOWN, (r - 1, c), payload)
        assert kind == "C" and isinstance(payload, int)
        return self._place_word(ClueArrow.RIGHT, (r, c - 1), payload)


# ── Public API ──────────────────────────────────────────────────────────────────


def synthesize(
    rows: int, cols: int, size: PuzzleSize, seed: int, params: SynthParams | None = None
) -> MaskTemplate:
    """Synthesize a fully packed (blank=0) crossing-rich MaskTemplate.

    Deterministic: the same seed always yields an identical template. Raises
    MaskSynthError if no valid grid is found within ``params.max_restarts``.
    """
    p = params or SynthParams()
    rng = random.Random(seed)
    total = rows * cols
    for _ in range(p.max_restarts):
        grid = _Builder(rows, cols, rng, p).build()
        if grid is None:
            continue
        runs = _evaluate(grid, rows, cols, p)
        if runs is None:
            continue
        ratio = sum(1 for t in grid.values() if t == CellType.CLUE) / total
        if not (p.min_clue_ratio <= ratio <= p.max_clue_ratio):
            continue
        if _interior_clue_count(grid) < p.interior_clue_min:
            continue
        if _has_solid_block(grid, rows, cols, *p.max_solid_block):
            continue
        lengths = _slot_length_counts(runs)
        if lengths[1] > p.max_len1_slots or lengths[2] > p.max_len2_slots:
            continue  # keep single/double-letter slots rare (no "dotty" scatter)
        min_x = p.min_crossings if p.min_crossings is not None else (len(runs) + 1) // 2
        if _crossing_count(runs) < min_x:
            continue
        if _component_count(runs) > p.max_components:
            continue
        # Geometry seal (GÖREV 1): cap crossing-less cells and incidental runs.
        if _single_slot_ratio(runs) > p.max_single_slot_ratio:
            continue
        if _max_incidental_len(grid, rows, cols) > p.max_incidental_len:
            continue
        return _assemble(grid, runs, rows, cols, size, seed)
    raise MaskSynthError(f"no valid grid for {rows}x{cols} (seed={seed}, restarts={p.max_restarts})")
