# tools/puzzle_generator/tests/test_pack_report.py
"""Unit tests for the pack verification report (pack_report)."""

from pathlib import Path

from kelime_gen.pack_report import build_report, format_report, verify_pack, write_report
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

# ── Minimal valid puzzle fixture (KEDİ crosses DAL at 'D') ────────────────────


def _puzzle(puzzle_id: int, template_id: str, with_corner_blank: bool = True) -> PuzzleData:
    cells = [
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
            clues=[ClueSpec(text="Ağaç parçası", arrow=ClueArrow.DOWN, word_id="w2")],
        ),
        CellSpec(row=1, col=1, type=CellType.LETTER, solution="K", word_ids=["w1"]),
        CellSpec(row=1, col=2, type=CellType.LETTER, solution="E", word_ids=["w1"]),
        CellSpec(row=1, col=3, type=CellType.LETTER, solution="D", word_ids=["w1", "w2"]),
        CellSpec(row=1, col=4, type=CellType.LETTER, solution="İ", word_ids=["w1"]),
        CellSpec(row=2, col=3, type=CellType.LETTER, solution="A", word_ids=["w2"]),
        CellSpec(row=3, col=3, type=CellType.LETTER, solution="L", word_ids=["w2"]),
    ]
    if with_corner_blank:
        cells.insert(0, CellSpec(row=0, col=0, type=CellType.BLANK))
    return PuzzleData(
        puzzle_id=puzzle_id,
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
                clue=ClueSpec(
                    text="Miyavlayan hayvan", arrow=ClueArrow.RIGHT, word_id="w1", source="llm"
                ),
            ),
            WordSpec(
                id="w2",
                answer="DAL",
                length=3,
                direction=ClueArrow.DOWN,
                clue_cell=WordCell(row=0, col=3),
                start_cell=WordCell(row=1, col=3),
                cells=[WordCell(row=r, col=3) for r in range(1, 4)],
                clue=ClueSpec(text="Ağaç parçası", arrow=ClueArrow.DOWN, word_id="w2"),
            ),
        ],
        template_id=template_id,
        safety=SafetyInfo(post_fill_scanned=True),
    )


def _write(directory: Path, puzzles: list[PuzzleData]) -> None:
    directory.mkdir(parents=True, exist_ok=True)
    for p in puzzles:
        (directory / f"puzzle_{p.puzzle_id:04d}.json").write_text(
            p.model_dump_json(indent=2), encoding="utf-8"
        )


def _stats(puzzle_id: int, duration: float, hits: int = 0, fallbacks: int = 0) -> dict[str, object]:
    return {
        "puzzle_id": puzzle_id,
        "template_id": f"t{puzzle_id}",
        "k": 1,
        "library_index": puzzle_id,
        "fallbacks": fallbacks,
        "fill_attempts": 1,
        "budget_hits": hits,
        "duration_s": duration,
    }


# ── verify_pack ───────────────────────────────────────────────────────────────


def test_verify_pack_accepts_clean_pack(tmp_path: Path) -> None:
    _write(tmp_path, [_puzzle(1, "small_frame_a"), _puzzle(2, "small_frame_b")])
    result = verify_pack(tmp_path, expected_count=2)
    assert result["ok"] is True
    assert result["actual_count"] == 2
    assert result["unique_masks"] == 2
    assert result["blank_violations"] == []
    # One llm + one placeholder clue per puzzle.
    assert result["clue_sources"] == {"llm": 2, "placeholder": 2}
    # The fixture has one interior clue: (1,0) is frame, (0,3) is frame -> k counts
    # only clues with row>=1 AND col>=1; (1,0) has col=0 so k=0 for every puzzle.
    assert result["k_distribution"] == {"0": 2}
    assert result["slot_count_distribution"] == {"2": 2}


def test_verify_pack_flags_count_mismatch(tmp_path: Path) -> None:
    _write(tmp_path, [_puzzle(1, "small_frame_a")])
    result = verify_pack(tmp_path, expected_count=2)
    assert result["ok"] is False
    assert result["actual_count"] == 1


def test_verify_pack_flags_missing_corner_blank(tmp_path: Path) -> None:
    _write(tmp_path, [_puzzle(1, "small_frame_a", with_corner_blank=False)])
    result = verify_pack(tmp_path, expected_count=1)
    assert result["ok"] is False
    assert len(result["blank_violations"]) == 1


def test_verify_pack_flags_duplicate_masks(tmp_path: Path) -> None:
    _write(tmp_path, [_puzzle(1, "same_mask"), _puzzle(2, "same_mask")])
    result = verify_pack(tmp_path, expected_count=2)
    assert result["ok"] is False
    assert result["duplicate_masks"] == ["same_mask"]
    assert result["unique_masks"] == 1


def test_verify_pack_skips_manifest(tmp_path: Path) -> None:
    _write(tmp_path, [_puzzle(1, "small_frame_a")])
    (tmp_path / "manifest.json").write_text("{}", encoding="utf-8")
    result = verify_pack(tmp_path, expected_count=1)
    assert result["ok"] is True


# ── build_report / write_report / format_report ──────────────────────────────


def test_build_report_aggregates_stats(tmp_path: Path) -> None:
    _write(tmp_path, [_puzzle(1, "a"), _puzzle(2, "b"), _puzzle(3, "c")])
    verification = verify_pack(tmp_path, expected_count=3)
    stats = [_stats(1, 0.5), _stats(2, 1.5, hits=2), _stats(3, 4.0, fallbacks=1)]
    report = build_report(verification, stats, total_seconds=6.2)
    assert report["timing"]["median_seconds"] == 1.5
    assert report["timing"]["max_seconds"] == 4.0
    assert report["timing"]["slowest_puzzles"][0]["puzzle_id"] == 3
    assert report["fill"]["node_budget_hits_total"] == 2
    assert report["fill"]["puzzles_with_budget_hits"] == 1
    assert report["fill"]["mask_fallbacks_total"] == 1
    assert report["fill"]["puzzles_with_fallbacks"] == 1


def test_write_and_format_report(tmp_path: Path) -> None:
    _write(tmp_path / "pack", [_puzzle(1, "a")])
    verification = verify_pack(tmp_path / "pack", expected_count=1)
    report = build_report(verification, [_stats(1, 0.5)], total_seconds=0.5)
    out = tmp_path / "reports" / "report.json"
    write_report(report, out)
    assert out.exists()
    text = format_report(report)
    assert "1/1" in text
    assert "BAŞARILI" in text
