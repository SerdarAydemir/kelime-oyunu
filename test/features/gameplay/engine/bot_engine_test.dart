// test/features/gameplay/engine/bot_engine_test.dart

import 'package:flutter_test/flutter_test.dart';

import 'package:kelime_oyunu/data/models/puzzle.dart';
import 'package:kelime_oyunu/features/gameplay/engine/bot_engine.dart';

// Shared test helpers live under test/ and have no package: path, so a relative
// import is unavoidable here (always_use_package_imports only resolves to lib/).
// ignore: always_use_package_imports
import '../../../helpers/engine_test_fixtures.dart';

void main() {
  const bot = BotEngine();

  // A 7-cell down word gives plenty of unsolved cells for count assertions.
  PuzzleData longPuzzle() => puzzleFromWords([
    buildWord(id: 'w1', answer: 'KİTAPÇI', startRow: 1, startCol: 1, direction: ClueArrow.down),
  ]);

  // Two disjoint down words, each carrying exactly one O -> two empty O cells.
  PuzzleData twoOPuzzle() => puzzleFromWords([
    buildWord(id: 'kol', answer: 'KOL', startRow: 1, startCol: 1, direction: ClueArrow.down),
    buildWord(id: 'top', answer: 'TOP', startRow: 1, startCol: 3, direction: ClueArrow.down),
  ]);

  // A single down word "KOL" -> exactly one empty O cell.
  PuzzleData oneOPuzzle() => puzzleFromWords([
    buildWord(id: 'kol', answer: 'KOL', startRow: 1, startCol: 1, direction: ClueArrow.down),
  ]);

  group('BotEngine.computeMove move count', () {
    // ── 1 ──────────────────────────────────────────────────────────────────
    test('easy band at a tied score places at most 2 cells', () {
      final move = bot.computeMove(
        puzzle: longPuzzle(),
        board: const {},
        scoreDiff: 0,
        difficultyBand: DifficultyBand.easy,
        seed: 1,
      );
      expect(move.placements.length, lessThanOrEqualTo(2));
    });

    // ── 2 ──────────────────────────────────────────────────────────────────
    test('hard band at a tied score places at least 3 cells', () {
      final move = bot.computeMove(
        puzzle: longPuzzle(),
        board: const {},
        scoreDiff: 0,
        difficultyBand: DifficultyBand.hard,
        seed: 2,
      );
      expect(move.placements.length, greaterThanOrEqualTo(3));
    });

    // ── 3 ──────────────────────────────────────────────────────────────────
    test('a big lead pulls an easy bot down to the floor (1 cell)', () {
      final move = bot.computeMove(
        puzzle: longPuzzle(),
        board: const {},
        scoreDiff: 50, // bot well ahead
        difficultyBand: DifficultyBand.easy,
        seed: 3,
      );
      expect(move.placements.length, 1);
    });

    // ── 4 ──────────────────────────────────────────────────────────────────
    test('a big deficit pushes a hard bot to the ceiling (6 cells)', () {
      final move = bot.computeMove(
        puzzle: longPuzzle(),
        board: const {},
        scoreDiff: -50, // bot well behind
        difficultyBand: DifficultyBand.hard,
        seed: 4,
      );
      expect(move.placements.length, 6);
    });
  });

  group('BotEngine.computeMove placement quality', () {
    // ── 5 ──────────────────────────────────────────────────────────────────
    test('every placement the bot makes is correct', () {
      final move = bot.computeMove(
        puzzle: longPuzzle(),
        board: const {},
        scoreDiff: 0,
        difficultyBand: DifficultyBand.hard,
        seed: 5,
      );
      expect(move.placements.every((p) => p.isCorrect), isTrue);
    });

    // ── 6 ──────────────────────────────────────────────────────────────────
    test('the near-complete word is finished before others are touched', () {
      // Word A "TAS" has 1 missing cell; word B "MASA" has 3. An easy bot with
      // a big lead places exactly 1 cell — it must be A's missing cell.
      final puzzle = puzzleFromWords([
        buildWord(id: 'a', answer: 'TAS', startRow: 1, startCol: 1, direction: ClueArrow.right),
        buildWord(id: 'b', answer: 'MASA', startRow: 3, startCol: 1, direction: ClueArrow.right),
      ]);
      // Not const: WordCell overrides ==, so it cannot be a const map key.
      final board = <WordCell, String>{
        const WordCell(row: 1, col: 1): 'T', // word A solved cells
        const WordCell(row: 1, col: 2): 'A',
        const WordCell(row: 3, col: 1): 'M', // word B: only 1 solved -> 3 missing
      };

      final move = bot.computeMove(
        puzzle: puzzle,
        board: board,
        scoreDiff: 50,
        difficultyBand: DifficultyBand.easy,
        seed: 6,
      );

      expect(move.placements.length, 1);
      // The only missing cell of word A is (1, 3).
      expect(move.placements.first.cell, const WordCell(row: 1, col: 3));
    });
  });

  group('BotEngine.computeMove letter reservations', () {
    int letterCount(BotMove move, String letter) =>
        move.placements.where((p) => p.letter == letter).length;

    // ── 9 ──────────────────────────────────────────────────────────────────
    // 1 O held, 2 empty O cells -> quota 1 -> the bot takes exactly one O and
    // leaves the other for the player. A ceiling move (hard, big deficit) wants
    // every cell, so the single O is the reservation biting, not a low count.
    test('holding one O leaves one of two O cells for the player', () {
      final move = bot.computeMove(
        puzzle: twoOPuzzle(),
        board: const {},
        scoreDiff: -50,
        difficultyBand: DifficultyBand.hard,
        seed: 10,
        reservedLetters: const {'O': 1},
      );
      expect(letterCount(move, 'O'), 1);
    });

    // ── 10 ─────────────────────────────────────────────────────────────────
    // 1 O held, only 1 empty O cell -> quota 0 -> the bot skips the O entirely
    // while still playing the other letters.
    test('holding the only O keeps the bot off that cell', () {
      final move = bot.computeMove(
        puzzle: oneOPuzzle(),
        board: const {},
        scoreDiff: -50,
        difficultyBand: DifficultyBand.hard,
        seed: 11,
        reservedLetters: const {'O': 1},
      );
      expect(letterCount(move, 'O'), 0);
      expect(move.placements.map((p) => p.letter), containsAll(['K', 'L']));
    });

    // ── 11 ─────────────────────────────────────────────────────────────────
    // Holding more O than exist clamps the quota at 0 (max(0, ...)): no negative
    // quota, no crash — the defensive clamp.
    test('holding more copies than cells clamps the quota at zero', () {
      final move = bot.computeMove(
        puzzle: oneOPuzzle(),
        board: const {},
        scoreDiff: -50,
        difficultyBand: DifficultyBand.hard,
        seed: 12,
        reservedLetters: const {'O': 3},
      );
      expect(letterCount(move, 'O'), 0);
    });

    // ── 12 ─────────────────────────────────────────────────────────────────
    // Every letter reserved -> no cell is available -> the bot passes.
    test('a fully reserved board yields an empty (passing) move', () {
      final move = bot.computeMove(
        puzzle: oneOPuzzle(),
        board: const {},
        scoreDiff: -50,
        difficultyBand: DifficultyBand.hard,
        seed: 13,
        reservedLetters: const {'K': 1, 'O': 1, 'L': 1},
      );
      expect(move.placements, isEmpty);
    });

    // ── 13 ─────────────────────────────────────────────────────────────────
    // The stalemate escape hatch ignores the reservations and fills anyway.
    test('ignoreReservations fills despite a fully reserved board', () {
      final move = bot.computeMove(
        puzzle: oneOPuzzle(),
        board: const {},
        scoreDiff: -50,
        difficultyBand: DifficultyBand.hard,
        seed: 14,
        reservedLetters: const {'K': 1, 'O': 1, 'L': 1},
        ignoreReservations: true,
      );
      expect(move.placements, isNotEmpty);
    });
  });

  group('BotEngine.bandForPuzzleIndex', () {
    // ── 7 ──────────────────────────────────────────────────────────────────
    test('maps indices to bands on a cyclic 20-puzzle ramp', () {
      expect(BotEngine.bandForPuzzleIndex(0), DifficultyBand.easy);
      expect(BotEngine.bandForPuzzleIndex(5), DifficultyBand.medium);
      expect(BotEngine.bandForPuzzleIndex(15), DifficultyBand.hard);
      expect(BotEngine.bandForPuzzleIndex(19), DifficultyBand.hard);
      expect(BotEngine.bandForPuzzleIndex(20), DifficultyBand.easy);
    });
  });

  group('BotEngine.computeMove timing', () {
    // ── 8 ──────────────────────────────────────────────────────────────────
    test('thinking delay stays within the 2000-5000 ms window', () {
      final move = bot.computeMove(
        puzzle: longPuzzle(),
        board: const {},
        scoreDiff: 0,
        difficultyBand: DifficultyBand.medium,
        seed: 7,
      );
      expect(move.thinkingDelayMs, inInclusiveRange(2000, 5000));
    });
  });
}
