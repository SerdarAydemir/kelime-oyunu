// test/features/gameplay/bloc/game_bloc_persistence_test.dart

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:kelime_oyunu/core/errors/app_exception.dart';
import 'package:kelime_oyunu/data/models/puzzle.dart';
import 'package:kelime_oyunu/data/models/saved_session.dart';
import 'package:kelime_oyunu/data/repositories/progress_repository.dart';
import 'package:kelime_oyunu/data/repositories/puzzle_repository.dart';
import 'package:kelime_oyunu/data/repositories/session_repository.dart';
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

// "KOL" at (1,1)-(1,3), shipped as level 4.
final _puzzle = puzzleFromWords([
  buildWord(id: 'w1', answer: 'KOL', startRow: 1, startCol: 1, direction: ClueArrow.right),
], puzzleId: 4);

final _completeBoard = <WordCell, String>{
  for (final c in _puzzle.cells)
    if (c.type == CellType.letter && c.solution != null)
      WordCell(row: c.row, col: c.col): c.solution!,
};

const _cell11 = WordCell(row: 1, col: 1);

const _defaultRack = [RackTile(letter: 'K'), RackTile(letter: 'O'), RackTile(letter: 'L')];

const _botProfile = BotProfile(
  id: 'sokrates',
  name: 'Sokrates',
  avatarAsset: 'assets/bot.png',
  description: 'Test bot',
  difficultyBand: DifficultyBand.medium,
);

MoveResult _moveResult({int scoreDelta = 1, Map<WordCell, String>? updatedBoard}) => MoveResult(
  placements: const [],
  events: const [],
  scoreDelta: scoreDelta,
  updatedBoard: updatedBoard ?? {const WordCell(row: 1, col: 1): 'K'},
  returnedLetters: const [],
  completedWordIds: const [],
  rackEmptied: false,
  rackEmptyBonus: 0,
);

GameActive _activeState({
  Map<WordCell, String> board = const {},
  List<Placement> pending = const [],
  int playerScore = 0,
  int botScore = 0,
}) => GameActive(
  puzzle: _puzzle,
  board: board,
  rack: _defaultRack,
  pendingPlacements: pending,
  playerScore: playerScore,
  botScore: botScore,
  phase: TurnPhase.playerTurn,
  botThinking: false,
  status: GameStatus.playing,
  rackSize: RackManager.baseRackSize,
  revealedWordIds: const {},
);

/// A record left behind by a half-played level 4.
SavedSession _savedLevel4() => SavedSession(
  levelId: 4,
  board: {const WordCell(row: 1, col: 1): 'K'},
  rackLetters: const ['O', 'L'],
  playerScore: 11,
  botScore: 5,
  rackSize: RackManager.powerUpRackSize,
  revealedWordIds: const {'w1'},
  swapQuotaRemaining: 3,
  botPlacedCells: {const WordCell(row: 1, col: 1)},
);

