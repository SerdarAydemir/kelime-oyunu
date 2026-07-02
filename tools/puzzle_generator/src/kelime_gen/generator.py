# tools/puzzle_generator/src/kelime_gen/generator.py
"""Orchestrates the v2 puzzle generation pipeline (architecture.md §6.6, §15).

Pipeline per puzzle:
  pick a full-frame mask from the enumerated library (seed=puzzle_id)
  -> CSP fill -> post-fill profanity scan -> clue writing
  -> CellSpec/WordSpec assembly -> difficulty score
  -> validated PuzzleData -> JSON on disk.

If the fill fails on the picked mask, the pack loop falls back to the *next*
mask in library order (never a seed restart) until the puzzle fills, so a
full pack is effectively guaranteed. Masks that produced a written puzzle are
never reused within one pack (mask uniqueness).

csp_filler owns the fill, post_fill_safety owns the profanity scan,
clue_writer owns the clue text, and mask_synth_frame owns the mask library;
this module wires them together.
"""

import sys
import time
from dataclasses import dataclass, field
from pathlib import Path
from typing import TypedDict

from pydantic import ValidationError

from kelime_gen.clue_writer import write_clues
from kelime_gen.csp_filler import CSPFiller, FillError
from kelime_gen.difficulty import difficulty_score
from kelime_gen.mask_synth_frame import FrameLibrary
from kelime_gen.mask_template import MaskTemplate
from kelime_gen.schema import (
    CellSpec,
    CellType,
    ClueSpec,
    PuzzleData,
    PuzzleSize,
    SafetyInfo,
    WordCell,
    WordSpec,
)
from kelime_gen.validators.post_fill_safety import scan_grid
from kelime_gen.word_pool import PoolEntry

# Difficulty label bands: score < threshold -> label; anything else -> "expert".
_DIFFICULTY_BANDS: list[tuple[int, str]] = [(25, "easy"), (50, "medium"), (75, "hard")]


def _difficulty_label(score: int) -> str:
    for threshold, label in _DIFFICULTY_BANDS:
        if score < threshold:
            return label
    return "expert"


def _build_grid(
    template: MaskTemplate,
    slot_assignments: dict[str, str],
) -> list[list[str]]:
    """Render assigned words onto a rows×cols matrix; non-letter cells stay ''."""
    grid: list[list[str]] = [
        ["" for _ in range(template.grid.cols)] for _ in range(template.grid.rows)
    ]
    for slot in template.slots:
        word = slot_assignments[slot.slot_id]
        for index, wc in enumerate(slot.cells):
            grid[wc.row][wc.col] = word[index]
    return grid


def _build_cells(
    template: MaskTemplate,
    grid: list[list[str]],
    clue_by_slot: dict[str, ClueSpec],
) -> list[CellSpec]:
    """Convert template cells into solution-bearing CellSpecs."""
    cells: list[CellSpec] = []
    for cell in template.cells:
        if cell.type == CellType.LETTER:
            cells.append(
                CellSpec(
                    row=cell.row,
                    col=cell.col,
                    type=CellType.LETTER,
                    solution=grid[cell.row][cell.col],
                    word_ids=list(cell.slot_ids),
                )
            )
        elif cell.type == CellType.CLUE:
            cells.append(
                CellSpec(
                    row=cell.row,
                    col=cell.col,
                    type=CellType.CLUE,
                    clues=[clue_by_slot[sid] for sid in cell.clue_slots],
                )
            )
        else:  # CellType.BLANK
            cells.append(CellSpec(row=cell.row, col=cell.col, type=CellType.BLANK))
    return cells


def _build_words(
    template: MaskTemplate,
    slot_assignments: dict[str, str],
    clue_by_slot: dict[str, ClueSpec],
    freq_map: dict[str, int],
) -> list[WordSpec]:
    """Build one WordSpec per slot, wiring in the per-slot clue and frequency."""
    words: list[WordSpec] = []
    for slot in template.slots:
        answer = slot_assignments[slot.slot_id]
        words.append(
            WordSpec(
                id=slot.slot_id,
                answer=answer,
                length=slot.length,
                direction=slot.direction,
                clue_cell=slot.clue_cell,
                start_cell=slot.cells[0],
                cells=[WordCell(row=c.row, col=c.col) for c in slot.cells],
                clue=clue_by_slot[slot.slot_id],
                frequency_score=freq_map.get(answer, 0),
            )
        )
    return words


