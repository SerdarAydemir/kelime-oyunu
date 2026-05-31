# tools/puzzle_generator/tests/test_build_manifest.py
"""Tests for build_manifest — manifest.json generation (schema v2)."""

import json
from pathlib import Path

from kelime_gen.build_manifest import build_manifest
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


def _make_puzzle_json(
    puzzle_id: int,
    template_id: str = "small_01",
    size: str = "small",
    difficulty: str = "easy",
    difficulty_score: int = 20,
) -> str:
    """Return a valid PuzzleData JSON string for use in tests.

    Uses a minimal 2-word (KEDİ × DAL) crossing puzzle so that the full Pydantic
    validation chain (safety scan, intersection consistency) is satisfied.
    """
    puzzle = PuzzleData(
        puzzle_id=puzzle_id,
        size=PuzzleSize(size),
        grid=GridSize(rows=4, cols=5),
        cells=[
            CellSpec(
                row=1,
                col=0,
                type=CellType.CLUE,
                clues=[ClueSpec(text="Miyavlayan hayvan", arrow=ClueArrow.RIGHT, word_id="w1")],
            ),
            CellSpec(
                row=0,
                col=3,
                type=CellType.CLUE,
                clues=[ClueSpec(text="Agac parcasi", arrow=ClueArrow.DOWN, word_id="w2")],
            ),
            CellSpec(row=1, col=1, type=CellType.LETTER, solution="K", word_ids=["w1"]),
            CellSpec(row=1, col=2, type=CellType.LETTER, solution="E", word_ids=["w1"]),
            CellSpec(row=1, col=3, type=CellType.LETTER, solution="D", word_ids=["w1", "w2"]),
            CellSpec(row=1, col=4, type=CellType.LETTER, solution="İ", word_ids=["w1"]),
            CellSpec(row=2, col=3, type=CellType.LETTER, solution="A", word_ids=["w2"]),
            CellSpec(row=3, col=3, type=CellType.LETTER, solution="L", word_ids=["w2"]),
        ],
        words=[
            WordSpec(
                id="w1",
                answer="KEDİ",
                length=4,
                direction=ClueArrow.RIGHT,
                clue_cell=WordCell(row=1, col=0),
                start_cell=WordCell(row=1, col=1),
                cells=[
                    WordCell(row=1, col=1),
                    WordCell(row=1, col=2),
                    WordCell(row=1, col=3),
                    WordCell(row=1, col=4),
                ],
                clue=ClueSpec(text="Miyavlayan hayvan", arrow=ClueArrow.RIGHT, word_id="w1"),
                frequency_score=80,
            ),
            WordSpec(
                id="w2",
                answer="DAL",
                length=3,
                direction=ClueArrow.DOWN,
                clue_cell=WordCell(row=0, col=3),
                start_cell=WordCell(row=1, col=3),
                cells=[
                    WordCell(row=1, col=3),
                    WordCell(row=2, col=3),
                    WordCell(row=3, col=3),
                ],
                clue=ClueSpec(text="Agac parcasi", arrow=ClueArrow.DOWN, word_id="w2"),
                frequency_score=60,
            ),
        ],
        template_id=template_id,
        safety=SafetyInfo(post_fill_scanned=True),
        difficulty=difficulty,  # type: ignore[arg-type]
        difficulty_score=difficulty_score,
    )
    return puzzle.model_dump_json(indent=2)


def test_basic_manifest(tmp_path: Path) -> None:
    """Two puzzle files produce a manifest with 2 entries and correct fields."""
    (tmp_path / "puzzle_0001.json").write_text(
        _make_puzzle_json(1, template_id="small_01", difficulty="easy", difficulty_score=20),
        encoding="utf-8",
    )
    (tmp_path / "puzzle_0002.json").write_text(
        _make_puzzle_json(2, template_id="small_02", difficulty="medium", difficulty_score=40),
        encoding="utf-8",
    )

    manifest = build_manifest(tmp_path)

    assert manifest["schema_version"] == 2
    assert manifest["total_puzzles"] == 2
    assert len(manifest["puzzles"]) == 2

    first = manifest["puzzles"][0]
    assert first["puzzle_id"] == 1
    assert first["file"] == "puzzle_0001.json"
    assert first["size"] == "small"
    assert first["difficulty"] == "easy"
    assert first["difficulty_score"] == 20
    assert first["template_id"] == "small_01"

    # manifest.json is written to the default location.
    assert (tmp_path / "manifest.json").exists()


def test_skips_manifest_json(tmp_path: Path) -> None:
    """An existing manifest.json is not counted as a puzzle."""
    (tmp_path / "puzzle_0001.json").write_text(
        _make_puzzle_json(1), encoding="utf-8"
    )
    # Simulate a stale manifest already present in the directory.
    (tmp_path / "manifest.json").write_text("{}", encoding="utf-8")

    manifest = build_manifest(tmp_path)

    assert manifest["total_puzzles"] == 1


def test_sorted_by_puzzle_id(tmp_path: Path) -> None:
    """Entries are ordered by puzzle_id ascending regardless of filesystem order."""
    for pid in (3, 1, 2):
        (tmp_path / f"puzzle_{pid:04d}.json").write_text(
            _make_puzzle_json(pid), encoding="utf-8"
        )

    manifest = build_manifest(tmp_path)

    ids = [e["puzzle_id"] for e in manifest["puzzles"]]
    assert ids == [1, 2, 3]


def test_custom_output_path(tmp_path: Path) -> None:
    """output_path redirects manifest.json to a different location."""
    puzzles_dir = tmp_path / "puzzles"
    puzzles_dir.mkdir()
    (puzzles_dir / "puzzle_0001.json").write_text(
        _make_puzzle_json(1), encoding="utf-8"
    )

    out = tmp_path / "other" / "manifest.json"
    out.parent.mkdir()
    build_manifest(puzzles_dir, output_path=out)

    assert out.exists()
    data = json.loads(out.read_text(encoding="utf-8"))
    assert data["total_puzzles"] == 1
    # Default location must NOT have been created.
    assert not (puzzles_dir / "manifest.json").exists()
