# tools/puzzle_generator/scripts/extract_pack_words.py
"""Extract the unique answer words of a generated pack into pack_words.json.

Output feeds the manual clue-review sessions: every unique answer with the
number of puzzles it appears in, its current clue text(s), and clue source(s).
Clue text and source are stored as lists because nothing in the schema forces
one clue per answer across a pack, but with the master-clue pipeline both
lists are expected to be singletons.

Usage (from the repo root or tools/puzzle_generator):
    python scripts/extract_pack_words.py --puzzles-dir assets/puzzles \
        --output tools/puzzle_generator/reports/pack_words.json
"""

from __future__ import annotations

import argparse
import io
import json
import sys
from collections import Counter
from pathlib import Path
from typing import Any

_GENERATOR_ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(_GENERATOR_ROOT / "src"))

from kelime_gen.build_manifest import MANIFEST_NAME  # noqa: E402
from kelime_gen.schema import PuzzleData  # noqa: E402


def _force_utf8_stdout() -> None:
    """Windows console UTF-8 fix (see CLAUDE.md); called only from main()."""
    if hasattr(sys.stdout, "buffer"):
        sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8")
    if hasattr(sys.stderr, "buffer"):
        sys.stderr = io.TextIOWrapper(sys.stderr.buffer, encoding="utf-8")


def extract_pack_words(puzzles_dir: Path) -> list[dict[str, Any]]:
    """Collect unique answers with puzzle counts, clue texts, and sources."""
    paths = [p for p in sorted(puzzles_dir.glob("*.json")) if p.name != MANIFEST_NAME]
    if not paths:
        raise FileNotFoundError(f"No puzzle JSON found in {puzzles_dir}")

    puzzle_count: Counter[str] = Counter()
    clues: dict[str, list[str]] = {}
    sources: dict[str, list[str]] = {}
    for path in paths:
        puzzle = PuzzleData.model_validate_json(path.read_text(encoding="utf-8"))
        seen_in_puzzle: set[str] = set()
        for word in puzzle.words:
            answer = word.answer
            if answer not in seen_in_puzzle:
                puzzle_count[answer] += 1
                seen_in_puzzle.add(answer)
            if word.clue.text not in clues.setdefault(answer, []):
                clues[answer].append(word.clue.text)
            if word.clue.source not in sources.setdefault(answer, []):
                sources[answer].append(word.clue.source)

    return [
        {
            "word": answer,
            "puzzle_count": puzzle_count[answer],
            "clues": clues[answer],
            "sources": sources[answer],
        }
        for answer in sorted(puzzle_count)
    ]


def main() -> None:
    _force_utf8_stdout()
    parser = argparse.ArgumentParser(description="Extract unique pack answers to JSON.")
    parser.add_argument("--puzzles-dir", type=Path, default=Path("assets/puzzles"))
    parser.add_argument(
        "--output",
        type=Path,
        default=_GENERATOR_ROOT / "reports" / "pack_words.json",
    )
    args = parser.parse_args()

    entries = extract_pack_words(args.puzzles_dir)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(entries, ensure_ascii=False, indent=2), encoding="utf-8")

    multi_clue = [e for e in entries if len(e["clues"]) > 1]
    print(f"Benzersiz kelime: {len(entries)}")
    print(f"Birden fazla clue metni olan kelime: {len(multi_clue)}")
    print(f"Yazıldı: {args.output}")


if __name__ == "__main__":
    main()
