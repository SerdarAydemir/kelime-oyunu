# tools/puzzle_generator/tests/test_clue_writer.py
"""Unit tests for clue_writer — curated, master (LLM), and placeholder clues."""

import pytest

from kelime_gen.clue_writer import truncate_clue, write_clue, write_clues
from kelime_gen.schema import ClueArrow, ClueSpec


# ── 1: master clue → source "llm" and text ───────────────────────────────────


def test_master_clue_source() -> None:
    clue = write_clue("KEDI", master_clues={"KEDI": "Evcil bir hayvan"})
    assert clue.source == "llm"
    assert clue.text == "Evcil bir hayvan"


# ── 2: leading/trailing whitespace is stripped ───────────────────────────────


def test_master_clue_stripped() -> None:
    clue = write_clue("KEDI", master_clues={"KEDI": "  Evcil bir hayvan  "})
    assert clue.text == "Evcil bir hayvan"


# ── 3: lower-case first letter is capitalised (Turkish-aware) ─────────────────


def test_master_first_letter_capitalised_turkish() -> None:
    # 'ı' must become 'I', not 'i'.
    clue = write_clue("ISIK", master_clues={"ISIK": "ışık veren nesne"})
    assert clue.text.startswith("Işık")

    # Regular ASCII: 'e' → 'E'.
    clue2 = write_clue("KEDI", master_clues={"KEDI": "evcil hayvan"})
    assert clue2.text.startswith("E")

    # Turkish dotted i: 'i' → 'İ'.
    clue3 = write_clue("INCI", master_clues={"INCI": "inci tanesi"})
    assert clue3.text.startswith("İ")


# ── 4: long master clue is truncated ─────────────────────────────────────────


def test_master_long_clue_truncated() -> None:
    long_def = "A" * 70          # 70 chars, well over the 60-char limit
    clue = write_clue("KEDI", master_clues={"KEDI": long_def})
    assert len(clue.text) == 60
    assert clue.text.endswith("...")


# ── 5: exactly 60 characters is NOT truncated ────────────────────────────────


def test_master_exactly_60_chars_not_truncated() -> None:
    exact_def = "B" * 60
    clue = write_clue("KEDI", master_clues={"KEDI": exact_def})
    assert clue.text == exact_def
    assert not clue.text.endswith("...")


# ── 5b: priority — curated beats master beats placeholder ─────────────────────


def test_priority_curated_beats_master() -> None:
    clue = write_clue(
        "EV",
        curated_clues={"EV": "Yaşanılan mesken"},
        master_clues={"EV": "Bir yapı"},
    )
    assert clue.source == "curated"
    assert clue.text == "Yaşanılan mesken"


def test_priority_master_beats_placeholder() -> None:
    # No curated entry, no category → master clue wins over bare placeholder.
    clue = write_clue("KEDI", category="Hayvan", master_clues={"KEDI": "Evcil hayvan"})
    assert clue.source == "llm"
    assert clue.text == "Evcil hayvan"


# ── 6: category produces correct placeholder text ────────────────────────────


def test_category_placeholder_text() -> None:
    clue = write_clue("ELMA", category="Meyve")
    assert clue.source == "placeholder"
    assert clue.text == "4 harfli bir meyve"


# ── 7: no arguments → bare placeholder ───────────────────────────────────────


def test_no_args_bare_placeholder() -> None:
    clue = write_clue("KALEM")
    assert clue.source == "placeholder"
    assert clue.text == "5 harfli kelime"


# ── 8: returned ClueSpec has correct arrow and empty word_id ─────────────────


def test_returned_clue_arrow_and_word_id() -> None:
    clue = write_clue("TOP")
    assert isinstance(clue, ClueSpec)
    assert clue.arrow == ClueArrow.RIGHT
    assert clue.word_id == ""


# ── 9: write_clues with per-word categories (mixed batch) ───────────────────


def test_write_clues_mixed_categories() -> None:
    words = ["ELMA", "KALEM", "KEDI"]
    cats = {"ELMA": "Meyve", "KEDI": "Hayvan"}   # KALEM has no category
    clues = write_clues(words, categories=cats)

    assert clues[0].text == "4 harfli bir meyve"
    assert clues[1].text == "5 harfli kelime"       # bare fallback
    assert clues[2].text == "4 harfli bir hayvan"


# ── 10: write_clues default_category fallback ────────────────────────────────


def test_write_clues_default_category_fallback() -> None:
    words = ["ELMA", "ARMUT", "KEDI"]
    cats = {"ELMA": "Meyve"}                        # ARMUT and KEDI not listed
    clues = write_clues(words, categories=cats, default_category="Nesne")

    assert clues[0].text == "4 harfli bir meyve"    # per-word category wins
    assert clues[1].text == "5 harfli bir nesne"    # default_category
    assert clues[2].text == "4 harfli bir nesne"    # default_category


# ── truncate_clue edge cases ─────────────────────────────────────────────────


def test_truncate_clue_max_len_too_small_raises() -> None:
    with pytest.raises(ValueError):
        truncate_clue("abc", max_len=2)


def test_truncate_clue_exact_boundary() -> None:
    # len = max_len: no truncation.
    assert truncate_clue("abc", max_len=3) == "abc"
    # len = max_len + 1: truncation kicks in.
    result = truncate_clue("abcd", max_len=3)
    assert result == "..."
    assert len(result) == 3
