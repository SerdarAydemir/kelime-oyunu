# tools/puzzle_generator/scripts/regen_only.py
"""Selectively regenerate individual puzzles of an existing pack (--only).

Rebuilds only the given puzzle ids with the CURRENT pool/exclusions/clues
while keeping every other puzzle untouched. Pack-level mask uniqueness is
preserved by seeding the used-mask set from the kept puzzles' template ids
(template_id = "<size>_frame_<bits>" maps back to a library index). Mask
choice starts at pick_index(seed=puzzle_id) and falls back in library order,
exactly like generate_pack; the CSP fill, node budget and safety/placeholder
gates are reused unchanged via generate_puzzle.

Usage:
    python scripts/regen_only.py --only 1,7,13 --puzzles-dir assets/puzzles
"""

from __future__ import annotations

import argparse
import io
import sys
import time
from pathlib import Path

_GENERATOR_ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(_GENERATOR_ROOT / "src"))

from kelime_gen.__main__ import (  # noqa: E402
    _BLACKLIST_PATH,
    _FRAME_CACHE_PATH,
    _MASTER_CLUES_PATH,
    _POOL_PATH,
    _REJECTED_PATH,
    _SENSITIVE_PATH,
    _SYMBOLS_PATH,
    _TWO_LETTER_PATH,
    _load_main_pool,
    _load_master_clues,
)
from kelime_gen.build_manifest import build_manifest  # noqa: E402
from kelime_gen.generator import FillStats, _next_free, generate_puzzle  # noqa: E402
from kelime_gen.mask_synth_frame import FrameLibrary, load_library  # noqa: E402
from kelime_gen.pack_report import verify_pack  # noqa: E402
from kelime_gen.pools import build_combined_pool_entries, load_excluded_answers  # noqa: E402
from kelime_gen.schema import PuzzleData, PuzzleSize  # noqa: E402
from kelime_gen.word_pool import load_blacklist  # noqa: E402

_FILL_ATTEMPTS_PER_MASK = 3
_MAX_MASK_FALLBACKS = 200


def _force_utf8_stdout() -> None:
    """Windows console UTF-8 fix (see CLAUDE.md); called only from main()."""
    if hasattr(sys.stdout, "buffer"):
        sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8")
    if hasattr(sys.stderr, "buffer"):
        sys.stderr = io.TextIOWrapper(sys.stderr.buffer, encoding="utf-8")


def _used_indices(puzzles_dir: Path, library: FrameLibrary, skip_ids: set[int]) -> set[int]:
    """Library indices of every kept puzzle, resolved from template_id bits."""
    bits_to_index = {bits: i for i, (_k, bits) in enumerate(library.entries)}
    used: set[int] = set()
    for path in sorted(puzzles_dir.glob("puzzle_*.json")):
        puzzle = PuzzleData.model_validate_json(path.read_text(encoding="utf-8"))
        if puzzle.puzzle_id in skip_ids:
            continue
        bits = int(puzzle.template_id.rsplit("_", 1)[-1], 16)  # bits are 012x hex
        index = bits_to_index.get(bits)
        if index is None:
            print(f"[UYARI] {path.name}: template kütüphanede yok, atlanıyor", file=sys.stderr)
            continue
        used.add(index)
    return used


def regenerate(puzzles_dir: Path, only_ids: list[int]) -> int:
    """Regenerate *only_ids* in place; returns the number of failures."""
    main_pool = _load_main_pool(_POOL_PATH)
    master_clues = _load_master_clues(_MASTER_CLUES_PATH)
    excluded = load_excluded_answers(_SENSITIVE_PATH, _REJECTED_PATH)
    combined_pool, curated_clues = build_combined_pool_entries(
        main_pool,
        _SYMBOLS_PATH,
        _TWO_LETTER_PATH,
        excluded=excluded,
        master_clue_answers=frozenset(master_clues),
    )
    blacklist = load_blacklist(_BLACKLIST_PATH) if _BLACKLIST_PATH.exists() else set()
    library = load_library(_FRAME_CACHE_PATH)
    used = _used_indices(puzzles_dir, library, set(only_ids))
    print(f"Havuz {len(combined_pool)}, kütüphane {len(library)}, korunan mask {len(used)}")

    failures = 0
    for puzzle_id in sorted(only_ids):
        started = time.perf_counter()
        index = _next_free(library.pick_index(seed=puzzle_id), used, len(library))
        fill_stats: FillStats = {"attempts": 0, "budget_hits": 0}
        puzzle: PuzzleData | None = None
        fallbacks = 0
        while fallbacks < _MAX_MASK_FALLBACKS:
            puzzle = generate_puzzle(
                template=library.template(index, PuzzleSize.MEDIUM),
                word_pool=combined_pool,
                blacklist=blacklist,
                puzzle_id=puzzle_id,
                category=None,
                curated_clues=curated_clues,
                master_clues=master_clues,
                max_fill_attempts=_FILL_ATTEMPTS_PER_MASK,
                seed=puzzle_id,
                fill_stats=fill_stats,
            )
            if puzzle is not None:
                break
            fallbacks += 1
            index = _next_free((index + 1) % len(library), used, len(library))
        if puzzle is None or not puzzle.safety.post_fill_scanned:
            failures += 1
            print(f"[ERROR] puzzle {puzzle_id}: yeniden üretilemedi", file=sys.stderr)
            continue
        path = puzzles_dir / f"puzzle_{puzzle_id:04d}.json"
        path.write_text(puzzle.model_dump_json(indent=2), encoding="utf-8")
        used.add(index)
        print(
            f"puzzle {puzzle_id}: ok ({fallbacks} fallback, "
            f"{time.perf_counter() - started:.1f} sn)"
        )
    return failures


def main() -> None:
    _force_utf8_stdout()  # must precede arg parsing (Windows console)
    parser = argparse.ArgumentParser(description="Selective puzzle regeneration.")
    parser.add_argument("--only", required=True, help="Virgülle ayrılmış puzzle id listesi")
    parser.add_argument("--puzzles-dir", type=Path, default=Path("assets/puzzles"))
    args = parser.parse_args()
    only_ids = sorted({int(x) for x in args.only.split(",") if x.strip()})

    failures = regenerate(args.puzzles_dir, only_ids)
    manifest = build_manifest(args.puzzles_dir)
    verification = verify_pack(args.puzzles_dir, expected_count=manifest["total_puzzles"])
    print(
        f"\n{len(only_ids) - failures}/{len(only_ids)} yenilendi; manifest "
        f"{manifest['total_puzzles']} bölüm; verify ok={verification['ok']} "
        f"placeholder={len(verification['placeholder_violations'])} "
        f"mask_benzersiz={verification['unique_masks']}"
    )
    if failures or not verification["ok"]:
        sys.exit(1)


if __name__ == "__main__":
    main()
