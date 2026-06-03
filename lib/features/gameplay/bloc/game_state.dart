// lib/features/gameplay/bloc/game_state.dart

import 'package:equatable/equatable.dart';

import 'package:kelime_oyunu/data/models/puzzle.dart';
import 'package:kelime_oyunu/features/gameplay/engine/rack_manager.dart';
import 'package:kelime_oyunu/features/gameplay/engine/score_engine.dart';

/// Whose turn it is, or whether the game is over.
enum TurnPhase { playerTurn, botThinking, finished }

/// The terminal outcome of the match (a tie counts as a loss, per spec §1.4).
enum GameStatus { playing, won, lost }

/// Base type for every gameplay state.
sealed class GameState extends Equatable {
  const GameState();

  @override
  List<Object?> get props => [];
}

/// Before any puzzle has been requested.
class GameInitial extends GameState {
  const GameInitial();
}

/// While the puzzle assets are loading.
class GameLoading extends GameState {
  const GameLoading();
}

/// A recoverable failure (e.g. the puzzle was not found).
class GameError extends GameState {
  const GameError(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}

/// The live game state during play and at the finish.
class GameActive extends GameState {
  const GameActive({
    required this.puzzle,
    required this.board,
    required this.rack,
    required this.pendingPlacements,
    required this.playerScore,
    required this.botScore,
    required this.phase,
    required this.botThinking,
    required this.status,
    required this.rackSize,
    required this.revealedWordIds,
    this.highlightedWordId,
    this.selectedRackIndex = -1,
  });

  final PuzzleData puzzle;

  /// Committed letters keyed by cell: solved + revealed cells.
  final Map<WordCell, String> board;

  /// The player's current rack.
  final List<RackTile> rack;

  /// Letters placed this turn but not yet confirmed.
  final List<Placement> pendingPlacements;

  final int playerScore;
  final int botScore;
  final TurnPhase phase;
  final bool botThinking;

  /// The word currently highlighted on the board, if any.
  final String? highlightedWordId;

  final GameStatus status;

  /// Current rack capacity: 5, or 6 after the sixth slot is unlocked.
  final int rackSize;

  /// IDs of words the player revealed with a hint.
  final Set<String> revealedWordIds;

  /// Index of the rack tile the player has tapped but not yet placed.
  /// -1 means no tile is currently selected (sentinel — avoids nullable copyWith ambiguity).
  final int selectedRackIndex;

  GameActive copyWith({
    PuzzleData? puzzle,
    Map<WordCell, String>? board,
    List<RackTile>? rack,
    List<Placement>? pendingPlacements,
    int? playerScore,
    int? botScore,
    TurnPhase? phase,
    bool? botThinking,
    String? highlightedWordId,
    GameStatus? status,
    int? rackSize,
    Set<String>? revealedWordIds,
    int? selectedRackIndex,
  }) {
    return GameActive(
      puzzle: puzzle ?? this.puzzle,
      board: board ?? this.board,
      rack: rack ?? this.rack,
      pendingPlacements: pendingPlacements ?? this.pendingPlacements,
      playerScore: playerScore ?? this.playerScore,
      botScore: botScore ?? this.botScore,
      phase: phase ?? this.phase,
      botThinking: botThinking ?? this.botThinking,
      highlightedWordId: highlightedWordId ?? this.highlightedWordId,
      status: status ?? this.status,
      rackSize: rackSize ?? this.rackSize,
      revealedWordIds: revealedWordIds ?? this.revealedWordIds,
      selectedRackIndex: selectedRackIndex ?? this.selectedRackIndex,
    );
  }

  @override
  List<Object?> get props => [
        puzzle,
        board,
        rack,
        pendingPlacements,
        playerScore,
        botScore,
        phase,
        botThinking,
        highlightedWordId,
        status,
        rackSize,
        revealedWordIds,
        selectedRackIndex,
      ];
}
