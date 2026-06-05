# tools/puzzle_generator/tests/test_pools.py
"""Tests for the combined min-1 pool (symbols + 2-letter + main) and CSP fill.

Locks in Step 2C (combined pool), 2D (2-letter-aware profanity) and 2E
(length-1 slots resolved by AC-3 against the 29-symbol domain).
"""

import collections
import json
from pathlib import Path

import pytest

from kelime_gen.csp_filler import CSPFiller
from kelime_gen.mask_synth import synthesize
from kelime_gen.pools import build_combined_pool, load_symbols, load_two_letter
from kelime_gen.schema import PuzzleSize, tr_upper
from kelime_gen.validators.post_fill_safety import scan_grid, scan_segment
from kelime_gen.word_pool import load_blacklist

_DATA = Path(__file__).resolve().parent.parent / "data"
_SYMBOLS = _DATA / "symbols.json"
_TWO_LETTER = _DATA / "two_letter.json"
_BLACKLIST = _DATA / "raw" / "profanity_blacklist.txt"
_MAIN_POOL = _DATA / "processed" / "word_pool_cleaned.json"


def _main_words() -> list[str]:
    """The real cleaned main pool; skip dependent tests if it is absent."""
    if not _MAIN_POOL.exists():
        pytest.skip("word_pool_cleaned.json not built")
    return [item["word"] for item in json.loads(_MAIN_POOL.read_text(encoding="utf-8"))]


def _combined() -> list[str]:
    return build_combined_pool(_main_words(), _SYMBOLS, _TWO_LETTER)


def test_combined_pool_has_every_length() -> None:
    by_len = collections.Counter(len(w) for w in _combined())
    assert by_len[1] == 29  # all Turkish letters
    assert by_len[2] >= 40  # curated two-letter pool
    assert all(by_len[n] > 0 for n in range(3, 9))


def test_pool_is_upper_and_unique() -> None:
    pool = _combined()
    assert len(pool) == len(set(pool))
    assert all(w == tr_upper(w) for w in pool)


def test_symbols_cover_turkish_alphabet() -> None:
    symbols = load_symbols(_SYMBOLS)
    assert set(symbols) == set("ABCÇDEFGĞHIİJKLMNOÖPRSŞTUÜVYZ")


def test_two_letter_clues_present() -> None:
    two = load_two_letter(_TWO_LETTER)
    assert len(two) >= 40
    assert all(len(w) == 2 and clue for w, clue in two.items())


def test_two_gram_inside_long_word_is_not_flagged() -> None:
    # A blacklisted 2-letter string must NOT prune a long word that merely
    # contains it as a syllable (the false-positive the §5.8 rule prevents).
    blacklist = {"XY"}
    assert scan_segment("AXYB", blacklist, min_n=3, max_n=8) == []  # 2-gram ignored
    assert scan_segment("XY", blacklist, min_n=3, max_n=8) == ["XY"]  # whole 2-letter caught


@pytest.mark.parametrize("seed", range(3))
def test_min1_mask_fills_cleanly(seed: int) -> None:
    pool = _combined()
    blacklist = {tr_upper(w) for w in load_blacklist(_BLACKLIST)} if _BLACKLIST.exists() else set()
    template = synthesize(8, 6, PuzzleSize.MEDIUM, seed)
    result = CSPFiller(pool, blacklist=blacklist, max_attempts=30, seed=seed).fill(template)
    # Every slot assigned.
    assert len(result.slot_assignments) == len(template.slots)
    # Render the grid and confirm it is profanity-free.
    rows, cols = template.grid.rows, template.grid.cols
    grid = [["" for _ in range(cols)] for _ in range(rows)]
    cells_by_id = {s.slot_id: s.cells for s in template.slots}
    for slot_id, word in result.slot_assignments.items():
        for k, wc in enumerate(cells_by_id[slot_id]):
            grid[wc.row][wc.col] = word[k]
    assert scan_grid(grid, blacklist) == []
    # Each assigned word length matches its slot length (1- and 2-letter included).
    for slot in template.slots:
        assert len(result.slot_assignments[slot.slot_id]) == slot.length
