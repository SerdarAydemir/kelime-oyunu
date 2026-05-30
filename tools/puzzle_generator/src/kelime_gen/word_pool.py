# tools/level_generator/src/kelime_gen/word_pool.py
"""Cleans the raw TDK word list into a scored, profanity-free word pool.

Pipeline (see architecture.md section 7.1):
  raw tdk_words.txt
    -> Turkish-aware uppercase normalization
    -> length filter (3-12) + Turkish-alphabet-only filter (drops Q/W/X)
    -> profanity blacklist removal
    -> length-based frequency score
    -> data/processed/word_pool_cleaned.json

The pure transform `build_pool` takes in-memory inputs so it can be unit
tested without touching the filesystem.
"""

import io
import json
import sys
from collections import Counter
from pathlib import Path
from typing import Iterable, TypedDict


def _force_utf8_stdout() -> None:
    """Windows console UTF-8 fix (see CLAUDE.md).

    Called only from `main()`, never at import time: wrapping stdout on import
    would close pytest's captured stream during teardown.
    """
    if hasattr(sys.stdout, "buffer"):
        sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8")

# Turkish uppercase alphabet. Note the absence of Q, W and X: any word that
# still contains one of those after normalization is considered foreign and
# dropped by `is_valid_word`. See architecture.md section 7.6.
TURKISH_LETTERS: frozenset[str] = frozenset("ABCÇDEFGĞHIİJKLMNOÖPRSŞTUÜVYZ")

# Shorter words are more common -> easier -> higher frequency score.
FREQUENCY_BY_LENGTH: dict[int, int] = {
    3: 90,
    4: 80,
    5: 70,
    6: 60,
    7: 50,
    8: 40,
    9: 30,
    10: 20,
    11: 15,
    12: 10,
}

MIN_LENGTH = 3
MAX_LENGTH = 12

# Turkish-aware uppercase mapping: translate dotted/dotless 'i' before upper().
_TR_UPPER_MAP = str.maketrans("iı", "İI")

# Resolve the generator root (tools/level_generator) from this file's location
# so the script works regardless of the current working directory.
_ROOT = Path(__file__).resolve().parents[2]
_RAW_DIR = _ROOT / "data" / "raw"
_PROCESSED_DIR = _ROOT / "data" / "processed"
_TDK_WORDS_PATH = _RAW_DIR / "tdk_words.txt"
_BLACKLIST_PATH = _RAW_DIR / "profanity_blacklist.txt"
_OUTPUT_PATH = _PROCESSED_DIR / "word_pool_cleaned.json"


class PoolEntry(TypedDict):
    word: str
    frequency_score: int


def tr_upper(text: str) -> str:
    """Uppercase a string using Turkish letter rules ('i' -> 'İ', 'ı' -> 'I')."""
    return text.translate(_TR_UPPER_MAP).upper()


def is_valid_word(word: str) -> bool:
    """Return True if `word` (already uppercased) is a usable pool entry.

    Rejects anything outside the 3-12 length window or containing a character
    that is not a Turkish uppercase letter (this also removes Q/W/X words,
    digits, punctuation and whitespace).
    """
    if not (MIN_LENGTH <= len(word) <= MAX_LENGTH):
        return False
    return all(char in TURKISH_LETTERS for char in word)


def frequency_for_length(length: int) -> int:
    """Map a word length to its frequency score."""
    return FREQUENCY_BY_LENGTH[length]


def build_pool(
    raw_words: Iterable[str],
    blacklist: set[str],
) -> list[PoolEntry]:
    """Normalize, filter, score and de-duplicate a raw word iterable.

    `blacklist` is matched as whole words after normalization. Sub-string /
    n-gram profanity inside grids is handled later by post_fill_safety, not
    here.
    """
    normalized_blacklist = {tr_upper(bad) for bad in blacklist}
    seen: set[str] = set()
    pool: list[PoolEntry] = []

    for raw in raw_words:
        word = tr_upper(raw.strip())
        if not word or word in seen:
            continue
        if not is_valid_word(word):
            continue
        if word in normalized_blacklist:
            continue
        seen.add(word)
        pool.append(
            PoolEntry(word=word, frequency_score=frequency_for_length(len(word))),
        )

    return pool


def load_lines(path: Path) -> list[str]:
    """Read a UTF-8 text file, returning non-empty stripped lines."""
    text = path.read_text(encoding="utf-8")
    return [line.strip() for line in text.splitlines() if line.strip()]


def load_blacklist(path: Path) -> set[str]:
    """Read the profanity blacklist into a normalized set."""
    return {tr_upper(line) for line in load_lines(path)}


def compute_distribution(pool: list[PoolEntry]) -> dict[int, int]:
    """Count pool entries by word length, sorted ascending by length."""
    counter = Counter(len(entry["word"]) for entry in pool)
    return dict(sorted(counter.items()))


def main() -> None:
    """Read raw data, build the cleaned pool, write JSON and print stats."""
    _force_utf8_stdout()
    if not _TDK_WORDS_PATH.exists():
        raise FileNotFoundError(
            f"Raw word list not found: {_TDK_WORDS_PATH}. "
            "Download it into data/raw/ first (see README).",
        )
    if not _BLACKLIST_PATH.exists():
        raise FileNotFoundError(
            f"Profanity blacklist not found: {_BLACKLIST_PATH}. "
            "Download it into data/raw/ first (see README).",
        )

    raw_words = load_lines(_TDK_WORDS_PATH)
    blacklist = load_blacklist(_BLACKLIST_PATH)
    pool = build_pool(raw_words, blacklist)

    _PROCESSED_DIR.mkdir(parents=True, exist_ok=True)
    _OUTPUT_PATH.write_text(
        json.dumps(pool, ensure_ascii=False, indent=2),
        encoding="utf-8",
    )

    distribution = compute_distribution(pool)
    print(f"Ham kelime sayısı       : {len(raw_words)}")
    print(f"Filtreden geçen (tekil) : {len(pool)}")
    print(f"Karaliste boyutu        : {len(blacklist)}")
    print("Uzunluğa göre dağılım   :")
    for length in range(MIN_LENGTH, MAX_LENGTH + 1):
        print(f"  {length:2d} harf: {distribution.get(length, 0)}")
    print(f"Çıktı yazıldı           : {_OUTPUT_PATH}")


if __name__ == "__main__":
    main()
