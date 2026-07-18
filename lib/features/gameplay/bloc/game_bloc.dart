// lib/features/gameplay/bloc/game_bloc.dart

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:kelime_oyunu/core/errors/app_exception.dart';
import 'package:kelime_oyunu/data/models/puzzle.dart';
import 'package:kelime_oyunu/data/repositories/progress_repository.dart';
import 'package:kelime_oyunu/data/repositories/puzzle_repository.dart';
import 'package:kelime_oyunu/data/repositories/session_repository.dart';
import 'package:kelime_oyunu/features/gameplay/bloc/game_event.dart';
import 'package:kelime_oyunu/features/gameplay/bloc/game_state.dart';
import 'package:kelime_oyunu/features/gameplay/bloc/move_narration.dart';
import 'package:kelime_oyunu/features/gameplay/bloc/session_codec.dart';
import 'package:kelime_oyunu/features/gameplay/engine/board_ops.dart';
import 'package:kelime_oyunu/features/gameplay/engine/bot_engine.dart';
import 'package:kelime_oyunu/features/gameplay/engine/rack_manager.dart';
import 'package:kelime_oyunu/features/gameplay/engine/score_engine.dart';

/// Turn-based orchestrator that wires the pure engines together (§8.1). One
/// instance plays exactly one puzzle, so the solution lookup is cached on load.
class GameBloc extends Bloc<GameEvent, GameState> {
  GameBloc({
    required this.botProfile,
    required this.puzzleIndex,
    required this._scoreEngine,
    required this._rackManager,
    required this._botEngine,
    required this._puzzleRepo,
    this._seed = 0,
    ProgressRepository? progressRepo,
    SessionRepository? sessionRepo,
  }) : _progressRepo = progressRepo ?? InMemoryProgressRepository(),
       _sessionRepo = sessionRepo ?? InMemorySessionRepository(),
       super(const GameInitial()) {
    on<PuzzleLoadRequested>(_onPuzzleLoadRequested);
    on<SessionResumeRequested>(_onSessionResumeRequested);
    on<SessionFlushRequested>(_onSessionFlushRequested);
    on<LetterPlaced>(_onLetterPlaced);
    on<LetterRecalled>(_onLetterRecalled);
    on<MoveConfirmed>(_onMoveConfirmed);
    on<MovePassed>(_onMovePassed);
    on<BotMoveCompleted>(_onBotMoveCompleted);
    on<LettersSwapped>(_onLettersSwapped);
    on<WordRevealed>(_onWordRevealed);
    on<SixthSlotUnlocked>(_onSixthSlotUnlocked);
    on<RackTileSelected>(_onRackTileSelected);
  }

  final PuzzleRepository _puzzleRepo;
  final ScoreEngine _scoreEngine;
  final RackManager _rackManager;
  final BotEngine _botEngine;
  // Optional by design: unwired blocs (every existing unit test) get their own
  // volatile storage, so nothing here can reach the disk unless main() says so.
  final ProgressRepository _progressRepo;
  final SessionRepository _sessionRepo;
  final int _seed;
  // Bot identity (UI reads name/avatar) and the puzzle's global difficulty index.
  final BotProfile botProfile;
  final int puzzleIndex;
  // Cell -> solution, cached on load (one puzzle per bloc). Seeds vary per call.
  Map<WordCell, String> _solutionByCell = const {};
  int _turnCounter = 0;
  int _nextSeed() => _seed + _turnCounter++;
  // Monotonic narration id: lets the UI detect a fresh move to narrate even
  // when two consecutive moves produce byte-identical events (§move_narration).
  int _narrationSeq = 0;
  // Refill is DEFERRED to the end of the bot's reply (F6): the player's rack
  // keeps its spent/empty look while the exchange narrates, and fresh letters
  // (plus any returned wrong ones) arrive only after the bot has played.
  bool _refillPending = false;
  List<String> _deferredReturns = const [];
  // Stalemate guard for the reserve filter: the bot reserves the player's held
  // letters, so a run of turns that neither side progresses could in theory
  // freeze the board. We count consecutive full turns (player + bot) that leave
  // the committed-cell total unchanged; after _stallLimit of them the next bot
  // turn plays with reservations off (min cells, board guaranteed to advance).
  // Normal aggressive play grows the board every turn, so this never fires.
  static const int _stallLimit = 2;
  int _stallCount = 0;
  int _lastTurnBoardCount = 0;

