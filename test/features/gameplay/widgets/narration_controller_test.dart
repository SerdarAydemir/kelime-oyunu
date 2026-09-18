// test/features/gameplay/widgets/narration_controller_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kelime_oyunu/data/models/puzzle.dart';
import 'package:kelime_oyunu/features/gameplay/bloc/game_state.dart';
import 'package:kelime_oyunu/features/gameplay/bloc/move_narration.dart';
import 'package:kelime_oyunu/features/gameplay/engine/rack_manager.dart';
import 'package:kelime_oyunu/features/gameplay/engine/score_engine.dart';
import 'package:kelime_oyunu/features/gameplay/widgets/narration_controller.dart';
import 'package:kelime_oyunu/features/gameplay/widgets/narration_timeline.dart';

// ignore: always_use_package_imports
import '../../../helpers/engine_test_fixtures.dart';

final _puzzle = puzzleFromWords([
  buildWord(id: 'w1', answer: 'KOLA', startRow: 1, startCol: 1, direction: ClueArrow.right),
]);

const _c1 = WordCell(row: 1, col: 1);
const _c2 = WordCell(row: 1, col: 2);
const _c3 = WordCell(row: 1, col: 3);
const _c4 = WordCell(row: 1, col: 4);

GameActive _stateWith(MoveNarration narration) => GameActive(
  puzzle: _puzzle,
  board: const {},
  rack: const [],
  pendingPlacements: const [],
  playerScore: 0,
  botScore: 0,
  phase: TurnPhase.playerTurn,
  botThinking: false,
  status: GameStatus.playing,
  rackSize: RackManager.baseRackSize,
  revealedWordIds: const {},
  narration: narration,
);

// The player's confirmed letter: scores in place, never flies.
const _playerMove = MoveNarration(
  id: 1,
  actor: NarrationActor.player,
  events: [ScoreEvent(cell: _c1, delta: 1)],
  placements: [Placement(cell: _c1, letter: 'K', expected: 'K')],
);

// The bot's reply, committed to the board in the same state: two correct
// letters that fly in, plus one wrong letter that bounces home.
const _botMove = MoveNarration(
  id: 2,
  actor: NarrationActor.bot,
  events: [
    ScoreEvent(cell: _c2, delta: 1),
    ScoreEvent(cell: _c3, delta: 1),
    ScoreEvent(cell: _c4, delta: -1),
  ],
  placements: [
    Placement(cell: _c2, letter: 'O', expected: 'O'),
    Placement(cell: _c3, letter: 'L', expected: 'L'),
    Placement(cell: _c4, letter: 'Z', expected: 'A'),
  ],
);

/// Gives the controller a real ticker so `tester.pump` drives its clock.
class _Host extends StatefulWidget {
  const _Host({required this.onReady});

  final ValueChanged<NarrationController> onReady;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> with SingleTickerProviderStateMixin {
  late final NarrationController controller;

  @override
  void initState() {
    super.initState();
    controller = NarrationController(vsync: this);
    widget.onReady(controller);
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

Duration _ms(num ms) => Duration(milliseconds: ms.ceil());

NarrationCue _letterCue(NarrationTimeline t, WordCell cell) =>
    t.cues.firstWhere((c) => c.kind == CueKind.letter && c.event.cell == cell);

void main() {
  testWidgets('queued bot letters stay hidden until their own timeline lands them', (tester) async {
    late NarrationController controller;
    await tester.pumpWidget(_Host(onReady: (c) => controller = c));

    controller.sync(_stateWith(_playerMove));
    controller.sync(_stateWith(_botMove)); // queued behind the player's story
    await tester.pump();

    expect(controller.currentActor, NarrationActor.player);
    // From the very first frame: the bot's committed letters are hidden, the
    // player's own letter is not, and the bot's wrong letter (never on the
    // board — the overlay ghosts it home) is not either.
    expect(controller.suppressedCells, {_c2, _c3});

    // Let the player's story finish: the bot's starts at progress 0.
    final playerMs = controller.currentTimeline!.totalMs;
    await tester.pump(_ms(playerMs + 1));
    expect(controller.currentActor, NarrationActor.bot);
    expect(controller.suppressedCells, {_c2, _c3}, reason: 'nothing has landed yet');

    // Advance just past the first bot letter's landing: only it becomes visible.
    final bot = controller.currentTimeline!;
    final botMs = bot.totalMs;
    final land2 = _letterCue(bot, _c2).landAt * botMs;
    final land3 = _letterCue(bot, _c3).landAt * botMs;
    await tester.pump(_ms(land2 + 1));
    expect(controller.suppressedCells, {_c3});

    await tester.pump(_ms(land3 - land2 + 1));
    expect(controller.suppressedCells, isEmpty);

    // Drain the queue so the ticker is idle before teardown.
    await tester.pumpAndSettle();
    expect(controller.narrating, isFalse);
  });

  testWidgets('a player-only narration never suppresses anything', (tester) async {
    late NarrationController controller;
    await tester.pumpWidget(_Host(onReady: (c) => controller = c));

    controller.sync(_stateWith(_playerMove));
    await tester.pump();
    expect(controller.suppressedCells, isEmpty);
    await tester.pumpAndSettle();
  });
}
