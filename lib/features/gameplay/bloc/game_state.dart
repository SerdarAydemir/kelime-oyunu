// lib/features/gameplay/bloc/game_state.dart

import 'package:equatable/equatable.dart';

import 'package:kelime_oyunu/data/models/puzzle.dart';
import 'package:kelime_oyunu/features/gameplay/bloc/move_narration.dart';
import 'package:kelime_oyunu/features/gameplay/engine/rack_manager.dart';
import 'package:kelime_oyunu/features/gameplay/engine/score_engine.dart';

/// Whose turn it is, or whether the game is over.
enum TurnPhase { playerTurn, botThinking, finished }

/// The terminal outcome of the match. A tie is its own first-class outcome on
/// the result screen (product decision). Any F7 progression rule that scores a
/// tie differently (e.g. for win-rate) is a separate decision and does not
/// change this enum.
enum GameStatus { playing, won, lost, tie }

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
    this.selectedRackIndex = -1,
    this.botPlacedCells = const {},
    this.swapQuotaRemaining = swapQuotaPerMatch,
    this.narration,
  });

  /// Total letters the player may swap over one match (swap joker budget).
  static const int swapQuotaPerMatch = 12;

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

  final GameStatus status;

  /// Current rack capacity: 5, or 6 after the sixth slot is unlocked.
  final int rackSize;

  /// IDs of words the player revealed with a hint.
  final Set<String> revealedWordIds;

  /// Index of the rack tile the player has tapped but not yet placed.
  /// -1 means no tile is currently selected (sentinel — avoids nullable copyWith ambiguity).
  final int selectedRackIndex;

  /// Cells where the bot placed letters (persisted across turns for visual feedback).
  final Set<WordCell> botPlacedCells;

  /// Letters the player may still swap this match (each swapped letter costs 1).
  final int swapQuotaRemaining;

  /// The move that just resolved, tagged for the UI narration layer to replay
  /// as an animated score story. Null before any move; the widget layer dedupes
  /// by [MoveNarration.id] so a lingering value never replays (game_state owns
  /// no timing — see move_narration.dart). Preserved across copyWith by default.
  final MoveNarration? narration;

  GameActive copyWith({
    PuzzleData? puzzle,
    Map<WordCell, String>? board,
    List<RackTile>? rack,
    List<Placement>? pendingPlacements,
    int? playerScore,
    int? botScore,
    TurnPhase? phase,
    bool? botThinking,
    GameStatus? status,
    int? rackSize,
    Set<String>? revealedWordIds,
    int? selectedRackIndex,
    Set<WordCell>? botPlacedCells,
    int? swapQuotaRemaining,
    MoveNarration? narration,
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
      status: status ?? this.status,
      rackSize: rackSize ?? this.rackSize,
      revealedWordIds: revealedWordIds ?? this.revealedWordIds,
      selectedRackIndex: selectedRackIndex ?? this.selectedRackIndex,
      botPlacedCells: botPlacedCells ?? this.botPlacedCells,
      swapQuotaRemaining: swapQuotaRemaining ?? this.swapQuotaRemaining,
      // Preserve by default: a resolved move sets it once, the botThinking
      // copy carries it through, and the next resolve replaces it. Never
      // cleared to null (no gameplay path needs an un-narrated GameActive).
      narration: narration ?? this.narration,
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
    status,
    rackSize,
    revealedWordIds,
    selectedRackIndex,
    botPlacedCells,
    swapQuotaRemaining,
    narration,
  ];
}
