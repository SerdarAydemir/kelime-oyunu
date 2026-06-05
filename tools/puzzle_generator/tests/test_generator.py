# tools/puzzle_generator/tests/test_generator.py
"""Unit tests for the v2 puzzle generation orchestrator."""

import json
from pathlib import Path

from kelime_gen.generator import generate_pack, generate_puzzle
from kelime_gen.mask_synth import SynthParams
from kelime_gen.mask_template import MaskTemplate, SlotSpec, TemplateCellSpec
from kelime_gen.pools import build_combined_pool_entries
from kelime_gen.schema import (
    CellType,
    ClueArrow,
    GridSize,
    PuzzleData,
    PuzzleSize,
    WordCell,
)
from kelime_gen.word_pool import PoolEntry

# ── Data paths (committed files) ──────────────────────────────────────────────

_DATA_DIR = Path(__file__).parents[1] / "data"
_SYMBOLS_PATH = _DATA_DIR / "symbols.json"
_TWO_LETTER_PATH = _DATA_DIR / "two_letter.json"

# ── Small-grid fixtures for generate_puzzle unit tests ────────────────────────


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


# ── Combined-pool fixture for synth / generate_pack tests ─────────────────────

# Turkish uppercase words by length for the test fixture.  These cover the
# slot lengths a synth 8×6 grid produces (3-8) without the main word pool
# file, which is generated and not committed to the repository.
_FIXTURE_MAIN_WORDS: list[str] = [
    # len 3
    "KAR", "ARI", "TOP", "SAP", "GÖL", "DAL", "TAŞ", "GÜN", "BAL", "YAZ",
    "GEL", "ATA", "KOL", "TUZ", "VAR", "YOK", "TAN", "HAK", "DEV", "SOR",
    "BAŞ", "YAY", "GEM", "BUZ", "NAR", "BAR", "KUŞ", "PUL", "SOL", "BOL",
    "NEY", "KOR", "SEV", "GİT", "ZAN", "KUM", "GAZ", "GÖZ", "KAN", "YAŞ",
    "ERK", "TOK", "KUL", "GER", "TAR", "SAN", "YAR", "DEL", "OKU", "MEY",
    # len 4
    "KEDİ", "KALE", "KAMP", "DERE", "FARE", "GECE", "HAVA", "KAYA", "MASA",
    "OKUL", "YAPI", "PARA", "SAAT", "ARKA", "YURT", "BABA", "DOST", "FARK",
    "HALK", "KARA", "LALE", "NANE", "RÜYA", "TANE", "ÜLKE", "VADİ", "ŞIŞE",
    "YÜZÜ", "ÖFKE", "SORU", "GÖRE", "YELE", "ÇÖRE", "GÜZE", "KIRI", "ELDE",
    # len 5
    "KALEM", "OKUMA", "BAHÇE", "KADEH", "KÖPRÜ", "YAZAR", "ŞEKER", "ÇOCUK",
    "DÜNYA", "İŞLEM", "KALIP", "MEYVE", "PASTA", "RESİM", "SALON", "TAHTA",
    "YAŞAM", "ZEMİN", "NEHİR", "GÜZEL", "SEFER", "BEYAZ", "TAVAN", "ÖĞREN",
    # len 6
    "ÇEKMEK", "DENEME", "GÖZLEM", "SÖZLER", "KELİME", "GELMEK", "ÇIKMAK",
    "YAZMAK", "BULMAK", "SEVMEK", "VERMEK", "BİLMEK",
    # len 7
    "ÇALIŞMA", "OKUYUCU", "GÖRÜNCE", "YAŞAYAN", "ORMANDA", "SEVGİLİ",
    # len 8
    "DONDURMA", "ÇALIŞMAK", "BEKLEMEK", "DÜŞÜNMEK",
]

# Fast SynthParams: reduced restart/budget so pack tests stay under CI time budget.
_FAST_SYNTH = SynthParams(max_restarts=300, fill_budget=80_000)


_MAIN_POOL_PATH = _DATA_DIR / "processed" / "word_pool_cleaned.json"


def _combined_pool() -> tuple[list[PoolEntry], dict[str, str]]:
    """Build combined pool: symbols (len 1) + two_letter (len 2) + main words (3-8).

    Uses the real word pool when available; falls back to the fixture list so
    the test is still runnable in environments without the generated pool file.
    """
    if _MAIN_POOL_PATH.exists():
        import json as _json
        raw = _json.loads(_MAIN_POOL_PATH.read_text(encoding="utf-8"))
        main_pool = [PoolEntry(word=e["word"], frequency_score=e["frequency_score"]) for e in raw]
    else:
        main_pool = [PoolEntry(word=w, frequency_score=70) for w in _FIXTURE_MAIN_WORDS]
    return build_combined_pool_entries(main_pool, _SYMBOLS_PATH, _TWO_LETTER_PATH)


