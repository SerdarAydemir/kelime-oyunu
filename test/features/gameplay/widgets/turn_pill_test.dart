// test/features/gameplay/widgets/turn_pill_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kelime_oyunu/data/models/puzzle.dart';
import 'package:kelime_oyunu/features/gameplay/bloc/game_state.dart';
import 'package:kelime_oyunu/features/gameplay/engine/rack_manager.dart';
import 'package:kelime_oyunu/features/gameplay/engine/score_engine.dart';
import 'package:kelime_oyunu/features/gameplay/widgets/level_top_bar.dart';
import 'package:kelime_oyunu/features/gameplay/widgets/score_header.dart';
import 'package:kelime_oyunu/features/gameplay/widgets/turn_pill.dart';
import 'package:kelime_oyunu/l10n/generated/app_localizations.dart';

// Relative imports — test helpers are not importable via package: path.
// ignore_for_file: always_use_package_imports
import '../../../helpers/engine_test_fixtures.dart';
import '../../../helpers/localized_app.dart';

final _puzzle = puzzleFromWords([
  buildWord(id: 'w1', answer: 'KOL', startRow: 1, startCol: 1, direction: ClueArrow.right),
]);

GameActive _state({
  TurnPhase phase = TurnPhase.playerTurn,
  bool botThinking = false,
  List<Placement> pending = const [],
  int selected = -1,
}) => GameActive(
  puzzle: _puzzle,
  board: const {},
  rack: const [
    RackTile(letter: 'K'),
    RackTile(letter: 'O'),
  ],
  pendingPlacements: pending,
  playerScore: 0,
  botScore: 0,
  phase: phase,
  botThinking: botThinking,
  status: GameStatus.playing,
  rackSize: RackManager.baseRackSize,
  revealedWordIds: const {},
  selectedRackIndex: selected,
);

Future<AppLocalizations> _l10n(WidgetTester tester) async {
  late AppLocalizations l10n;
  await tester.pumpWidget(
    localizedApp(
      home: Builder(
        builder: (context) {
          l10n = AppLocalizations.of(context);
          return const SizedBox();
        },
      ),
    ),
  );
  return l10n;
}

void main() {
  testWidgets('turnPillFor picks the README text and tint per state', (tester) async {
    final l10n = await _l10n(tester);
    expect(turnPillFor(_state(), l10n), (text: 'Sıra sende', tint: TurnTint.player, dots: false));
    expect(turnPillFor(_state(selected: 1), l10n), (
      text: 'Boş bir hücreye dokun',
      tint: TurnTint.player,
      dots: false,
    ));
    expect(
      turnPillFor(
        _state(
          pending: const [Placement(cell: WordCell(row: 1, col: 1), letter: 'K', expected: 'K')],
        ),
        l10n,
      ),
      (text: '1 harf bekliyor · onayla', tint: TurnTint.player, dots: false),
    );
    expect(turnPillFor(_state(phase: TurnPhase.botThinking, botThinking: true), l10n), (
      text: 'Rakip düşünüyor',
      tint: TurnTint.bot,
      dots: true,
    ));
  });

  testWidgets('ScoreHeader shows both names, both scores and VS', (tester) async {
    await tester.pumpWidget(
      localizedApp(
        home: const Scaffold(
          body: ScoreHeader(playerScore: 12, botScore: 9, botName: 'Rakip', botThinking: false),
        ),
      ),
    );
    expect(find.text('Sen'), findsOneWidget);
    expect(find.text('Rakip'), findsOneWidget);
    expect(find.text('12'), findsOneWidget);
    expect(find.text('9'), findsOneWidget);
    expect(find.text('VS'), findsOneWidget);
  });

  testWidgets('LevelTopBar shows the BÖLÜM tag and the number, never the total', (tester) async {
    await tester.pumpWidget(
      localizedApp(
        home: Scaffold(body: LevelTopBar(levelId: 7, onExit: () {})),
      ),
    );
    expect(find.text('BÖLÜM'), findsOneWidget);
    expect(find.text('7'), findsOneWidget);
    expect(find.textContaining('/'), findsNothing);
    expect(find.byIcon(Icons.arrow_back), findsOneWidget);
    expect(find.byIcon(Icons.more_horiz), findsOneWidget);
  });
}
