# tools/puzzle_generator/src/kelime_gen/clue_writer.py
"""Clue text generation for puzzle words (architecture.md §7).

Priority order for a single word:
  1. Curated clue  → source="curated"  (hand-crafted; len-1/2 answers)
  2. Master clue   → source="llm"      (LLM-written; len 3-8 answers)
  3. Category hint → source="placeholder"  ("{n} harfli bir {category}")
  4. Bare fallback → source="placeholder"  ("{n} harfli kelime")

word_id and arrow direction are left as defaults (generator.py assigns them).
"""

from kelime_gen.schema import ClueArrow, ClueSpec, tr_lower

# Turkish-aware first-letter capitalisation.  We only need the i/ı→İ/I
# mapping; the rest of .upper() is fine for sentence-initial capitalisation.
_TR_UPPER_MAP = str.maketrans("iı", "İI")


def truncate_clue(text: str, max_len: int = 60) -> str:
    """Truncate *text* to at most *max_len* characters (inclusive of ellipsis).

    Returns *text* unchanged when it already fits.  The ellipsis suffix "..."
    counts toward *max_len*, so the visible content is ``max_len - 3`` chars.
    Raises ValueError when *max_len* is less than 3 (no room for any content).
    """
    if max_len < 3:
        raise ValueError(f"max_len must be >= 3, got {max_len}")
    if len(text) <= max_len:
        return text
    return text[: max_len - 3] + "..."


def _capitalise_first(text: str) -> str:
    """Uppercase only the first character using Turkish letter rules.

    str.upper() alone would mishandle 'i' → 'I' (should be 'İ') and
    'ı' → 'I' (correct, but only after the translation).
    """
    if not text:
        return text
    first = text[0:1].translate(_TR_UPPER_MAP).upper()
    return first + text[1:]


def write_clue(
    word: str,
    category: str | None = None,
    curated_clues: dict[str, str] | None = None,
    master_clues: dict[str, str] | None = None,
) -> ClueSpec:
    """Produce a ClueSpec for *word*.

    Priority:
      1. *curated_clues[word]* → source="curated" (hand-crafted; len-1/2 answers).
      2. *master_clues[word]*  → source="llm" (LLM-written; len 3-8 answers).
      3. *category*            → source="placeholder", "{n} harfli bir {category}".
      4. Neither               → source="placeholder", "{n} harfli kelime".

    Curated and master clues are first-letter capitalised and truncated to fit
    the 60-character clue budget.

    *arrow* defaults to RIGHT and *word_id* to "" — the generator assigns both.
    """
    word_len = len(word)

    if curated_clues and word in curated_clues:
        text: str = truncate_clue(_capitalise_first(curated_clues[word].strip()))
        source: str = "curated"
    elif master_clues and word in master_clues:
        text = truncate_clue(_capitalise_first(master_clues[word].strip()))
        source = "llm"
    elif category is not None:
        text = f"{word_len} harfli bir {tr_lower(category.strip())}"
        source = "placeholder"
    else:
        text = f"{word_len} harfli kelime"
        source = "placeholder"

    return ClueSpec(
        text=text,
        arrow=ClueArrow.RIGHT,
        word_id="",
        source=source,  # type: ignore[arg-type]
    )


def write_clues(
    words: list[str],
    categories: dict[str, str] | None = None,
    default_category: str | None = None,
    curated_clues: dict[str, str] | None = None,
    master_clues: dict[str, str] | None = None,
) -> list[ClueSpec]:
    """Produce a ClueSpec for every word in *words*.

    Per-word priority:
      1. ``curated_clues[word]`` if provided (len-1/2 hand-crafted clues).
      2. ``master_clues[word]`` if provided (LLM-written, len 3-8 clues).
      3. ``categories[word]`` if provided.
      4. *default_category* if provided.
      5. Bare placeholder fallback.

    Supports mixed batches (each word may have a different category) as well as
    single-category batches (pass *default_category*).
    """
    cats = categories or {}

    result: list[ClueSpec] = []
    for word in words:
        cat = cats.get(word) or default_category
        result.append(
            write_clue(
                word,
                category=cat,
                curated_clues=curated_clues,
                master_clues=master_clues,
            )
        )
    return result
