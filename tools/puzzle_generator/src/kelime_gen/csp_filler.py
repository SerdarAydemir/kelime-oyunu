# tools/puzzle_generator/src/kelime_gen/csp_filler.py
"""CSP fill: assign words to mask slots (architecture.md §6).

Each SlotSpec is a CSP variable; the word pool is its domain. The binary
constraint is that two intersecting slots share the same letter at their
crossing cell; the global constraint is that every assigned word is distinct
(no repeats within one puzzle). The pipeline is node consistency -> AC-3 ->
backtracking search with MRV / degree / LCV heuristics and forward checking.

An optional blacklist enables an incremental profanity guard during search:
before recursing on a candidate word, the runs it completes in the partial
grid are scanned, so dead-end fills are pruned at the word level instead of
discarding the whole grid post-fill. This is a feasibility layer only —
post_fill_safety.scan_grid in generator.py stays the authoritative safety net
(architecture.md §6.4). When no blacklist is given, the guard is fully disabled
and behaviour is identical to a plain CSP fill.
"""

import random
from collections import deque
from collections.abc import Iterable

from pydantic import BaseModel

from kelime_gen.mask_template import MaskTemplate, SlotSpec
from kelime_gen.schema import tr_upper
from kelime_gen.validators.post_fill_safety import scan_segment

# A run is an ordered tuple of contiguous letter-cell coordinates (one row or
# one column), used by the incremental profanity guard.
Run = tuple[tuple[int, int], ...]

# Crossing map: (slot_a, slot_b) -> (index_in_a, index_in_b). Stored in both
# directions so a lookup from either slot yields its own cell index first.
Intersections = dict[tuple[str, str], tuple[int, int]]


class FillError(Exception):
    """Raised when no consistent fill is found within max_attempts."""


class _NodeBudgetExceeded(Exception):
    """Internal: one backtracking attempt ran past its node budget."""


class FillResult(BaseModel):
    """A successful fill: slot_id -> assigned word (Turkish upper-case)."""

    slot_assignments: dict[str, str]


def compute_intersections(slots: list[SlotSpec]) -> Intersections:
    """Find every crossing cell between slot pairs (symmetric result)."""
    cell_owners: dict[tuple[int, int], list[tuple[str, int]]] = {}
    for slot in slots:
        for idx, wc in enumerate(slot.cells):
            cell_owners.setdefault((wc.row, wc.col), []).append((slot.slot_id, idx))

    result: Intersections = {}
    for owners in cell_owners.values():
        if len(owners) < 2:
            continue
        for i in range(len(owners)):
            for j in range(i + 1, len(owners)):
                a_id, a_idx = owners[i]
                b_id, b_idx = owners[j]
                result[(a_id, b_id)] = (a_idx, b_idx)
                result[(b_id, a_id)] = (b_idx, a_idx)
    return result


