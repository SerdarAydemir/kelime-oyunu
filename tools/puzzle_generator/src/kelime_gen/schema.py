# tools/puzzle_generator/src/kelime_gen/schema.py
"""Pydantic data models defining the puzzle JSON contract (schema v2).

These models are the single source of truth shared between the Python
generator (producer) and the Flutter client (consumer). See architecture.md
section 4 (JSON schema v2) and section 6.4 (post-fill safety).
"""

import sys
from datetime import datetime, timezone
from enum import Enum
from typing import Literal, Self

from pydantic import BaseModel, Field, field_validator, model_validator

# Turkish-aware case mapping. Python's str.upper()/str.lower() handle the
# dotted/dotless 'i' incorrectly for Turkish, so we translate first.
# See architecture.md section 14 (Türkçe işleme).
_TR_UPPER_MAP = str.maketrans("iı", "İI")
_TR_LOWER_MAP = str.maketrans("İI", "iı")


def tr_upper(text: str) -> str:
    """Uppercase a string using Turkish letter rules. str.upper() is forbidden."""
    return text.translate(_TR_UPPER_MAP).upper()


def tr_lower(text: str) -> str:
    """Lowercase a string using Turkish letter rules."""
    return text.translate(_TR_LOWER_MAP).lower()


class ClueArrow(str, Enum):
    """Reading direction of a clue (MVP: right/down only)."""

    RIGHT = "right"
    DOWN = "down"


class ClueSpec(BaseModel):
    """A single clue pointing at one word."""

    text: str = Field(max_length=60)
    arrow: ClueArrow
    word_id: str
    image_id: str | None = None
    source: Literal["tdk", "llm", "placeholder", "curated"] = "placeholder"


class CellType(str, Enum):
    """The role a grid cell plays."""

    LETTER = "letter"
    CLUE = "clue"
    BLANK = "blank"


class CellSpec(BaseModel):
    """A single grid cell. Its constraints depend on `type`."""

    row: int = Field(ge=0)
    col: int = Field(ge=0)
    type: CellType
    solution: str | None = None
    word_ids: list[str] = Field(default_factory=list)
    clues: list[ClueSpec] = Field(default_factory=list)

    @field_validator("solution", mode="before")
    @classmethod
    def normalize_solution(cls, value: str | None) -> str | None:
        """Letter solutions are always stored in Turkish upper-case."""
        return None if value is None else tr_upper(value)

    @model_validator(mode="after")
    def check_by_type(self) -> Self:
        """Enforce per-type field rules (architecture.md §4.2)."""
        if self.type == CellType.LETTER:
            if self.solution is None:
                raise ValueError("letter cell requires a solution")
            if len(self.solution) != 1:
                raise ValueError("letter cell solution must be a single letter")
        elif self.type == CellType.CLUE:
            if not 1 <= len(self.clues) <= 2:
                raise ValueError("clue cell must carry 1 or 2 clues")
        elif self.type == CellType.BLANK:
            if self.solution is not None or self.clues or self.word_ids:
                raise ValueError(
                    "blank cell must have no solution, clues, or word_ids"
                )
        return self


class WordCell(BaseModel):
    """A single coordinate that belongs to a word's answer."""

    row: int = Field(ge=0)
    col: int = Field(ge=0)


class WordSpec(BaseModel):
    """A single answer word and its placement."""

    id: str
    answer: str = Field(min_length=1, max_length=15)
    length: int = Field(ge=1, le=15)
    direction: ClueArrow
    clue_cell: WordCell
    start_cell: WordCell
    cells: list[WordCell] = Field(min_length=1)
    clue: ClueSpec
    frequency_score: int = Field(ge=0, le=100, default=0)

    @field_validator("answer", mode="before")
    @classmethod
    def normalize_answer(cls, value: str) -> str:
        """Answers are always stored in Turkish upper-case."""
        return tr_upper(value)

    @model_validator(mode="after")
    def check_lengths(self) -> Self:
        """`length` must equal both the answer length and the cell count."""
        if self.length != len(self.answer):
            raise ValueError(
                f"length {self.length} != answer length {len(self.answer)}"
            )
        if len(self.cells) != self.length:
            raise ValueError(
                f"cell count {len(self.cells)} != length {self.length}"
            )
        return self


class GridSize(BaseModel):
    """Board dimensions in cells."""

    rows: int = Field(ge=4, le=12)
    cols: int = Field(ge=4, le=10)


class PuzzleSize(str, Enum):
    """Named board-size tier (architecture.md §5.3)."""

    SMALL = "small"
    MEDIUM = "medium"
    LARGE = "large"


class SafetyInfo(BaseModel):
    """Result of the post-fill profanity scan."""

    post_fill_scanned: bool = False
    scanner_version: str = "2.0.0"


