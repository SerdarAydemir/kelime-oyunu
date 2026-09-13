# tools/puzzle_generator/tests/test_build_blacklist.py
"""Tests for scripts/build_blacklist.py (normalization rules + file output)."""

from __future__ import annotations

import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))

import build_blacklist

_SAMPLE = [
    "abaza",
    "ağzına sıçayım",  # multi-word -> dropped
    "",  # empty -> dropped
    "Abaza",  # duplicate after tr_upper -> dropped
    "sik",  # 3 letters -> dropped (MIN_ENTRY_LENGTH = 4)
    "oç",  # 2 letters -> dropped
    "piçlik",  # dotted i must become İ, not I
    "ıslık",  # dotless ı must become I
    "  zibidi  ",  # surrounding whitespace is not "multi-word"
]


def test_normalize_applies_turkish_upper_and_filters() -> None:
    entries, stats = build_blacklist.normalize_entries(_SAMPLE)

    assert entries == ["ABAZA", "ISLIK", "PİÇLİK", "ZİBİDİ"]
    assert entries == sorted(entries)
    assert stats.raw == len(_SAMPLE)
    assert stats.dropped_empty == 1
    assert stats.dropped_multiword == 1
    assert stats.dropped_short == 2
    assert stats.dropped_duplicate == 1
    assert stats.kept == 4


def test_min_length_threshold_is_four() -> None:
    """Three-letter entries collide with common Turkish syllables (see docstring)."""
    assert build_blacklist.MIN_ENTRY_LENGTH == 4
    entries, _ = build_blacklist.normalize_entries(["mal", "ana", "göt", "kaka"])
    assert entries == ["KAKA"]


def test_run_writes_sorted_file_from_local_source(tmp_path: Path) -> None:
    source = tmp_path / "karaliste.txt"
    source.write_text("\n".join(_SAMPLE) + "\n", encoding="utf-8")
    output = tmp_path / "out" / "profanity_blacklist.txt"

    stats = build_blacklist.run(["--source", str(source), "--output", str(output)])

    assert stats.kept == 4
    assert output.read_text(encoding="utf-8") == "ABAZA\nISLIK\nPİÇLİK\nZİBİDİ\n"


def test_run_refuses_to_write_empty_list(tmp_path: Path) -> None:
    source = tmp_path / "karaliste.txt"
    source.write_text("a b\n\nx\n", encoding="utf-8")
    output = tmp_path / "profanity_blacklist.txt"

    with pytest.raises(SystemExit) as exc:
        build_blacklist.run(["--source", str(source), "--output", str(output)])

    assert exc.value.code == 1
    assert not output.exists()
