# tools/puzzle_generator/src/kelime_gen/clue_writer.py
"""Clue text generation for puzzle words (architecture.md §7).

Priority order for a single word:
  1. TDK definition  → source="tdk"    (strip, first-letter capitalise, truncate)
  2. Category hint   → source="placeholder"  ("{n} harfli bir {category}")
  3. Bare fallback   → source="placeholder"  ("{n} harfli kelime")

LLM rewriting (§7.1 Phase 2) and TDK network fetching (§7.4) are out of scope
here; the generator orchestrator will handle those layers.
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
    tdk_definition: str | None = None,
    category: str | None = None,
) -> ClueSpec:
    """Produce a ClueSpec for *word*.

    Priority:
      1. *tdk_definition* → source="tdk", text stripped + capitalised + truncated.
      2. *category*       → source="placeholder", "{n} harfli bir {category}".
      3. Neither          → source="placeholder", "{n} harfli kelime".

    *arrow* defaults to RIGHT and *word_id* to "" — the generator assigns both.
    """
    word_len = len(word)

    if tdk_definition is not None:
        cleaned = tdk_definition.strip()
        capitalised = _capitalise_first(cleaned)
        text: str = truncate_clue(capitalised)
        source: str = "tdk"
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
    tdk_definitions: dict[str, str] | None = None,
    categories: dict[str, str] | None = None,
    default_category: str | None = None,
) -> list[ClueSpec]:
    """Produce a ClueSpec for every word in *words*.

    Per-word priority:
      1. ``tdk_definitions[word]`` if provided.
      2. ``categories[word]`` if provided.
      3. *default_category* if provided.
      4. Bare placeholder fallback.

    Supports mixed batches (each word may have a different category) as well as
    single-category batches (pass *default_category*).
    """
    tdk_defs = tdk_definitions or {}
    cats = categories or {}

    result: list[ClueSpec] = []
    for word in words:
        tdk_def = tdk_defs.get(word)
        cat = cats.get(word) or default_category
        result.append(write_clue(word, tdk_definition=tdk_def, category=cat))
    return result
