# tools/puzzle_generator/scripts/reclue.py
"""Combined audit + re-clue workflow for the generated pack (P2c+P1).

Subcommands:
  next-batch  Emit the next 50 unaudited pack words (puzzle_count DESC,
              alphabetical tie-break) as the batch input JSON. --curated
              emits the curated (symbols/two_letter) words instead.
  apply       Validate a completed batch JSON and fold it into the label
              files: approved -> master_clues.json (+approved_words.json),
              rejected -> rejected_words.json, sensitive -> candidate list
              (reports/sensitive_candidates.json — NEVER sensitive_answers.txt,
              that file is owner-approved only). --curated edits symbols/
              two_letter clue text instead of master_clues.
  write-pack  Rewrite clue text in the 200 puzzle JSONs in place from the
              updated clue maps (geometry untouched), rebuild the manifest,
              and re-run verify_pack.
  status      Progress counters.

Audit trail lives in data/processed/reclue_results.json (committed).
"""

from __future__ import annotations

import io
import json
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Annotated, Any

import typer

_ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(_ROOT / "src"))

from kelime_gen.build_manifest import build_manifest  # noqa: E402
from kelime_gen.clue_writer import write_clue  # noqa: E402
from kelime_gen.pack_report import verify_pack  # noqa: E402
from kelime_gen.schema import PuzzleData, tr_upper  # noqa: E402

_PROCESSED = _ROOT / "data" / "processed"
_PACK_WORDS = _ROOT / "reports" / "pack_words.json"
_RESULTS = _PROCESSED / "reclue_results.json"
_MASTER = _PROCESSED / "master_clues.json"
_APPROVED = _PROCESSED / "approved_words.json"
_REJECTED = _PROCESSED / "rejected_words.json"
_CANDIDATES = _ROOT / "reports" / "sensitive_candidates.json"
_SYMBOLS = _ROOT / "data" / "symbols.json"
_TWO_LETTER = _ROOT / "data" / "two_letter.json"

_BATCH_SIZE = 50
_CLUE_TARGET = 20  # soft budget (double-clue cell); 21..24 warns
_CLUE_HARD_MAX = 24  # validation error above this
_VERDICTS = ("approved", "rejected", "sensitive")
_AUDIT_SOURCE = "claude_audit"
_AUDIT_MODEL = "claude-fable-5"

app = typer.Typer(name="reclue", help="Pack audit + re-clue workflow.", no_args_is_help=True)


def _force_utf8_stdout() -> None:
    """Windows console UTF-8 fix (see CLAUDE.md); called only from main()."""
    if hasattr(sys.stdout, "buffer"):
        sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8")
    if hasattr(sys.stderr, "buffer"):
        sys.stderr = io.TextIOWrapper(sys.stderr.buffer, encoding="utf-8")


def _read_json(path: Path, default: Any) -> Any:
    if not path.exists():
        return default
    return json.loads(path.read_text(encoding="utf-8"))


