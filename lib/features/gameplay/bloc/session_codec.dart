// lib/features/gameplay/bloc/session_codec.dart

import 'package:kelime_oyunu/data/models/puzzle.dart';
import 'package:kelime_oyunu/data/models/saved_session.dart';
import 'package:kelime_oyunu/features/gameplay/bloc/game_state.dart';
import 'package:kelime_oyunu/features/gameplay/engine/rack_manager.dart';

// Pure mapping between the live [GameActive] and the persisted [SavedSession]
// (F7 plan §K5). Kept out of the bloc so the round-trip is testable without
// Hive, a bloc, or a binding.

/// Snapshots [state] for persistence.
SavedSession sessionFromState(GameActive state) => SavedSession(
  levelId: state.puzzle.puzzleId,
  board: Map<WordCell, String>.unmodifiable(state.board),
  rackLetters: [for (final tile in state.rack) tile.letter],
  playerScore: state.playerScore,
  botScore: state.botScore,
  rackSize: state.rackSize,
  revealedWordIds: Set<String>.unmodifiable(state.revealedWordIds),
  swapQuotaRemaining: state.swapQuotaRemaining,
  botPlacedCells: Set<WordCell>.unmodifiable(state.botPlacedCells),
);

/// Rebuilds a playable state from [session] against the freshly loaded [puzzle].
///
/// The resume always lands on a clean player turn: no pending placements, no
/// selection, nothing narrating (F6 state is never persisted). Scores, board,
/// rack and the spent jokers are exactly what the player left behind.
GameActive stateFromSession(SavedSession session, PuzzleData puzzle) => GameActive(
  puzzle: puzzle,
  board: session.board,
  rack: [for (final letter in session.rackLetters) RackTile(letter: letter)],
  pendingPlacements: const [],
  playerScore: session.playerScore,
  botScore: session.botScore,
  phase: TurnPhase.playerTurn,
  botThinking: false,
  status: GameStatus.playing,
  rackSize: session.rackSize,
  revealedWordIds: session.revealedWordIds,
  botPlacedCells: session.botPlacedCells,
  swapQuotaRemaining: session.swapQuotaRemaining,
);
