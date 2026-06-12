// lib/features/gameplay/bloc/game_bloc.dart

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:kelime_oyunu/core/errors/app_exception.dart';
import 'package:kelime_oyunu/data/models/puzzle.dart';
import 'package:kelime_oyunu/data/repositories/puzzle_repository.dart';
import 'package:kelime_oyunu/features/gameplay/bloc/game_event.dart';
import 'package:kelime_oyunu/features/gameplay/bloc/game_state.dart';
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
  }) : super(const GameInitial()) {
    on<PuzzleLoadRequested>(_onPuzzleLoadRequested);
    on<WordSelected>(_onWordSelected);
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
  final int _seed;
  // Bot identity (UI reads name/avatar) and the puzzle's global difficulty index.
  final BotProfile botProfile;
  final int puzzleIndex;
  // Cell -> solution, cached on load (one puzzle per bloc). Seeds vary per call.
  Map<WordCell, String> _solutionByCell = const {};
  int _turnCounter = 0;
  int _nextSeed() => _seed + _turnCounter++;

  Future<void> _onPuzzleLoadRequested(PuzzleLoadRequested event, Emitter<GameState> emit) async {
    emit(const GameLoading());
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
      emit(
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
      );
    } on PuzzleNotFoundException catch (e) {
      emit(GameError(e.message));
    }
  }

  void _onWordSelected(WordSelected event, Emitter<GameState> emit) {
    final current = state;
    if (current is! GameActive) return;
    // Toggle: tapping the already-highlighted word clears the selection.
    final next = current.highlightedWordId == event.wordId ? null : event.wordId;
    emit(current.copyWith(highlightedWordId: next));
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
    final afterMove = current.copyWith(
      board: newBoard,
      rack: _rackManager.refill(
        currentRack: current.rack,
        puzzle: current.puzzle,
        board: newBoard,
        returnedLetters: result.returnedLetters,
        seed: _nextSeed(),
        targetSize: current.rackSize,
      ),
      pendingPlacements: const [],
      playerScore: current.playerScore + result.scoreDelta,
      highlightedWordId: null, // a confirmed move clears any selection
      selectedRackIndex: -1, // the refill may shrink the rack — drop the index
    );
    if (isBoardComplete(current.puzzle, newBoard)) {
      emit(_finish(afterMove));
      return;
    }
    await _runBotTurn(afterMove, emit);
  }

  Future<void> _onMovePassed(MovePassed event, Emitter<GameState> emit) async {
    final current = state;
    if (current is! GameActive) return;
    await _runBotTurn(current, emit);
  }

  void _onBotMoveCompleted(BotMoveCompleted event, Emitter<GameState> emit) {
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
    // Clear transient flags (Karar 2/3), then refresh every tile the bot's
    // move just killed: deadness is permanent (the board only fills up), so
    // the player must never carry unplayable letters into their turn.
    final resetRack = [for (final t in current.rack) RackTile(letter: t.letter)];
    final playableRack = _rackManager.ensurePlayable(
      currentRack: resetRack,
      puzzle: current.puzzle,
      board: newBoard,
      seed: _nextSeed(),
    );
    if (!identical(playableRack, resetRack)) {
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
    );
    emit(isBoardComplete(current.puzzle, newBoard) ? _finish(afterBot) : afterBot);
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
      emit(next);
      return;
    }
    await _runBotTurn(next, emit);
  }

  void _onWordRevealed(WordRevealed event, Emitter<GameState> emit) {
    final current = state;
    if (current is! GameActive) return;
    if (!current.puzzle.words.any((w) => w.id == event.wordId)) return;
    // Reveal SHOWS the word as a ghost (the painter draws the solution faintly
    // on still-empty, playable cells); it does NOT commit letters to the board.
    // The player still places real tiles to score, so the board can only be
    // completed — and the game finished — through a real move (§1.5).
    emit(current.copyWith(revealedWordIds: {...current.revealedWordIds, event.wordId}));
  }

  void _onSixthSlotUnlocked(SixthSlotUnlocked event, Emitter<GameState> emit) {
    final current = state;
    if (current is! GameActive) return;
    if (current.rackSize >= RackManager.powerUpRackSize) return;
    final extra = _rackManager.initialRack(
      puzzle: current.puzzle,
      board: current.board,
      rackSize: 1,
      seed: _nextSeed(),
    );
    emit(
      current.copyWith(rack: [...current.rack, ...extra], rackSize: RackManager.powerUpRackSize),
    );
  }

  // Computes the bot's move, shows the thinking phase, waits out the humanized
  // delay, then feeds the move back in. Shared by confirm / pass / swap.
  Future<void> _runBotTurn(GameActive current, Emitter<GameState> emit) async {
    final botMove = _botEngine.computeMove(
      puzzle: current.puzzle,
      board: current.board,
      scoreDiff: current.botScore - current.playerScore,
      difficultyBand: BotEngine.bandForPuzzleIndex(puzzleIndex),
      seed: _nextSeed(),
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

  GameActive _finish(GameActive snapshot) {
    final status = snapshot.playerScore > snapshot.botScore ? GameStatus.won : GameStatus.lost;
    return snapshot.copyWith(phase: TurnPhase.finished, botThinking: false, status: status);
  }
}
