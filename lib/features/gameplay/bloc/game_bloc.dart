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

part 'package:kelime_oyunu/features/gameplay/bloc/game_bloc_jokers.dart';
part 'package:kelime_oyunu/features/gameplay/bloc/game_bloc_turn.dart';

/// Turn-based orchestrator that wires the pure engines together (§8.1). One
/// instance plays exactly one puzzle, so the solution lookup is cached on load.
///
/// Handlers are grouped by responsibility across part files: this file owns
/// load / resume / persistence and the terminal state, `game_bloc_turn.dart`
/// the player-bot turn cycle, `game_bloc_jokers.dart` the paid helpers.
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
