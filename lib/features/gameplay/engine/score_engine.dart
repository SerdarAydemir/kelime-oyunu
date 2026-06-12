// lib/features/gameplay/engine/score_engine.dart

import 'package:equatable/equatable.dart';

import 'package:kelime_oyunu/data/models/puzzle.dart';

// Pure Dart scoring engine (architecture.md §8.2). No Flutter imports so it can
// be unit-tested in isolation. Immutability is enforced via `const`
// constructors, `final` fields, and Equatable value semantics; the @immutable
// annotation is intentionally omitted to keep this file Flutter-import-free.

/// A single letter a player dropped onto one grid cell during a turn.
class Placement extends Equatable {
  const Placement({
    required this.cell,
    required this.letter,
    required this.expected,
  });

  final WordCell cell;

  /// The letter the player actually placed.
  final String letter;

  /// The correct solution letter for [cell].
  final String expected;

  /// Whether the placed [letter] matches the [expected] solution.
  bool get isCorrect => letter == expected;

  @override
  List<Object?> get props => [cell, letter, expected];
}

/// One scoring outcome produced by resolving a move.
///
/// [cell] is null for game-level bonuses (word completion, rack emptied) that
/// do not belong to a single cell; it is non-null for per-letter +1 / -1 events.
class ScoreEvent extends Equatable {
  const ScoreEvent({
    required this.delta,
    this.cell,
    this.completedWordId,
    this.wordBonus,
  });

  /// The cell this event animates over, or null for game-level bonuses.
  final WordCell? cell;

  /// Signed point change carried by this event.
  final int delta;

  /// ID of the word completed by this event, or null.
  final String? completedWordId;

  /// Completion bonus amount (equals word length), or null.
  final int? wordBonus;

  @override
  List<Object?> get props => [cell, delta, completedWordId, wordBonus];
}

/// The full result of resolving one confirmed move.
class MoveResult extends Equatable {
  const MoveResult({
    required this.placements,
    required this.events,
    required this.scoreDelta,
    required this.updatedBoard,
    required this.returnedLetters,
    required this.completedWordIds,
    required this.rackEmptied,
    required this.rackEmptyBonus,
  });

  /// The placements that were resolved (input echo, for the caller).
  final List<Placement> placements;

  /// Ordered scoring events, suitable for driving per-cell animations.
  final List<ScoreEvent> events;

  /// Net point change for the whole move (letters + all bonuses).
  final int scoreDelta;

  /// The board after applying only the correct placements.
  final Map<WordCell, String> updatedBoard;

  /// Letters that were wrong and must return to the rack. The engine does not
  /// manage the rack; the caller forwards these to RackManager.refill.
  final List<String> returnedLetters;

  /// IDs of words newly completed by this move.
  final List<String> completedWordIds;

  /// Whether the player emptied their rack with all-correct placements.
  final bool rackEmptied;

  /// Rack-empty bonus (+5 or +6), or 0 when the rack was not emptied.
  final int rackEmptyBonus;

  @override
  List<Object?> get props => [
        placements,
        events,
        scoreDelta,
        updatedBoard,
        returnedLetters,
        completedWordIds,
        rackEmptied,
        rackEmptyBonus,
      ];
}

/// Resolves a confirmed move into scores, events, and the next board state.
class ScoreEngine {
  const ScoreEngine();

  // Rack sizes that qualify for the "emptied rack" bonus (architecture.md §1.4):
  // nominally 5/6, but the rack shrinks below 5 near the endgame (RackManager
  // stops padding from the alphabet once unsolved cells run short), so any rack
  // of 2..6 tiles qualifies. A 1-tile rack is excluded as trivially emptied.
  static const int _minBonusRackSize = 2;
  static const int _powerUpRackSize = 6;

  /// Resolves [placements] against [puzzle] and the current [board].
  ///
  /// [rackStartCount] is the rack size at the start of the turn (nominally 5
  /// or 6, smaller near the endgame); it is used to detect an emptied rack.
  /// Scoring rules follow architecture.md §1.4.
  MoveResult resolveMove({
    required List<Placement> placements,
    required PuzzleData puzzle,
    required Map<WordCell, String> board,
    required int rackStartCount,
  }) {
    final events = <ScoreEvent>[];
    final returnedLetters = <String>[];
    final updatedBoard = Map<WordCell, String>.of(board);
    final newlyFilled = <WordCell>{};
    var scoreDelta = 0;

    // 1. Per-letter scoring: correct +1 (committed to board), wrong -1 (returned).
    for (final placement in placements) {
      if (placement.isCorrect) {
        updatedBoard[placement.cell] = placement.letter;
        newlyFilled.add(placement.cell);
        scoreDelta += 1;
        events.add(ScoreEvent(cell: placement.cell, delta: 1));
      } else {
        returnedLetters.add(placement.letter);
        scoreDelta -= 1;
        events.add(ScoreEvent(cell: placement.cell, delta: -1));
      }
    }

    // 2. Word-completion bonus, only for words newly completed this turn.
    final completedWordIds = <String>[];
    for (final word in puzzle.words) {
      final allFilled = word.cells.every(updatedBoard.containsKey);
      if (!allFilled) continue;
      final completedThisTurn = word.cells.any(newlyFilled.contains);
      if (!completedThisTurn) continue;
      completedWordIds.add(word.id);
      scoreDelta += word.length;
      events.add(
        ScoreEvent(
          delta: word.length,
          completedWordId: word.id,
          wordBonus: word.length,
        ),
      );
    }

    // 3. Emptied-rack bonus: every placement correct and the whole rack played.
    //    The bonus equals the rack size, so a shrunk endgame rack still rewards
    //    emptying — just proportionally less (+2..+4 instead of +5/+6).
    var rackEmptied = false;
    var rackEmptyBonus = 0;
    final allCorrect = placements.isNotEmpty && returnedLetters.isEmpty;
    final playedWholeRack = rackStartCount == placements.length;
    final qualifyingSize =
        rackStartCount >= _minBonusRackSize && rackStartCount <= _powerUpRackSize;
    if (allCorrect && playedWholeRack && qualifyingSize) {
      rackEmptied = true;
      rackEmptyBonus = rackStartCount;
      scoreDelta += rackEmptyBonus;
      events.add(ScoreEvent(delta: rackEmptyBonus));
    }

    return MoveResult(
      placements: placements,
      events: events,
      scoreDelta: scoreDelta,
      updatedBoard: updatedBoard,
      returnedLetters: returnedLetters,
      completedWordIds: completedWordIds,
      rackEmptied: rackEmptied,
      rackEmptyBonus: rackEmptyBonus,
    );
  }
}
