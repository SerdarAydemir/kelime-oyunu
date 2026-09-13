# tools/puzzle_generator/scripts/rebuild_pool_from_master.py
"""Rebuild data/processed/word_pool_cleaned.json from master_clues.json.

The original pool was derived from the raw TDK list (data/raw/tdk_words.txt),
which is neither tracked nor available any more. Since the P0 placeholder
gate, the *effective* pool is exactly the set of words that carry a master
clue, so the pool can be regenerated from master_clues.json alone:

  master_clues.json keys
    -> word_pool.build_pool()   (tr_upper, length 3-12, Turkish letters only)
    -> data/processed/word_pool_cleaned.json   (same PoolEntry format)

The profanity blacklist is deliberately NOT applied here: answer-level
exclusions (sensitive_answers.txt, rejected_words.json) are applied at
generate time by pools.load_excluded_answers, and every master-clue word has
already passed the clue audit. Substring safety stays with post_fill_safety.

Usage (from the repo root or tools/puzzle_generator):
    python scripts/rebuild_pool_from_master.py
    python scripts/rebuild_pool_from_master.py --master path/to/master_clues.json \
        --output path/to/word_pool_cleaned.json
"""

from __future__ import annotations

import argparse
import io
import json
import sys
from pathlib import Path

_GENERATOR_ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(_GENERATOR_ROOT / "src"))

from kelime_gen.word_pool import PoolEntry, build_pool, compute_distribution

_MASTER_CLUES_PATH = _GENERATOR_ROOT / "data" / "processed" / "master_clues.json"
_OUTPUT_PATH = _GENERATOR_ROOT / "data" / "processed" / "word_pool_cleaned.json"


def _force_utf8_stdout() -> None:
    """Console UTF-8 fix (see CLAUDE.md); called only from main().

    Only needed on the Windows console; a no-op in effect on Linux/macOS
    where stdout is already UTF-8.
    """
    if hasattr(sys.stdout, "buffer"):
        sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8")


def load_master_words(path: Path) -> list[str]:
    """Return the master-clue answer words in deterministic (sorted) order."""
    raw = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(raw, dict):
        raise TypeError(f"{path}: expected a JSON object keyed by answer word")
    return sorted(raw)


def rebuild_pool(master_path: Path) -> list[PoolEntry]:
    """Pure transform: master_clues.json -> PoolEntry list (no blacklist)."""
    return build_pool(load_master_words(master_path), blacklist=set())


def write_pool(pool: list[PoolEntry], output_path: Path) -> None:
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(json.dumps(pool, ensure_ascii=False, indent=2), encoding="utf-8")


def main() -> None:
    _force_utf8_stdout()
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--master", type=Path, default=_MASTER_CLUES_PATH)
    parser.add_argument("--output", type=Path, default=_OUTPUT_PATH)
    args = parser.parse_args()

    if not args.master.exists():
        print(f"master_clues.json bulunamadı: {args.master}", file=sys.stderr)
        sys.exit(1)

    master_words = load_master_words(args.master)
    pool = rebuild_pool(args.master)
    if not pool:
        print("Havuz boş çıktı — master_clues.json içeriğini kontrol et.", file=sys.stderr)
        sys.exit(1)
    write_pool(pool, args.output)

    distribution = compute_distribution(pool)
    print(f"Master clue kelime sayısı : {len(master_words)}")
    print(f"Havuza giren (tekil)      : {len(pool)}")
    print(f"Elenen                    : {len(master_words) - len(pool)}")
    print("Uzunluğa göre dağılım     :")
    for length, count in distribution.items():
        print(f"  {length:2d} harf: {count}")
    print(f"Çıktı yazıldı             : {args.output}")


if __name__ == "__main__":
    main()
