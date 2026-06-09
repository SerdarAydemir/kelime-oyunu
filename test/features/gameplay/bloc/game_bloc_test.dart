// test/features/gameplay/bloc/game_bloc_test.dart

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:kelime_oyunu/core/errors/app_exception.dart';
import 'package:kelime_oyunu/data/models/puzzle.dart';
import 'package:kelime_oyunu/data/repositories/puzzle_repository.dart';
import 'package:kelime_oyunu/features/gameplay/bloc/game_bloc.dart';
import 'package:kelime_oyunu/features/gameplay/bloc/game_event.dart';
import 'package:kelime_oyunu/features/gameplay/bloc/game_state.dart';
import 'package:kelime_oyunu/features/gameplay/engine/bot_engine.dart';
import 'package:kelime_oyunu/features/gameplay/engine/rack_manager.dart';
import 'package:kelime_oyunu/features/gameplay/engine/score_engine.dart';

// Shared helpers live under test/ with no package: path (relative import only).
// ignore: always_use_package_imports
import '../../../helpers/engine_test_fixtures.dart';

class MockPuzzleRepository extends Mock implements PuzzleRepository {}

class MockScoreEngine extends Mock implements ScoreEngine {}

class MockRackManager extends Mock implements RackManager {}

class MockBotEngine extends Mock implements BotEngine {}

// A 3-letter word "KOL" at (1,1)-(1,3): letter cells K, O, L.
final _puzzle = puzzleFromWords([
  buildWord(id: 'w1', answer: 'KOL', startRow: 1, startCol: 1, direction: ClueArrow.right),
]);

// Board with every letter cell filled — used to drive the finish transition.
final _completeBoard = <WordCell, String>{
  for (final c in _puzzle.cells)
    if (c.type == CellType.letter && c.solution != null)
      WordCell(row: c.row, col: c.col): c.solution!,
};

const _cell11 = WordCell(row: 1, col: 1);

const _defaultRack = [
  RackTile(letter: 'K'),
  RackTile(letter: 'O'),
  RackTile(letter: 'L'),
  RackTile(letter: 'A'),
  RackTile(letter: 'B'),
];

const _botProfile = BotProfile(
  id: 'sokrates',
  name: 'Sokrates',
  avatarAsset: 'assets/bot.png',
  description: 'Test bot',
  difficultyBand: DifficultyBand.medium,
);

MoveResult _moveResult({int scoreDelta = 1, Map<WordCell, String>? updatedBoard}) {
  return MoveResult(
    placements: const [],
    events: const [],
    scoreDelta: scoreDelta,
    updatedBoard: updatedBoard ?? {const WordCell(row: 1, col: 1): 'K'},
    returnedLetters: const [],
    completedWordIds: const [],
    rackEmptied: false,
    rackEmptyBonus: 0,
  );
}

GameActive _activeState({
  List<RackTile> rack = _defaultRack,
  List<Placement> pending = const [],
  Map<WordCell, String> board = const {},
  int playerScore = 0,
  int botScore = 0,
  TurnPhase phase = TurnPhase.playerTurn,
  bool botThinking = false,
  String? highlightedWordId,
}) {
  return GameActive(
    puzzle: _puzzle,
    board: board,
    rack: rack,
    pendingPlacements: pending,
    playerScore: playerScore,
    botScore: botScore,
    phase: phase,
    botThinking: botThinking,
    status: GameStatus.playing,
    rackSize: RackManager.baseRackSize,
    revealedWordIds: const {},
    highlightedWordId: highlightedWordId,
  );
}

