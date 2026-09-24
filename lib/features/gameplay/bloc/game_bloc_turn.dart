// lib/features/gameplay/bloc/game_bloc_turn.dart

part of 'package:kelime_oyunu/features/gameplay/bloc/game_bloc.dart';

/// The turn cycle: pending placements, move confirmation, the bot's reply and
/// the deferred refill. Private extension — same library as [GameBloc].
extension _TurnHandlers on GameBloc {
  void _onLetterPlaced(LetterPlaced event, Emitter<GameState> emit) {
    final current = state;
    if (current is! GameActive) return;
    // Reject invalid targets: clue/blank cells and already-committed cells.
    // Defence in depth — the UI also filters these (game_screen._onCellTap).
    final isLetterCell = current.puzzle.cells.any(
      (c) => c.type == CellType.letter && c.row == event.cell.row && c.col == event.cell.col,
    );
    if (!isLetterCell || current.board.containsKey(event.cell)) {
      debugPrint('Rejected placement on invalid cell: ${event.cell}');
      return;
    }
    // The rack can shrink between turns (endgame refill / dead-tile refresh),
    // so a selection index captured before the rebuild may be stale.
    if (event.rackIndex < 0 || event.rackIndex >= current.rack.length) {
      debugPrint('Rejected placement from stale rack index: ${event.rackIndex}');
      return;
    }
    final tile = current.rack[event.rackIndex];
    final placement = Placement(
      cell: event.cell,
      letter: tile.letter,
      expected: _solutionByCell[event.cell] ?? '',
      rackIndex: event.rackIndex,
    );
    // Replace any existing pending letter on the same cell (no duplicates).
    final pending = <Placement>[
      for (final p in current.pendingPlacements)
        if (p.cell != event.cell) p,
      placement,
    ];
    emit(
      current.copyWith(pendingPlacements: pending, rack: markPlacedTiles(current.rack, pending)),
    );
  }

  void _onLetterRecalled(LetterRecalled event, Emitter<GameState> emit) {
    final current = state;
    if (current is! GameActive) return;
    final pending = <Placement>[
      for (final p in current.pendingPlacements)
        if (p.cell != event.cell) p,
    ];
    emit(
      current.copyWith(pendingPlacements: pending, rack: markPlacedTiles(current.rack, pending)),
    );
  }

  Future<void> _onMoveConfirmed(MoveConfirmed event, Emitter<GameState> emit) async {
    final current = state;
    if (current is! GameActive) return;
    final result = _scoreEngine.resolveMove(
      placements: current.pendingPlacements,
      puzzle: current.puzzle,
      board: current.board,
      // Real tile count, not the nominal capacity: the rack shrinks near the
      // endgame and emptying it must still earn the bonus (ScoreEngine §1.4).
      rackStartCount: current.rack.length,
    );
    final newBoard = result.updatedBoard;
    // No refill here: the rack stays spent-looking while the exchange plays
    // out, and _onBotMoveCompleted deals the new letters (with any returned
    // wrong ones) after the bot's move — so fresh tiles arrive last (F6).
    _refillPending = true;
    _deferredReturns = result.returnedLetters;
    final afterMove = current.copyWith(
      board: newBoard,
      pendingPlacements: const [],
      playerScore: current.playerScore + result.scoreDelta,
      playerWordsFound: current.playerWordsFound + result.completedWordIds.length,
      selectedRackIndex: -1, // placed tiles are gone — drop the index
      narration: MoveNarration(
        id: _narrationSeq++,
        actor: NarrationActor.player,
        events: result.events,
        placements: result.placements,
      ),
    );
    if (isBoardComplete(current.puzzle, newBoard)) {
      emit(await _finish(afterMove));
      return;
    }
    await _runBotTurn(afterMove, emit);
  }

  Future<void> _onMovePassed(MovePassed event, Emitter<GameState> emit) async {
    final current = state;
    if (current is! GameActive) return;
    await _runBotTurn(current, emit);
  }

