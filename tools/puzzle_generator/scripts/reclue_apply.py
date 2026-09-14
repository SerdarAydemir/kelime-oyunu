# tools/puzzle_generator/scripts/reclue_apply.py
"""Apply a Claude re-clue batch to master_clues.json with validation.

Input: a JSON object {"KELİME": "yeni ipucu", ...}. Every entry is validated
independently; the ones that pass are written to master_clues.json as

    {"text": <clue>, "source": "claude_reclue", "model": "claude-fable-5-1",
     "previous": <old text>}

(replacing the old record, so the model-keyed pool quality gate in
rebuild_pool_from_master.py lets the word back in). Rejected entries are
listed with their reason and are never written.

Rules (P1 re-clue, 2026-09):
  * clue is non-empty after stripping
  * clue length <= MAX_CLUE_LEN (20) characters
  * clue does not contain the answer, nor its first 4 letters (whole word
    for answers shorter than 4), compared with tr_upper on both sides
  * clue differs from the current text
  * the word exists in master_clues.json

Exit code is 1 when at least one entry was rejected (accepted ones are still
written), 0 otherwise. --dry-run validates without writing.

Usage (from the repo root or tools/puzzle_generator):
    python scripts/reclue_apply.py batch.json
    python scripts/reclue_apply.py batch.json --dry-run
"""

from __future__ import annotations

import argparse
import io
import json
import sys
from collections.abc import Mapping, Sequence
from dataclasses import dataclass
from pathlib import Path
from typing import Any

_GENERATOR_ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(_GENERATOR_ROOT / "src"))

from kelime_gen.word_pool import tr_upper

MASTER_PATH = _GENERATOR_ROOT / "data" / "processed" / "master_clues.json"
MAX_CLUE_LEN = 20
PREFIX_LEN = 4
SOURCE = "claude_reclue"
MODEL = "claude-fable-5-1"


@dataclass(frozen=True)
class Rejection:
    word: str
    reason: str


def _force_utf8_stdout() -> None:
    """Windows console UTF-8 fix (see CLAUDE.md); called only from main()."""
    for name in ("stdout", "stderr"):
        stream = getattr(sys, name)
        if hasattr(stream, "buffer"):
            setattr(sys, name, io.TextIOWrapper(stream.buffer, encoding="utf-8"))


def validate_clue(word: str, clue: str, old_text: str | None) -> str | None:
    """Return a rejection reason, or None when *clue* is acceptable for *word*."""
    if old_text is None:
        return "master_clues.json içinde yok"
    text = clue.strip()
    if not text:
        return "boş ipucu"
    if len(text) > MAX_CLUE_LEN:
        return f"{len(text)} karakter > {MAX_CLUE_LEN}"
    upper_clue = tr_upper(text)
    if word in upper_clue:
        return "ipucu cevabı içeriyor"
    prefix = word[:PREFIX_LEN]
    if prefix in upper_clue:
        return f"ipucu cevabın ilk {len(prefix)} harfini içeriyor ({prefix})"
    if text == old_text.strip():
        return "eski ipucuyla aynı"
    return None


def validate_batch(
    batch: Mapping[str, str],
    master: Mapping[str, Mapping[str, Any]],
) -> tuple[dict[str, dict[str, Any]], list[Rejection]]:
    """Split *batch* into (accepted word -> new record, rejections)."""
    accepted: dict[str, dict[str, Any]] = {}
    rejected: list[Rejection] = []
    for raw_word, clue in batch.items():
        word = tr_upper(raw_word.strip())
        old = master.get(word)
        old_text = str(old["text"]) if old is not None else None
        reason = validate_clue(word, str(clue), old_text)
        if reason is not None:
            rejected.append(Rejection(word, reason))
            continue
        accepted[word] = {
            "text": str(clue).strip(),
            "source": SOURCE,
            "model": MODEL,
            "previous": old_text,
        }
    return accepted, rejected


def apply_batch(
    master: dict[str, dict[str, Any]],
    accepted: Mapping[str, dict[str, Any]],
) -> None:
    """Replace the master records for every accepted word (in place)."""
    for word, record in accepted.items():
        master[word] = dict(record)


def run(argv: Sequence[str] | None = None) -> tuple[int, int]:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("batch", type=Path, help='JSON: {"KELİME": "yeni ipucu"}')
    parser.add_argument("--master", type=Path, default=MASTER_PATH)
    parser.add_argument("--dry-run", action="store_true", help="Doğrula, yazma")
    args = parser.parse_args(argv)

    batch = json.loads(args.batch.read_text(encoding="utf-8"))
    if not isinstance(batch, dict) or not all(isinstance(v, str) for v in batch.values()):
        print("Girdi {kelime: ipucu} biçiminde bir JSON nesnesi olmalı.", file=sys.stderr)
        sys.exit(2)
    master = json.loads(args.master.read_text(encoding="utf-8"))

    accepted, rejected = validate_batch(batch, master)
    if accepted and not args.dry_run:
        apply_batch(master, accepted)
        args.master.write_text(
            json.dumps(master, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
        )

    verb = "doğrulandı" if args.dry_run else "yazıldı"
    print(f"{len(accepted)} ipucu {verb}, {len(rejected)} reddedildi.")
    for r in rejected:
        print(f"  RED {r.word}: {r.reason}", file=sys.stderr)
    return len(accepted), len(rejected)


def main() -> None:
    _force_utf8_stdout()
    _, rejected = run()
    if rejected:
        sys.exit(1)


if __name__ == "__main__":
    main()
