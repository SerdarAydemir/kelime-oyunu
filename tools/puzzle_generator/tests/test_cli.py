# tools/puzzle_generator/tests/test_cli.py
"""CLI preflight tests for `kelime-gen generate`.

Only the cheap fail-fast paths are exercised here; a full generation run is
covered by test_generator through generate_pack directly.
"""

from pathlib import Path

import pytest
from typer.testing import CliRunner

from kelime_gen import __main__ as cli

_runner = CliRunner()


def test_generate_fails_without_profanity_blacklist(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    """Missing blacklist must abort with exit 1 — never a silent empty-set scan."""
    missing = tmp_path / "profanity_blacklist.txt"
    monkeypatch.setattr(cli, "_BLACKLIST_PATH", missing)

    result = _runner.invoke(cli.app, ["generate", "--count", "1", "--output-dir", str(tmp_path)])

    assert result.exit_code == 1
    assert "Küfür kara listesi bulunamadı" in result.output
    assert str(missing) in result.output
    # Nothing was generated.
    assert not list(tmp_path.glob("puzzle_*.json"))


def test_generate_rejects_unknown_size(tmp_path: Path) -> None:
    result = _runner.invoke(cli.app, ["generate", "--size", "huge", "--output-dir", str(tmp_path)])
    assert result.exit_code == 1
    assert "Geçersiz size" in result.output
