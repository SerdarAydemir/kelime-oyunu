# tools/puzzle_generator/src/kelime_gen/generator.py
"""Orchestrates the v2 puzzle generation pipeline (architecture.md §6.6, §15).

Pipeline per puzzle:
  mask template (+ transform) -> CSP fill -> post-fill profanity scan
  -> clue writing -> CellSpec/WordSpec assembly -> difficulty score
  -> validated PuzzleData -> JSON on disk.

csp_filler owns the fill, post_fill_safety owns the profanity scan, and
clue_writer owns the clue text; this module wires them together.
"""

import random
import sys
from pathlib import Path

from pydantic import ValidationError

from kelime_gen.clue_writer import write_clues
from kelime_gen.csp_filler import CSPFiller, FillError
from kelime_gen.difficulty import difficulty_score
from kelime_gen.mask_template import MaskTemplate, get_transforms
from kelime_gen.schema import (
    CellSpec,
    CellType,
    ClueSpec,
    PuzzleData,
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


def generate_puzzle(
    template: MaskTemplate,
    word_pool: list[PoolEntry],
    blacklist: set[str],
    puzzle_id: int,
    category: str | None,
    tdk_definitions: dict[str, str] | None = None,
    generator_version: str = "2.0.0",
    max_fill_attempts: int = 200,
    seed: int | None = None,
) -> PuzzleData | None:
    """Generate one validated PuzzleData, or None on any recoverable failure.

    Failures (fill, profanity, schema) are logged to stderr and surface as None
    so the pack loop can skip and retry with another template/seed.
    """
    word_strings = [p["word"] for p in word_pool]
    freq_map = {p["word"]: p["frequency_score"] for p in word_pool}

    # 1-2. CSP fill. The blacklist is passed so the filler avoids cross-slot
    # profanity at the word level; scan_grid below stays the authoritative net.
    try:
        fill = CSPFiller(
            word_strings,
            blacklist=blacklist,
            max_attempts=max_fill_attempts,
            seed=seed,
        ).fill(template)
    except FillError as exc:
        print(f"[SKIP] puzzle {puzzle_id}: fill failed — {exc}", file=sys.stderr)
        return None
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

    # 4. Clues — attach the real word_id and arrow direction to each slot's clue.
    items = list(slot_assignments.items())
    answers = [answer for _, answer in items]
    raw_clues = write_clues(
        answers, tdk_definitions=tdk_definitions, default_category=category
    )
    slot_by_id = {s.slot_id: s for s in template.slots}
    clue_by_slot: dict[str, ClueSpec] = {
        sid: clue.model_copy(
            update={"word_id": sid, "arrow": slot_by_id[sid].direction}
        )
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


def generate_pack(
    templates: list[MaskTemplate],
    word_pool: list[PoolEntry],
    blacklist: set[str],
    start_puzzle_id: int,
    count: int,
    category: str | None,
    output_dir: Path,
    tdk_definitions: dict[str, str] | None = None,
    generator_version: str = "2.0.0",
    seed: int | None = None,
) -> tuple[int, int]:
    """Generate *count* puzzles into *output_dir*; return (success, failure).

    Each puzzle picks a random template and a random geometric transform of it,
    then writes puzzle_{id:04d}.json. *seed* makes selection reproducible.
    """
    if not templates:
        raise ValueError("generate_pack requires at least one template")
    output_dir.mkdir(parents=True, exist_ok=True)
    rng = random.Random(seed)
    success = 0
    failed = 0

    for offset in range(count):
        puzzle_id = start_puzzle_id + offset
        variant = rng.choice(get_transforms(rng.choice(templates)))
        puzzle = generate_puzzle(
            template=variant,
            word_pool=word_pool,
            blacklist=blacklist,
            puzzle_id=puzzle_id,
            category=category,
            tdk_definitions=tdk_definitions,
            generator_version=generator_version,
            seed=rng.randrange(1_000_000),
        )
        if puzzle is None:
            failed += 1
            continue
        # Defence in depth: never write an unscanned puzzle (coding-standards §8.7).
        if not puzzle.safety.post_fill_scanned:
            failed += 1
            print(
                f"[ERROR] puzzle {puzzle_id}: not scanned — refusing to write.",
                file=sys.stderr,
            )
            continue
        path = output_dir / f"puzzle_{puzzle_id:04d}.json"
        path.write_text(puzzle.model_dump_json(indent=2), encoding="utf-8")
        success += 1

    return success, failed