void main() {
  late MockPuzzleRepository puzzleRepo;
  late MockScoreEngine scoreEngine;
  late MockRackManager rackManager;
  late MockBotEngine botEngine;
  late InMemoryProgressRepository progressRepo;
  late InMemorySessionRepository sessionRepo;

  setUpAll(() {
    registerFallbackValue(_puzzle);
    registerFallbackValue(<WordCell, String>{});
    registerFallbackValue(<RackTile>[]);
    registerFallbackValue(<String>[]);
    registerFallbackValue(<Placement>[]);
    registerFallbackValue(<String, int>{});
    registerFallbackValue(DifficultyBand.easy);
  });

  setUp(() {
    puzzleRepo = MockPuzzleRepository();
    scoreEngine = MockScoreEngine();
    rackManager = MockRackManager();
    botEngine = MockBotEngine();
    progressRepo = InMemoryProgressRepository();
    sessionRepo = InMemorySessionRepository();

    when(() => puzzleRepo.loadPuzzle(4)).thenAnswer((_) async => _puzzle);
    when(
      () => rackManager.initialRack(
        puzzle: any(named: 'puzzle'),
        board: any(named: 'board'),
        rackSize: any(named: 'rackSize'),
        seed: any(named: 'seed'),
      ),
    ).thenReturn(_defaultRack);
    when(
      () => rackManager.refill(
        currentRack: any(named: 'currentRack'),
        puzzle: any(named: 'puzzle'),
        board: any(named: 'board'),
        returnedLetters: any(named: 'returnedLetters'),
        seed: any(named: 'seed'),
        targetSize: any(named: 'targetSize'),
      ),
    ).thenReturn(_defaultRack);
    when(
      () => rackManager.ensurePlayable(
        currentRack: any(named: 'currentRack'),
        puzzle: any(named: 'puzzle'),
        board: any(named: 'board'),
        seed: any(named: 'seed'),
      ),
    ).thenReturn(_defaultRack);
    when(
      () => botEngine.computeMove(
        puzzle: any(named: 'puzzle'),
        board: any(named: 'board'),
        scoreDiff: any(named: 'scoreDiff'),
        difficultyBand: any(named: 'difficultyBand'),
        seed: any(named: 'seed'),
        reservedLetters: any(named: 'reservedLetters'),
        ignoreReservations: any(named: 'ignoreReservations'),
      ),
    ).thenReturn(const BotMove(placements: [], thinkingDelayMs: 0));
  });

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

  GameBloc buildBloc() => GameBloc(
    puzzleRepo: puzzleRepo,
    scoreEngine: scoreEngine,
    rackManager: rackManager,
    botEngine: botEngine,
    botProfile: _botProfile,
    puzzleIndex: 3,
    progressRepo: progressRepo,
    sessionRepo: sessionRepo,
  );

  // ── Progress ───────────────────────────────────────────────────────────────

  group('progress', () {
    blocTest<GameBloc, GameState>(
      'a win unlocks the next level on disk',
      build: () {
        stubResolveMove(_moveResult(scoreDelta: 0, updatedBoard: _completeBoard));
        return buildBloc();
      },
      seed: () => _activeState(
        playerScore: 10,
        pending: const [Placement(cell: _cell11, letter: 'K', expected: 'K')],
      ),
      act: (bloc) => bloc.add(const MoveConfirmed()),
      verify: (_) {
        expect(progressRepo.highestCompletedLevel, 4);
        expect(progressRepo.isUnlocked(5), isTrue);
      },
    );

    blocTest<GameBloc, GameState>(
      'a loss leaves progression exactly where it was (hard progression)',
      build: () {
        stubResolveMove(_moveResult(scoreDelta: 0, updatedBoard: _completeBoard));
        return buildBloc();
      },
      seed: () => _activeState(playerScore: 1, botScore: 9),
      act: (bloc) => bloc.add(const MoveConfirmed()),
      verify: (_) {
        expect(progressRepo.highestCompletedLevel, 0);
        expect(progressRepo.isUnlocked(5), isFalse);
      },
    );

    blocTest<GameBloc, GameState>(
      'a tie does not advance the ladder either',
      build: () {
        stubResolveMove(_moveResult(scoreDelta: 0, updatedBoard: _completeBoard));
        return buildBloc();
      },
      seed: () => _activeState(playerScore: 7, botScore: 7),
      act: (bloc) => bloc.add(const MoveConfirmed()),
      verify: (_) => expect(progressRepo.highestCompletedLevel, 0),
    );
  });

  // ── Session save ───────────────────────────────────────────────────────────

  group('session save', () {
    blocTest<GameBloc, GameState>(
      'loading a level writes an opening record, so even move 1 is resumable',
      build: buildBloc,
      act: (bloc) => bloc.add(const PuzzleLoadRequested(4)),
      verify: (_) {
        final saved = sessionRepo.load();
        expect(saved, isNotNull);
        expect(saved!.levelId, 4);
        expect(saved.board, isEmpty);
        expect(saved.playerScore, 0);
      },
    );

    blocTest<GameBloc, GameState>(
      'the record is refreshed once the bot has replied and the turn is ours',
      build: () {
        stubResolveMove(_moveResult(scoreDelta: 2));
        return buildBloc();
      },
      seed: () => _activeState(playerScore: 4, botScore: 1),
      act: (bloc) => bloc.add(const BotMoveCompleted(BotMove(placements: [], thinkingDelayMs: 0))),
      verify: (_) {
        final saved = sessionRepo.load();
        expect(saved!.playerScore, 4);
        expect(saved.botScore, 3);
        expect(saved.board, {const WordCell(row: 1, col: 1): 'K'});
      },
    );

    blocTest<GameBloc, GameState>(
      'a spent hint is persisted — a restart must not hand the joker back',
      build: buildBloc,
      seed: _activeState,
      act: (bloc) => bloc.add(const WordRevealed('w1')),
      verify: (_) => expect(sessionRepo.load()!.revealedWordIds, {'w1'}),
    );

    blocTest<GameBloc, GameState>(
      'finishing a match clears the record — nothing left to continue',
      build: () {
        stubResolveMove(_moveResult(scoreDelta: 0, updatedBoard: _completeBoard));
        return buildBloc();
      },
      seed: () => _activeState(playerScore: 10),
      act: (bloc) => bloc.add(const MoveConfirmed()),
      verify: (_) => expect(sessionRepo.load(), isNull),
    );

    blocTest<GameBloc, GameState>(
      'the lifecycle flush writes the live match down',
      build: buildBloc,
      seed: () => _activeState(playerScore: 6, botScore: 2),
      act: (bloc) => bloc.add(const SessionFlushRequested()),
      verify: (_) => expect(sessionRepo.load()!.playerScore, 6),
    );

    blocTest<GameBloc, GameState>(
      'mid-turn states are not resume points: pending letters are never saved',
      build: buildBloc,
      seed: () => _activeState(
        pending: const [Placement(cell: _cell11, letter: 'K', expected: 'K')],
      ),
      act: (bloc) => bloc.add(const LetterPlaced(rackIndex: 0, cell: _cell11)),
      verify: (_) => expect(sessionRepo.load(), isNull),
    );
  });

  // ── Session resume ─────────────────────────────────────────────────────────

  group('session resume', () {
    blocTest<GameBloc, GameState>(
      'restores the saved board, scores and jokers instead of a fresh game',
      build: () {
        sessionRepo = InMemorySessionRepository(initial: _savedLevel4());
        return buildBloc();
      },
      act: (bloc) => bloc.add(const SessionResumeRequested(4)),
      expect: () => [
        isA<GameLoading>(),
        isA<GameActive>()
            .having((s) => s.playerScore, 'playerScore', 11)
            .having((s) => s.botScore, 'botScore', 5)
            .having((s) => s.board, 'board', {const WordCell(row: 1, col: 1): 'K'})
            .having((s) => s.rack.map((t) => t.letter), 'rack', ['O', 'L'])
            .having((s) => s.rackSize, 'rackSize', RackManager.powerUpRackSize)
            .having((s) => s.revealedWordIds, 'revealed', {'w1'})
            .having((s) => s.swapQuotaRemaining, 'swapQuota', 3)
            .having((s) => s.phase, 'phase', TurnPhase.playerTurn),
      ],
    );

    blocTest<GameBloc, GameState>(
      'falls back to a fresh game when nothing was saved',
      build: buildBloc,
      act: (bloc) => bloc.add(const SessionResumeRequested(4)),
      expect: () => [
        isA<GameLoading>(),
        isA<GameActive>()
            .having((s) => s.playerScore, 'playerScore', 0)
            .having((s) => s.board, 'board', isEmpty),
      ],
    );

    blocTest<GameBloc, GameState>(
      'a record for another level never leaks into the level being opened',
      build: () {
        sessionRepo = InMemorySessionRepository(
          initial: SavedSession(
            levelId: 9,
            board: {const WordCell(row: 1, col: 1): 'K'},
            rackLetters: const ['O'],
            playerScore: 40,
            botScore: 2,
            rackSize: RackManager.baseRackSize,
            revealedWordIds: const {},
            swapQuotaRemaining: 1,
            botPlacedCells: const {},
          ),
        );
        return buildBloc();
      },
      act: (bloc) => bloc.add(const SessionResumeRequested(4)),
      expect: () => [
        isA<GameLoading>(),
        isA<GameActive>()
            .having((s) => s.playerScore, 'playerScore', 0)
            .having((s) => s.board, 'board', isEmpty),
      ],
      // The fresh level-4 opening replaces the stale level-9 record.
      verify: (_) => expect(sessionRepo.load()!.levelId, 4),
    );

    blocTest<GameBloc, GameState>(
      'a record pointing at a puzzle this build no longer ships is dropped',
      build: () {
        sessionRepo = InMemorySessionRepository(initial: _savedLevel4());
        when(() => puzzleRepo.loadPuzzle(4)).thenThrow(const PuzzleNotFoundException('gone'));
        return buildBloc();
      },
      act: (bloc) => bloc.add(const SessionResumeRequested(4)),
      expect: () => [isA<GameLoading>(), isA<GameError>()],
      verify: (_) => expect(sessionRepo.load(), isNull),
    );
  });
}
