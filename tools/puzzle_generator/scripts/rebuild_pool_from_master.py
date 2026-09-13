# tools/puzzle_generator/scripts/rebuild_pool_from_master.py
"""Rebuild data/processed/word_pool_cleaned.json from master_clues.json.

The original pool was derived from the raw TDK list (data/raw/tdk_words.txt),
which is neither tracked nor available any more. Since the P0 placeholder
gate, the *effective* pool is exactly the set of words that carry a master
clue, so the pool can be regenerated from master_clues.json alone:

  master_clues.json entries
    -> clue-quality gate (drop EXCLUDED_MODELS, see below)
    -> word_pool.build_pool()   (tr_upper, length 3-12, Turkish letters only)
    -> data/processed/word_pool_cleaned.json   (same PoolEntry format)

Clue-quality gate: entries whose clue was written by gemini-2.5-flash-lite are
excluded by default. The 2026-09 dry run showed the gated pool (~8.8k words)
still fills 200/200 puzzles (avg 1.62 mask fallbacks, max 48, zero blacklist
rejections), while flash-lite clues were ~15%+ wrong or forced. A flash-lite
word re-enters the pool only after a Claude re-clue rewrites its entry
(source="claude_reclue"), because the gate keys on the *model* field and the
re-clue replaces it. `--include-model gemini-2.5-flash-lite` lifts the gate
for experiments.

The profanity blacklist is deliberately NOT applied here: answer-level
exclusions (sensitive_answers.txt, rejected_words.json) are applied at
generate time by pools.load_excluded_answers, and every master-clue word has
already passed the clue audit. Substring safety stays with post_fill_safety.

Usage (from the repo root or tools/puzzle_generator):
    python scripts/rebuild_pool_from_master.py
    python scripts/rebuild_pool_from_master.py --include-model gemini-2.5-flash-lite
    python scripts/rebuild_pool_from_master.py --master path/to/master_clues.json \
        --output path/to/word_pool_cleaned.json
"""

from __future__ import annotations

import argparse
import io
import json
import sys
from collections import Counter
from collections.abc import Sequence
from pathlib import Path

_GENERATOR_ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(_GENERATOR_ROOT / "src"))

from kelime_gen.word_pool import PoolEntry, build_pool, compute_distribution

_MASTER_CLUES_PATH = _GENERATOR_ROOT / "data" / "processed" / "master_clues.json"
_OUTPUT_PATH = _GENERATOR_ROOT / "data" / "processed" / "word_pool_cleaned.json"

# Clue models whose words are held out of the pool until re-clued.
EXCLUDED_MODELS: frozenset[str] = frozenset({"gemini-2.5-flash-lite"})


def _force_utf8_stdout() -> None:
    """Console UTF-8 fix (see CLAUDE.md); called only from main().

    Only needed on the Windows console; a no-op in effect on Linux/macOS
    where stdout is already UTF-8.
    """
    if hasattr(sys.stdout, "buffer"):
        sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8")


def _load_master(path: Path) -> dict[str, dict[str, object]]:
    raw = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(raw, dict):
        raise TypeError(f"{path}: expected a JSON object keyed by answer word")
    return raw


def load_master_words(
    path: Path,
    excluded_models: frozenset[str] = EXCLUDED_MODELS,
) -> tuple[list[str], Counter[str]]:
    """Return (sorted gated answer words, per-model counts of excluded entries).

    An entry is excluded when its ``model`` field is in *excluded_models*;
    entries without a model field are kept (legacy/curated rows).
    """
    master = _load_master(path)
    kept: list[str] = []
    dropped: Counter[str] = Counter()
    for word, entry in master.items():
        model = entry.get("model") if isinstance(entry, dict) else None
        if isinstance(model, str) and model in excluded_models:
            dropped[model] += 1
            continue
        kept.append(word)
    return sorted(kept), dropped


def rebuild_pool(
    master_path: Path,
    excluded_models: frozenset[str] = EXCLUDED_MODELS,
) -> list[PoolEntry]:
    """Pure transform: master_clues.json -> gated PoolEntry list (no blacklist)."""
    words, _ = load_master_words(master_path, excluded_models)
    return build_pool(words, blacklist=set())


def write_pool(pool: list[PoolEntry], output_path: Path) -> None:
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(json.dumps(pool, ensure_ascii=False, indent=2), encoding="utf-8")


def run(argv: Sequence[str] | None = None) -> list[PoolEntry]:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--master", type=Path, default=_MASTER_CLUES_PATH)
    parser.add_argument("--output", type=Path, default=_OUTPUT_PATH)
    parser.add_argument(
        "--include-model",
        action="append",
        default=[],
        metavar="MODEL",
        help="Lift the quality gate for this clue model (repeatable), "
        f"e.g. {', '.join(sorted(EXCLUDED_MODELS))}",
    )
    args = parser.parse_args(argv)

    if not args.master.exists():
        print(f"master_clues.json bulunamadı: {args.master}", file=sys.stderr)
        sys.exit(1)

    excluded_models = EXCLUDED_MODELS - frozenset(args.include_model)
    master_words, dropped = load_master_words(args.master, excluded_models)
    pool = build_pool(master_words, blacklist=set())
    if not pool:
        print("Havuz boş çıktı — master_clues.json içeriğini kontrol et.", file=sys.stderr)
        sys.exit(1)
    write_pool(pool, args.output)

    distribution = compute_distribution(pool)
    print(f"Master clue giriş sayısı  : {len(master_words) + sum(dropped.values())}")
    for model, count in sorted(dropped.items()):
        print(f"Kalite kapısı ({model}): -{count}")
    print(f"Kapıdan geçen kelime      : {len(master_words)}")
    print(f"Havuza giren (tekil)      : {len(pool)}")
    print(f"Elenen (uzunluk/harf)     : {len(master_words) - len(pool)}")
    print("Uzunluğa göre dağılım     :")
    for length, count in distribution.items():
        print(f"  {length:2d} harf: {count}")
    print(f"Çıktı yazıldı             : {args.output}")
    return pool


def main() -> None:
    _force_utf8_stdout()
    run()


if __name__ == "__main__":
    main()
