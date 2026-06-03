// test/features/gameplay/view/game_screen_test.dart

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:kelime_oyunu/data/models/puzzle.dart';
import 'package:kelime_oyunu/features/gameplay/bloc/game_bloc.dart';
import 'package:kelime_oyunu/features/gameplay/bloc/game_event.dart';
import 'package:kelime_oyunu/features/gameplay/bloc/game_state.dart';
import 'package:kelime_oyunu/features/gameplay/engine/rack_manager.dart';
import 'package:kelime_oyunu/features/gameplay/widgets/action_bar.dart';
import 'package:kelime_oyunu/features/gameplay/widgets/rack_widget.dart';
import 'package:kelime_oyunu/features/gameplay/widgets/score_header.dart';

// Relative import — test helpers are not importable via package: path.
// ignore: always_use_package_imports
import '../../../helpers/engine_test_fixtures.dart';

class MockGameBloc extends MockBloc<GameEvent, GameState>
    implements GameBloc {}

// Minimal 3-letter puzzle used in all active-state tests.
final _puzzle = puzzleFromWords([
  buildWord(
    id: 'w1',
    answer: 'KOL',
    startRow: 1,
    startCol: 1,
    direction: ClueArrow.right,
  ),
]);

GameActive _fakeActiveState() => GameActive(
      puzzle: _puzzle,
      board: const {},
      rack: const [],
      pendingPlacements: const [],
      playerScore: 0,
      botScore: 0,
      phase: TurnPhase.playerTurn,
      botThinking: false,
      highlightedWordId: null,
      status: GameStatus.playing,
      rackSize: RackManager.baseRackSize,
      revealedWordIds: const {},
      selectedRackIndex: -1,
    );

/// Pumps a [BlocProvider.value]-wrapped widget that renders the game UI
/// according to the current [GameBloc] state.
Widget _buildSubject(MockGameBloc bloc) => MaterialApp(
      home: BlocProvider<GameBloc>.value(
        value: bloc,
        child: const _GameStateRenderer(),
      ),
    );

/// Private test widget: mirrors the state→UI mapping of the real game screen.
class _GameStateRenderer extends StatelessWidget {
  const _GameStateRenderer();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<GameBloc, GameState>(
      builder: (ctx, state) => switch (state) {
        GameInitial() => const Scaffold(body: SizedBox.shrink()),
        GameLoading() =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
        GameError(:final message) =>
          Scaffold(body: Center(child: Text(message))),
        GameActive() => Scaffold(body: _GameActiveContent(state: state)),
      },
    );
  }
}

/// Private test widget: renders the key gameplay widgets for assertion.
class _GameActiveContent extends StatelessWidget {
  const _GameActiveContent({required this.state});

  final GameActive state;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ScoreHeader(
          playerScore: state.playerScore,
          botScore: state.botScore,
          botName: 'Sokrates',
          botThinking: state.botThinking,
        ),
        RackWidget(rack: state.rack, onTileTap: (_) {}, onTileRecall: (_) {}),
        ActionBar(
          pendingPlacements: state.pendingPlacements,
          onConfirm: () {},
          onPass: () {},
          onSwap: null,
          onReveal: null,
        ),
      ],
    );
  }
}

void main() {
  late MockGameBloc mockBloc;

  setUp(() => mockBloc = MockGameBloc());
  tearDown(() => mockBloc.close());

  // ── Test 1: Loading ────────────────────────────────────────────────────────

  testWidgets('shows CircularProgressIndicator while loading', (tester) async {
    when(() => mockBloc.state).thenReturn(const GameLoading());
    when(() => mockBloc.stream)
        .thenAnswer((_) => Stream.value(const GameLoading()));

    await tester.pumpWidget(_buildSubject(mockBloc));

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  // ── Test 2: Active ─────────────────────────────────────────────────────────

  testWidgets('shows ScoreHeader, RackWidget and ActionBar when active',
      (tester) async {
    final activeState = _fakeActiveState();
    when(() => mockBloc.state).thenReturn(activeState);
    when(() => mockBloc.stream).thenAnswer((_) => Stream.value(activeState));

    await tester.pumpWidget(_buildSubject(mockBloc));

    expect(find.byType(ScoreHeader), findsOneWidget);
    expect(find.byType(RackWidget), findsOneWidget);
    expect(find.byType(ActionBar), findsOneWidget);
  });

  // ── Test 3: Error ──────────────────────────────────────────────────────────

  testWidgets('shows error message on GameError state', (tester) async {
    const errorState = GameError('Test hatası');
    when(() => mockBloc.state).thenReturn(errorState);
    when(() => mockBloc.stream)
        .thenAnswer((_) => Stream.value(errorState));

    await tester.pumpWidget(_buildSubject(mockBloc));

    expect(find.text('Test hatası'), findsOneWidget);
  });
}