class FillStats(TypedDict):
    """Per-fill diagnostics surfaced to the pack loop for reporting."""

    attempts: int
    budget_hits: int


def generate_puzzle(
    template: MaskTemplate,
    word_pool: list[PoolEntry],
    blacklist: set[str],
    puzzle_id: int,
    category: str | None,
    curated_clues: dict[str, str] | None = None,
    master_clues: dict[str, str] | None = None,
    generator_version: str = "2.0.0",
    max_fill_attempts: int = 200,
    seed: int | None = None,
    fill_stats: FillStats | None = None,
) -> PuzzleData | None:
    """Generate one validated PuzzleData, or None on any recoverable failure.

    Failures (fill, profanity, schema) are logged to stderr and surface as None
    so the pack loop can skip and retry with another template/seed. When a
    fill_stats dict is passed, the filler's attempt/budget diagnostics are
    accumulated into it (also on failure).
    """
    word_strings = [p["word"] for p in word_pool]
    freq_map = {p["word"]: p["frequency_score"] for p in word_pool}

    # 1-2. CSP fill. The blacklist is passed so the filler avoids cross-slot
    # profanity at the word level; scan_grid below stays the authoritative net.
    # min_n=3 / max_n=8 match the profanity scanner window (architecture.md §6.4).
    filler = CSPFiller(
        word_strings,
        blacklist=blacklist,
        max_attempts=max_fill_attempts,
        seed=seed,
        min_n=3,
        max_n=8,
    )
    try:
        fill = filler.fill(template)
    except FillError as exc:
        print(f"[SKIP] puzzle {puzzle_id}: fill failed — {exc}", file=sys.stderr)
        return None
    finally:
        if fill_stats is not None:
            fill_stats["attempts"] += filler.last_attempts
            fill_stats["budget_hits"] += filler.last_budget_hits
    slot_assignments = fill.slot_assignments

    # 3. Render the grid and scan it for profanity (architecture.md §6.4).
    #    Defence in depth: the CSP guard should make this a no-op, but a full
    #    independent scan is the contract behind safety.post_fill_scanned.
    grid = _build_grid(template, slot_assignments)
    hits = scan_grid(grid, blacklist)
    if hits:
        print(
            f"[SKIP] puzzle {puzzle_id}: profanity {sorted(set(hits))}",
            file=sys.stderr,
        )
        return None

    # 4. Clues — curated (len-1/2) beats LLM (len 3-8) beats placeholder.
    #    Then attach the real word_id and arrow direction to each slot's clue.
    items = list(slot_assignments.items())
    answers = [answer for _, answer in items]
    raw_clues = write_clues(
        answers,
        default_category=category,
        curated_clues=curated_clues,
        master_clues=master_clues,
    )
    # Placeholder gate (P0, runtime half): the pool pre-filter should make
    # placeholders impossible, but if one slips through ("N harfli kelime" is
    # unplayable) the puzzle is rejected here instead of being written to disk.
    unclued = sorted({answer for (_, answer), c in zip(items, raw_clues) if c.source == "placeholder"})
    if unclued:
        print(f"[SKIP] puzzle {puzzle_id}: placeholder clue for {unclued}", file=sys.stderr)
        return None

    slot_by_id = {s.slot_id: s for s in template.slots}
    clue_by_slot: dict[str, ClueSpec] = {
        sid: clue.model_copy(update={"word_id": sid, "arrow": slot_by_id[sid].direction})
        for (sid, _answer), clue in zip(items, raw_clues)
    }

    # 5-8. Assemble and validate the puzzle (any schema error -> None).
    try:
        draft = PuzzleData(
            puzzle_id=puzzle_id,
            size=template.size,
            grid=template.grid,
            cells=_build_cells(template, grid, clue_by_slot),
            words=_build_words(template, slot_assignments, clue_by_slot, freq_map),
            template_id=template.template_id,
            safety=SafetyInfo(post_fill_scanned=True),
            generator_version=generator_version,
        )
    except ValidationError as exc:
        print(f"[SKIP] puzzle {puzzle_id}: validation failed — {exc}", file=sys.stderr)
        return None

    score = difficulty_score(draft)
    return draft.model_copy(
        update={"difficulty_score": score, "difficulty": _difficulty_label(score)}
    )


