# tools/level_generator/src/kelime_gen/schema.py
"""Pydantic data models defining the level JSON contract.

These models are the single source of truth shared between the Python
generator (producer) and the Flutter client (consumer). See architecture.md
sections 4.1 (JSON schema) and 7.2 (pydantic schema).
"""

import sys
from enum import Enum

from pydantic import BaseModel, Field, field_validator, model_validator

# Turkish-aware uppercase mapping. casefold/upper() in Python lower the
# dotted/dotless 'i' incorrectly for Turkish, so we translate first.
# See architecture.md section 7.6.
_TR_UPPER_MAP = str.maketrans("iı", "İI")


def _tr_upper(text: str) -> str:
    """Uppercase a string using Turkish letter rules."""
    return text.translate(_TR_UPPER_MAP).upper()


class Difficulty(str, Enum):
    TUTORIAL = "tutorial"
    EASY = "easy"
    MEDIUM = "medium"
    HARD = "hard"
    EXPERT = "expert"


class Direction(str, Enum):
    HORIZONTAL = "horizontal"
    VERTICAL = "vertical"
    DIAGONAL_DOWN = "diagonal_down"
    DIAGONAL_UP = "diagonal_up"


class Position(BaseModel):
    row: int = Field(ge=0)
    col: int = Field(ge=0)


class WordPlacement(BaseModel):
    word: str = Field(min_length=2, max_length=15)
    start: Position
    direction: Direction
    length: int = Field(ge=2, le=15)
    frequency_score: int = Field(ge=0, le=100)
    hint_tr: str = Field(max_length=60)

    @field_validator("word", mode="before")
    @classmethod
    def force_turkish_upper(cls, value: str) -> str:
        """Words are always stored in Turkish upper-case form."""
        return _tr_upper(value)


class GridSize(BaseModel):
    rows: int = Field(ge=5, le=18)
    cols: int = Field(ge=5, le=18)


class Rewards(BaseModel):
    coins_base: int = Field(ge=10, le=500)
    coins_perfect: int = Field(ge=20, le=1000)
    stars_threshold_seconds: list[int] = Field(min_length=3, max_length=3)


class Safety(BaseModel):
    post_fill_scanned: bool
    scanner_version: str


class Level(BaseModel):
    schema_version: int = 1
    level_id: int = Field(ge=1)
    pack_id: str
    difficulty: Difficulty
    difficulty_score: int = Field(ge=0, le=100)
    category: str
    category_display_tr: str
    grid_size: GridSize
    grid: list[list[str]]
    words: list[WordPlacement] = Field(min_length=3, max_length=25)
    bonus_words: list[str] = []
    rewards: Rewards
    safety: Safety
    generated_at: str
    generator_version: str

    @model_validator(mode="after")
    def require_safety_scan(self) -> "Level":
        """A level can never be persisted without a passing post-fill scan.

        See coding-standards.md section 8.7 and architecture.md section 7.3.
        """
        if not self.safety.post_fill_scanned:
            raise ValueError("Level cannot be saved without post-fill safety scan")
        return self


if __name__ == "__main__":
    # Smoke test: build a valid level and serialize it. Running this module
    # exercises every model and validator, acting as an import sanity check.
    sample = Level(
        schema_version=1,
        level_id=42,
        pack_id="pack_002_hayvanlar",
        difficulty=Difficulty.EASY,
        difficulty_score=34,
        category="hayvanlar",
        category_display_tr="Hayvanlar",
        grid_size=GridSize(rows=8, cols=8),
        grid=[
            ["K", "E", "D", "İ", "A", "R", "N", "L"],
            ["B", "T", "K", "U", "Ş", "M", "E", "İ"],
        ],
        words=[
            WordPlacement(
                word="kedi",  # lower-case input is forced to Turkish upper
                start=Position(row=0, col=0),
                direction=Direction.HORIZONTAL,
                length=4,
                frequency_score=88,
                hint_tr="Miyavlayan ev hayvanı",
            ),
            WordPlacement(
                word="KUŞ",
                start=Position(row=1, col=2),
                direction=Direction.HORIZONTAL,
                length=3,
                frequency_score=75,
                hint_tr="Uçan canlı",
            ),
            WordPlacement(
                word="EMU",
                start=Position(row=1, col=5),
                direction=Direction.VERTICAL,
                length=3,
                frequency_score=20,
                hint_tr="Avustralya'ya özgü iri kuş",
            ),
        ],
        bonus_words=["EK", "EL"],
        rewards=Rewards(
            coins_base=50,
            coins_perfect=100,
            stars_threshold_seconds=[60, 120, 180],
        ),
        safety=Safety(post_fill_scanned=True, scanner_version="1.0.0"),
        generated_at="2026-05-15T10:30:00Z",
        generator_version="1.2.0",
    )

    # Write UTF-8 bytes directly: the default Windows console encoding
    # (cp1252) cannot encode Turkish characters such as 'İ'.
    sys.stdout.buffer.write(sample.model_dump_json(indent=2).encode("utf-8"))
    sys.stdout.buffer.write(b"\n")
