// lib/features/gameplay/bloc/game_bloc_jokers.dart

part of 'package:kelime_oyunu/features/gameplay/bloc/game_bloc.dart';

/// Paid helpers: letter swap, word reveal and the sixth rack slot. Private
/// extension — same library as [GameBloc].
extension _JokerHandlers on GameBloc {
  Future<void> _onLettersSwapped(LettersSwapped event, Emitter<GameState> emit) async {
    final current = state;
    if (current is! GameActive) return;
    // Each swapped letter costs 1 from the per-match quota (12).
    final count = event.swapIndices.toSet().length;
    if (count == 0 || count > current.swapQuotaRemaining) {
      debugPrint('Rejected swap: quota ${current.swapQuotaRemaining}, asked $count');
      return;
    }
    final rack = _rackManager.swapLetters(
      currentRack: current.rack,
      swapIndices: event.swapIndices,
      puzzle: current.puzzle,
      board: current.board,
      seed: _nextSeed(),
    );
    final next = current.copyWith(
      rack: rack,
      swapQuotaRemaining: current.swapQuotaRemaining - count,
    );
    // Ad-paid swap keeps the turn; the free swap costs it (§1.5).
    if (event.viaAd) {
      // Still the player's turn, but the quota is spent — persist it so a
      // restart cannot hand the jokers back.
      await _emitAndSave(next, emit);
      return;
    }
    await _runBotTurn(next, emit);
  }

  Future<void> _onWordRevealed(WordRevealed event, Emitter<GameState> emit) async {
    final current = state;
    if (current is! GameActive) return;
    if (!current.puzzle.words.any((w) => w.id == event.wordId)) return;
    // Reveal SHOWS the word as a ghost (the painter draws the solution faintly
    // on still-empty, playable cells); it does NOT commit letters to the board.
    // The player still places real tiles to score, so the board can only be
    // completed — and the game finished — through a real move (§1.5).
    // Persisted: a revealed word is a spent joker, it must stay revealed.
    await _emitAndSave(
      current.copyWith(revealedWordIds: {...current.revealedWordIds, event.wordId}),
      emit,
    );
  }

  Future<void> _onSixthSlotUnlocked(SixthSlotUnlocked event, Emitter<GameState> emit) async {
    final current = state;
    if (current is! GameActive) return;
    if (current.rackSize >= RackManager.powerUpRackSize) return;
    final extra = _rackManager.initialRack(
      puzzle: current.puzzle,
      board: current.board,
      rackSize: 1,
      seed: _nextSeed(),
    );
    // Persisted: the slot was paid for, a restart must not take it back.
    await _emitAndSave(
      current.copyWith(rack: [...current.rack, ...extra], rackSize: RackManager.powerUpRackSize),
      emit,
    );
  }
}
