# tools/puzzle_generator/src/kelime_gen/csp_filler.py
"""CSP fill: assign words to mask slots (architecture.md §6).

Each SlotSpec is a CSP variable; the word pool is its domain. The binary
constraint is that two intersecting slots share the same letter at their
crossing cell; the global constraint is that every assigned word is distinct
(no repeats within one puzzle). The pipeline is node consistency -> AC-3 ->
backtracking search with MRV / degree / LCV heuristics and forward checking.

Profanity scanning is NOT this module's concern: the word pool arrives clean
from word_pool.py, and the filled grid is scanned later in post_fill_safety.py.
The generator.py orchestrator owns that ordering.
"""

import random
from collections import deque

from pydantic import BaseModel

from kelime_gen.mask_template import MaskTemplate, SlotSpec
from kelime_gen.schema import tr_upper

# Crossing map: (slot_a, slot_b) -> (index_in_a, index_in_b). Stored in both
# directions so a lookup from either slot yields its own cell index first.
Intersections = dict[tuple[str, str], tuple[int, int]]


class FillError(Exception):
    """Raised when no consistent fill is found within max_attempts."""


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
        max_attempts: int = 20,
        seed: int | None = None,
    ) -> None:
        # Defensive normalization; word_pool.py already returns clean upper-case.
        self._word_pool: list[str] = [tr_upper(w) for w in word_pool]
        self._max_attempts = max_attempts
        self._rng = random.Random(seed)
        # Diagnostics populated by fill() for testability.
        self.last_assignment_order: list[str] = []
        self.domains_before_ac3: dict[str, int] = {}
        self.domains_after_ac3: dict[str, int] = {}

    def fill(self, template: MaskTemplate) -> FillResult:
        """Fill the template's slots. Raises FillError on failure."""
        slots = template.slots
        if not slots:
            raise FillError("template has no slots to fill")

        intersections = compute_intersections(slots)
        neighbors = self._build_neighbors(slots, intersections)

        # 1. Node consistency: keep only length-matched words per slot.
        base_domains: dict[str, list[str]] = {}
        for slot in slots:
            words = [w for w in self._word_pool if len(w) == slot.length]
            if not words:
                raise FillError(
                    f"slot {slot.slot_id!r}: no length-{slot.length} words in pool"
                )
            base_domains[slot.slot_id] = words
        self.domains_before_ac3 = {s: len(d) for s, d in base_domains.items()}

        # 2. AC-3 arc consistency.
        self._ac3(base_domains, intersections, neighbors)
        self.domains_after_ac3 = {s: len(d) for s, d in base_domains.items()}

        # 3. Backtracking search with random restarts.
        for _ in range(self._max_attempts):
            domains = {s: list(d) for s, d in base_domains.items()}
            for d in domains.values():
                self._rng.shuffle(d)
            self.last_assignment_order = []
            assignment: dict[str, str] = {}
            if self._backtrack(assignment, domains, intersections, neighbors):
                return FillResult(slot_assignments=assignment)

        raise FillError(f"no consistent fill after {self._max_attempts} attempts")

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
        if len(assignment) == len(domains):
            return True

        slot_id = self._select_unassigned(assignment, domains, neighbors)
        self.last_assignment_order.append(slot_id)

        for word in self._order_values(slot_id, assignment, domains, intersections, neighbors):
            saved = {s: list(d) for s, d in domains.items()}
            assignment[slot_id] = word
            domains[slot_id] = [word]
            if self._forward_check(slot_id, word, assignment, domains, intersections):
                if self._backtrack(assignment, domains, intersections, neighbors):
                    return True
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
                removed += sum(
                    1
                    for wn in domains[n_id]
                    if word == wn or word[idx_s] != wn[idx_n]
                )
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
                filtered = [
                    wn
                    for wn in domains[n_id]
                    if word != wn and word[idx_s] == wn[idx_n]
                ]
            else:
                # No crossing: only enforce the global all-different constraint.
                filtered = [wn for wn in domains[n_id] if wn != word]
            if not filtered:
                return False
            domains[n_id] = filtered
        return True