void main() {
  late MockPuzzleRepository puzzleRepo;
  late MockScoreEngine scoreEngine;
  late MockRackManager rackManager;
  late MockBotEngine botEngine;

  setUpAll(() {
    registerFallbackValue(_puzzle);
    registerFallbackValue(<WordCell, String>{});
    registerFallbackValue(<RackTile>[]);
    registerFallbackValue(<String>[]);
    registerFallbackValue(<Placement>[]);
    registerFallbackValue(DifficultyBand.easy);
  });

  setUp(() {
    puzzleRepo = MockPuzzleRepository();
    scoreEngine = MockScoreEngine();
    rackManager = MockRackManager();
    botEngine = MockBotEngine();
  });

  GameBloc buildBloc() => GameBloc(
    puzzleRepo: puzzleRepo,
    scoreEngine: scoreEngine,
    rackManager: rackManager,
    botEngine: botEngine,
    botProfile: _botProfile,
    puzzleIndex: 0,
  );

  void stubInitialRack() {
    when(
      () => rackManager.initialRack(
        puzzle: any(named: 'puzzle'),
        board: any(named: 'board'),
        rackSize: any(named: 'rackSize'),
        seed: any(named: 'seed'),
      ),
    ).thenReturn(_defaultRack);
  }

  void stubRefill() {
    when(
      () => rackManager.refill(
        currentRack: any(named: 'currentRack'),
        puzzle: any(named: 'puzzle'),
        board: any(named: 'board'),
        returnedLetters: any(named: 'returnedLetters'),
        seed: any(named: 'seed'),
      ),
    ).thenReturn(_defaultRack);
  }

  void stubResolveMove(MoveResult result) {
    when(
      () => scoreEngine.resolveMove(
        placements: any(named: 'placements'),
        puzzle: any(named: 'puzzle'),
        board: any(named: 'board'),
        rackStartCount: any(named: 'rackStartCount'),
      ),
    ).thenReturn(result);
  }

  void stubComputeMove() {
    when(
      () => botEngine.computeMove(
        puzzle: any(named: 'puzzle'),
        board: any(named: 'board'),
        scoreDiff: any(named: 'scoreDiff'),
        difficultyBand: any(named: 'difficultyBand'),
        seed: any(named: 'seed'),
      ),
    ).thenReturn(const BotMove(placements: [], thinkingDelayMs: 0));
  }

  // Returns the rack it was given (the "not stuck" path) so bot-turn tests using
  // the mocked RackManager keep the player's rack unchanged.
  void stubEnsurePlayable() {
    when(
      () => rackManager.ensurePlayable(
        currentRack: any(named: 'currentRack'),
        puzzle: any(named: 'puzzle'),
        board: any(named: 'board'),
        seed: any(named: 'seed'),
      ),
    ).thenAnswer((inv) => inv.namedArguments[#currentRack] as List<RackTile>);
  }

  group('PuzzleLoadRequested', () {
    // ── 1 ──────────────────────────────────────────────────────────────────
    blocTest<GameBloc, GameState>(
      'emits [GameLoading, GameActive] when the puzzle loads',
      build: () {
        when(() => puzzleRepo.loadPuzzle(1)).thenAnswer((_) async => _puzzle);
        stubInitialRack();
        return buildBloc();
      },
      act: (bloc) => bloc.add(const PuzzleLoadRequested(1)),
      expect: () => [isA<GameLoading>(), isA<GameActive>()],
    );

    // ── 2 ──────────────────────────────────────────────────────────────────
    blocTest<GameBloc, GameState>(
      'emits [GameLoading, GameError] when the puzzle is missing',
      build: () {
        when(
          () => puzzleRepo.loadPuzzle(999),
        ).thenThrow(const PuzzleNotFoundException('not found'));
        return buildBloc();
      },
      act: (bloc) => bloc.add(const PuzzleLoadRequested(999)),
      expect: () => [isA<GameLoading>(), isA<GameError>()],
    );
  });

  group('LetterPlaced', () {
    // ── 3 ──────────────────────────────────────────────────────────────────
    blocTest<GameBloc, GameState>(
      'adds a pending placement and marks the rack tile placed',
      build: buildBloc,
      seed: _activeState,
      act: (bloc) => bloc.add(const LetterPlaced(rackIndex: 0, cell: _cell11)),
      expect: () => [
        isA<GameActive>()
            .having((s) => s.pendingPlacements.length, 'pending', 1)
            .having((s) => s.rack.firstWhere((t) => t.letter == 'K').isPlaced, 'K placed', true),
      ],
    );

    // ── 4 ──────────────────────────────────────────────────────────────────
    blocTest<GameBloc, GameState>(
      'placing twice on the same cell replaces (no duplicate pending)',
      build: buildBloc,
      seed: _activeState,
      act: (bloc) => bloc
        ..add(const LetterPlaced(rackIndex: 0, cell: _cell11))
        ..add(const LetterPlaced(rackIndex: 1, cell: _cell11)),
      expect: () => [
        isA<GameActive>().having((s) => s.pendingPlacements.length, 'pending', 1),
        isA<GameActive>().having((s) => s.pendingPlacements.length, 'pending', 1),
      ],
    );

    // ── 4a: BUG 1 — non-letter (clue/blank) cell is rejected (no-op) ─────────
    blocTest<GameBloc, GameState>(
      'ignores placement on a non-letter cell',
      build: buildBloc,
      seed: _activeState,
      // (0,0) is outside the KOL word, so it is not a letter cell.
      act: (bloc) => bloc.add(const LetterPlaced(rackIndex: 0, cell: WordCell(row: 0, col: 0))),
      expect: () => <GameState>[],
    );

    // ── 4b: BUG 1 — already-committed cell is rejected (no-op) ───────────────
    blocTest<GameBloc, GameState>(
      'ignores placement on an already-filled cell',
      build: buildBloc,
      seed: () => _activeState(board: {_cell11: 'K'}),
      act: (bloc) => bloc.add(const LetterPlaced(rackIndex: 0, cell: _cell11)),
      expect: () => <GameState>[],
    );
  });

  group('LetterRecalled', () {
    // ── 5 ──────────────────────────────────────────────────────────────────
    blocTest<GameBloc, GameState>(
      'removes the pending placement and frees the rack tile',
      build: buildBloc,
      seed: () => _activeState(
        rack: const [
          RackTile(letter: 'K', isPlaced: true),
          RackTile(letter: 'O'),
          RackTile(letter: 'L'),
          RackTile(letter: 'A'),
          RackTile(letter: 'B'),
        ],
        pending: const [Placement(cell: _cell11, letter: 'K', expected: 'K')],
      ),
      act: (bloc) => bloc.add(const LetterRecalled(_cell11)),
      expect: () => [
        isA<GameActive>()
            .having((s) => s.pendingPlacements, 'pending', isEmpty)
            .having((s) => s.rack.every((t) => !t.isPlaced), 'none placed', true),
      ],
    );
  });

  group('MoveConfirmed', () {
    // ── 6 ──────────────────────────────────────────────────────────────────
    blocTest<GameBloc, GameState>(
      'resolves the score, raises playerScore and enters botThinking',
      build: () {
        stubResolveMove(_moveResult(scoreDelta: 1));
        stubRefill();
        stubComputeMove();
        stubEnsurePlayable();
        return buildBloc();
      },
      seed: () => _activeState(
        pending: const [Placement(cell: _cell11, letter: 'K', expected: 'K')],
      ),
      act: (bloc) => bloc.add(const MoveConfirmed()),
      wait: const Duration(milliseconds: 50),
      expect: () => [
        isA<GameActive>()
            .having((s) => s.phase, 'phase', TurnPhase.botThinking)
            .having((s) => s.playerScore, 'playerScore', 1),
        isA<GameActive>().having((s) => s.phase, 'phase', TurnPhase.playerTurn),
      ],
      verify: (_) {
        // The player's move is scored with the real rack size (5).
        verify(
          () => scoreEngine.resolveMove(
            placements: any(named: 'placements'),
            puzzle: any(named: 'puzzle'),
            board: any(named: 'board'),
            rackStartCount: 5,
          ),
        ).called(1);
      },
    );

    // ── 8 ──────────────────────────────────────────────────────────────────
    blocTest<GameBloc, GameState>(
      'finishes as won when the move fills the board',
      build: () {
        stubResolveMove(_moveResult(scoreDelta: 0, updatedBoard: _completeBoard));
        stubRefill();
        return buildBloc();
      },
      seed: () => _activeState(
        playerScore: 10,
        pending: const [Placement(cell: _cell11, letter: 'K', expected: 'K')],
      ),
      act: (bloc) => bloc.add(const MoveConfirmed()),
      expect: () => [
        isA<GameActive>()
            .having((s) => s.phase, 'phase', TurnPhase.finished)
            .having((s) => s.status, 'status', GameStatus.won),
      ],
    );

    // ── 8a: a confirmed move clears the word highlight ──────────────────────
    blocTest<GameBloc, GameState>(
      'clears the word highlight after a confirmed move',
      build: () {
        stubResolveMove(_moveResult(scoreDelta: 1));
        stubRefill();
        stubComputeMove();
        stubEnsurePlayable();
        return buildBloc();
      },
      seed: () => _activeState(
        highlightedWordId: 'w1',
        pending: const [Placement(cell: _cell11, letter: 'K', expected: 'K')],
      ),
      act: (bloc) => bloc.add(const MoveConfirmed()),
      wait: const Duration(milliseconds: 50),
      expect: () => [
        isA<GameActive>().having((s) => s.highlightedWordId, 'highlight', isNull),
        isA<GameActive>().having((s) => s.highlightedWordId, 'highlight', isNull),
      ],
    );
  });

  group('BotMoveCompleted', () {
    // ── 7 ──────────────────────────────────────────────────────────────────
    blocTest<GameBloc, GameState>(
      'applies the bot move and hands the turn back to the player',
      build: () {
        stubResolveMove(_moveResult(scoreDelta: 2));
        stubEnsurePlayable();
        return buildBloc();
      },
      seed: () => _activeState(phase: TurnPhase.botThinking, botThinking: true),
      act: (bloc) => bloc.add(
        const BotMoveCompleted(
          BotMove(
            placements: [Placement(cell: _cell11, letter: 'K', expected: 'K')],
            thinkingDelayMs: 0,
          ),
        ),
      ),
      expect: () => [
        isA<GameActive>()
            .having((s) => s.phase, 'phase', TurnPhase.playerTurn)
            .having((s) => s.botThinking, 'botThinking', false)
            .having((s) => s.botScore, 'botScore', 2),
      ],
    );

    // ── BUG 2: a fully dead rack is refreshed when the turn returns ──────────
    // Real RackManager + ScoreEngine so ensurePlayable actually runs; the seeded
    // rack {Z,J,V,Y,B} shares no letter with KOL, so it must be refreshed.
    blocTest<GameBloc, GameState>(
      'refreshes a stuck (all-dead) rack so the player can move again',
      build: () => GameBloc(
        puzzleRepo: puzzleRepo,
        scoreEngine: const ScoreEngine(),
        rackManager: const RackManager(),
        botEngine: botEngine,
        botProfile: _botProfile,
        puzzleIndex: 0,
      ),
      seed: () => _activeState(
        phase: TurnPhase.botThinking,
        botThinking: true,
        rack: const [
          RackTile(letter: 'Z'),
          RackTile(letter: 'J'),
          RackTile(letter: 'V'),
          RackTile(letter: 'Y'),
          RackTile(letter: 'B'),
        ],
      ),
      act: (bloc) => bloc.add(const BotMoveCompleted(BotMove(placements: [], thinkingDelayMs: 0))),
      expect: () => [
        isA<GameActive>().having(
          (s) =>
              const RackManager().hasPlayableMove(rack: s.rack, puzzle: s.puzzle, board: s.board),
          'rack has a playable move',
          isTrue,
        ),
      ],
    );
  });

  group('MovePassed', () {
    // ── 9 ──────────────────────────────────────────────────────────────────
    blocTest<GameBloc, GameState>(
      'passes the turn to the bot (enters botThinking)',
      build: () {
        stubResolveMove(_moveResult(scoreDelta: 0));
        stubComputeMove();
        stubEnsurePlayable();
        return buildBloc();
      },
      seed: _activeState,
      act: (bloc) => bloc.add(const MovePassed()),
      wait: const Duration(milliseconds: 50),
      expect: () => [
        isA<GameActive>().having((s) => s.phase, 'phase', TurnPhase.botThinking),
        isA<GameActive>().having((s) => s.phase, 'phase', TurnPhase.playerTurn),
      ],
    );
  });

  group('WordRevealed', () {
    // ── BUG/feature: ghost reveal — no board commit, no finish ──────────────
    blocTest<GameBloc, GameState>(
      'reveals as a ghost: board unchanged, no finish, only revealedWordIds grows',
      build: buildBloc,
      seed: _activeState,
      act: (bloc) => bloc.add(const WordRevealed('w1')),
      expect: () => [
        isA<GameActive>()
            .having((s) => s.revealedWordIds, 'revealedWordIds', {'w1'})
            .having((s) => s.board, 'board stays empty', isEmpty)
            .having((s) => s.phase, 'phase', TurnPhase.playerTurn)
            .having((s) => s.status, 'status', GameStatus.playing),
      ],
    );

    // Unknown word id is a no-op (no state change).
    blocTest<GameBloc, GameState>(
      'ignores an unknown word id',
      build: buildBloc,
      seed: _activeState,
      act: (bloc) => bloc.add(const WordRevealed('nope')),
      expect: () => <GameState>[],
    );
  });

  group('WordSelected', () {
    // ── 10 ─────────────────────────────────────────────────────────────────
    blocTest<GameBloc, GameState>(
      'updates the highlighted word id',
      build: buildBloc,
      seed: _activeState,
      act: (bloc) => bloc.add(const WordSelected('w1')),
      expect: () => [isA<GameActive>().having((s) => s.highlightedWordId, 'highlight', 'w1')],
    );

    // ── 10a: re-selecting the highlighted word clears it (toggle) ───────────
    blocTest<GameBloc, GameState>(
      're-selecting the highlighted word clears the highlight',
      build: buildBloc,
      seed: () => _activeState(highlightedWordId: 'w1'),
      act: (bloc) => bloc.add(const WordSelected('w1')),
      expect: () => [isA<GameActive>().having((s) => s.highlightedWordId, 'highlight', isNull)],
    );
  });
}
