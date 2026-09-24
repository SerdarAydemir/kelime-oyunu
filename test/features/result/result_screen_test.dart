// test/features/result/result_screen_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:kelime_oyunu/core/constants/game_constants.dart';
import 'package:kelime_oyunu/features/gameplay/bloc/game_state.dart';
import 'package:kelime_oyunu/features/result/view/result_screen.dart';

// Relative import — test helpers are not importable via package: path.
// ignore: always_use_package_imports
import '../../helpers/localized_app.dart';

/// Pumps the result screen in a router that records where a tap navigates to.
Future<String?> _pump(
  WidgetTester tester, {
  required GameStatus status,
  int levelId = 5,
  int playerScore = 10,
  int botScore = 4,
  Future<void> Function(WidgetTester tester)? act,
}) async {
  String? destination;
  Widget capture(GoRouterState state) {
    destination = state.uri.toString();
    return const Scaffold(body: Text('elsewhere'));
  }

  final router = GoRouter(
    initialLocation: ResultScreen.location(
      status: status,
      levelId: levelId,
      playerScore: playerScore,
      botScore: botScore,
    ),
    routes: [
      GoRoute(
        path: '/result/:levelId',
        builder: (_, s) {
          final q = s.uri.queryParameters;
          return ResultScreen(
            status: GameStatus.values.byName(q['status']!),
            levelId: int.parse(s.pathParameters['levelId']!),
            playerScore: int.parse(q['p']!),
            botScore: int.parse(q['b']!),
            botName: 'Rakip',
          );
        },
      ),
      GoRoute(path: '/gameplay/:levelId', builder: (_, s) => capture(s)),
      GoRoute(path: '/map', builder: (_, s) => capture(s)),
    ],
  );
  await tester.pumpWidget(localizedRouterApp(router));
  await tester.pumpAndSettle();
  if (act != null) {
    await act(tester);
    await tester.pumpAndSettle();
  }
  return destination;
}

void main() {
  test('location encodes the outcome for the route', () {
    expect(
      ResultScreen.location(status: GameStatus.won, levelId: 5, playerScore: 12, botScore: 9),
      '/result/5?status=won&p=12&b=9',
    );
  });

  group('outcome', () {
    testWidgets('won: dawn copy, altitude pill, scores and the gap', (tester) async {
      await _pump(tester, status: GameStatus.won);
      expect(find.text('BÖLÜM 5 · KAZANDIN'), findsOneWidget);
      expect(find.text('Bir adım daha\nzirveye'), findsOneWidget);
      expect(find.textContaining('+40 m → '), findsOneWidget);
      expect(find.text('Sen'), findsOneWidget);
      expect(find.text('10'), findsOneWidget);
      expect(find.text('Rakip'), findsOneWidget);
      expect(find.text('4'), findsOneWidget);
      expect(find.text('fark 6'), findsOneWidget);
    });

    testWidgets('lost: camp copy with retry and map', (tester) async {
      await _pump(tester, status: GameStatus.lost);
      expect(find.text('BÖLÜM 5 · KAYBETTİN'), findsOneWidget);
      expect(find.text('Kampta\nbir gece daha'), findsOneWidget);
      expect(find.textContaining('Rakip bu eli aldı'), findsOneWidget);
      expect(find.text('Tekrar dene'), findsOneWidget);
      expect(find.text('Haritaya dön'), findsOneWidget);
      expect(find.textContaining('tırmanmaya devam'), findsNothing);
    });

    testWidgets('draw: behaves like lost with its own copy', (tester) async {
      await _pump(tester, status: GameStatus.tie);
      expect(find.text('BÖLÜM 5 · BERABERE'), findsOneWidget);
      expect(find.text('Berabere ·\nRakiple başa baş'), findsOneWidget);
      expect(find.textContaining('Puanlar eşit'), findsOneWidget);
      expect(find.text('Tekrar dene'), findsOneWidget);
      expect(find.text('Haritaya dön'), findsOneWidget);
    });
  });

  group('hard progression actions', () {
    testWidgets('offers the next level only after a win on a non-final level', (tester) async {
      await _pump(tester, status: GameStatus.won, levelId: 5);
      expect(find.text('Bölüm 6 · tırmanmaya devam'), findsOneWidget);
      expect(find.text('Tekrar oyna'), findsOneWidget);
      expect(find.text('Harita'), findsOneWidget);
      expect(find.text('Tüm bölümleri bitirdin! 🎉'), findsNothing);
    });

    testWidgets('congratulates and hides the next level when the final level is won', (
      tester,
    ) async {
      await _pump(tester, status: GameStatus.won, levelId: kLastLevelId);
      expect(find.textContaining('tırmanmaya devam'), findsNothing);
      expect(find.text('Tüm bölümleri bitirdin! 🎉'), findsOneWidget);
      expect(find.text('Tekrar oyna'), findsOneWidget);
    });

    testWidgets('does not congratulate when the final level is lost', (tester) async {
      await _pump(tester, status: GameStatus.lost, levelId: kLastLevelId);
      expect(find.text('Tüm bölümleri bitirdin! 🎉'), findsNothing);
      expect(find.text('Tekrar dene'), findsOneWidget);
    });

    testWidgets('next / replay / map navigate', (tester) async {
      expect(
        await _pump(
          tester,
          status: GameStatus.won,
          act: (t) => t.tap(find.text('Bölüm 6 · tırmanmaya devam')),
        ),
        '/gameplay/6',
      );
      expect(
        await _pump(tester, status: GameStatus.won, act: (t) => t.tap(find.text('Tekrar oyna'))),
        '/gameplay/5',
      );
      expect(
        await _pump(tester, status: GameStatus.won, act: (t) => t.tap(find.text('Harita'))),
        '/map',
      );
      expect(
        await _pump(tester, status: GameStatus.lost, act: (t) => t.tap(find.text('Tekrar dene'))),
        '/gameplay/5',
      );
      expect(
        await _pump(tester, status: GameStatus.tie, act: (t) => t.tap(find.text('Haritaya dön'))),
        '/map',
      );
    });
  });
}
