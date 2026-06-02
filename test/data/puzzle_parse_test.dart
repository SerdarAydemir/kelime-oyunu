// test/data/puzzle_parse_test.dart

import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kelime_oyunu/data/models/puzzle.dart';
import 'package:kelime_oyunu/data/repositories/puzzle_repository.dart';

// Reads a file from test/fixtures/ relative to the project root.
// Inlined to avoid a cross-test relative import (coding-standards.md §1.5).
String _loadFixture(String name) =>
    File('test/fixtures/$name').readAsStringSync();

// Test-only AssetBundle: serves strings from an in-memory map; all other
// AssetBundle methods throw UnimplementedError via Fake's noSuchMethod.
final class _MapAssetBundle extends Fake implements AssetBundle {
  _MapAssetBundle(this._assets);

  final Map<String, String> _assets;

  @override
  Future<String> loadString(String key, {bool cache = true}) async {
    final content = _assets[key];
    if (content == null) throw StateError('Asset not found: $key');
    return content;
  }
}

void main() {
  // Parse the fixture once; all parse tests share the same PuzzleData instance.
  late final PuzzleData puzzle;

  setUpAll(() {
    final raw = _loadFixture('puzzle_0001.json');
    puzzle = PuzzleData.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  });

  // ── 1: top-level fields ─────────────────────────────────────────────────────

  test('fromJson: puzzleId, size and grid dimensions are parsed correctly', () {
    expect(puzzle.puzzleId, 1);
    expect(puzzle.size, PuzzleSize.medium);
    expect(puzzle.grid.rows, 8);
    expect(puzzle.grid.cols, 6);
  });

  // ── 2: cell types ───────────────────────────────────────────────────────────

  test('cells list is non-empty and contains letter and clue CellTypes', () {
    expect(puzzle.cells.isNotEmpty, isTrue);
    final types = puzzle.cells.map((c) => c.type).toSet();
    expect(types, containsAll([CellType.letter, CellType.clue]));
  });

  // ── 3: double-clue cell ─────────────────────────────────────────────────────

  test('double-clue cell at (4, 2) carries exactly two clues', () {
    final cell = puzzle.cells.firstWhere(
      (c) => c.type == CellType.clue && c.clues.length == 2,
    );
    expect(cell.row, 4);
    expect(cell.col, 2);
    expect(
      cell.clues.map((c) => c.arrow).toSet(),
      containsAll([ClueArrow.right, ClueArrow.down]),
    );
  });

  // ── 4: word cell coordinates ─────────────────────────────────────────────────

  test('WordSpec "DL" has 7 cells running down column 1, rows 1-7', () {
    final dl = puzzle.words.firstWhere((w) => w.id == 'DL');
    expect(dl.length, 7);
    expect(dl.cells.length, 7);
    for (var i = 0; i < dl.cells.length; i++) {
      expect(dl.cells[i], WordCell(row: i + 1, col: 1));
    }
  });

  // ── 5: ClueArrow enum ────────────────────────────────────────────────────────

  test('"right" parses to ClueArrow.right for word "A1"', () {
    final a1 = puzzle.words.firstWhere((w) => w.id == 'A1');
    expect(a1.direction, ClueArrow.right);
  });

  // ── 6: unknown enum value ────────────────────────────────────────────────────

  test('"diagonal" as ClueArrow value throws ArgumentError', () {
    expect(
      () => ClueSpec.fromJson(const {
        'text': 'Test',
        'arrow': 'diagonal',
        'word_id': 'x',
        'image_id': null,
        'source': 'placeholder',
      }),
      throwsA(isA<ArgumentError>()),
    );
  });

  // ── 7: AssetPuzzleRepository.loadManifest ───────────────────────────────────

  test('loadManifest returns at least one entry with positive puzzleId', () async {
    final manifestContent =
        File('assets/puzzles/manifest.json').readAsStringSync();
    final bundle = _MapAssetBundle({
      'assets/puzzles/manifest.json': manifestContent,
    });
    final repo = AssetPuzzleRepository(bundle: bundle);

    final entries = await repo.loadManifest();

    expect(entries.isNotEmpty, isTrue);
    expect(entries.every((e) => e.puzzleId > 0), isTrue);
  });
}
