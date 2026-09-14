# tools/puzzle_generator/tests/test_reclue_apply.py
"""Tests for scripts/reclue_apply.py (validation rules + master write)."""

from __future__ import annotations

import json
import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))

import reclue_apply

_MASTER = {
    "ÇIKIN": {
        "text": "Dürülecek bohça",
        "source": "gemini",
        "model": "gemini-2.5-flash-lite",
        "meaning_used": "bohça",
    },
    "KARAMEL": {"text": "Yanık şeker tadı", "source": "gemini", "model": "gemini-2.5-flash-lite"},
    "SES": {"text": "Kulakla algılanan", "source": "gemini", "model": "gemini-2.5-flash-lite"},
}


@pytest.mark.parametrize(
    ("word", "clue", "reason_part"),
    [
        ("ÇIKIN", "", "boş"),
        ("ÇIKIN", "   ", "boş"),
        ("ÇIKIN", "Bir bohçaya sarılmış eşya paketi", "> 20"),
        ("ÇIKIN", "Küçük çıkın bohçası", "cevabı içeriyor"),
        ("KARAMEL", "Kara şekerin tadı", "ilk 4 harfini"),  # prefix KARA, case-insensitive
        ("SES", "Sesli kelime", "cevabı içeriyor"),  # word shorter than 4: whole word
        ("ÇIKIN", "Dürülecek bohça", "aynı"),
        ("ÇIKIN", "  Dürülecek bohça ", "aynı"),
        ("YOKKELİME", "Bir şey", "içinde yok"),
    ],
)
def test_rejections(word: str, clue: str, reason_part: str) -> None:
    accepted, rejected = reclue_apply.validate_batch({word: clue}, _MASTER)
    assert accepted == {}
    assert len(rejected) == 1 and reason_part in rejected[0].reason


def test_accepted_record_shape_and_key_normalization() -> None:
    accepted, rejected = reclue_apply.validate_batch({"çıkın": " Bohça, küçük paket "}, _MASTER)

    assert rejected == []
    assert accepted == {
        "ÇIKIN": {
            "text": "Bohça, küçük paket",
            "source": "claude_reclue",
            "model": "claude-fable-5-1",
            "previous": "Dürülecek bohça",
        }
    }


def test_exactly_twenty_characters_is_allowed() -> None:
    clue = "x" * 20
    accepted, rejected = reclue_apply.validate_batch({"ÇIKIN": clue}, _MASTER)
    assert rejected == [] and accepted["ÇIKIN"]["text"] == clue


def test_apply_replaces_record_and_drops_old_fields() -> None:
    master = json.loads(json.dumps(_MASTER))
    accepted, _ = reclue_apply.validate_batch({"ÇIKIN": "Bohça"}, master)
    reclue_apply.apply_batch(master, accepted)

    assert master["ÇIKIN"] == accepted["ÇIKIN"]
    assert "meaning_used" not in master["ÇIKIN"]
    assert master["KARAMEL"] == _MASTER["KARAMEL"]  # untouched


def test_run_writes_accepted_and_reports_rejected(tmp_path: Path) -> None:
    master_path = tmp_path / "master_clues.json"
    master_path.write_text(json.dumps(_MASTER, ensure_ascii=False), encoding="utf-8")
    batch_path = tmp_path / "batch.json"
    batch_path.write_text(
        json.dumps({"ÇIKIN": "Bohça", "SES": "Sesli harf"}, ensure_ascii=False),
        encoding="utf-8",
    )

    ok, bad = reclue_apply.run([str(batch_path), "--master", str(master_path)])

    assert (ok, bad) == (1, 1)
    written = json.loads(master_path.read_text(encoding="utf-8"))
    assert written["ÇIKIN"]["source"] == "claude_reclue"
    assert written["ÇIKIN"]["previous"] == "Dürülecek bohça"
    assert written["SES"] == _MASTER["SES"]


def test_dry_run_does_not_write(tmp_path: Path) -> None:
    master_path = tmp_path / "master_clues.json"
    master_path.write_text(json.dumps(_MASTER, ensure_ascii=False), encoding="utf-8")
    batch_path = tmp_path / "batch.json"
    batch_path.write_text(json.dumps({"ÇIKIN": "Bohça"}), encoding="utf-8")

    ok, bad = reclue_apply.run([str(batch_path), "--master", str(master_path), "--dry-run"])

    assert (ok, bad) == (1, 0)
    assert json.loads(master_path.read_text(encoding="utf-8")) == _MASTER
