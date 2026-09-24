// test/features/map/climb_map_screen_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:kelime_oyunu/core/config/dev_flags.dart';
import 'package:kelime_oyunu/data/repositories/progress_repository.dart';
import 'package:kelime_oyunu/features/map/cubit/map_state.dart';
import 'package:kelime_oyunu/features/map/view/climb_map_screen.dart';
import 'package:kelime_oyunu/features/map/widgets/map_nodes.dart';

// Relative import — test helpers are not importable via package: path.
// ignore: always_use_package_imports
import '../../helpers/localized_app.dart';

/// Pumps the map inside a router that records where a tap navigates to.
Future<String?> _pumpAndTap(
  WidgetTester tester, {
  required int highestCompletedLevel,
  bool unlockAll = false,
  required Future<void> Function(WidgetTester tester) act,
}) async {
  String? destination;
  final router = GoRouter(
    initialLocation: '/map',
    routes: [
      GoRoute(
        path: '/map',
        builder: (context, state) => ClimbMapScreen(
          progressRepo: InMemoryProgressRepository(highestCompletedLevel: highestCompletedLevel),
          unlockAll: unlockAll,
        ),
      ),
      GoRoute(
        path: '/gameplay/:levelId',
        builder: (context, state) {
          destination = state.uri.toString();
          return const Scaffold(body: Text('gameplay'));
        },
      ),
      GoRoute(
        path: '/',
        builder: (_, _) => const Scaffold(body: Text('home')),
      ),
    ],
  );
  await tester.pumpWidget(localizedRouterApp(router));
  await tester.pump();
  await act(tester);
  await tester.pump();
  return destination;
}

Finder _node(int level) => find.byWidgetPredicate((w) => w is MapNode && w.level == level);

MapNode _nodeWidget(WidgetTester tester, int level) => tester.widget<MapNode>(_node(level));

void main() {
  group('node states', () {
    testWidgets('a new player may only play level 1; far nodes are painted, not built', (
      tester,
    ) async {
      await _pumpAndTap(tester, highestCompletedLevel: 0, act: (_) async {});

      expect(_nodeWidget(tester, 1).kind, MapNodeKind.current);
      expect(_nodeWidget(tester, 1).onTap, isNotNull);
      expect(_nodeWidget(tester, 2).kind, MapNodeKind.upcoming);
      // A locked node is inert, not merely styled as dead.
      expect(_nodeWidget(tester, 2).onTap, isNull);
      expect(_node(5), findsNothing);
      expect(find.text('BURADASIN'), findsOneWidget);
    });

    testWidgets('won levels stay replayable and the frontier is highlighted', (tester) async {
      await _pumpAndTap(tester, highestCompletedLevel: 3, act: (_) async {});

      expect(_nodeWidget(tester, 1).kind, MapNodeKind.done);
      expect(_nodeWidget(tester, 3).onTap, isNotNull);
      expect(_nodeWidget(tester, 4).kind, MapNodeKind.current);
      expect(_nodeWidget(tester, 5).kind, MapNodeKind.upcoming);
    });

    testWidgets('the header shows the current level and altitude, never the total', (tester) async {
      await _pumpAndTap(tester, highestCompletedLevel: 7, act: (_) async {});

      expect(find.text('TIRMANIŞ'), findsOneWidget);
      expect(find.text('Bölüm 8 · 280 m'), findsOneWidget);
      expect(find.text('yukarısı sisin içinde…'), findsOneWidget);
      expect(find.text('Kamp · başlangıç'), findsOneWidget);
      expect(find.textContaining('200'), findsNothing);
    });
  });

  group('navigation', () {
    testWidgets('tapping a won level opens it fresh (no resume flag)', (tester) async {
      final destination = await _pumpAndTap(
        tester,
        highestCompletedLevel: 2,
        act: (tester) => tester.tap(_node(1)),
      );

      expect(destination, '/gameplay/1');
    });

    testWidgets('tapping the frontier opens it', (tester) async {
      final destination = await _pumpAndTap(
        tester,
        highestCompletedLevel: 2,
        act: (tester) => tester.tap(_node(3)),
      );

      expect(destination, '/gameplay/3');
    });

    testWidgets('tapping a locked level goes nowhere', (tester) async {
      final destination = await _pumpAndTap(
        tester,
        highestCompletedLevel: 0,
        act: (tester) => tester.tap(_node(3), warnIfMissed: false),
      );

      expect(destination, isNull);
    });

    testWidgets('the back arrow returns home', (tester) async {
      await _pumpAndTap(
        tester,
        highestCompletedLevel: 0,
        act: (tester) => tester.tap(find.byIcon(Icons.arrow_back)),
      );
      await tester.pumpAndSettle();
      expect(find.text('home'), findsOneWidget);
    });
  });

  group('DEV_UNLOCK_ALL override', () {
    test('the compile-time flag is off in the test build', () {
      expect(kDevUnlockAll, isFalse);
    });

    testWidgets('with the override far nodes are numbered, tappable, and a DEV tag shows', (
      tester,
    ) async {
      final destination = await _pumpAndTap(
        tester,
        highestCompletedLevel: 0,
        unlockAll: true,
        act: (tester) async {
          expect(find.text('DEV'), findsOneWidget);
          expect(_nodeWidget(tester, 5).kind, MapNodeKind.far);
          expect(find.descendant(of: _node(5), matching: find.text('5')), findsOneWidget);
          await tester.tap(_node(5));
        },
      );

      expect(destination, '/gameplay/5');
    });

    testWidgets('without the override there is no DEV tag and no far numbers', (tester) async {
      await _pumpAndTap(
        tester,
        highestCompletedLevel: 0,
        act: (tester) async {
          expect(find.text('DEV'), findsNothing);
          expect(find.descendant(of: _node(2), matching: find.text('2')), findsNothing);
          expect(find.descendant(of: _node(2), matching: find.byIcon(Icons.lock)), findsOneWidget);
        },
      );
    });
  });
}
