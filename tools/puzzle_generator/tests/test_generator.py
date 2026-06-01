# tools/puzzle_generator/tests/test_generator.py
"""Unit tests for the v2 puzzle generation orchestrator."""

from pathlib import Path

from kelime_gen.generator import generate_pack, generate_puzzle
from kelime_gen.mask_template import MaskTemplate, SlotSpec, TemplateCellSpec
from kelime_gen.schema import (
    CellType,
    ClueArrow,
    GridSize,
    PuzzleData,
    PuzzleSize,
    WordCell,
)
from kelime_gen.word_pool import PoolEntry


def _crossing_template() -> MaskTemplate:
    """s1 (right, row 1) crosses s2 (down, col 2) at cell (1, 2).

    Clue cells carry clue_slots so generate_puzzle can attach clues to them.
    """
    return MaskTemplate(
        template_id="small_test",
        size=PuzzleSize.SMALL,
        grid=GridSize(rows=4, cols=4),
        cells=[
            TemplateCellSpec(row=1, col=0, type=CellType.CLUE, clue_slots=["s1"]),
            TemplateCellSpec(row=0, col=2, type=CellType.CLUE, clue_slots=["s2"]),
            TemplateCellSpec(row=1, col=1, type=CellType.LETTER, slot_ids=["s1"]),
            TemplateCellSpec(row=1, col=2, type=CellType.LETTER, slot_ids=["s1", "s2"]),
            TemplateCellSpec(row=1, col=3, type=CellType.LETTER, slot_ids=["s1"]),
            TemplateCellSpec(row=2, col=2, type=CellType.LETTER, slot_ids=["s2"]),
            TemplateCellSpec(row=3, col=2, type=CellType.LETTER, slot_ids=["s2"]),
        ],
        slots=[
            SlotSpec(
                slot_id="s1",
                direction=ClueArrow.RIGHT,
                clue_cell=WordCell(row=1, col=0),
                cells=[WordCell(row=1, col=1), WordCell(row=1, col=2), WordCell(row=1, col=3)],
                length=3,
            ),
            SlotSpec(
                slot_id="s2",
                direction=ClueArrow.DOWN,
                clue_cell=WordCell(row=0, col=2),
                cells=[WordCell(row=1, col=2), WordCell(row=2, col=2), WordCell(row=3, col=2)],
                length=3,
            ),
        ],
    )


def _pool() -> list[PoolEntry]:
    # KAR[1]='A' must equal ARI[0]='A' at the crossing cell.
    return [
        PoolEntry(word="KAR", frequency_score=90),
        PoolEntry(word="ARI", frequency_score=90),
        PoolEntry(word="TOP", frequency_score=90),
        PoolEntry(word="SAP", frequency_score=90),
    ]


# ── 1: successful generation produces a scanned, valid puzzle ─────────────────


def test_generate_puzzle_success() -> None:
    puzzle = generate_puzzle(
        _crossing_template(), _pool(), set(), puzzle_id=1, category=None, seed=1
    )
    assert puzzle is not None
    assert puzzle.safety.post_fill_scanned is True
    assert len(puzzle.words) == 2
    assert puzzle.difficulty in {"easy", "medium", "hard", "expert"}
    assert 0 <= puzzle.difficulty_score <= 100
    # Each clue cell received exactly one clue (clues=[] would fail schema).
    clue_cells = [c for c in puzzle.cells if c.type == CellType.CLUE]
    assert len(clue_cells) == 2
    assert all(len(c.clues) == 1 for c in clue_cells)
    # The clue arrow/word_id were wired from the slot.
    by_word = {w.id: w for w in puzzle.words}
    assert by_word["s1"].clue.arrow == ClueArrow.RIGHT
    assert by_word["s1"].clue.word_id == "s1"


# ── 2: an unfillable pool yields None (FillError swallowed) ────────────────────


def test_generate_puzzle_fill_error_returns_none() -> None:
    only_length_4 = [PoolEntry(word="DORT", frequency_score=80)]
    puzzle = generate_puzzle(
        _crossing_template(), only_length_4, set(), puzzle_id=2, category=None, seed=1
    )
    assert puzzle is None


# ── 3: generate_pack writes re-parseable JSON files ───────────────────────────


def test_generate_pack_writes_json(tmp_path: Path) -> None:
    ok, fail = generate_pack(
        templates=[_crossing_template()],
        word_pool=_pool(),
        blacklist=set(),
        start_puzzle_id=1,
        count=2,
        category=None,
        output_dir=tmp_path,
        seed=1,
    )
    assert ok == 2
    assert fail == 0

    files = sorted(tmp_path.glob("puzzle_*.json"))
    assert [f.name for f in files] == ["puzzle_0001.json", "puzzle_0002.json"]
    for f in files:
        parsed = PuzzleData.model_validate_json(f.read_text(encoding="utf-8"))
        assert parsed.safety.post_fill_scanned is True
        assert len(parsed.words) == 2


# ── 4: a blacklisted crossing word is steered around by the CSP guard ─────────


def test_generate_puzzle_blacklist_steers_fill() -> None:
    # "KAR" crossing "ARI" spells KAR on row 1; blacklist it so the only clean
    # crossing left is "SAP" × "ARI" ... but ARI[0] must equal the row word's
    # index-1 letter. Blacklisting KAR forces the filler to a clean alternative
    # rather than discarding the whole puzzle. The produced puzzle must be
    # profanity-free under the same blacklist.
    blacklist = {"KAR"}
    puzzle = generate_puzzle(
        _crossing_template(), _pool(), blacklist, puzzle_id=1, category=None, seed=1
    )
    assert puzzle is not None
    assert puzzle.safety.post_fill_scanned is True
    # No across/down answer may be the blacklisted word.
    assert all(w.answer != "KAR" for w in puzzle.words)