  Future<void> _onBotMoveCompleted(BotMoveCompleted event, Emitter<GameState> emit) async {
    final current = state;
    if (current is! GameActive) return;
    // The bot has no rack, so rackStartCount: 0 disables the empty-rack bonus;
    // it still earns +1 per letter and any word-completion bonus (§9.3).
    final result = _scoreEngine.resolveMove(
      placements: event.botMove.placements,
      puzzle: current.puzzle,
      board: current.board,
      rackStartCount: 0,
    );
    final newBoard = result.updatedBoard;
    // Stalemate accounting: this is the end of a full turn (the player already
    // moved before the bot). If the committed-cell total did not grow across the
    // whole turn, the board stalled; otherwise reset. See _stallLimit above.
    if (newBoard.length > _lastTurnBoardCount) {
      _stallCount = 0;
    } else {
      _stallCount++;
    }
    _lastTurnBoardCount = newBoard.length;
    // Clear transient flags (Karar 2/3) from the previous turn, then deal the
    // DEFERRED refill (queued by _onMoveConfirmed): new letters and returned
    // wrong ones arrive only now, after the bot has played (F6). Refilling
    // against the post-bot board also makes the demand-aware deal sharper.
    final resetRack = [for (final t in current.rack) RackTile(letter: t.letter)];
    final dealtRack = _refillPending
        ? _rackManager.refill(
            currentRack: resetRack,
            puzzle: current.puzzle,
            board: newBoard,
            returnedLetters: _deferredReturns,
            seed: _nextSeed(),
            targetSize: current.rackSize,
          )
        : resetRack;
    _refillPending = false;
    _deferredReturns = const [];
    // Refresh every tile the bot's move just killed: deadness is permanent
    // (the board only fills up), so the player never starts a turn stuck.
    final playableRack = _rackManager.ensurePlayable(
      currentRack: dealtRack,
      puzzle: current.puzzle,
      board: newBoard,
      seed: _nextSeed(),
    );
    if (!identical(playableRack, dealtRack)) {
      debugPrint('Dead rack tiles refreshed after bot move.');
    }
    final afterBot = current.copyWith(
      board: newBoard,
      botScore: current.botScore + result.scoreDelta,
      rack: playableRack,
      phase: TurnPhase.playerTurn,
      botThinking: false,
      botPlacedCells: {...current.botPlacedCells, ...event.botMove.placements.map((p) => p.cell)},
      selectedRackIndex: -1, // tiles may have been replaced/dropped — drop the index
      narration: MoveNarration(
        id: _narrationSeq++,
        actor: NarrationActor.bot,
        events: result.events,
        placements: result.placements,
      ),
    );
    // The main resume point: the bot has replied and the turn is the player's
    // again, so this is exactly the position a restart should come back to.
    if (isBoardComplete(current.puzzle, newBoard)) {
      emit(await _finish(afterBot));
    } else {
      await _emitAndSave(afterBot, emit);
    }
  }

  // Computes the bot's move, shows the thinking phase, waits out the humanized
  // delay, then feeds the move back in. Shared by confirm / pass / swap.
  Future<void> _runBotTurn(GameActive current, Emitter<GameState> emit) async {
    // Reserve the letters the player is still holding so the bot leaves a target
    // cell open for each. On a stalled board, drop the reservation for this one
    // turn so the bot fills the minimum and the game cannot lock up.
    final botMove = _botEngine.computeMove(
      puzzle: current.puzzle,
      board: current.board,
      scoreDiff: current.botScore - current.playerScore,
      difficultyBand: BotEngine.bandForPuzzleIndex(puzzleIndex),
      seed: _nextSeed(),
      reservedLetters: heldLetters(current.rack),
      ignoreReservations: _stallCount >= GameBloc._stallLimit,
    );
    emit(current.copyWith(phase: TurnPhase.botThinking, botThinking: true));
    await Future<void>.delayed(Duration(milliseconds: botMove.thinkingDelayMs));
    if (isClosed) return;
    add(BotMoveCompleted(botMove));
  }
}
