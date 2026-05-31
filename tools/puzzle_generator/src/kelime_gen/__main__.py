# tools/puzzle_generator/src/kelime_gen/__main__.py
"""Typer CLI entry point for the v2 puzzle generator."""

import io
import json
import sys
from pathlib import Path
from typing import Annotated

import typer

from kelime_gen.generator import generate_pack
from kelime_gen.mask_template import MaskTemplate, load_templates_dir
from kelime_gen.word_pool import PoolEntry, load_blacklist

app = typer.Typer(
    name="kelime-gen",
    help="Türkçe Kelime Bulmaca puzzle generator (v2).",
    no_args_is_help=True,
)

# Generator root (tools/puzzle_generator), resolved from this file's location.
_ROOT = Path(__file__).resolve().parents[2]
_POOL_PATH = _ROOT / "data" / "processed" / "word_pool_cleaned.json"
_BLACKLIST_PATH = _ROOT / "data" / "raw" / "profanity_blacklist.txt"
_TEMPLATES_DIR = _ROOT / "templates"

# Placeholder clues stay bare ("N harfli kelime"). The later LLM phase fills
# tdk_definitions instead of touching this constant (architecture.md §7).
_DEFAULT_CATEGORY: str | None = None

_VALID_SIZES = ("small", "medium", "large", "all")


def _force_utf8_stdout() -> None:
    """Windows console UTF-8 fix for stdout and stderr (see CLAUDE.md).

    Both streams are wrapped because the generator writes Turkish messages to
    stderr. Called only from main(), never at import time.
    """
    if hasattr(sys.stdout, "buffer"):
        sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8")
    if hasattr(sys.stderr, "buffer"):
        sys.stderr = io.TextIOWrapper(sys.stderr.buffer, encoding="utf-8")


def _load_pool(path: Path) -> list[PoolEntry]:
    """Load the cleaned word pool JSON into PoolEntry items."""
    raw = json.loads(path.read_text(encoding="utf-8"))
    return [
        PoolEntry(word=item["word"], frequency_score=item["frequency_score"])
        for item in raw
    ]


@app.callback()
def _callback() -> None:
    """Türkçe Kelime Bulmaca puzzle generator."""
    # Empty callback forces multi-command mode so `generate` stays a named
    # subcommand instead of collapsing into the root command.


@app.command()
def generate(
    count: Annotated[int, typer.Option(help="Üretilecek bulmaca sayısı")] = 200,
    output_dir: Annotated[Path, typer.Option(help="Çıktı klasörü")] = Path(
        "assets/puzzles"
    ),
    size: Annotated[
        str, typer.Option(help="small | medium | large | all")
    ] = "all",
) -> None:
    """Bulmaca bölümlerini üretir ve JSON olarak yazar."""
    if size not in _VALID_SIZES:
        print(
            f"Geçersiz size '{size}'. Seçenekler: {', '.join(_VALID_SIZES)}.",
            file=sys.stderr,
        )
        raise typer.Exit(code=1)

    if not _POOL_PATH.exists():
        print(
            f"Kelime havuzu bulunamadı: {_POOL_PATH}. Önce word_pool çalıştır.",
            file=sys.stderr,
        )
        raise typer.Exit(code=1)

    pool = _load_pool(_POOL_PATH)
    blacklist = load_blacklist(_BLACKLIST_PATH) if _BLACKLIST_PATH.exists() else set()

    templates: list[MaskTemplate] = load_templates_dir(_TEMPLATES_DIR)
    if size != "all":
        templates = [t for t in templates if t.size.value == size]
    if not templates:
        print(
            f"Şablon bulunamadı (size={size}, klasör={_TEMPLATES_DIR}). "
            "Önce templates/ altına mask şablonları ekle.",
            file=sys.stderr,
        )
        raise typer.Exit(code=1)

    success, failed = generate_pack(
        templates=templates,
        word_pool=pool,
        blacklist=blacklist,
        start_puzzle_id=1,
        count=count,
        category=_DEFAULT_CATEGORY,
        output_dir=output_dir,
    )

    print(f"\nToplam: {success} üretildi, {failed} başarısız ({len(templates)} şablon)")
    if failed > 0:
        raise typer.Exit(code=1)


def main() -> None:
    """Console-script entry point: apply the UTF-8 fix before Typer parses args."""
    _force_utf8_stdout()
    app()


if __name__ == "__main__":
    main()
