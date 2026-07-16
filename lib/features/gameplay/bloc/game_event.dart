// lib/features/gameplay/bloc/game_event.dart

import 'package:equatable/equatable.dart';

import 'package:kelime_oyunu/data/models/puzzle.dart';
import 'package:kelime_oyunu/features/gameplay/engine/bot_engine.dart';

/// Base type for every gameplay event. Names use the past-tense passive voice:
/// the user action has happened, the bloc reacts (coding-standards.md §3.1).
sealed class GameEvent extends Equatable {
  const GameEvent();

  @override
  List<Object?> get props => [];
}

/// The player opened a puzzle; load it and start a fresh game.
class PuzzleLoadRequested extends GameEvent {
  const PuzzleLoadRequested(this.puzzleId);

  final int puzzleId;

  @override
  List<Object?> get props => [puzzleId];
}

/// The player chose to continue the half-played match on [levelId].
///
/// Falls back to a fresh game if there is no saved match, or if the saved one
/// belongs to a different level.
class SessionResumeRequested extends GameEvent {
  const SessionResumeRequested(this.levelId);

  final int levelId;

  @override
  List<Object?> get props => [levelId];
}

/// The app is going to the background; write the match down now.
class SessionFlushRequested extends GameEvent {
  const SessionFlushRequested();
}

/// The player dropped the rack tile at [rackIndex] onto [cell].
class LetterPlaced extends GameEvent {
  const LetterPlaced({required this.rackIndex, required this.cell});

  final int rackIndex;
  final WordCell cell;

  @override
  List<Object?> get props => [rackIndex, cell];
}

/// The player took a pending letter back off [cell].
class LetterRecalled extends GameEvent {
  const LetterRecalled(this.cell);

  final WordCell cell;

  @override
  List<Object?> get props => [cell];
}

/// The player confirmed their move; resolve scoring and hand the turn to the bot.
class MoveConfirmed extends GameEvent {
  const MoveConfirmed();
}

/// The player passed without placing anything; hand the turn to the bot.
class MovePassed extends GameEvent {
  const MovePassed();
}

/// The bot's move finished computing and its humanized delay elapsed.
class BotMoveCompleted extends GameEvent {
  const BotMoveCompleted(this.botMove);

  final BotMove botMove;

  @override
  List<Object?> get props => [botMove];
}

/// The player swapped the rack tiles at [swapIndices].
///
/// [viaAd] true: the swap was paid for with a rewarded ad and the turn stays
/// with the player. false: the swap is free but consumes the turn (§1.5).
class LettersSwapped extends GameEvent {
  const LettersSwapped(this.swapIndices, {this.viaAd = false});

  final List<int> swapIndices;
  final bool viaAd;

  @override
  List<Object?> get props => [swapIndices, viaAd];
}

/// The player spent a hint to reveal the whole word [wordId] (after an ad).
class WordRevealed extends GameEvent {
  const WordRevealed(this.wordId);

  final String wordId;

  @override
  List<Object?> get props => [wordId];
}

/// The player unlocked the sixth rack slot (after a rewarded ad).
class SixthSlotUnlocked extends GameEvent {
  const SixthSlotUnlocked();
}

/// The player tapped a rack tile to select it for placement.
/// [rackIndex] == -1 clears the current selection.
class RackTileSelected extends GameEvent {
  const RackTileSelected(this.rackIndex);

  final int rackIndex;

  @override
  List<Object?> get props => [rackIndex];
}
