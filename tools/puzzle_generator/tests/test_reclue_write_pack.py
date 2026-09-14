# tools/puzzle_generator/tests/test_reclue_write_pack.py
"""write-pack must refresh cells[].clues (what the renderer paints), not only words[].clue."""

from __future__ import annotations

import json
import sys
from pathlib import Path

import pytest

from kelime_gen.schema import (
    CellSpec,
    CellType,
    ClueArrow,
    ClueSpec,
    GridSize,
    PuzzleData,
    PuzzleSize,
    SafetyInfo,
    WordCell,
    WordSpec,
)

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))

import reclue


def _puzzle() -> PuzzleData:
    clue = ClueSpec(text="Miyavlayan hayvan", arrow=ClueArrow.RIGHT, word_id="w1", source="llm")
    cells = [
        CellSpec(row=0, col=0, type=CellType.BLANK),
        CellSpec(row=1, col=0, type=CellType.CLUE, clues=[clue]),
        CellSpec(row=1, col=1, type=CellType.LETTER, solution="K", word_ids=["w1"]),
        CellSpec(row=1, col=2, type=CellType.LETTER, solution="E", word_ids=["w1"]),
        CellSpec(row=1, col=3, type=CellType.LETTER, solution="D", word_ids=["w1"]),
        CellSpec(row=1, col=4, type=CellType.LETTER, solution="İ", word_ids=["w1"]),
    ]
    return PuzzleData(
        puzzle_id=1,
        size=PuzzleSize.SMALL,
        grid=GridSize(rows=4, cols=5),
        cells=cells,
        words=[
            WordSpec(
                id="w1",
                answer="KEDİ",
                length=4,
                direction=ClueArrow.RIGHT,
                clue_cell=WordCell(row=1, col=0),
                start_cell=WordCell(row=1, col=1),
                cells=[WordCell(row=1, col=c) for c in range(1, 5)],
                clue=clue,
            )
        ],
        template_id="t1",
        safety=SafetyInfo(post_fill_scanned=True),
    )


def test_write_pack_syncs_cell_clues(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    pack = tmp_path / "pack"
    pack.mkdir()
    (pack / "puzzle_0001.json").write_text(_puzzle().model_dump_json(indent=2), encoding="utf-8")
    master = tmp_path / "master_clues.json"
    master.write_text(
        json.dumps({"KEDİ": {"text": "Ev kedisi", "source": "claude_reclue"}}), encoding="utf-8"
    )
    empty = tmp_path / "empty.json"
    empty.write_text("[]", encoding="utf-8")
    monkeypatch.setattr(reclue, "_MASTER", master)
    monkeypatch.setattr(reclue, "_SYMBOLS", empty)
    monkeypatch.setattr(reclue, "_TWO_LETTER", empty)

    reclue.write_pack(puzzles_dir=pack, expected_count=1)

    raw = json.loads((pack / "puzzle_0001.json").read_text(encoding="utf-8"))
    assert raw["words"][0]["clue"]["text"] == "Ev kedisi"
    cell_clues = [c for cell in raw["cells"] for c in (cell.get("clues") or [])]
    assert [c["text"] for c in cell_clues] == ["Ev kedisi"]
    assert cell_clues[0]["source"] == raw["words"][0]["clue"]["source"]
