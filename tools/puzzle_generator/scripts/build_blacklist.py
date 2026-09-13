# tools/puzzle_generator/scripts/build_blacklist.py
"""Build data/raw/profanity_blacklist.txt from ooguz/turkce-kufur-karaliste.

Source: https://github.com/ooguz/turkce-kufur-karaliste (karaliste.txt),
licensed CC BY-SA 4.0 — attribution lives in the generator README.

Pipeline (pure, deterministic):
    raw lines -> tr_upper -> drop multi-word entries (any whitespace)
              -> drop entries shorter than MIN_ENTRY_LENGTH -> dedupe -> sort

Why MIN_ENTRY_LENGTH is 4, not 3 (measured against the ~30k master pool):
    post_fill_safety.scan_segment slides a 3..8-letter window over every
    horizontal/vertical run, forward AND reversed, and the CSP guard prunes on
    the same primitive. Of the source's 21 three-letter entries, most are
    ordinary Turkish syllables or words: MAL (714 pool words contain it),
    AMN (375), MNA (232), ANA (212), EMİ (188) — ANA, MAL and CİM are pool
    answers themselves. Even the genuinely profane ones hide inside everyday
    words (GÖT in GÖTÜRMEK, ÇÜK in KÜÇÜK, BOK in BOKS, SİK in KLASİK). Keeping
    them would reject a large share of legitimate grids and make the fill
    intractable. Three-letter answers are controlled at the answer level
    instead: every interior letter run in the 9×7 frame is a clued slot, i.e.
    a pool word, and profane short answers are excluded via
    data/raw/sensitive_answers.txt. Four-letter entries still collide (e.g.
    AMNA via reversed ANMA) but at a rate the mask-fallback loop absorbs;
    the generation report tracks those rejections.

Usage (from the repo root or tools/puzzle_generator):
    python scripts/build_blacklist.py                 # download + write
    python scripts/build_blacklist.py --source karaliste.txt  # offline
"""

from __future__ import annotations

import argparse
import io
import sys
import urllib.request
from collections.abc import Iterable, Sequence
from dataclasses import dataclass
from pathlib import Path

_GENERATOR_ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(_GENERATOR_ROOT / "src"))

from kelime_gen.word_pool import tr_upper

SOURCE_URL = "https://raw.githubusercontent.com/ooguz/turkce-kufur-karaliste/master/karaliste.txt"
OUTPUT_PATH = _GENERATOR_ROOT / "data" / "raw" / "profanity_blacklist.txt"
MIN_ENTRY_LENGTH = 4  # see module docstring before changing


@dataclass(frozen=True)
class BuildStats:
    """Counts reported after a build (all in raw-line units)."""

    raw: int
    dropped_empty: int
    dropped_multiword: int
    dropped_short: int
    dropped_duplicate: int
    kept: int


def _force_utf8_stdout() -> None:
    """Windows console UTF-8 fix (see CLAUDE.md); called only from main()."""
    if hasattr(sys.stdout, "buffer"):
        sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8")


def normalize_entries(
    raw_lines: Iterable[str],
    min_length: int = MIN_ENTRY_LENGTH,
) -> tuple[list[str], BuildStats]:
    """Normalize raw blacklist lines into a sorted, deduplicated entry list."""
    raw = dropped_empty = dropped_multiword = dropped_short = dropped_duplicate = 0
    seen: set[str] = set()
    for line in raw_lines:
        raw += 1
        stripped = line.strip()
        if not stripped:
            dropped_empty += 1
            continue
        if any(ch.isspace() for ch in stripped):
            dropped_multiword += 1
            continue
        entry = tr_upper(stripped)
        if len(entry) < min_length:
            dropped_short += 1
            continue
        if entry in seen:
            dropped_duplicate += 1
            continue
        seen.add(entry)
    entries = sorted(seen)
    stats = BuildStats(
        raw=raw,
        dropped_empty=dropped_empty,
        dropped_multiword=dropped_multiword,
        dropped_short=dropped_short,
        dropped_duplicate=dropped_duplicate,
        kept=len(entries),
    )
    return entries, stats


def fetch_source(url: str) -> list[str]:
    """Download the upstream list and return its raw lines."""
    with urllib.request.urlopen(url, timeout=30) as response:
        text: str = response.read().decode("utf-8")
    return text.splitlines()


def write_blacklist(entries: Sequence[str], output_path: Path) -> None:
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text("\n".join(entries) + "\n", encoding="utf-8")


def format_stats(stats: BuildStats) -> str:
    dropped = stats.dropped_empty + stats.dropped_multiword + stats.dropped_short
    return (
        f"Ham satır: {stats.raw}\n"
        f"Atılan: {dropped + stats.dropped_duplicate} "
        f"(boş {stats.dropped_empty}, boşluklu {stats.dropped_multiword}, "
        f"<{MIN_ENTRY_LENGTH} harf {stats.dropped_short}, tekrar {stats.dropped_duplicate})\n"
        f"Yazılan giriş: {stats.kept}"
    )


def run(argv: Sequence[str] | None = None) -> BuildStats:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--source", type=Path, help="Yerel karaliste.txt (indirme yerine)")
    parser.add_argument("--url", default=SOURCE_URL)
    parser.add_argument("--output", type=Path, default=OUTPUT_PATH)
    args = parser.parse_args(argv)

    if args.source is not None:
        raw_lines = args.source.read_text(encoding="utf-8").splitlines()
    else:
        raw_lines = fetch_source(args.url)

    entries, stats = normalize_entries(raw_lines)
    if not entries:
        print("Kara liste boş çıktı — dosya yazılmadı.", file=sys.stderr)
        sys.exit(1)
    write_blacklist(entries, args.output)
    print(format_stats(stats))
    print(f"Yazıldı: {args.output}")
    return stats


def main() -> None:
    _force_utf8_stdout()
    run()


if __name__ == "__main__":
    main()
