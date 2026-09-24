// test/features/gameplay/widgets/result_dialog_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kelime_oyunu/core/constants/game_constants.dart';
import 'package:kelime_oyunu/features/gameplay/bloc/game_state.dart';
import 'package:kelime_oyunu/features/gameplay/widgets/result_dialog.dart';

// Relative import — test helpers are not importable via package: path.
// ignore: always_use_package_imports
import '../../../helpers/localized_app.dart';

void main() {
  Widget harness({
    required GameStatus status,
    int playerScore = 10,
    int botScore = 4,
    int levelId = 5,
    VoidCallback? onReplay,
    VoidCallback? onNext,
    VoidCallback? onLevels,
  }) {
    return localizedApp(
      home: Scaffold(
        body: ResultDialog(
          status: status,
          playerScore: playerScore,
          botScore: botScore,
          botName: 'Rakip',
          levelId: levelId,
          onReplay: onReplay ?? () {},
          onNext: onNext ?? () {},
          onLevels: onLevels ?? () {},
        ),
      ),
    );
  }

  group('ResultDialog outcome title', () {
    testWidgets('shows "KAZANDIN" when the player won', (tester) async {
      await tester.pumpWidget(harness(status: GameStatus.won));
      expect(find.text('KAZANDIN'), findsOneWidget);
    });

    testWidgets('shows "KAYBETTİN" when the player lost', (tester) async {
      await tester.pumpWidget(harness(status: GameStatus.lost));
      expect(find.text('KAYBETTİN'), findsOneWidget);
    });

    testWidgets('shows "BERABERE" on a tie', (tester) async {
      await tester.pumpWidget(harness(status: GameStatus.tie));
      expect(find.text('BERABERE'), findsOneWidget);
    });
  });

  testWidgets('renders the "Bölüm X / N" progress label against kLastLevelId', (tester) async {
    await tester.pumpWidget(harness(status: GameStatus.won, levelId: 5));
    expect(find.text('Bölüm 5 / $kLastLevelId'), findsOneWidget);
  });

  testWidgets('renders both scores and the absolute difference', (tester) async {
    await tester.pumpWidget(harness(status: GameStatus.won, playerScore: 10, botScore: 4));
    expect(find.text('Sen'), findsOneWidget);
    expect(find.text('10'), findsOneWidget);
    expect(find.text('Rakip'), findsOneWidget);
    expect(find.text('4'), findsOneWidget);
    expect(find.text('fark 6'), findsOneWidget);
  });

  group('hard progression actions', () {
    testWidgets('offers the next level only after a win on a non-final level', (tester) async {
      await tester.pumpWidget(harness(status: GameStatus.won, levelId: 5));
      expect(find.text('Bölüm 6 · tırmanmaya devam'), findsOneWidget);
      expect(find.text('Tekrar oyna'), findsOneWidget);
      expect(find.text('Tüm bölümleri bitirdin! 🎉'), findsNothing);
    });

    testWidgets('hides the next level after a loss — only "Tekrar oyna"', (tester) async {
      await tester.pumpWidget(harness(status: GameStatus.lost, levelId: 5));
      expect(find.text('Bölüm 6 · tırmanmaya devam'), findsNothing);
      expect(find.text('Tüm bölümleri bitirdin! 🎉'), findsNothing);
      expect(find.text('Tekrar oyna'), findsOneWidget);
    });

    testWidgets('hides the next level on a tie — a draw does not advance', (tester) async {
      await tester.pumpWidget(harness(status: GameStatus.tie, levelId: 5));
      expect(find.text('Bölüm 6 · tırmanmaya devam'), findsNothing);
      expect(find.text('Tekrar oyna'), findsOneWidget);
    });

    testWidgets('congratulates only when the final level is won', (tester) async {
      await tester.pumpWidget(harness(status: GameStatus.won, levelId: kLastLevelId));
      expect(find.text('Bölüm 6 · tırmanmaya devam'), findsNothing);
      expect(find.text('Tüm bölümleri bitirdin! 🎉'), findsOneWidget);
      expect(find.text('Tekrar oyna'), findsOneWidget);
    });

    testWidgets('does not congratulate when the final level is lost', (tester) async {
      await tester.pumpWidget(harness(status: GameStatus.lost, levelId: kLastLevelId));
      expect(find.text('Tüm bölümleri bitirdin! 🎉'), findsNothing);
      expect(find.text('Bölüm 6 · tırmanmaya devam'), findsNothing);
      expect(find.text('Tekrar oyna'), findsOneWidget);
    });

    testWidgets('fires onNext / onReplay when the buttons are tapped', (tester) async {
      var next = 0;
      var replay = 0;
      await tester.pumpWidget(
        harness(status: GameStatus.won, levelId: 5, onNext: () => next++, onReplay: () => replay++),
      );
      await tester.tap(find.text('Bölüm 6 · tırmanmaya devam'));
      await tester.tap(find.text('Tekrar oyna'));
      await tester.pump();
      expect(next, 1);
      expect(replay, 1);
    });

    testWidgets('offers the level grid on every outcome — back is disabled here', (tester) async {
      for (final status in [GameStatus.won, GameStatus.lost, GameStatus.tie]) {
        await tester.pumpWidget(harness(status: status, levelId: 5));
        expect(find.text('Bölümler'), findsOneWidget, reason: 'no way out of a $status board');
      }
    });

    testWidgets('fires onLevels when the grid button is tapped', (tester) async {
      var levels = 0;
      await tester.pumpWidget(
        harness(status: GameStatus.lost, levelId: 5, onLevels: () => levels++),
      );

      await tester.tap(find.text('Bölümler'));
      await tester.pump();

      expect(levels, 1);
    });
  });
}
