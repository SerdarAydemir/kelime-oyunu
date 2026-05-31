# tools/puzzle_generator/src/kelime_gen/build_manifest.py
"""Builds assets/puzzles/manifest.json from the generated puzzle files (schema v2).

The manifest is consumed by the Flutter app to populate the level-select screen
without loading every full puzzle JSON upfront (architecture.md §8).
"""

import json
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

from kelime_gen.schema import PuzzleData

MANIFEST_NAME = "manifest.json"
_SCHEMA_VERSION = 2


def build_manifest(
    puzzles_dir: Path,
    output_path: Path | None = None,
) -> dict[str, Any]:
    """Read every puzzle JSON (except manifest.json) and write manifest.json.

    Each entry in manifest["puzzles"] carries only the fields Flutter needs for
    the level-select screen, avoiding the cost of loading full puzzle JSON files.

    Puzzles are ordered by puzzle_id ascending so the Flutter client can iterate
    without re-sorting.

    Args:
        puzzles_dir: Directory that contains puzzle_NNNN.json files.
        output_path: Destination path for manifest.json. When None the file is
                     written to puzzles_dir / "manifest.json".

    Returns:
        The manifest dict that was written to disk.
    """
    entries: list[dict[str, Any]] = []

    for path in sorted(puzzles_dir.glob("*.json")):
        # Skip an existing manifest to avoid an infinite-loop / self-reference.
        if path.name == MANIFEST_NAME:
            continue
        puzzle = PuzzleData.model_validate_json(path.read_text(encoding="utf-8"))
        entries.append(
            {
                "puzzle_id": puzzle.puzzle_id,
                "file": path.name,
                "size": puzzle.size.value,
                "difficulty": puzzle.difficulty,
                "difficulty_score": puzzle.difficulty_score,
                "template_id": puzzle.template_id,
            }
        )

    # Sort by puzzle_id so Flutter can iterate cheaply.
    entries.sort(key=lambda e: e["puzzle_id"])

    manifest: dict[str, Any] = {
        "schema_version": _SCHEMA_VERSION,
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "total_puzzles": len(entries),
        "puzzles": entries,
    }

    dest = output_path if output_path is not None else puzzles_dir / MANIFEST_NAME
    dest.write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2),
        encoding="utf-8",
    )
    return manifest