  Future<void> _onPuzzleLoadRequested(PuzzleLoadRequested event, Emitter<GameState> emit) async {
    emit(const GameLoading());
    // A replay reuses this bloc: drop any refill deferred by an earlier match.
    _refillPending = false;
    _deferredReturns = const [];
    // Fresh board: reset the stalemate accounting to an empty position.
    _stallCount = 0;
    _lastTurnBoardCount = 0;
    try {
      final puzzle = await _puzzleRepo.loadPuzzle(event.puzzleId);
      _solutionByCell = buildSolutionByCell(puzzle);
      const board = <WordCell, String>{};
      final rack = _rackManager.initialRack(
        puzzle: puzzle,
        board: board,
        rackSize: RackManager.baseRackSize,
        seed: _nextSeed(),
      );
      // Saving the opening position too: the record always describes the match
      // in flight, so starting a new level also retires the previous one's.
      await _emitAndSave(
        GameActive(
          puzzle: puzzle,
          board: board,
          rack: rack,
          pendingPlacements: const [],
          playerScore: 0,
          botScore: 0,
          phase: TurnPhase.playerTurn,
          botThinking: false,
          status: GameStatus.playing,
          rackSize: RackManager.baseRackSize,
          revealedWordIds: const {},
        ),
        emit,
      );
    } on PuzzleNotFoundException catch (e) {
      emit(GameError(e.message));
    }
  }

  /// Restores the half-played match for [event.levelId], or starts it fresh if
  /// no usable record exists.
  Future<void> _onSessionResumeRequested(
    SessionResumeRequested event,
    Emitter<GameState> emit,
  ) async {
    final saved = _sessionRepo.load();
    if (saved == null || saved.levelId != event.levelId) {
      await _onPuzzleLoadRequested(PuzzleLoadRequested(event.levelId), emit);
      return;
    }
    emit(const GameLoading());
    _refillPending = false;
    _deferredReturns = const [];
    try {
      // The puzzle is an asset, not part of the record: reload it by id (§K4).
      final puzzle = await _puzzleRepo.loadPuzzle(saved.levelId);
      _solutionByCell = buildSolutionByCell(puzzle);
      // Resume mid-board: seed the stalemate baseline from the restored board so
      // the first turn back measures progress against it, not against empty.
      _stallCount = 0;
      _lastTurnBoardCount = saved.board.length;
      emit(stateFromSession(saved, puzzle));
    } on PuzzleNotFoundException catch (e) {
      // The record points at a puzzle this build no longer ships: drop it
      // rather than stranding the player on an error screen forever.
      await _sessionRepo.clear();
      emit(GameError(e.message));
    }
  }

  /// Lifecycle flush (onPause / onDetach): the last chance to write before the
  /// OS may kill us. A no-op unless the player is mid-match and to move.
  Future<void> _onSessionFlushRequested(
    SessionFlushRequested event,
    Emitter<GameState> emit,
  ) async {
    final current = state;
    if (current is GameActive) await _saveIfResumable(current);
  }

  /// Persists [next] *before* emitting it (architecture.md §11.2: write first,
  /// then paint), so a kill between the two can never lose the move.
  Future<void> _emitAndSave(GameActive next, Emitter<GameState> emit) async {
    await _saveIfResumable(next);
    emit(next);
  }

  /// Writes [snapshot] only at a resumable moment: the player is to move and
  /// the match is live. Mid-turn states (pending letters, the bot thinking)
  /// are not resume points — see F7 plan §K6 for the save-scumming trade-off.
  Future<void> _saveIfResumable(GameActive snapshot) async {
    if (snapshot.phase != TurnPhase.playerTurn || snapshot.status != GameStatus.playing) return;
    await _sessionRepo.save(sessionFromState(snapshot));
  }

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
      ignoreReservations: _stallCount >= _stallLimit,
    );
    emit(current.copyWith(phase: TurnPhase.botThinking, botThinking: true));
    await Future<void>.delayed(Duration(milliseconds: botMove.thinkingDelayMs));
    if (isClosed) return;
    add(BotMoveCompleted(botMove));
  }

  void _onRackTileSelected(RackTileSelected event, Emitter<GameState> emit) {
    final current = state;
    if (current is! GameActive) return;
    emit(current.copyWith(selectedRackIndex: event.rackIndex));
  }

  /// Resolves the terminal status and persists its consequences *before* the
  /// finished state is emitted (architecture.md §11.2: write first, then paint).
  ///
  /// Only a win advances progression — the existing hard-progression rule is
  /// unchanged here, it is merely written down now.
  Future<GameActive> _finish(GameActive snapshot) async {
    final GameStatus status;
    if (snapshot.playerScore > snapshot.botScore) {
      status = GameStatus.won;
    } else if (snapshot.playerScore < snapshot.botScore) {
      status = GameStatus.lost;
    } else {
      status = GameStatus.tie;
    }
    if (status == GameStatus.won) {
      await _progressRepo.recordWin(snapshot.puzzle.puzzleId);
    }
    // The match is over however it ended: there is nothing left to resume, and
    // a stale record would offer "Devam Et" into a finished board.
    await _sessionRepo.clear();
    return snapshot.copyWith(phase: TurnPhase.finished, botThinking: false, status: status);
  }
}
