# tools/level_generator/src/kelime_gen/build_manifest.py
"""Builds assets/levels/manifest.json from the generated level files."""

import json
from pathlib import Path
from typing import Any

MANIFEST_NAME = "manifest.json"
MANIFEST_VERSION = "1.0.0"


def build_manifest(levels_dir: Path) -> dict[str, Any]:
    """Read every level JSON (except manifest.json) and write manifest.json.

    Packs are ordered by their lowest level_id; the first pack unlocks freely
    and each subsequent pack requires the previous one to be completed. See
    architecture.md section 4.3.
    """
    packs: dict[str, dict[str, Any]] = {}
    total = 0

    for path in sorted(levels_dir.glob("*.json")):
        if path.name == MANIFEST_NAME:
            continue
        data = json.loads(path.read_text(encoding="utf-8"))
        pack_id = data["pack_id"]
        total += 1
        pack = packs.setdefault(
            pack_id,
            {
                "id": pack_id,
                "title_tr": data["category_display_tr"],
                "level_ids": [],
                "icon": f"icons/{pack_id}.png",
            },
        )
        pack["level_ids"].append(data["level_id"])

    # Order packs by their lowest level_id; sort level_ids within each pack.
    ordered = sorted(packs.values(), key=lambda p: min(p["level_ids"]))
    for pack in ordered:
        pack["level_ids"].sort()

    # First pack unlocks freely; the rest chain off the previous pack.
    pack_list: list[dict[str, Any]] = []
    previous_id: str | None = None
    for pack in ordered:
        unlock: dict[str, Any] | None = (
            None
            if previous_id is None
            else {"type": "previous_pack_completed", "pack_id": previous_id}
        )
        pack_list.append(
            {
                "id": pack["id"],
                "title_tr": pack["title_tr"],
                "level_ids": pack["level_ids"],
                "unlock_requirement": unlock,
                "icon": pack["icon"],
            }
        )
        previous_id = pack["id"]

    manifest: dict[str, Any] = {
        "version": MANIFEST_VERSION,
        "total_levels": total,
        "packs": pack_list,
    }

    (levels_dir / MANIFEST_NAME).write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2),
        encoding="utf-8",
    )
    return manifest
