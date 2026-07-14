// test/features/gameplay/engine/score_engine_test.dart

import 'package:flutter_test/flutter_test.dart';

import 'package:kelime_oyunu/data/models/puzzle.dart';
import 'package:kelime_oyunu/features/gameplay/engine/score_engine.dart';

// Shared test helpers live under test/ and have no package: path, so a relative
// import is unavoidable here (always_use_package_imports only resolves to lib/).
// ignore: always_use_package_imports
import '../../../helpers/engine_test_fixtures.dart';

void main() {
  const engine = ScoreEngine();

  group('ScoreEngine.resolveMove', () {
    // ── 1 ──────────────────────────────────────────────────────────────────
    test('single correct placement scores +1 with a cell-bound event', () {
      final puzzle = puzzleFromWords([
        buildWord(id: 'w1', answer: 'MASA', startRow: 1, startCol: 1, direction: ClueArrow.right),
      ]);

      final result = engine.resolveMove(
        placements: const [Placement(cell: WordCell(row: 1, col: 1), letter: 'M', expected: 'M')],
        puzzle: puzzle,
        board: const {},
        rackStartCount: 5,
      );

      expect(result.scoreDelta, 1);
      expect(result.events.first.cell, isNotNull);
      expect(result.returnedLetters, isEmpty);
    });

    // ── 2 ──────────────────────────────────────────────────────────────────
    test('single wrong placement scores -1 and returns the letter', () {
      final puzzle = puzzleFromWords([
        buildWord(id: 'w1', answer: 'MASA', startRow: 1, startCol: 1, direction: ClueArrow.right),
      ]);

      final result = engine.resolveMove(
        placements: const [Placement(cell: WordCell(row: 1, col: 1), letter: 'X', expected: 'M')],
        puzzle: puzzle,
        board: const {},
        rackStartCount: 5,
      );

      expect(result.scoreDelta, -1);
      expect(result.returnedLetters, ['X']);
      expect(result.updatedBoard, isEmpty);
    });

    // ── 3 ──────────────────────────────────────────────────────────────────
    test('mixed move (2 correct, 1 wrong) nets +1 and returns 1 letter', () {
      final puzzle = puzzleFromWords([
        buildWord(id: 'w1', answer: 'MASA', startRow: 1, startCol: 1, direction: ClueArrow.right),
      ]);

      final result = engine.resolveMove(
        placements: const [
          Placement(cell: WordCell(row: 1, col: 1), letter: 'M', expected: 'M'),
          Placement(cell: WordCell(row: 1, col: 2), letter: 'A', expected: 'A'),
          Placement(cell: WordCell(row: 1, col: 3), letter: 'Z', expected: 'S'),
        ],
        puzzle: puzzle,
        board: const {},
        rackStartCount: 5,
      );

      expect(result.scoreDelta, 1);
      expect(result.returnedLetters.length, 1);
    });

    // ── 4 ──────────────────────────────────────────────────────────────────
    test('completing a 4-letter word adds a +4 game-level bonus event', () {
      final puzzle = puzzleFromWords([
        buildWord(id: 'w1', answer: 'MASA', startRow: 1, startCol: 1, direction: ClueArrow.right),
      ]);

      final result = engine.resolveMove(
        placements: const [
          Placement(cell: WordCell(row: 1, col: 1), letter: 'M', expected: 'M'),
          Placement(cell: WordCell(row: 1, col: 2), letter: 'A', expected: 'A'),
          Placement(cell: WordCell(row: 1, col: 3), letter: 'S', expected: 'S'),
          Placement(cell: WordCell(row: 1, col: 4), letter: 'A', expected: 'A'),
        ],
        puzzle: puzzle,
        board: const {},
        rackStartCount: 5,
      );

      // 4 correct letters (+4) plus the completion bonus (+4).
      expect(result.scoreDelta, 8);
      expect(result.completedWordIds, contains('w1'));
      expect(result.events.any((e) => e.cell == null && e.wordBonus == 4), isTrue);
    });

    // ── 5 ──────────────────────────────────────────────────────────────────
    test('an incomplete word grants no completion bonus', () {
      final puzzle = puzzleFromWords([
        buildWord(id: 'w1', answer: 'MASA', startRow: 1, startCol: 1, direction: ClueArrow.right),
      ]);

      final result = engine.resolveMove(
        placements: const [
          Placement(cell: WordCell(row: 1, col: 1), letter: 'M', expected: 'M'),
          Placement(cell: WordCell(row: 1, col: 2), letter: 'A', expected: 'A'),
          Placement(cell: WordCell(row: 1, col: 3), letter: 'S', expected: 'S'),
        ],
        puzzle: puzzle,
        board: const {},
        rackStartCount: 5,
      );

      expect(result.scoreDelta, 3);
      expect(result.completedWordIds, isEmpty);
    });

    // ── 6 ──────────────────────────────────────────────────────────────────
    test('emptying a 5-tile rack with all-correct play grants +5', () {
      final puzzle = puzzleFromWords([
        buildWord(id: 'w1', answer: 'KALEM', startRow: 1, startCol: 1, direction: ClueArrow.right),
      ]);

      final result = engine.resolveMove(
        placements: const [
          Placement(cell: WordCell(row: 1, col: 1), letter: 'K', expected: 'K'),
          Placement(cell: WordCell(row: 1, col: 2), letter: 'A', expected: 'A'),
          Placement(cell: WordCell(row: 1, col: 3), letter: 'L', expected: 'L'),
          Placement(cell: WordCell(row: 1, col: 4), letter: 'E', expected: 'E'),
          Placement(cell: WordCell(row: 1, col: 5), letter: 'M', expected: 'M'),
        ],
        puzzle: puzzle,
        board: const {},
        rackStartCount: 5,
      );

      expect(result.rackEmptied, isTrue);
      expect(result.rackEmptyBonus, 5);
    });

    // ── 7 ──────────────────────────────────────────────────────────────────
    test('emptying a 6-tile power-up rack grants +6', () {
      final puzzle = puzzleFromWords([
        buildWord(id: 'w1', answer: 'KAPLAN', startRow: 1, startCol: 1, direction: ClueArrow.down),
      ]);

      final result = engine.resolveMove(
        placements: const [
          Placement(cell: WordCell(row: 1, col: 1), letter: 'K', expected: 'K'),
          Placement(cell: WordCell(row: 2, col: 1), letter: 'A', expected: 'A'),
          Placement(cell: WordCell(row: 3, col: 1), letter: 'P', expected: 'P'),
          Placement(cell: WordCell(row: 4, col: 1), letter: 'L', expected: 'L'),
          Placement(cell: WordCell(row: 5, col: 1), letter: 'A', expected: 'A'),
          Placement(cell: WordCell(row: 6, col: 1), letter: 'N', expected: 'N'),
        ],
        puzzle: puzzle,
        board: const {},
        rackStartCount: 6,
      );

      expect(result.rackEmptied, isTrue);
      expect(result.rackEmptyBonus, 6);
    });

    // ── 7a (endgame): a shrunk rack still earns the emptied-rack bonus ───────
    test('emptying a shrunk 3-tile endgame rack grants +3', () {
      // Near the endgame RackManager stops padding the rack from the alphabet,
      // so it can legitimately start a turn with fewer than 5 tiles.
      final puzzle = puzzleFromWords([
        buildWord(id: 'w1', answer: 'KALEM', startRow: 1, startCol: 1, direction: ClueArrow.right),
      ]);

      final result = engine.resolveMove(
        placements: const [
          Placement(cell: WordCell(row: 1, col: 3), letter: 'L', expected: 'L'),
          Placement(cell: WordCell(row: 1, col: 4), letter: 'E', expected: 'E'),
          Placement(cell: WordCell(row: 1, col: 5), letter: 'M', expected: 'M'),
        ],
        puzzle: puzzle,
        board: {const WordCell(row: 1, col: 1): 'K', const WordCell(row: 1, col: 2): 'A'},
        rackStartCount: 3,
      );

      expect(result.rackEmptied, isTrue);
      expect(result.rackEmptyBonus, 3);
    });

    // ── 7b (endgame): a single-tile rack is trivially emptied — no bonus ─────
    test('emptying a 1-tile rack grants no bonus', () {
      final puzzle = puzzleFromWords([
        buildWord(id: 'w1', answer: 'KALEM', startRow: 1, startCol: 1, direction: ClueArrow.right),
      ]);

      final result = engine.resolveMove(
        placements: const [Placement(cell: WordCell(row: 1, col: 5), letter: 'M', expected: 'M')],
        puzzle: puzzle,
        board: {
          const WordCell(row: 1, col: 1): 'K',
          const WordCell(row: 1, col: 2): 'A',
          const WordCell(row: 1, col: 3): 'L',
          const WordCell(row: 1, col: 4): 'E',
        },
        rackStartCount: 1,
      );

      expect(result.rackEmptied, isFalse);
      expect(result.rackEmptyBonus, 0);
    });

    // ── 8 ──────────────────────────────────────────────────────────────────
    test('a wrong letter in the move blocks the emptied-rack bonus', () {
      final puzzle = puzzleFromWords([
        buildWord(id: 'w1', answer: 'KALEM', startRow: 1, startCol: 1, direction: ClueArrow.right),
      ]);

      final result = engine.resolveMove(
        placements: const [
          Placement(cell: WordCell(row: 1, col: 1), letter: 'K', expected: 'K'),
          Placement(cell: WordCell(row: 1, col: 2), letter: 'A', expected: 'A'),
          Placement(cell: WordCell(row: 1, col: 3), letter: 'L', expected: 'L'),
          Placement(cell: WordCell(row: 1, col: 4), letter: 'E', expected: 'E'),
          Placement(cell: WordCell(row: 1, col: 5), letter: 'Z', expected: 'M'),
        ],
        puzzle: puzzle,
        board: const {},
        rackStartCount: 5,
      );

      expect(result.rackEmptied, isFalse);
      expect(result.rackEmptyBonus, 0);
    });

    // ── 9 ──────────────────────────────────────────────────────────────────
    test('word completion and emptied rack stack into scoreDelta', () {
      final puzzle = puzzleFromWords([
        buildWord(id: 'w1', answer: 'KALEM', startRow: 1, startCol: 1, direction: ClueArrow.right),
      ]);

      final result = engine.resolveMove(
        placements: const [
          Placement(cell: WordCell(row: 1, col: 1), letter: 'K', expected: 'K'),
          Placement(cell: WordCell(row: 1, col: 2), letter: 'A', expected: 'A'),
          Placement(cell: WordCell(row: 1, col: 3), letter: 'L', expected: 'L'),
          Placement(cell: WordCell(row: 1, col: 4), letter: 'E', expected: 'E'),
          Placement(cell: WordCell(row: 1, col: 5), letter: 'M', expected: 'M'),
        ],
        puzzle: puzzle,
        board: const {},
        rackStartCount: 5,
      );

      // 5 letters (+5) + word bonus (+5) + rack bonus (+5).
      expect(result.scoreDelta, 15);
      expect(result.completedWordIds, contains('w1'));
      expect(result.rackEmptyBonus, 5);
    });

    // ── 10 ─────────────────────────────────────────────────────────────────
    test('updatedBoard contains only the correct placements', () {
      final puzzle = puzzleFromWords([
        buildWord(id: 'w1', answer: 'MASA', startRow: 1, startCol: 1, direction: ClueArrow.right),
      ]);

      final result = engine.resolveMove(
        placements: const [
          Placement(cell: WordCell(row: 1, col: 1), letter: 'M', expected: 'M'),
          Placement(cell: WordCell(row: 1, col: 2), letter: 'Z', expected: 'A'),
        ],
        puzzle: puzzle,
        board: const {},
        rackStartCount: 5,
      );

      expect(result.updatedBoard.containsKey(const WordCell(row: 1, col: 1)), isTrue);
      expect(result.updatedBoard.containsKey(const WordCell(row: 1, col: 2)), isFalse);
    });
  });
}
