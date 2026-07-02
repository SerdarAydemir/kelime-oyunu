# tools/puzzle_generator/src/kelime_gen/pack_report.py
"""Post-generation verification report for a generated puzzle pack.

After generate_pack writes a pack, verify_pack independently re-reads every
puzzle JSON from disk and checks the full-frame invariants (count, single
corner blank, mask uniqueness) and collects the distributions the production
report needs (clue sources, interior-clue k, slot counts). build_report merges
that with the generator's per-puzzle runtime stats (durations, fill attempts,
node-budget hits, mask fallbacks) into one JSON-ready report.
"""

from __future__ import annotations

import json
import statistics
from collections import Counter
from collections.abc import Mapping, Sequence
from pathlib import Path
from typing import Any

from kelime_gen.build_manifest import MANIFEST_NAME
from kelime_gen.schema import CellType, PuzzleData


def verify_pack(puzzles_dir: Path, expected_count: int) -> dict[str, Any]:
    """Re-read every written puzzle and verify the full-frame invariants.

    Returns a JSON-ready dict; verification["ok"] is True only when the file
    count matches, every puzzle has exactly one BLANK cell at (0,0), no two
    puzzles share a mask (template_id), and no clue has source="placeholder"
    (detection half of the P0 gate — "N harfli kelime" is unplayable).
    """
    paths = [p for p in sorted(puzzles_dir.glob("*.json")) if p.name != MANIFEST_NAME]
    blank_violations: list[str] = []
    placeholder_violations: list[str] = []
    sources: Counter[str] = Counter()
    k_distribution: Counter[int] = Counter()
    slot_counts: Counter[int] = Counter()
    template_ids: list[str] = []

    for path in paths:
        puzzle = PuzzleData.model_validate_json(path.read_text(encoding="utf-8"))
        template_ids.append(puzzle.template_id)
        blanks = [(c.row, c.col) for c in puzzle.cells if c.type == CellType.BLANK]
        if blanks != [(0, 0)]:
            blank_violations.append(f"{path.name}: blank hücreler {blanks}")
        # Interior clues sit off the frame (row>=1 and col>=1) -> their count is k.
        k = sum(1 for c in puzzle.cells if c.type == CellType.CLUE and c.row >= 1 and c.col >= 1)
        k_distribution[k] += 1
        slot_counts[len(puzzle.words)] += 1
        for word in puzzle.words:
            sources[word.clue.source] += 1
            if word.clue.source == "placeholder":
                placeholder_violations.append(f"{path.name}: {word.answer}")

    duplicate_masks = [t for t, n in Counter(template_ids).items() if n > 1]
    ok = (
        len(paths) == expected_count
        and not blank_violations
        and not duplicate_masks
        and not placeholder_violations
    )
    return {
        "ok": ok,
        "expected_count": expected_count,
        "actual_count": len(paths),
        "blank_violations": blank_violations,
        "placeholder_violations": placeholder_violations,
        "unique_masks": len(set(template_ids)),
        "duplicate_masks": duplicate_masks,
        "clue_sources": dict(sources),
        "k_distribution": {str(k): v for k, v in sorted(k_distribution.items())},
        "slot_count_distribution": {str(k): v for k, v in sorted(slot_counts.items())},
    }


def build_report(
    verification: dict[str, Any],
    puzzle_stats: Sequence[Mapping[str, Any]],
    total_seconds: float,
) -> dict[str, Any]:
    """Merge disk verification with the generator's per-puzzle runtime stats."""
    durations = [float(s["duration_s"]) for s in puzzle_stats]
    budget_hits = sum(int(s["budget_hits"]) for s in puzzle_stats)
    budget_puzzles = sum(1 for s in puzzle_stats if int(s["budget_hits"]) > 0)
    fallbacks = sum(int(s["fallbacks"]) for s in puzzle_stats)
    fallback_puzzles = sum(1 for s in puzzle_stats if int(s["fallbacks"]) > 0)
    return {
        "verification": verification,
        "timing": {
            "total_seconds": round(total_seconds, 1),
            "median_seconds": round(statistics.median(durations), 3) if durations else 0.0,
            "max_seconds": round(max(durations), 3) if durations else 0.0,
            "slowest_puzzles": [
                {"puzzle_id": s["puzzle_id"], "duration_s": round(float(s["duration_s"]), 3)}
                for s in sorted(puzzle_stats, key=lambda x: -float(x["duration_s"]))[:5]
            ],
        },
        "fill": {
            "node_budget_hits_total": budget_hits,
            "puzzles_with_budget_hits": budget_puzzles,
            "mask_fallbacks_total": fallbacks,
            "puzzles_with_fallbacks": fallback_puzzles,
        },
        "puzzles": [dict(s) for s in puzzle_stats],
    }


def write_report(report: dict[str, Any], path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")


def format_report(report: dict[str, Any]) -> str:
    """Human-readable (console) summary of a pack report."""
    v = report["verification"]
    t = report["timing"]
    f = report["fill"]
    lines = [
        "── Üretim Doğrulama Raporu ──",
        f"Bulmaca: {v['actual_count']}/{v['expected_count']}"
        + ("  ✓" if v["actual_count"] == v["expected_count"] else "  ✗"),
        f"Blank=0 (köşe hariç): {'✓' if not v['blank_violations'] else v['blank_violations']}",
        f"Mask tekrarsız: {v['unique_masks']} benzersiz"
        + ("  ✓" if not v["duplicate_masks"] else f"  ✗ {v['duplicate_masks']}"),
        f"İpucu kaynakları: {v['clue_sources']}",
        f"k dağılımı: {v['k_distribution']}",
        f"Kelime sayısı dağılımı: {v['slot_count_distribution']}",
        f"Süre: toplam {t['total_seconds']} sn, medyan {t['median_seconds']} sn, "
        f"max {t['max_seconds']} sn",
        f"Node bütçesi: {f['node_budget_hits_total']} aşım "
        f"({f['puzzles_with_budget_hits']} bulmacada)",
        f"Mask fallback: {f['mask_fallbacks_total']} kez "
        f"({f['puzzles_with_fallbacks']} bulmacada)",
        f"SONUÇ: {'BAŞARILI ✓' if v['ok'] else 'BAŞARISIZ ✗'}",
    ]
    return "\n".join(lines)
