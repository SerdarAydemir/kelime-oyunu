# tools/level_generator/src/kelime_gen/hint_writer.py
"""Generates user-facing Turkish hints for a level's words.

This is the placeholder implementation (pipeline step A): hints are derived
purely from word length and category. v1.1 replaces this with LLM-authored,
human-reviewed hints (see architecture.md section 7.1).
"""


def write_hints(words: list[str], category: str) -> list[str]:
    """Return a placeholder hint per word.

    Example:
        write_hints(["KEDİ"], "hayvanlar") -> ["4 harfli bir hayvanlar kelimesi"]
    """
    return [f"{len(word)} harfli bir {category} kelimesi" for word in words]
