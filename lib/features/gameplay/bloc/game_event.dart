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

/// The player tapped a clue/word to highlight it on the board.
class WordSelected extends GameEvent {
  const WordSelected(this.wordId);

  final String wordId;

  @override
  List<Object?> get props => [wordId];
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

/// The player swapped the rack tiles at [swapIndices] (after a rewarded ad).
class LettersSwapped extends GameEvent {
  const LettersSwapped(this.swapIndices);

  final List<int> swapIndices;

  @override
  List<Object?> get props => [swapIndices];
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