class PuzzleStat(TypedDict):
    """Per-puzzle runtime stats collected by generate_pack for the report."""

    puzzle_id: int
    template_id: str
    k: int
    library_index: int
    fallbacks: int
    fill_attempts: int
    budget_hits: int
    duration_s: float


@dataclass
class PackResult:
    """Outcome of one generate_pack run."""

    success: int = 0
    failed: int = 0
    stats: list[PuzzleStat] = field(default_factory=list)


def _next_free(index: int, used: set[int], size: int) -> int:
    """First library index >= index (cyclic) not yet used in this pack."""
    while index in used:
        index = (index + 1) % size
    return index


def generate_pack(
    word_pool: list[PoolEntry],
    blacklist: set[str],
    start_puzzle_id: int,
    count: int,
    category: str | None,
    output_dir: Path,
    *,
    library: FrameLibrary,
    size: PuzzleSize = PuzzleSize.MEDIUM,
    curated_clues: dict[str, str] | None = None,
    master_clues: dict[str, str] | None = None,
    generator_version: str = "2.0.0",
    fill_attempts_per_mask: int = 3,
    max_mask_fallbacks: int = 200,
) -> PackResult:
    """Generate *count* puzzles into *output_dir* from the frame mask library.

    Mask choice is deterministic: library.pick_index(seed=puzzle_id). When the
    CSP fill fails on a mask, the loop falls back to the *next* mask in library
    order (mask-ordered fallback — never a seed restart), up to
    max_mask_fallbacks masks per puzzle. A mask that produced a written puzzle
    is never reused within the pack, so every puzzle gets a unique mask.

    fill_attempts_per_mask is deliberately small: measured on the 9x7 frame,
    a mask that survives its first few budget-capped attempts almost never
    fills on later shuffles, while the library holds tens of thousands of
    fresh masks — cutting losses early and falling back is far cheaper.
    """
    if count > len(library):
        raise ValueError(
            f"generate_pack: count {count} exceeds library size {len(library)} "
            "(mask uniqueness cannot hold)"
        )
    output_dir.mkdir(parents=True, exist_ok=True)
    result = PackResult()
    used: set[int] = set()

    for offset in range(count):
        puzzle_id = start_puzzle_id + offset
        started = time.perf_counter()
        index = _next_free(library.pick_index(seed=puzzle_id), used, len(library))
        fill_stats: FillStats = {"attempts": 0, "budget_hits": 0}
        puzzle: PuzzleData | None = None
        fallbacks = 0

        while fallbacks < max_mask_fallbacks:
            template = library.template(index, size)
            puzzle = generate_puzzle(
                template=template,
                word_pool=word_pool,
                blacklist=blacklist,
                puzzle_id=puzzle_id,
                category=category,
                curated_clues=curated_clues,
                master_clues=master_clues,
                generator_version=generator_version,
                max_fill_attempts=fill_attempts_per_mask,
                seed=puzzle_id,
                fill_stats=fill_stats,
            )
            if puzzle is not None:
                break
            fallbacks += 1
            index = _next_free((index + 1) % len(library), used, len(library))

        if puzzle is None:
            result.failed += 1
            print(
                f"[ERROR] puzzle {puzzle_id}: {max_mask_fallbacks} mask denendi, "
                "hiçbiri dolmadı — atlanıyor.",
                file=sys.stderr,
            )
            continue
        # Defence in depth: never write an unscanned puzzle (coding-standards §8.7).
        if not puzzle.safety.post_fill_scanned:
            result.failed += 1
            print(
                f"[ERROR] puzzle {puzzle_id}: not scanned — refusing to write.",
                file=sys.stderr,
            )
            continue
        path = output_dir / f"puzzle_{puzzle_id:04d}.json"
        path.write_text(puzzle.model_dump_json(indent=2), encoding="utf-8")
        used.add(index)
        result.success += 1
        result.stats.append(
            PuzzleStat(
                puzzle_id=puzzle_id,
                template_id=puzzle.template_id,
                k=library.entries[index][0],
                library_index=index,
                fallbacks=fallbacks,
                fill_attempts=fill_stats["attempts"],
                budget_hits=fill_stats["budget_hits"],
                duration_s=round(time.perf_counter() - started, 3),
            )
        )

    return result