def _write_json(path: Path, data: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def _curated_answers() -> set[str]:
    entries = _read_json(_SYMBOLS, []) + _read_json(_TWO_LETTER, [])
    return {tr_upper(e["answer"]) for e in entries}


def _pack_entries() -> list[dict[str, Any]]:
    entries = _read_json(_PACK_WORDS, None)
    if entries is None:
        print(f"pack_words bulunamadı: {_PACK_WORDS} (önce extract_pack_words).", file=sys.stderr)
        raise typer.Exit(code=1)
    return list(entries)


def _results() -> dict[str, dict[str, Any]]:
    return dict(_read_json(_RESULTS, {}))


@app.command("next-batch")
def next_batch(
    curated: Annotated[bool, typer.Option(help="Curated (symbols/two_letter) batch'i")] = False,
    size: Annotated[int, typer.Option(help="Batch boyutu")] = _BATCH_SIZE,
) -> None:
    """Emit the next unaudited batch, highest puzzle_count first."""
    done = set(_results())
    curated_set = _curated_answers()
    remaining = [
        e
        for e in _pack_entries()
        if e["word"] not in done and (e["word"] in curated_set) == curated
    ]
    remaining.sort(key=lambda e: (-int(e["puzzle_count"]), str(e["word"])))
    batch = remaining if curated else remaining[:size]
    out = [
        {
            "word": e["word"],
            "length": len(e["word"]),
            "puzzle_count": e["puzzle_count"],
            "current_clues": e["clues"],
            "sources": e["sources"],
        }
        for e in batch
    ]
    print(json.dumps(out, ensure_ascii=False, indent=2))
    print(f"[{len(out)} kelime; kalan {len(remaining) - len(batch)}]", file=sys.stderr)


def _validate_entry(entry: dict[str, Any], curated_mode: bool, errors: list[str]) -> None:
    word, verdict = entry.get("word", ""), entry.get("verdict", "")
    clue = (entry.get("clue") or "").strip()
    if verdict not in _VERDICTS:
        errors.append(f"{word}: geçersiz verdict '{verdict}'")
        return
    if curated_mode and verdict != "approved":
        errors.append(f"{word}: curated kelimeye yalnız 'approved' verilebilir (yapısal dolgu)")
    if verdict == "approved":
        if not clue:
            errors.append(f"{word}: approved ama clue boş")
        elif len(clue) > _CLUE_HARD_MAX:
            errors.append(f"{word}: clue {len(clue)} kr > {_CLUE_HARD_MAX} (hard limit)")
        elif len(clue) > _CLUE_TARGET:
            print(f"[UYARI] {word}: clue {len(clue)} kr (> hedef {_CLUE_TARGET})")
        if len(word) >= 3 and tr_upper(word) in tr_upper(clue):
            errors.append(f"{word}: clue cevabın kendisini içeriyor")
    elif clue:
        print(f"[UYARI] {word}: {verdict} verdiktinde clue yok sayılır")


@app.command("apply")
def apply(
    batch_path: Annotated[Path, typer.Argument(help="Batch çıktı JSON dosyası")],
    curated: Annotated[bool, typer.Option(help="Curated batch modu")] = False,
) -> None:
    """Validate a batch and fold it into the label/clue files (all-or-nothing)."""
    batch: list[dict[str, Any]] = _read_json(batch_path, None)
    if not isinstance(batch, list) or not batch:
        print(f"Batch okunamadı veya boş: {batch_path}", file=sys.stderr)
        raise typer.Exit(code=1)

    results = _results()
    pack_words = {e["word"] for e in _pack_entries()}
    curated_set = _curated_answers()
    errors: list[str] = []
    seen: set[str] = set()
    for entry in batch:
        word = entry.get("word", "")
        if word in seen:
            errors.append(f"{word}: batch içinde mükerrer")
        seen.add(word)
        if word not in pack_words:
            errors.append(f"{word}: pack_words'te yok")
        if word in results:
            errors.append(f"{word}: zaten işlenmiş (batch {results[word]['batch']})")
        if (word in curated_set) != curated:
            errors.append(f"{word}: curated modu uyuşmazlığı (--curated={curated})")
        _validate_entry(entry, curated, errors)
    if errors:
        print("Batch REDDEDİLDİ, hiçbir dosya yazılmadı:", file=sys.stderr)
        for err in errors:
            print(f"  - {err}", file=sys.stderr)
        raise typer.Exit(code=1)

    batch_no = 1 + max((int(r["batch"]) for r in results.values()), default=0)
    stamp = datetime.now(timezone.utc).isoformat(timespec="seconds")
    master = _read_json(_MASTER, {})
    approved_list: list[str] = _read_json(_APPROVED, [])
    rejected_list: list[str] = _read_json(_REJECTED, [])
    candidates: list[dict[str, Any]] = _read_json(_CANDIDATES, [])
    curated_files = {p: _read_json(p, []) for p in (_SYMBOLS, _TWO_LETTER)}

    tally = {v: 0 for v in _VERDICTS}
    for entry in batch:
        word, verdict = entry["word"], entry["verdict"]
        clue = (entry.get("clue") or "").strip()
        note = (entry.get("note") or "").strip()
        tally[verdict] += 1
        results[word] = {
            "verdict": verdict,
            "clue": clue or None,
            "note": note or None,
            "batch": batch_no,
            "decided_at": stamp,
        }
        if verdict == "approved" and curated:
            hit = False
            for rows in curated_files.values():
                for row in rows:
                    if tr_upper(row["answer"]) == word:
                        row["clue"], hit = clue, True
            if not hit:  # curated_set membership already checked; belt and braces
                print(f"[UYARI] {word}: curated dosyalarında bulunamadı", file=sys.stderr)
        elif verdict == "approved":
            record: dict[str, Any] = {"text": clue, "source": _AUDIT_SOURCE, "model": _AUDIT_MODEL}
            if note:
                record["note"] = note
            master[word] = record
            if word not in approved_list:
                approved_list.append(word)
        elif verdict == "rejected":
            if word not in rejected_list:
                rejected_list.append(word)
        else:
            candidates.append({"word": word, "note": note, "batch": batch_no, "at": stamp})

    _write_json(_RESULTS, results)
    if curated:
        for path, rows in curated_files.items():
            _write_json(path, rows)
    else:
        _write_json(_MASTER, master)
        _write_json(_APPROVED, sorted(approved_list))
    _write_json(_REJECTED, sorted(rejected_list))
    _write_json(_CANDIDATES, candidates)
    print(
        f"Batch {batch_no} uygulandı: {tally['approved']} approved, "
        f"{tally['rejected']} rejected, {tally['sensitive']} sensitive aday."
    )
    if tally["sensitive"]:
        print(f"Sensitive adaylar onay için: {_CANDIDATES}")


@app.command("write-pack")
def write_pack(
    puzzles_dir: Annotated[Path, typer.Option(help="Pack klasörü")] = Path("assets/puzzles"),
    expected_count: Annotated[int, typer.Option(help="Beklenen puzzle sayısı")] = 200,
) -> None:
    """Rewrite clue text in place from the updated clue maps; geometry untouched."""
    curated_map = {
        tr_upper(e["answer"]): str(e["clue"])
        for e in _read_json(_SYMBOLS, []) + _read_json(_TWO_LETTER, [])
    }
    master_map = {tr_upper(w): str(rec["text"]) for w, rec in _read_json(_MASTER, {}).items()}

    changed_words = changed_files = 0
    for path in sorted(puzzles_dir.glob("puzzle_*.json")):
        raw = json.loads(path.read_text(encoding="utf-8"))
        touched = False
        for w in raw["words"]:
            spec = write_clue(tr_upper(w["answer"]), None, curated_map, master_map)
            if spec.source == "placeholder":
                print(f"{path.name}: {w['answer']} clue'suz kaldı — durduruldu.", file=sys.stderr)
                raise typer.Exit(code=1)
            if w["clue"]["text"] != spec.text or w["clue"]["source"] != spec.source:
                w["clue"]["text"], w["clue"]["source"] = spec.text, spec.source
                touched = True
                changed_words += 1
        if touched:
            puzzle = PuzzleData.model_validate(raw)  # re-validate before writing
            path.write_text(puzzle.model_dump_json(indent=2), encoding="utf-8")
            changed_files += 1

    manifest = build_manifest(puzzles_dir)
    verification = verify_pack(puzzles_dir, expected_count=expected_count)
    print(
        f"{changed_words} clue güncellendi ({changed_files} dosyada); "
        f"manifest: {manifest['total_puzzles']} bölüm."
    )
    print(
        f"verify_pack: ok={verification['ok']} "
        f"placeholder={len(verification['placeholder_violations'])} "
        f"kaynaklar={verification['clue_sources']}"
    )
    if not verification["ok"]:
        raise typer.Exit(code=1)


@app.command("status")
def status() -> None:
    """Progress counters for the audit."""
    entries = _pack_entries()
    results = _results()
    curated_set = _curated_answers()
    tally = {v: 0 for v in _VERDICTS}
    for r in results.values():
        tally[str(r["verdict"])] += 1
    todo = [e["word"] for e in entries if e["word"] not in results]
    todo_curated = sum(1 for w in todo if w in curated_set)
    print(
        f"Pack: {len(entries)} benzersiz kelime; işlenen {len(results)} "
        f"(approved {tally['approved']}, rejected {tally['rejected']}, "
        f"sensitive aday {tally['sensitive']})"
    )
    print(f"Kalan: {len(todo)} ({todo_curated} curated, {len(todo) - todo_curated} normal)")


def main() -> None:
    """Console entry point: apply the UTF-8 fix before Typer parses args."""
    _force_utf8_stdout()
    app()


if __name__ == "__main__":
    main()