def _strip_timestamp(raw: str) -> object:
    """Remove the non-deterministic generated_at field before comparison."""
    d = json.loads(raw)
    d.pop("generated_at", None)
    return d


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
    clue_cells = [c for c in puzzle.cells if c.type == CellType.CLUE]
    assert len(clue_cells) == 2
    assert all(len(c.clues) == 1 for c in clue_cells)
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


# ── 3: generate_pack uses synth mask and writes re-parseable JSON files ────────


def test_generate_pack_writes_json(tmp_path: Path) -> None:
    combined_pool, curated_clues = _combined_pool()
    ok, fail = generate_pack(
        word_pool=combined_pool,
        blacklist=set(),
        start_puzzle_id=1,
        count=2,
        category=None,
        output_dir=tmp_path,
        size=PuzzleSize.MEDIUM,
        curated_clues=curated_clues,
        synth_params=_FAST_SYNTH,
    )
    assert ok == 2, f"Expected 2 successes, got ok={ok} fail={fail}"
    assert fail == 0

    files = sorted(tmp_path.glob("puzzle_*.json"))
    assert [f.name for f in files] == ["puzzle_0001.json", "puzzle_0002.json"]
    for f in files:
        parsed = PuzzleData.model_validate_json(f.read_text(encoding="utf-8"))
        assert parsed.safety.post_fill_scanned is True
        assert parsed.size == PuzzleSize.MEDIUM
        assert parsed.grid == GridSize(rows=8, cols=6)
        assert len(parsed.words) >= 1


# ── 4: a blacklisted crossing word is steered around by the CSP guard ─────────


def test_generate_puzzle_blacklist_steers_fill() -> None:
    blacklist = {"KAR"}
    puzzle = generate_puzzle(
        _crossing_template(), _pool(), blacklist, puzzle_id=1, category=None, seed=1
    )
    assert puzzle is not None
    assert puzzle.safety.post_fill_scanned is True
    assert all(w.answer != "KAR" for w in puzzle.words)


# ── 5: curated clues take priority over tdk/placeholder ───────────────────────


def test_generate_puzzle_curated_clue_priority() -> None:
    pool = _pool()
    # All pool words are in curated dict → every answer must get source="curated".
    curated = {p["word"]: f"İpucu: {p['word']}" for p in pool}
    puzzle = generate_puzzle(
        _crossing_template(),
        pool,
        set(),
        puzzle_id=1,
        category=None,
        curated_clues=curated,
        seed=1,
    )
    assert puzzle is not None
    for word in puzzle.words:
        assert word.clue.source == "curated"
        assert word.clue.text == f"İpucu: {word.answer}"


# ── 6: generate_pack + synth determinism (seeds 1–5 run twice, same output) ───


def test_generate_pack_synth_determinism(tmp_path: Path) -> None:
    """Same puzzle_id always produces the same output (synth + fill both seeded)."""
    combined_pool, curated_clues = _combined_pool()

    def _run(outdir: Path) -> list[object]:
        ok, fail = generate_pack(
            word_pool=combined_pool,
            blacklist=set(),
            start_puzzle_id=1,
            count=5,
            category=None,
            output_dir=outdir,
            size=PuzzleSize.MEDIUM,
            curated_clues=curated_clues,
            synth_params=_FAST_SYNTH,
        )
        assert fail == 0, f"Expected 0 failures, got {fail}"
        assert ok == 5, f"Expected 5 successes, got {ok}"
        return [
            _strip_timestamp((outdir / f"puzzle_{i:04d}.json").read_text(encoding="utf-8"))
            for i in range(1, 6)
        ]

    run1 = _run(tmp_path / "r1")
    run2 = _run(tmp_path / "r2")
    assert run1 == run2, "Puzzle generation must be deterministic for fixed seeds"

    # Schema validation + curated clue spot-check on the first run's output.
    raw_dir = tmp_path / "r1"
    for i in range(1, 6):
        raw = (raw_dir / f"puzzle_{i:04d}.json").read_text(encoding="utf-8")
        puzzle = PuzzleData.model_validate_json(raw)
        assert puzzle.safety.post_fill_scanned is True
        assert puzzle.size == PuzzleSize.MEDIUM
        assert puzzle.grid == GridSize(rows=8, cols=6)
        # Any len-1 or len-2 answer that appears in the curated map must use it.
        for word in puzzle.words:
            if len(word.answer) <= 2 and word.answer in curated_clues:
                assert word.clue.source == "curated", (
                    f"puzzle {i}: expected curated source for {word.answer!r}, "
                    f"got {word.clue.source!r}"
                )
