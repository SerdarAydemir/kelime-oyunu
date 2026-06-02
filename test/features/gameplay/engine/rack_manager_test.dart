// test/features/gameplay/engine/rack_manager_test.dart

import 'package:flutter_test/flutter_test.dart';

import 'package:kelime_oyunu/data/models/puzzle.dart';
import 'package:kelime_oyunu/features/gameplay/engine/rack_manager.dart';

// Shared test helpers live under test/ and have no package: path, so a relative
// import is unavoidable here (always_use_package_imports only resolves to lib/).
// ignore: always_use_package_imports
import '../../../helpers/engine_test_fixtures.dart';

// Builds a board where every letter cell of [puzzle] is already solved.
Map<WordCell, String> _fullBoard(PuzzleData puzzle) => {
      for (final cell in puzzle.cells)
        if (cell.type == CellType.letter && cell.solution != null)
          WordCell(row: cell.row, col: cell.col): cell.solution!,
    };

void main() {
  const manager = RackManager();

  // A 7-letter word gives 7 unsolved cells, enough to fill a rack without the
  // alphabet fallback. Solution letters: {K, A, L, E, M, O}.
  PuzzleData wordPuzzle() => puzzleFromWords([
        buildWord(
          id: 'w1',
          answer: 'KALEMOK',
          startRow: 1,
          startCol: 1,
          direction: ClueArrow.right,
        ),
      ]);

  group('RackManager.initialRack', () {
    // ── 1 ──────────────────────────────────────────────────────────────────
    test('produces a rack of the requested size', () {
      final rack = manager.initialRack(
        puzzle: wordPuzzle(),
        board: const {},
        rackSize: RackManager.baseRackSize,
        seed: 1,
      );
      expect(rack.length, 5);
    });

    // ── 2 ──────────────────────────────────────────────────────────────────
    test('draws letters from the unsolved cells when the pool suffices', () {
      final puzzle = wordPuzzle();
      final solutionLetters = puzzle.cells
          .where((c) => c.type == CellType.letter)
          .map((c) => c.solution)
          .toSet();
      final rack = manager.initialRack(
        puzzle: puzzle,
        board: const {},
        rackSize: RackManager.baseRackSize,
        seed: 2,
      );
      expect(rack.every((t) => solutionLetters.contains(t.letter)), isTrue);
    });

    // ── 8 ──────────────────────────────────────────────────────────────────
    test('falls back to the alphabet pool when every cell is solved', () {
      final puzzle = wordPuzzle();
      final rack = manager.initialRack(
        puzzle: puzzle,
        board: _fullBoard(puzzle),
        rackSize: RackManager.baseRackSize,
        seed: 3,
      );
      // No unsolved cells remain, yet the rack is still filled to size.
      expect(rack.length, 5);
    });
  });

  group('RackManager.refill', () {
    // ── 3 ──────────────────────────────────────────────────────────────────
    test('tops the rack back up to baseRackSize', () {
      const playedRack = [
        RackTile(letter: 'K', isPlaced: true),
        RackTile(letter: 'A', isPlaced: true),
        RackTile(letter: 'L', isPlaced: true),
        RackTile(letter: 'E', isPlaced: true),
        RackTile(letter: 'M', isPlaced: true),
      ];
      final rack = manager.refill(
        currentRack: playedRack,
        puzzle: wordPuzzle(),
        board: const {},
        returnedLetters: const [],
        seed: 4,
      );
      expect(rack.length, RackManager.baseRackSize);
    });

    // ── 4 ──────────────────────────────────────────────────────────────────
    test('returned letters are carried over flagged isReturned', () {
      const playedRack = [
        RackTile(letter: 'K', isPlaced: true),
        RackTile(letter: 'A', isPlaced: true),
        RackTile(letter: 'L', isPlaced: true),
        RackTile(letter: 'E', isPlaced: true),
        RackTile(letter: 'M', isPlaced: true),
      ];
      final rack = manager.refill(
        currentRack: playedRack,
        puzzle: wordPuzzle(),
        board: const {},
        returnedLetters: const ['Z'],
        seed: 5,
      );
      expect(rack.length, RackManager.baseRackSize);
      expect(
        rack.any((t) => t.letter == 'Z' && t.isReturned),
        isTrue,
      );
    });

    // ── 9 (Karar 2) ─────────────────────────────────────────────────────────
    test('unplayed tiles survive a refill as clean tiles', () {
      // Puzzle letters {K, Ö, P, R, Ü} deliberately exclude A and B so freshly
      // drawn tiles cannot collide with the unplayed letters under test.
      final puzzle = puzzleFromWords([
        buildWord(
          id: 'w1',
          answer: 'KÖPRÜ',
          startRow: 1,
          startCol: 1,
          direction: ClueArrow.right,
        ),
      ]);
      const currentRack = [
        RackTile(letter: 'A'), // unplayed — must be kept
        RackTile(letter: 'B'), // unplayed — must be kept
        RackTile(letter: 'C', isPlaced: true),
        RackTile(letter: 'D', isPlaced: true),
        RackTile(letter: 'E', isPlaced: true),
      ];
      final rack = manager.refill(
        currentRack: currentRack,
        puzzle: puzzle,
        board: const {},
        returnedLetters: const [],
        seed: 6,
      );
      expect(rack.length, RackManager.baseRackSize);
      // The two unplayed letters are still present and reset to clean state.
      final kept = rack.where((t) => t.letter == 'A' || t.letter == 'B');
      expect(kept.length, 2);
      expect(kept.every((t) => !t.isPlaced && !t.isReturned), isTrue);
    });
  });

  group('RackManager.swapLetters', () {
    // A puzzle whose every unsolved cell is 'B' makes the draw deterministic.
    PuzzleData allBPuzzle() => puzzleFromWords([
          buildWord(
            id: 'w1',
            answer: 'BBBBB',
            startRow: 1,
            startCol: 1,
            direction: ClueArrow.right,
          ),
        ]);

    const aRack = [
      RackTile(letter: 'A'),
      RackTile(letter: 'A'),
      RackTile(letter: 'A'),
      RackTile(letter: 'A'),
      RackTile(letter: 'A'),
    ];

    // ── 5 ──────────────────────────────────────────────────────────────────
    test('replaces the letter at the selected index', () {
      final rack = manager.swapLetters(
        currentRack: aRack,
        swapIndices: const [0],
        puzzle: allBPuzzle(),
        board: const {},
        seed: 7,
      );
      // Drawn from the all-'B' pool, so the swapped tile is now 'B'.
      expect(rack[0].letter, 'B');
      // Untouched indices are unchanged.
      expect(rack[1].letter, 'A');
    });

    // ── 6 ──────────────────────────────────────────────────────────────────
    test('preserves the rack size', () {
      final rack = manager.swapLetters(
        currentRack: aRack,
        swapIndices: const [0, 2, 4],
        puzzle: allBPuzzle(),
        board: const {},
        seed: 8,
      );
      expect(rack.length, aRack.length);
    });
  });

  group('RackManager determinism', () {
    // ── 7 ──────────────────────────────────────────────────────────────────
    test('the same seed yields an identical rack', () {
      final puzzle = wordPuzzle();
      final a = manager.initialRack(
        puzzle: puzzle,
        board: const {},
        rackSize: RackManager.baseRackSize,
        seed: 99,
      );
      final b = manager.initialRack(
        puzzle: puzzle,
        board: const {},
        rackSize: RackManager.baseRackSize,
        seed: 99,
      );
      expect(a, equals(b));
    });
  });
}
