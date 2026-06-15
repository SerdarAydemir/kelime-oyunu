// test/features/gameplay/widgets/result_dialog_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kelime_oyunu/core/constants/game_constants.dart';
import 'package:kelime_oyunu/features/gameplay/bloc/game_state.dart';
import 'package:kelime_oyunu/features/gameplay/widgets/result_dialog.dart';

void main() {
  Widget harness({
    required GameStatus status,
    int playerScore = 10,
    int botScore = 4,
    int levelId = 5,
    VoidCallback? onReplay,
    VoidCallback? onNext,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: ResultDialog(
          status: status,
          playerScore: playerScore,
          botScore: botScore,
          botName: 'Sokrates',
          levelId: levelId,
          onReplay: onReplay ?? () {},
          onNext: onNext ?? () {},
        ),
      ),
    );
  }

  group('ResultDialog outcome title', () {
    testWidgets('shows "Kazandın!" when the player won', (tester) async {
      await tester.pumpWidget(harness(status: GameStatus.won));
      expect(find.text('Kazandın! 🎉'), findsOneWidget);
    });

    testWidgets('shows "Kaybettin" when the player lost', (tester) async {
      await tester.pumpWidget(harness(status: GameStatus.lost));
      expect(find.text('Kaybettin'), findsOneWidget);
    });

    testWidgets('shows "Berabere" on a tie', (tester) async {
      await tester.pumpWidget(harness(status: GameStatus.tie));
      expect(find.text('Berabere'), findsOneWidget);
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
    expect(find.text('Sokrates'), findsOneWidget);
    expect(find.text('4'), findsOneWidget);
    expect(find.text('Fark: 6'), findsOneWidget);
  });

  group('hard progression actions', () {
    testWidgets('offers "Sonraki Bölüm" only after a win on a non-final level', (tester) async {
      await tester.pumpWidget(harness(status: GameStatus.won, levelId: 5));
      expect(find.text('Sonraki Bölüm'), findsOneWidget);
      expect(find.text('Tekrar Oyna'), findsOneWidget);
      expect(find.text('Tüm bölümleri bitirdin! 🎉'), findsNothing);
    });

    testWidgets('hides "Sonraki Bölüm" after a loss — only "Tekrar Oyna"', (tester) async {
      await tester.pumpWidget(harness(status: GameStatus.lost, levelId: 5));
      expect(find.text('Sonraki Bölüm'), findsNothing);
      expect(find.text('Tüm bölümleri bitirdin! 🎉'), findsNothing);
      expect(find.text('Tekrar Oyna'), findsOneWidget);
    });

    testWidgets('hides "Sonraki Bölüm" on a tie — a draw does not advance', (tester) async {
      await tester.pumpWidget(harness(status: GameStatus.tie, levelId: 5));
      expect(find.text('Sonraki Bölüm'), findsNothing);
      expect(find.text('Tekrar Oyna'), findsOneWidget);
    });

    testWidgets('congratulates only when the final level is won', (tester) async {
      await tester.pumpWidget(harness(status: GameStatus.won, levelId: kLastLevelId));
      expect(find.text('Sonraki Bölüm'), findsNothing);
      expect(find.text('Tüm bölümleri bitirdin! 🎉'), findsOneWidget);
      expect(find.text('Tekrar Oyna'), findsOneWidget);
    });

    testWidgets('does not congratulate when the final level is lost', (tester) async {
      await tester.pumpWidget(harness(status: GameStatus.lost, levelId: kLastLevelId));
      expect(find.text('Tüm bölümleri bitirdin! 🎉'), findsNothing);
      expect(find.text('Sonraki Bölüm'), findsNothing);
      expect(find.text('Tekrar Oyna'), findsOneWidget);
    });

    testWidgets('fires onNext / onReplay when the buttons are tapped', (tester) async {
      var next = 0;
      var replay = 0;
      await tester.pumpWidget(
        harness(status: GameStatus.won, levelId: 5, onNext: () => next++, onReplay: () => replay++),
      );
      await tester.tap(find.text('Sonraki Bölüm'));
      await tester.tap(find.text('Tekrar Oyna'));
      await tester.pump();
      expect(next, 1);
      expect(replay, 1);
    });
  });
}
