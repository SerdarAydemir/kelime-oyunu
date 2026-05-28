# tools/level_generator/tests/test_schema_validator.py
"""Unit tests for schema_validator: geometric checks + pydantic integration."""

import json
from pathlib import Path

import pytest

from kelime_gen.schema import Level
from kelime_gen.validators.schema_validator import validate_level_file

_FIXTURES = Path(__file__).parent / "fixtures"
_EASY = _FIXTURES / "sample_level_easy.json"
_INVALID = _FIXTURES / "sample_level_invalid.json"


@pytest.fixture()
def easy_data() -> dict:  # type: ignore[type-arg]
    """Load sample_level_easy.json as a dict for in-test manipulation."""
    return json.loads(_EASY.read_text(encoding="utf-8"))


def _write_level(data: dict, tmp_path: Path) -> Path:  # type: ignore[type-arg]
    path = tmp_path / "level.json"
    path.write_text(json.dumps(data, ensure_ascii=False), encoding="utf-8")
    return path


def test_valid_level_parses_successfully() -> None:
    level = validate_level_file(_EASY)
    assert isinstance(level, Level)
    assert level.level_id == 1


def test_compatible_intersection_is_valid() -> None:
    # KEDİ (horizontal) and KALE (vertical) both start at (0,0) with 'K'.
    # Shared cell with matching letter must NOT raise.
    level = validate_level_file(_EASY)
    words = {w.word for w in level.words}
    assert "KEDİ" in words
    assert "KALE" in words


def test_incompatible_intersection_raises(
    easy_data: dict,  # type: ignore[type-arg]
    tmp_path: Path,
) -> None:
    # Change KALE → ZALE: expects 'Z' at (0,0), but grid[0][0]='K' → conflict.
    for word in easy_data["words"]:
        if word["word"] == "KALE":
            word["word"] = "ZALE"
            break
    with pytest.raises(ValueError):
        validate_level_file(_write_level(easy_data, tmp_path))


def test_safety_false_raises() -> None:
    with pytest.raises(ValueError):
        validate_level_file(_INVALID)


def test_out_of_bounds_placement_raises(
    easy_data: dict,  # type: ignore[type-arg]
    tmp_path: Path,
) -> None:
    # KEDİ is 4 letters horizontal; start.col=4 → last cell at col 7 → OOB in 6-wide grid.
    easy_data["words"][0]["start"]["col"] = 4
    with pytest.raises(ValueError):
        validate_level_file(_write_level(easy_data, tmp_path))


def test_grid_size_mismatch_raises(
    easy_data: dict,  # type: ignore[type-arg]
    tmp_path: Path,
) -> None:
    easy_data["grid_size"]["rows"] = 7  # actual grid has 6 rows
    with pytest.raises(ValueError):
        validate_level_file(_write_level(easy_data, tmp_path))


def test_word_not_in_grid_raises(
    easy_data: dict,  # type: ignore[type-arg]
    tmp_path: Path,
) -> None:
    # KEDİ and KALE both expect 'K' at (0,0); replacing with 'Z' breaks both.
    easy_data["grid"][0][0] = "Z"
    with pytest.raises(ValueError):
        validate_level_file(_write_level(easy_data, tmp_path))
