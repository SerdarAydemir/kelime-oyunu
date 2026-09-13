# tools/puzzle_generator/tests/test_rebuild_pool_from_master.py
"""Tests for scripts/rebuild_pool_from_master.py (clue-quality gate)."""

from __future__ import annotations

import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))

import rebuild_pool_from_master as rebuild

_MASTER = {
    "KALEM": {"text": "Yazı aracı", "source": "claude_audit", "model": "claude-fable-5"},
    "AKTÜEL": {"text": "Güncel", "source": "gemini", "model": "gemini-2.5-flash"},
    "ABANIŞ": {"text": "Dayanma", "source": "gemini", "model": "gemini-2.5-flash-lite"},
    "BOĞUNÇ": {"text": "Boyun bağı", "source": "gemini", "model": "gemini-2.5-flash-lite"},
    # Re-clued flash-lite word: model replaced, so it passes the gate again.
    "ÇIKIN": {
        "text": "Bohça",
        "source": "claude_reclue",
        "model": "claude-fable-5-1",
        "previous": "Dürülecek bohça",
    },
    "ESKİ": {"text": "Yeni değil", "source": "curated"},  # no model field -> kept
}


def _write_master(tmp_path: Path) -> Path:
    path = tmp_path / "master_clues.json"
    path.write_text(json.dumps(_MASTER, ensure_ascii=False), encoding="utf-8")
    return path


def test_gate_excludes_flash_lite_by_default(tmp_path: Path) -> None:
    words, dropped = rebuild.load_master_words(_write_master(tmp_path))

    assert words == ["AKTÜEL", "ESKİ", "KALEM", "ÇIKIN"]
    assert dropped == {"gemini-2.5-flash-lite": 2}


def test_gate_can_be_lifted_per_model(tmp_path: Path) -> None:
    words, dropped = rebuild.load_master_words(_write_master(tmp_path), frozenset())

    assert "ABANIŞ" in words and "BOĞUNÇ" in words
    assert dropped == {}


def test_run_writes_gated_pool_and_include_model_lifts_gate(tmp_path: Path) -> None:
    master = _write_master(tmp_path)
    out = tmp_path / "pool.json"

    pool = rebuild.run(["--master", str(master), "--output", str(out)])
    assert sorted(e["word"] for e in pool) == ["AKTÜEL", "ESKİ", "KALEM", "ÇIKIN"]
    assert json.loads(out.read_text(encoding="utf-8")) == pool

    pool_all = rebuild.run(
        ["--master", str(master), "--output", str(out), "--include-model", "gemini-2.5-flash-lite"]
    )
    assert len(pool_all) == len(_MASTER)


def test_default_excluded_models_is_flash_lite_only() -> None:
    assert rebuild.EXCLUDED_MODELS == frozenset({"gemini-2.5-flash-lite"})
