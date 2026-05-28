# tools/level_generator/src/kelime_gen/validators/schema_validator.py
"""Validates generated level JSON files against the schema and game rules.

Two layers of checks:
  1. Pydantic (schema.py Level model) — field types, ranges, safety flag, word
     upper-casing. Pydantic's ValidationError is wrapped into ValueError so
     callers deal with a single exception type.
  2. Geometric checks — grid dimension consistency, word placement bounds,
     letter-in-grid match, and crossing-cell letter compatibility.
"""

import json
from pathlib import Path

from pydantic import ValidationError

from kelime_gen.schema import Direction, Level, WordPlacement

# Row/column delta for each direction — mirrors word_search_generator but kept
# local so this module has no dependency on the generator.
_DELTAS: dict[Direction, tuple[int, int]] = {
    Direction.HORIZONTAL: (0, 1),
    Direction.VERTICAL: (1, 0),
    Direction.DIAGONAL_DOWN: (1, 1),
    Direction.DIAGONAL_UP: (-1, 1),
}


def _path_cells(placement: WordPlacement) -> list[tuple[int, int]]:
    dr, dc = _DELTAS[placement.direction]
    return [
        (placement.start.row + i * dr, placement.start.col + i * dc)
        for i in range(placement.length)
    ]


def validate_level_file(path: Path) -> Level:
    """Parse and fully validate a level JSON file.

    Raises:
        ValueError: for any schema or geometric inconsistency.
    """
    try:
        level = Level.model_validate_json(path.read_text(encoding="utf-8"))
    except ValidationError as exc:
        raise ValueError(
            f"Schema validation failed for '{path.name}': {exc}"
        ) from exc

    rows = level.grid_size.rows
    cols = level.grid_size.cols

    # Grid dimension consistency.
    if len(level.grid) != rows:
        raise ValueError(
            f"'{path.name}': grid has {len(level.grid)} rows "
            f"but grid_size.rows={rows}."
        )
    for r, row in enumerate(level.grid):
        if len(row) != cols:
            raise ValueError(
                f"'{path.name}': grid row {r} has {len(row)} cols "
                f"but grid_size.cols={cols}."
            )

    # Per-placement geometric checks (bounds + letter match + crossing conflict).
    cell_to_letter: dict[tuple[int, int], str] = {}
    for placement in level.words:
        cells = _path_cells(placement)
        for i, (r, c) in enumerate(cells):
            if not (0 <= r < rows and 0 <= c < cols):
                raise ValueError(
                    f"'{path.name}': word '{placement.word}' cell ({r},{c}) "
                    f"is out of bounds (grid {rows}×{cols})."
                )
            expected = placement.word[i]
            actual = level.grid[r][c]
            if actual != expected:
                raise ValueError(
                    f"'{path.name}': word '{placement.word}' expects '{expected}' "
                    f"at ({r},{c}) but grid contains '{actual}'."
                )
            if (r, c) in cell_to_letter and cell_to_letter[(r, c)] != expected:
                raise ValueError(
                    f"'{path.name}': crossing conflict at ({r},{c}) — "
                    f"'{cell_to_letter[(r, c)]}' vs '{expected}'."
                )
            cell_to_letter[(r, c)] = expected

    return level


def validate_all(levels_dir: Path) -> tuple[int, int, list[str]]:
    """Validate every .json file in `levels_dir`.

    Returns:
        (ok_count, fail_count, error_messages)
    """
    ok = 0
    fail = 0
    errors: list[str] = []
    for path in sorted(levels_dir.glob("*.json")):
        try:
            validate_level_file(path)
            ok += 1
        except Exception as exc:
            fail += 1
            errors.append(f"{path.name}: {exc}")
    return ok, fail, errors
