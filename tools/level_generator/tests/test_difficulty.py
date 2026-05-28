# tools/level_generator/tests/test_difficulty.py
"""Unit tests for the difficulty score formula."""

from kelime_gen.difficulty import difficulty_score
from kelime_gen.schema import (
    Difficulty,
    Direction,
    GridSize,
    Level,
    Position,
    Rewards,
    Safety,
    WordPlacement,
)


def _make_word(word: str, freq: int, direction: Direction) -> WordPlacement:
    return WordPlacement(
        word=word,
        start=Position(row=0, col=0),
        direction=direction,
        length=len(word),
        frequency_score=freq,
        hint_tr="ipucu",
    )


def _make_level(rows: int, cols: int, words: list[WordPlacement]) -> Level:
    return Level(
        schema_version=1,
        level_id=1,
        pack_id="test",
        difficulty=Difficulty.EASY,
        difficulty_score=0,
        category="test",
        category_display_tr="Test",
        grid_size=GridSize(rows=rows, cols=cols),
        grid=[["A"] * cols for _ in range(rows)],
        words=words,
        bonus_words=[],
        rewards=Rewards(
            coins_base=50,
            coins_perfect=100,
            stars_threshold_seconds=[60, 120, 180],
        ),
        safety=Safety(post_fill_scanned=True, scanner_version="1.0.0"),
        generated_at="2026-01-01T00:00:00Z",
        generator_version="1.0.0",
    )


def test_short_words_small_grid_gives_low_score() -> None:
    # 3 three-letter words, high frequency → very easy → score ≈ 8
    words = [_make_word("AAA", 90, Direction.HORIZONTAL) for _ in range(3)]
    assert difficulty_score(_make_level(5, 5, words)) < 40


def test_long_words_big_grid_gives_high_score() -> None:
    # 12-letter words, low frequency, large grid, one diagonal → score ≈ 68
    words = [
        _make_word("A" * 12, 10, Direction.HORIZONTAL),
        _make_word("B" * 12, 10, Direction.HORIZONTAL),
        _make_word("C" * 12, 10, Direction.DIAGONAL_DOWN),
    ]
    assert difficulty_score(_make_level(18, 18, words)) > 60


def test_score_always_within_0_to_100() -> None:
    # Easiest possible: short high-frequency words, tiny grid, no diagonals.
    words_easy = [_make_word("AA", 100, Direction.HORIZONTAL) for _ in range(3)]
    assert 0 <= difficulty_score(_make_level(5, 5, words_easy)) <= 100

    # Hardest possible: max-length rare words, full 18×18 grid, all diagonal.
    words_hard = [_make_word("A" * 15, 0, Direction.DIAGONAL_DOWN) for _ in range(3)]
    assert 0 <= difficulty_score(_make_level(18, 18, words_hard)) <= 100


def test_diagonal_words_increase_score() -> None:
    base_words = [_make_word("ABCDE", 50, Direction.HORIZONTAL) for _ in range(3)]
    diag_words = [
        _make_word("ABCDE", 50, Direction.HORIZONTAL),
        _make_word("ABCDE", 50, Direction.HORIZONTAL),
        _make_word("ABCDE", 50, Direction.DIAGONAL_DOWN),
    ]
    score_h = difficulty_score(_make_level(10, 10, base_words))
    score_d = difficulty_score(_make_level(10, 10, diag_words))
    assert score_d > score_h
