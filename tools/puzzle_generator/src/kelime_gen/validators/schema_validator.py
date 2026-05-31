# tools/puzzle_generator/src/kelime_gen/validators/schema_validator.py
"""Validates generated puzzle JSON against the v2 schema and grid bounds.

Two layers of checks:
  1. Pydantic (schema.py PuzzleData) — field types/ranges, the safety flag,
     Turkish upper-casing, intersection consistency and clue/letter cell roles.
     Pydantic's ValidationError is wrapped into ValueError so callers deal with
     a single exception type.
  2. Bounds checks — every cell and every word cell must lie inside the grid.
     schema.py validates the letter/solution/intersection logic but not bounds.
"""

from pathlib import Path

from pydantic import ValidationError

from kelime_gen.schema import PuzzleData

MANIFEST_NAME = "manifest.json"


def _check_bounds(puzzle: PuzzleData, name: str) -> None:
    """Raise ValueError if any cell or word cell falls outside the grid."""
    rows = puzzle.grid.rows
    cols = puzzle.grid.cols

    def in_bounds(row: int, col: int) -> bool:
        return 0 <= row < rows and 0 <= col < cols

    for cell in puzzle.cells:
        if not in_bounds(cell.row, cell.col):
            raise ValueError(
                f"'{name}': cell ({cell.row},{cell.col}) is out of bounds "
                f"(grid {rows}×{cols})."
            )
    for word in puzzle.words:
        for wc in word.cells:
            if not in_bounds(wc.row, wc.col):
                raise ValueError(
                    f"'{name}': word '{word.id}' cell ({wc.row},{wc.col}) "
                    f"is out of bounds (grid {rows}×{cols})."
                )


def validate_puzzle_file(path: Path) -> PuzzleData:
    """Parse and fully validate a puzzle JSON file.

    Raises:
        ValueError: for any schema or geometric inconsistency.
    """
    try:
        puzzle = PuzzleData.model_validate_json(path.read_text(encoding="utf-8"))
    except ValidationError as exc:
        raise ValueError(
            f"Schema validation failed for '{path.name}': {exc}"
        ) from exc
    _check_bounds(puzzle, path.name)
    return puzzle


def validate_all(puzzles_dir: Path) -> tuple[int, int, list[str]]:
    """Validate every .json file (except manifest.json) in `puzzles_dir`.

    Returns:
        (ok_count, fail_count, error_messages)
    """
    ok = 0
    fail = 0
    errors: list[str] = []
    for path in sorted(puzzles_dir.glob("*.json")):
        if path.name == MANIFEST_NAME:
            continue
        try:
            validate_puzzle_file(path)
            ok += 1
        except Exception as exc:
            fail += 1
            errors.append(f"{path.name}: {exc}")
    return ok, fail, errors
