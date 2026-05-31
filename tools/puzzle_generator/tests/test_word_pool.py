# tools/level_generator/tests/test_word_pool.py
"""Unit tests for the word pool cleaning pipeline."""

from kelime_gen.word_pool import PoolEntry, build_pool, tr_upper


def _words(pool: list[PoolEntry]) -> set[str]:
    return {entry["word"] for entry in pool}


def test_profanity_filter_removes_blacklisted_word() -> None:
    pool = build_pool(["KEDİ", "KÖTÜSÖZ"], blacklist={"kötüsöz"})
    words = _words(pool)
    assert "KEDİ" in words
    assert "KÖTÜSÖZ" not in words


def test_qwx_filter_drops_foreign_letters() -> None:
    pool = build_pool(["WALL", "QATAR", "XENON", "ELMA"], blacklist=set())
    words = _words(pool)
    assert words == {"ELMA"}


def test_length_filter_keeps_only_3_to_12() -> None:
    pool = build_pool(
        ["AB", "KEDİ", "KARARLILIKLA", "OLAĞANÜSTÜLÜK"],
        blacklist=set(),
    )
    words = _words(pool)
    assert "AB" not in words  # 2 letters -> dropped
    assert "KEDİ" in words  # 4 letters -> kept
    assert "KARARLILIKLA" in words  # 12 letters -> kept
    assert "OLAĞANÜSTÜLÜK" not in words  # 13 letters -> dropped


def test_tr_upper_handles_dotted_and_dotless_i() -> None:
    assert tr_upper("kedi") == "KEDİ"
    assert tr_upper("ıssız") == "ISSIZ"


def test_frequency_score_follows_length() -> None:
    pool = build_pool(["ELMA", "KEDİ", "ARMUTLAR"], blacklist=set())
    scores = {entry["word"]: entry["frequency_score"] for entry in pool}
    assert scores["ELMA"] == 80  # 4 letters
    assert scores["KEDİ"] == 80  # 4 letters
    assert scores["ARMUTLAR"] == 40  # 8 letters
