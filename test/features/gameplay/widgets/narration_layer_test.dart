// test/features/gameplay/widgets/narration_layer_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kelime_oyunu/data/models/puzzle.dart';
import 'package:kelime_oyunu/features/gameplay/bloc/game_state.dart';
import 'package:kelime_oyunu/features/gameplay/bloc/move_narration.dart';
import 'package:kelime_oyunu/features/gameplay/engine/rack_manager.dart';
import 'package:kelime_oyunu/features/gameplay/engine/score_engine.dart';
import 'package:kelime_oyunu/features/gameplay/widgets/narration_controller.dart';
import 'package:kelime_oyunu/features/gameplay/widgets/narration_layer.dart';

// ignore: always_use_package_imports
import '../../../helpers/engine_test_fixtures.dart';

final _puzzle = puzzleFromWords([
  buildWord(id: 'w1', answer: 'KOL', startRow: 1, startCol: 1, direction: ClueArrow.right),
]);

const _c1 = WordCell(row: 1, col: 1);
const _c2 = WordCell(row: 1, col: 2);

GameActive _stateWith(MoveNarration narration, {int playerScore = 0, int botScore = 0}) {
  return GameActive(
    puzzle: _puzzle,
    board: const {},
    rack: const [],
    pendingPlacements: const [],
    playerScore: playerScore,
    botScore: botScore,
    phase: TurnPhase.playerTurn,
    botThinking: false,
    status: GameStatus.playing,
    rackSize: RackManager.baseRackSize,
    revealedWordIds: const {},
    narration: narration,
  );
}

/// Hosts a real [NarrationController] against the test vsync so `tester.pump`
/// drives the score-story clock deterministically.
class _Host extends StatefulWidget {
  const _Host({required this.state});

  final GameActive state;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> with SingleTickerProviderStateMixin {
  late final NarrationController controller;

  @override
  void initState() {
    super.initState();
    controller = NarrationController(vsync: this);
    controller.sync(widget.state);
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Column(
          children: [
            AnimatedBuilder(
              animation: controller,
              builder: (_, _) => Text('P${controller.displayPlayerScore}'),
            ),
            Expanded(
              child: NarrationLayer(controller: controller, puzzle: widget.state.puzzle),
            ),
          ],
        ),
      ),
    );
  }
}

void main() {
  testWidgets('counts the score up cue by cue and pops +1 badges on the wave', (tester) async {
    final state = _stateWith(
      const MoveNarration(
        id: 1,
        actor: NarrationActor.player,
        events: [
          ScoreEvent(cell: _c1, delta: 1),
          ScoreEvent(cell: _c2, delta: 1),
        ],
        placements: [
          Placement(cell: _c1, letter: 'K', expected: 'K'),
          Placement(cell: _c2, letter: 'O', expected: 'O'),
        ],
      ),
      playerScore: 2, // post-move total; the counter walks 0 → 2
    );

    await tester.pumpWidget(_Host(state: state));
    await tester.pump(); // kick the controller's forward()

    // Starts at the pre-move value, not the bloc total.
    expect(find.text('P0'), findsOneWidget);

    var sawBadge = false;
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 30));
      if (find.text('+1').evaluate().isNotEmpty) sawBadge = true;
    }

    // A +1 badge was on screen during the wave, and the counter settled on the
    // final total exactly (never jumped past it).
    expect(sawBadge, isTrue, reason: 'expected a +1 badge to appear during the wave');

    await tester.pumpAndSettle();
    expect(find.text('P2'), findsOneWidget);
    expect(find.text('+1'), findsNothing); // badges gone once the story ends
  });

  testWidgets('a −1 badge shows for a wrong letter', (tester) async {
    final state = _stateWith(
      const MoveNarration(
        id: 2,
        actor: NarrationActor.player,
        events: [ScoreEvent(cell: _c1, delta: -1)],
        placements: [Placement(cell: _c1, letter: 'Z', expected: 'K')],
      ),
      playerScore: -1,
    );

    await tester.pumpWidget(_Host(state: state));
    await tester.pump();

    var sawNeg = false;
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 30));
      if (find.text('-1').evaluate().isNotEmpty) sawNeg = true;
    }
    expect(sawNeg, isTrue, reason: 'expected a -1 badge for the wrong letter');

    await tester.pumpAndSettle();
    expect(find.text('P-1'), findsOneWidget);
  });
}
