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
import 'package:kelime_oyunu/features/gameplay/widgets/narration_tiles.dart';

// ignore: always_use_package_imports
import '../../../helpers/engine_test_fixtures.dart';

final _puzzle = puzzleFromWords([
  buildWord(id: 'w1', answer: 'KOL', startRow: 1, startCol: 1, direction: ClueArrow.right),
]);

const _c1 = WordCell(row: 1, col: 1);
const _c2 = WordCell(row: 1, col: 2);
const _c3 = WordCell(row: 1, col: 3);

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
  final GlobalKey _rackKey = GlobalKey();
  final GlobalKey _avatarKey = GlobalKey();

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
            // Flight sources: a laid-out avatar + rack the overlay can anchor to.
            Row(
              children: [
                SizedBox(key: _avatarKey, width: 32, height: 32),
                SizedBox(key: _rackKey, width: 200, height: 48),
              ],
            ),
            Expanded(
              child: NarrationLayer(
                controller: controller,
                puzzle: widget.state.puzzle,
                rackKey: _rackKey,
                botAvatarKey: _avatarKey,
              ),
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

  testWidgets('completing a word raises a frame/glow and settles on the total', (tester) async {
    // KOL completed: +1 per letter (3) then a +3 word bonus → 6 total.
    final state = _stateWith(
      const MoveNarration(
        id: 3,
        actor: NarrationActor.player,
        events: [
          ScoreEvent(cell: _c1, delta: 1),
          ScoreEvent(cell: _c2, delta: 1),
          ScoreEvent(cell: _c3, delta: 1),
          ScoreEvent(delta: 3, completedWordId: 'w1', wordBonus: 3),
        ],
        placements: [
          Placement(cell: _c1, letter: 'K', expected: 'K'),
          Placement(cell: _c2, letter: 'O', expected: 'O'),
          Placement(cell: _c3, letter: 'L', expected: 'L'),
        ],
      ),
      playerScore: 6,
    );

    await tester.pumpWidget(_Host(state: state));
    await tester.pump();

    var sawFrame = false;
    var sawTotalBadge = false;
    for (var i = 0; i < 80; i++) {
      await tester.pump(const Duration(milliseconds: 30));
      if (find.byKey(const ValueKey('frame_w1')).evaluate().isNotEmpty) sawFrame = true;
      // The word bonus is ONE "+3" badge over the lit word, never three +1s.
      if (find.text('+3').evaluate().isNotEmpty) sawTotalBadge = true;
    }
    expect(sawFrame, isTrue, reason: 'expected a word-completion frame to appear');
    expect(sawTotalBadge, isTrue, reason: 'expected a single +3 total badge');

    await tester.pumpAndSettle();
    expect(find.text('P6'), findsOneWidget); // 3 letters + 3 word bonus
  });

  testWidgets('a BOT letter flies in (FlyingTile) then hands off to the board', (tester) async {
    final state = _stateWith(
      const MoveNarration(
        id: 4,
        actor: NarrationActor.bot,
        events: [
          ScoreEvent(cell: _c1, delta: 1),
          ScoreEvent(cell: _c2, delta: 1),
        ],
        placements: [
          Placement(cell: _c1, letter: 'K', expected: 'K'),
          Placement(cell: _c2, letter: 'O', expected: 'O'),
        ],
      ),
      botScore: 2,
    );

    await tester.pumpWidget(_Host(state: state));
    await tester.pump();

    var sawFlight = false;
    for (var i = 0; i < 60; i++) {
      await tester.pump(const Duration(milliseconds: 25));
      if (find.byType(FlyingTile).evaluate().isNotEmpty) sawFlight = true;
    }
    expect(sawFlight, isTrue, reason: 'expected a FlyingTile mid-wave');

    // After the story ends the tiles are gone (handed off to the committed grid).
    await tester.pumpAndSettle();
    expect(find.byType(FlyingTile), findsNothing);
  });

  testWidgets('PLAYER letters never fly — they are evaluated in place with a pulse', (
    tester,
  ) async {
    final state = _stateWith(
      const MoveNarration(
        id: 6,
        actor: NarrationActor.player,
        events: [
          ScoreEvent(cell: _c1, delta: 1),
          ScoreEvent(cell: _c2, delta: -1),
        ],
        placements: [
          Placement(cell: _c1, letter: 'K', expected: 'K'),
          Placement(cell: _c2, letter: 'O', expected: 'X'),
        ],
      ),
      playerScore: 0,
    );

    await tester.pumpWidget(_Host(state: state));
    await tester.pump();

    var sawFlight = false;
    var sawPulse = false;
    for (var i = 0; i < 60; i++) {
      await tester.pump(const Duration(milliseconds: 25));
      if (find.byType(FlyingTile).evaluate().isNotEmpty) sawFlight = true;
      if (find.byType(CellPulse).evaluate().isNotEmpty) sawPulse = true;
    }
    expect(sawFlight, isFalse, reason: 'player letters are already on the board');
    expect(sawPulse, isTrue, reason: 'each letter should flash its cell as it scores');
  });

  testWidgets('tapping to 2x finishes the story by half-time without cancelling', (tester) async {
    final state = _stateWith(
      const MoveNarration(
        id: 5,
        actor: NarrationActor.player,
        events: [
          ScoreEvent(cell: _c1, delta: 1),
          ScoreEvent(cell: _c2, delta: 1),
          ScoreEvent(cell: _c3, delta: 1),
        ],
        placements: [
          Placement(cell: _c1, letter: 'K', expected: 'K'),
          Placement(cell: _c2, letter: 'O', expected: 'O'),
          Placement(cell: _c3, letter: 'L', expected: 'L'),
        ],
      ),
      playerScore: 3,
    );

    await tester.pumpWidget(_Host(state: state));
    await tester.pump();
    final host = tester.state<_HostState>(find.byType(_Host));
    final total = host.controller.currentTimeline!.totalMs;
    expect(host.controller.isSpedUp, isFalse);

    host.controller.toggleSpeed(); // the screen's tap-catcher calls this
    expect(host.controller.isSpedUp, isTrue);
    await tester.pump(); // let the sped-up ticker establish its start frame

    // Less than the full 1× duration — at 1× the story would still be running,
    // but at 2× it is already done and the score fully counted (fast-forward,
    // not a skip).
    await tester.pump(Duration(milliseconds: total - 100));
    await tester.pump();
    expect(host.controller.narrating, isFalse);
    expect(find.text('P3'), findsOneWidget);
  });
}