class CSPFiller:
    """Fills a MaskTemplate from a word pool via AC-3 + backtracking search."""

    def __init__(
        self,
        word_pool: list[str],
        blacklist: Iterable[str] | None = None,
        max_attempts: int = 20,
        seed: int | None = None,
        min_n: int = 3,
        max_n: int = 8,
        node_budget: int | None = 25_000,
    ) -> None:
        # Defensive normalization; word_pool.py already returns clean upper-case.
        self._word_pool: list[str] = [tr_upper(w) for w in word_pool]
        # Empty blacklist -> guard disabled, grid never maintained (zero cost).
        self._blacklist: frozenset[str] = (
            frozenset(tr_upper(w) for w in blacklist) if blacklist else frozenset()
        )
        self._min_n = min_n
        self._max_n = max_n
        self._max_attempts = max_attempts
        # Per-attempt backtracking node budget (None disables). Failing fills
        # are heavy-tailed: a single unlucky search tree can run for minutes,
        # so each attempt is capped and retried with a different shuffle.
        self._node_budget = node_budget
        self._nodes = 0
        self._seed = seed
        self._rng = random.Random(seed)
        # Partial grid + run index, (re)built per fill() when a blacklist is set.
        self._grid: dict[tuple[int, int], str] = {}
        self._cell_to_runs: dict[tuple[int, int], list[Run]] = {}
        self._slot_by_id: dict[str, SlotSpec] = {}
        # Diagnostics populated by fill() for testability.
        self.last_assignment_order: list[str] = []
        self.domains_before_ac3: dict[str, int] = {}
        self.domains_after_ac3: dict[str, int] = {}
        self.last_budget_hits = 0
        self.last_attempts = 0

    def fill(self, template: MaskTemplate) -> FillResult:
        """Fill the template's slots. Raises FillError on failure."""
        slots = template.slots
        if not slots:
            raise FillError("template has no slots to fill")

        # Reset every per-fill piece of state so repeated calls on one instance
        # are deterministic: the RNG returns to its seed and not a single letter
        # leaks from a previous attempt or a previous fill() call.
        self._rng = random.Random(self._seed)
        self._grid = {}
        self._slot_by_id = {s.slot_id: s for s in slots}
        self._cell_to_runs = self._build_runs(slots) if self._blacklist else {}

        intersections = compute_intersections(slots)
        neighbors = self._build_neighbors(slots, intersections)

        # 1. Node consistency: keep only length-matched words per slot.
        base_domains: dict[str, list[str]] = {}
        for slot in slots:
            words = [w for w in self._word_pool if len(w) == slot.length]
            if not words:
                raise FillError(f"slot {slot.slot_id!r}: no length-{slot.length} words in pool")
            base_domains[slot.slot_id] = words
        self.domains_before_ac3 = {s: len(d) for s, d in base_domains.items()}

        # 2. AC-3 arc consistency.
        self._ac3(base_domains, intersections, neighbors)
        self.domains_after_ac3 = {s: len(d) for s, d in base_domains.items()}

        # 3. Backtracking search with random restarts. Every attempt gets its
        # own node budget; an exhausted attempt is abandoned and retried with
        # a different domain shuffle (the RNG keeps advancing across attempts).
        self.last_budget_hits = 0
        self.last_attempts = 0
        for attempt in range(self._max_attempts):
            # Each restart starts from an empty grid — no residue from the
            # previous attempt may influence the profanity guard.
            self._grid = {}
            self._nodes = 0
            domains = {s: list(d) for s, d in base_domains.items()}
            for d in domains.values():
                self._rng.shuffle(d)
            self.last_assignment_order = []
            assignment: dict[str, str] = {}
            self.last_attempts = attempt + 1
            try:
                if self._backtrack(assignment, domains, intersections, neighbors):
                    return FillResult(slot_assignments=assignment)
            except _NodeBudgetExceeded:
                self.last_budget_hits += 1

        raise FillError(f"no consistent fill after {self._max_attempts} attempts")

    # ── Profanity guard (active only when a blacklist was supplied) ────────────

    @staticmethod
    def _build_runs(slots: list[SlotSpec]) -> dict[tuple[int, int], list[Run]]:
        """Map each letter cell to the maximal horizontal/vertical runs on it.

        A run is a maximal contiguous sequence of letter cells in one row or
        column. Clue/blank cells (absent from any slot) break runs, mirroring
        how scan_grid's _segments splits on empty cells. Computed once per fill.
        """
        letter_cells: set[tuple[int, int]] = set()
        for slot in slots:
            for wc in slot.cells:
                letter_cells.add((wc.row, wc.col))

        by_row: dict[int, list[int]] = {}
        by_col: dict[int, list[int]] = {}
        for r, c in letter_cells:
            by_row.setdefault(r, []).append(c)
            by_col.setdefault(c, []).append(r)

        runs: list[Run] = []
        for r, cols in by_row.items():
            ordered = sorted(cols)
            run: list[tuple[int, int]] = [(r, ordered[0])]
            for c in ordered[1:]:
                if c == run[-1][1] + 1:
                    run.append((r, c))
                else:
                    runs.append(tuple(run))
                    run = [(r, c)]
            runs.append(tuple(run))
        for c, rows in by_col.items():
            ordered = sorted(rows)
            run = [(ordered[0], c)]
            for r in ordered[1:]:
                if r == run[-1][0] + 1:
                    run.append((r, c))
                else:
                    runs.append(tuple(run))
                    run = [(r, c)]
            runs.append(tuple(run))

        cell_to_runs: dict[tuple[int, int], list[Run]] = {}
        for built in runs:
            for cell in built:
                cell_to_runs.setdefault(cell, []).append(built)
        return cell_to_runs

    def _place(self, slot: SlotSpec, word: str) -> dict[tuple[int, int], str | None]:
        """Write a word's letters into the partial grid; return prior values.

        Crossing cells already hold the same letter from their other (assigned)
        slot; the returned snapshot lets _restore replay that prior value so a
        shared cell is never wrongly cleared on backtrack.
        """
        prev: dict[tuple[int, int], str | None] = {}
        for idx, wc in enumerate(slot.cells):
            cell = (wc.row, wc.col)
            prev[cell] = self._grid.get(cell)
            self._grid[cell] = word[idx]
        return prev

    def _restore(self, prev: dict[tuple[int, int], str | None]) -> None:
        for cell, value in prev.items():
            if value is None:
                self._grid.pop(cell, None)
            else:
                self._grid[cell] = value

    def _creates_profanity(self, slot: SlotSpec) -> bool:
        """True if the just-placed slot completes a blacklisted run segment.

        Only the runs touched by this slot's cells are scanned, and within each
        run only the currently-filled contiguous segments. Completeness holds
        because the last cell to fill any segment belongs to some slot, so the
        segment is scanned the moment it becomes complete.
        """
        checked: set[int] = set()
        for wc in slot.cells:
            for run in self._cell_to_runs.get((wc.row, wc.col), ()):
                rid = id(run)
                if rid in checked:
                    continue
                checked.add(rid)
                segment: list[str] = []
                for cell in run:
                    letter = self._grid.get(cell)
                    if letter is None:
                        if segment and scan_segment(
                            "".join(segment), self._blacklist, self._min_n, self._max_n
                        ):
                            return True
                        segment = []
                    else:
                        segment.append(letter)
                if segment and scan_segment(
                    "".join(segment), self._blacklist, self._min_n, self._max_n
                ):
                    return True
        return False

    @staticmethod
    def _build_neighbors(
        slots: list[SlotSpec],
        intersections: Intersections,
    ) -> dict[str, list[str]]:
        neighbors: dict[str, list[str]] = {s.slot_id: [] for s in slots}
        for a_id, b_id in intersections:
            neighbors[a_id].append(b_id)
        return neighbors

    # ── AC-3 ────────────────────────────────────────────────────────────────

    def _ac3(
        self,
        domains: dict[str, list[str]],
        intersections: Intersections,
        neighbors: dict[str, list[str]],
    ) -> None:
        queue: deque[tuple[str, str]] = deque(intersections.keys())
        while queue:
            x_id, y_id = queue.popleft()
            if self._revise(domains, intersections, x_id, y_id):
                if not domains[x_id]:
                    raise FillError(f"slot {x_id!r}: domain emptied during AC-3")
                for z_id in neighbors[x_id]:
                    if z_id != y_id:
                        queue.append((z_id, x_id))

    @staticmethod
    def _revise(
        domains: dict[str, list[str]],
        intersections: Intersections,
        x_id: str,
        y_id: str,
    ) -> bool:
        idx_x, idx_y = intersections[(x_id, y_id)]
        kept: list[str] = [
            wx
            for wx in domains[x_id]
            if any(wx != wy and wx[idx_x] == wy[idx_y] for wy in domains[y_id])
        ]
        if len(kept) != len(domains[x_id]):
            domains[x_id] = kept
            return True
        return False

    # ── Backtracking search ───────────────────────────────────────────────────

    def _backtrack(
        self,
        assignment: dict[str, str],
        domains: dict[str, list[str]],
        intersections: Intersections,
        neighbors: dict[str, list[str]],
    ) -> bool:
        self._nodes += 1
        if self._node_budget is not None and self._nodes > self._node_budget:
            raise _NodeBudgetExceeded
        if len(assignment) == len(domains):
            return True

        slot_id = self._select_unassigned(assignment, domains, neighbors)
        self.last_assignment_order.append(slot_id)
        slot = self._slot_by_id[slot_id]

        for word in self._order_values(slot_id, assignment, domains, intersections, neighbors):
            saved = {s: list(d) for s, d in domains.items()}
            assignment[slot_id] = word
            domains[slot_id] = [word]

            # Place the word on the grid and reject it if it completes a
            # blacklisted run. Grid maintenance is skipped entirely when no
            # blacklist was supplied (prev stays None).
            prev = self._place(slot, word) if self._blacklist else None
            profane = prev is not None and self._creates_profanity(slot)

            if not profane and self._forward_check(
                slot_id, word, assignment, domains, intersections
            ):
                if self._backtrack(assignment, domains, intersections, neighbors):
                    return True

            if prev is not None:
                self._restore(prev)
            del assignment[slot_id]
            for s, d in saved.items():
                domains[s] = d

        self.last_assignment_order.pop()
        return False

    @staticmethod
    def _select_unassigned(
        assignment: dict[str, str],
        domains: dict[str, list[str]],
        neighbors: dict[str, list[str]],
    ) -> str:
        """MRV (fewest remaining values), tie-break by highest degree."""
        unassigned = [s for s in domains if s not in assignment]

        def degree(slot_id: str) -> int:
            return sum(1 for n in neighbors[slot_id] if n not in assignment)

        return min(unassigned, key=lambda s: (len(domains[s]), -degree(s)))

    @staticmethod
    def _order_values(
        slot_id: str,
        assignment: dict[str, str],
        domains: dict[str, list[str]],
        intersections: Intersections,
        neighbors: dict[str, list[str]],
    ) -> list[str]:
        """LCV: try the word that removes the fewest neighbour options first."""
        open_neighbors = [n for n in neighbors[slot_id] if n not in assignment]

        def constraining(word: str) -> int:
            removed = 0
            for n_id in open_neighbors:
                idx_s, idx_n = intersections[(slot_id, n_id)]
                removed += sum(1 for wn in domains[n_id] if word == wn or word[idx_s] != wn[idx_n])
            return removed

        return sorted(domains[slot_id], key=constraining)

    @staticmethod
    def _forward_check(
        slot_id: str,
        word: str,
        assignment: dict[str, str],
        domains: dict[str, list[str]],
        intersections: Intersections,
    ) -> bool:
        """Prune unassigned domains; return False if any becomes empty."""
        for n_id in domains:
            if n_id == slot_id or n_id in assignment:
                continue
            key = (slot_id, n_id)
            if key in intersections:
                idx_s, idx_n = intersections[key]
                filtered = [wn for wn in domains[n_id] if word != wn and word[idx_s] == wn[idx_n]]
            else:
                # No crossing: only enforce the global all-different constraint.
                filtered = [wn for wn in domains[n_id] if wn != word]
            if not filtered:
                return False
            domains[n_id] = filtered
        return True