class PuzzleData(BaseModel):
    """Top-level puzzle model — the v2 JSON contract."""

    schema_version: int = 2
    puzzle_id: int = Field(ge=1)
    size: PuzzleSize
    grid: GridSize
    cells: list[CellSpec] = Field(min_length=1)
    words: list[WordSpec] = Field(min_length=1, max_length=30)
    difficulty: Literal["easy", "medium", "hard", "expert"] = "medium"
    difficulty_score: int = Field(ge=0, le=100, default=0)
    template_id: str
    safety: SafetyInfo = Field(default_factory=SafetyInfo)
    generated_at: str = Field(
        default_factory=lambda: datetime.now(timezone.utc).isoformat()
    )
    generator_version: str = "2.0.0"

    @model_validator(mode="after")
    def require_safety_scan(self) -> Self:
        """A puzzle can never be persisted without a passing post-fill scan.

        See coding-standards.md §8.7 and architecture.md §6.4.
        """
        if not self.safety.post_fill_scanned:
            raise ValueError("Puzzle cannot be saved without post-fill safety scan")
        return self

    @model_validator(mode="after")
    def check_grid_consistency(self) -> Self:
        """Cross-check every word against the grid cells (architecture.md §4.4).

        - Each word cell must map to a `letter` cell whose solution equals the
          corresponding answer letter (intersection consistency).
        - Each word's clue_cell must map to a `clue` cell.
        """
        cell_by_pos = {(c.row, c.col): c for c in self.cells}
        for word in self.words:
            for index, wc in enumerate(word.cells):
                cell = cell_by_pos.get((wc.row, wc.col))
                if cell is None or cell.type != CellType.LETTER:
                    raise ValueError(
                        f"word {word.id}: cell ({wc.row},{wc.col}) is not a letter cell"
                    )
                if cell.solution != word.answer[index]:
                    raise ValueError(
                        f"word {word.id}: letter mismatch at ({wc.row},{wc.col}): "
                        f"cell={cell.solution!r} answer={word.answer[index]!r}"
                    )
            clue_cell = cell_by_pos.get((word.clue_cell.row, word.clue_cell.col))
            if clue_cell is None or clue_cell.type != CellType.CLUE:
                raise ValueError(
                    f"word {word.id}: clue_cell "
                    f"({word.clue_cell.row},{word.clue_cell.col}) is not a clue cell"
                )
        return self


if __name__ == "__main__":
    # Smoke test: exercises every model and validator as an import sanity check.
    # A small 2-word intersecting puzzle: KEDİ (right) crosses DAL (down) at 'D'.
    valid = PuzzleData(
        puzzle_id=1,
        size=PuzzleSize.SMALL,
        grid=GridSize(rows=4, cols=5),
        cells=[
            CellSpec(
                row=1,
                col=0,
                type=CellType.CLUE,
                clues=[
                    ClueSpec(text="Miyavlayan hayvan", arrow=ClueArrow.RIGHT, word_id="w1")
                ],
            ),
            CellSpec(
                row=0,
                col=3,
                type=CellType.CLUE,
                clues=[
                    ClueSpec(text="Ağaç parçası", arrow=ClueArrow.DOWN, word_id="w2")
                ],
            ),
            CellSpec(row=1, col=1, type=CellType.LETTER, solution="k", word_ids=["w1"]),
            CellSpec(row=1, col=2, type=CellType.LETTER, solution="E", word_ids=["w1"]),
            CellSpec(row=1, col=3, type=CellType.LETTER, solution="D", word_ids=["w1", "w2"]),
            CellSpec(row=1, col=4, type=CellType.LETTER, solution="İ", word_ids=["w1"]),
            CellSpec(row=2, col=3, type=CellType.LETTER, solution="A", word_ids=["w2"]),
            CellSpec(row=3, col=3, type=CellType.LETTER, solution="L", word_ids=["w2"]),
        ],
        words=[
            WordSpec(
                id="w1",
                answer="kedi",  # lower-case input is forced to Turkish upper
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
                clue=ClueSpec(text="Ağaç parçası", arrow=ClueArrow.DOWN, word_id="w2"),
                frequency_score=60,
            ),
        ],
        template_id="small_01",
        safety=SafetyInfo(post_fill_scanned=True),
    )

    # Verify the safety guard rejects an unscanned puzzle (model_validate
    # re-runs validators; model_copy would not).
    try:
        PuzzleData.model_validate(
            {**valid.model_dump(), "safety": {"post_fill_scanned": False}}
        )
        raise SystemExit("FAIL: unscanned puzzle was accepted")
    except ValueError:
        pass  # expected

    assert tr_upper("kedi") == "KEDİ"
    assert tr_upper("ıssız") == "ISSIZ"

    # Write UTF-8 bytes directly: the Windows console (cp1252) cannot encode
    # Turkish characters such as 'İ'.
    sys.stdout.buffer.write(valid.model_dump_json(indent=2).encode("utf-8"))
    sys.stdout.buffer.write(b"\n")
