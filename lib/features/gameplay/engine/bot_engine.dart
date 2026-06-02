// lib/features/gameplay/engine/bot_engine.dart

import 'dart:math';

import 'package:equatable/equatable.dart';

import 'package:kelime_oyunu/data/models/puzzle.dart';
import 'package:kelime_oyunu/features/gameplay/engine/score_engine.dart';

// Pure Dart AI opponent (architecture.md §9). No Flutter imports so it stays
// unit-testable. The bot always plays correct letters (§9.3); its difficulty is
// expressed purely through how many cells it fills and which ones.

/// Baseline difficulty tier for a bot, before per-move rubber-banding.
enum DifficultyBand { easy, medium, hard }

/// A bot opponent's identity and baseline difficulty (matchmaking metadata).
class BotProfile extends Equatable {
  const BotProfile({
    required this.id,
    required this.name,
    required this.avatarAsset,
    required this.description,
    required this.difficultyBand,
  });

  final String id;
  final String name;
  final String avatarAsset;
  final String description;
  final DifficultyBand difficultyBand;

  @override
  List<Object?> get props => [id, name, avatarAsset, description, difficultyBand];
}

/// One computed bot turn: the cells it fills plus a humanized display delay.
class BotMove extends Equatable {
  const BotMove({
    required this.placements,
    required this.thinkingDelayMs,
  });

  final List<Placement> placements;

  /// Display-only delay before the move is revealed (2000–5000 ms, §9.5).
  final int thinkingDelayMs;

  @override
  List<Object?> get props => [placements, thinkingDelayMs];
}

/// Computes the bot's move for a turn.
class BotEngine {
  const BotEngine();

  // The score gap beyond which rubber-banding saturates, in points.
  static const int _rubberBandLimit = 30;

  /// Computes the bot's move given the current board and score gap.
  ///
  /// [scoreDiff] is `botScore - playerScore`; a positive gap (bot ahead) pulls
  /// the move count toward the band floor, a negative gap (bot behind) toward
  /// the ceiling (architecture.md §9.4).
  BotMove computeMove({
    required PuzzleData puzzle,
    required Map<WordCell, String> board,
    required int scoreDiff,
    required DifficultyBand difficultyBand,
    required int seed,
  }) {
    final rng = Random(seed);
    final range = _bandRange(difficultyBand);
    final targetCount = _targetCount(range.min, range.max, scoreDiff);

    final solutionByCell = _solutionByCell(puzzle);
    final cells = _prioritizedCells(puzzle, board, targetCount);

    final placements = <Placement>[];
    for (final cell in cells) {
      final solution = solutionByCell[cell];
      // Unreachable: prioritized cells are always letter cells of this puzzle.
      if (solution == null) continue;
      placements.add(
        Placement(cell: cell, letter: solution, expected: solution),
      );
    }

    final thinkingDelayMs = rng.nextInt(3001) + 2000;
    return BotMove(placements: placements, thinkingDelayMs: thinkingDelayMs);
  }

  /// Maps a global puzzle index to its baseline band on a cyclic 20-puzzle ramp.
  ///
  /// Within each block of 20: 0–4 easy, 5–14 medium, 15–19 hard (§9.2).
  static DifficultyBand bandForPuzzleIndex(int puzzleIndex) {
    final phase = puzzleIndex % 20;
    if (phase <= 4) return DifficultyBand.easy;
    if (phase <= 14) return DifficultyBand.medium;
    return DifficultyBand.hard;
  }

  // Min/max cells the bot places, per baseline band.
  ({int min, int max}) _bandRange(DifficultyBand band) => switch (band) {
        DifficultyBand.easy => (min: 1, max: 2),
        DifficultyBand.medium => (min: 2, max: 4),
        DifficultyBand.hard => (min: 3, max: 6),
      };

  // Interpolates a move count inside [min, max] using rubber-banding.
  //
  //   t = (clamp(scoreDiff, -30, 30) + 30) / 60   → 0.0 (behind) .. 1.0 (ahead)
  //   count = min + (max - min) * (1 - t)         → ceiling when behind,
  //                                                  floor when ahead
  int _targetCount(int min, int max, int scoreDiff) {
    final clamped = scoreDiff.clamp(-_rubberBandLimit, _rubberBandLimit);
    final t = (clamped + _rubberBandLimit) / (2 * _rubberBandLimit);
    final raw = min + (max - min) * (1 - t);
    return raw.round().clamp(min, max);
  }

  // Builds a (row,col) -> solution letter lookup for letter cells.
  Map<WordCell, String> _solutionByCell(PuzzleData puzzle) {
    final map = <WordCell, String>{};
    for (final cell in puzzle.cells) {
      if (cell.type != CellType.letter) continue;
      final solution = cell.solution;
      if (solution != null) {
        map[WordCell(row: cell.row, col: cell.col)] = solution;
      }
    }
    return map;
  }

  // Selects up to [count] unsolved cells, preferring words closest to finished
  // (fewest missing cells first), so the bot tends to complete half-done words.
  List<WordCell> _prioritizedCells(
    PuzzleData puzzle,
    Map<WordCell, String> board,
    int count,
  ) {
    final ranked = <({WordSpec word, int missing})>[];
    for (final word in puzzle.words) {
      final missing = word.cells.where((c) => !board.containsKey(c)).length;
      if (missing > 0) ranked.add((word: word, missing: missing));
    }
    ranked.sort((a, b) => a.missing.compareTo(b.missing));

    final selected = <WordCell>[];
    final seen = <WordCell>{};
    for (final entry in ranked) {
      for (final cell in entry.word.cells) {
        if (selected.length >= count) break;
        if (board.containsKey(cell)) continue;
        if (!seen.add(cell)) continue; // skip cells already taken at a crossing
        selected.add(cell);
      }
      if (selected.length >= count) break;
    }
    return selected;
  }
}
