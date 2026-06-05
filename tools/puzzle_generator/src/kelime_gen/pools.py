# tools/puzzle_generator/src/kelime_gen/pools.py
"""Combined word pool for min-1 CSP fill (architecture.md §5.8, §6.5).

A min-1 mask has slots of length 1..8. The CSP filler picks a word per slot by
length, so the pool must supply every length:

  * length 1 -> single letters from data/symbols.json (29 Turkish letters)
  * length 2 -> curated words from data/two_letter.json
  * length 3..8 -> the main pool (word_pool_cleaned.json), trimmed to <= 8

Clue text for the 1- and 2-letter answers is kept in those JSON files and used
by the clue writer; the CSP fill itself only needs the word strings, so this
module exposes both the strings (for filling) and the answer->clue maps.
"""

from __future__ import annotations

import json
from pathlib import Path

from kelime_gen.schema import tr_upper
from kelime_gen.word_pool import PoolEntry

MAX_SLOT_LEN = 8

# Frequency scores for curated single- and two-letter entries.  Higher than
# the main-pool range (40-90) so they are considered "easy" for difficulty.
_FREQ_LEN1 = 95
_FREQ_LEN2 = 92


def _load_answer_clue(path: Path) -> dict[str, str]:
    """Load a [{answer, clue}] JSON file into an answer->clue map (tr_upper)."""
    raw = json.loads(path.read_text(encoding="utf-8"))
    return {tr_upper(item["answer"]): item["clue"] for item in raw}


def load_symbols(path: Path) -> dict[str, str]:
    """Single-letter answer -> clue (e.g. 'N' -> 'Azotun simgesi')."""
    return _load_answer_clue(path)


def load_two_letter(path: Path) -> dict[str, str]:
    """Two-letter answer -> clue (e.g. 'EV' -> 'Yaşanılan mesken')."""
    return _load_answer_clue(path)


def build_combined_pool(
    main_words: list[str],
    symbols_path: Path,
    two_letter_path: Path,
    max_len: int = MAX_SLOT_LEN,
) -> list[str]:
    """Combine symbols (len 1) + two-letter (len 2) + main (len 3..max_len).

    Returns a deduplicated, sorted list of upper-case word strings — sorted so
    the downstream CSP fill stays deterministic for a fixed seed.
    """
    words: set[str] = set()
    words.update(load_symbols(symbols_path))
    words.update(load_two_letter(two_letter_path))
    for word in main_words:
        upper = tr_upper(word)
        if 3 <= len(upper) <= max_len:
            words.add(upper)
    return sorted(words)


def build_combined_pool_entries(
    main_pool: list[PoolEntry],
    symbols_path: Path,
    two_letter_path: Path,
    max_len: int = MAX_SLOT_LEN,
) -> tuple[list[PoolEntry], dict[str, str]]:
    """Build (entries, curated_clues) for the min-1 combined pool.

    entries:
      Deduplicated, sorted list of PoolEntry covering all slot lengths 1..max_len.
      - len-1: from symbols.json (freq=95)
      - len-2: from two_letter.json (freq=92)
      - len-3..max_len: from main_pool (original frequency_score preserved)

    curated_clues:
      answer -> clue text for every len-1 and len-2 entry.  The clue_writer
      gives these priority over TDK/placeholder so the player always sees a
      hand-crafted hint for single letters and common two-letter words.

    Both outputs are sorted by answer string for downstream determinism.
    """
    symbols = load_symbols(symbols_path)
    two_letter = load_two_letter(two_letter_path)

    curated_clues: dict[str, str] = {**symbols, **two_letter}

    seen: set[str] = set()
    entries: list[PoolEntry] = []

    for answer, _ in sorted(symbols.items()):
        if answer not in seen:
            seen.add(answer)
            entries.append(PoolEntry(word=answer, frequency_score=_FREQ_LEN1))

    for answer, _ in sorted(two_letter.items()):
        if answer not in seen:
            seen.add(answer)
            entries.append(PoolEntry(word=answer, frequency_score=_FREQ_LEN2))

    for entry in main_pool:
        upper = tr_upper(entry["word"])
        if 3 <= len(upper) <= max_len and upper not in seen:
            seen.add(upper)
            entries.append(PoolEntry(word=upper, frequency_score=entry["frequency_score"]))

    entries.sort(key=lambda e: e["word"])
    return entries, curated_clues
