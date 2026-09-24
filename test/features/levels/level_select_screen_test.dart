// test/features/levels/level_select_screen_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:kelime_oyunu/core/config/dev_flags.dart';
import 'package:kelime_oyunu/core/constants/game_constants.dart';
import 'package:kelime_oyunu/data/models/saved_session.dart';
import 'package:kelime_oyunu/data/repositories/progress_repository.dart';
import 'package:kelime_oyunu/data/repositories/session_repository.dart';
import 'package:kelime_oyunu/features/levels/cubit/level_select_state.dart';
import 'package:kelime_oyunu/features/levels/view/level_select_screen.dart';
import 'package:kelime_oyunu/features/levels/widgets/level_tile.dart';
import 'package:kelime_oyunu/features/levels/widgets/resume_banner.dart';

// Relative import — test helpers are not importable via package: path.
// ignore: always_use_package_imports
import '../../helpers/localized_app.dart';

SavedSession _session({int levelId = 3}) => SavedSession(
  levelId: levelId,
  board: const {},
  rackLetters: const ['A'],
  playerScore: 12,
  botScore: 8,
  rackSize: 5,
  revealedWordIds: const {},
  swapQuotaRemaining: 12,
  botPlacedCells: const {},
);

/// Pumps the screen inside a router that records where a tap navigates to.
Future<String?> _pumpAndTap(
  WidgetTester tester, {
  required int highestCompletedLevel,
  SavedSession? saved,
  bool unlockAll = false,
  required Future<void> Function(WidgetTester tester) act,
}) async {
  String? destination;
  final router = GoRouter(
    initialLocation: '/levels',
    routes: [
      GoRoute(
        path: '/levels',
        builder: (context, state) => LevelSelectScreen(
          progressRepo: InMemoryProgressRepository(highestCompletedLevel: highestCompletedLevel),
          sessionRepo: InMemorySessionRepository(initial: saved),
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
    ],
  );
  await tester.pumpWidget(localizedRouterApp(router));
  await tester.pumpAndSettle();
  await act(tester);
  await tester.pumpAndSettle();
  return destination;
}

LevelTile _tile(WidgetTester tester, int levelId) =>
    tester.widget<LevelTile>(find.byWidgetPredicate((w) => w is LevelTile && w.levelId == levelId));

void main() {
  group('lock state', () {
    testWidgets('a new player may only play level 1', (tester) async {
      await _pumpAndTap(tester, highestCompletedLevel: 0, act: (_) async {});

      expect(_tile(tester, 1).status, LevelStatus.current);
      expect(_tile(tester, 1).onTap, isNotNull);
      expect(_tile(tester, 2).status, LevelStatus.locked);
      // A locked level is inert, not merely styled as dead.
      expect(_tile(tester, 2).onTap, isNull);
    });

    testWidgets('won levels stay replayable and the frontier is highlighted', (tester) async {
      await _pumpAndTap(tester, highestCompletedLevel: 3, act: (_) async {});

      expect(_tile(tester, 1).status, LevelStatus.completed);
      expect(_tile(tester, 3).status, LevelStatus.completed);
      expect(_tile(tester, 3).onTap, isNotNull);
      expect(_tile(tester, 4).status, LevelStatus.current);
      expect(_tile(tester, 5).status, LevelStatus.locked);
    });

    testWidgets('progress line reports how far the player has come', (tester) async {
      await _pumpAndTap(tester, highestCompletedLevel: 7, act: (_) async {});

      expect(find.text('7/$kLastLevelId bölüm tamamlandı'), findsOneWidget);
    });
  });

  group('navigation', () {
    testWidgets('tapping an unlocked level opens it fresh (no resume flag)', (tester) async {
      final destination = await _pumpAndTap(
        tester,
        highestCompletedLevel: 2,
        act: (tester) =>
            tester.tap(find.byWidgetPredicate((w) => w is LevelTile && w.levelId == 1)),
      );

      expect(destination, '/gameplay/1');
    });

    testWidgets('tapping a locked level goes nowhere', (tester) async {
      final destination = await _pumpAndTap(
        tester,
        highestCompletedLevel: 0,
        act: (tester) => tester.tap(
          find.byWidgetPredicate((w) => w is LevelTile && w.levelId == 5),
          warnIfMissed: false,
        ),
      );

      expect(destination, isNull);
    });
  });

  group('DEV_UNLOCK_ALL override', () {
    test('the compile-time flag is off in the test build', () {
      expect(kDevUnlockAll, isFalse);
    });

    test('unlockAll makes a locked level playable without changing its status', () {
      const state = LevelSelectState(highestCompletedLevel: 0, unlockAll: true);
      expect(state.statusOf(kLastLevelId), LevelStatus.locked);
      expect(state.isPlayable(kLastLevelId), isTrue);
      expect(const LevelSelectState(highestCompletedLevel: 0).isPlayable(2), isFalse);
    });

    testWidgets('with the override a locked level opens and a DEV tag shows', (tester) async {
      final destination = await _pumpAndTap(
        tester,
        highestCompletedLevel: 0,
        unlockAll: true,
        act: (tester) async {
          expect(find.text('DEV'), findsOneWidget);
          await tester.tap(find.byWidgetPredicate((w) => w is LevelTile && w.levelId == 5));
        },
      );

      expect(destination, '/gameplay/5');
    });

    testWidgets('with the override locked tiles show their number', (tester) async {
      await _pumpAndTap(
        tester,
        highestCompletedLevel: 0,
        unlockAll: true,
        act: (tester) async {
          final last = find.byWidgetPredicate((w) => w is LevelTile && w.levelId == kLastLevelId);
          await tester.scrollUntilVisible(last, 200, scrollable: find.byType(Scrollable).first);
          expect(_tile(tester, kLastLevelId).status, LevelStatus.locked);
          expect(find.descendant(of: last, matching: find.text('$kLastLevelId')), findsOneWidget);
          expect(find.descendant(of: last, matching: find.byIcon(Icons.lock)), findsNothing);
        },
      );
    });

    testWidgets('without the override locked tiles keep the padlock, no number', (tester) async {
      await _pumpAndTap(
        tester,
        highestCompletedLevel: 0,
        act: (tester) async {
          final last = find.byWidgetPredicate((w) => w is LevelTile && w.levelId == kLastLevelId);
          await tester.scrollUntilVisible(last, 200, scrollable: find.byType(Scrollable).first);
          expect(find.descendant(of: last, matching: find.text('$kLastLevelId')), findsNothing);
          expect(find.descendant(of: last, matching: find.byIcon(Icons.lock)), findsOneWidget);
        },
      );
    });

    testWidgets('without the override there is no DEV tag', (tester) async {
      await _pumpAndTap(
        tester,
        highestCompletedLevel: 0,
        act: (tester) async => expect(find.text('DEV'), findsNothing),
      );
    });
  });

  group('resume entry', () {
    testWidgets('a half-played match is offered up front with its score', (tester) async {
      await _pumpAndTap(tester, highestCompletedLevel: 2, saved: _session(), act: (_) async {});

      expect(find.byType(ResumeBanner), findsOneWidget);
      expect(find.text('Yarım kalan oyun'), findsOneWidget);
      expect(find.text('Bölüm 3 · Sen 12 – Rakip 8'), findsOneWidget);
    });

    testWidgets('no banner when there is nothing to continue', (tester) async {
      await _pumpAndTap(tester, highestCompletedLevel: 2, act: (_) async {});

      expect(find.byType(ResumeBanner), findsNothing);
    });

    testWidgets('continuing asks for a restore, not a restart', (tester) async {
      final destination = await _pumpAndTap(
        tester,
        highestCompletedLevel: 2,
        saved: _session(),
        act: (tester) => tester.tap(find.byType(ResumeBanner)),
      );

      expect(destination, '/gameplay/3?resume=true');
    });
  });
}
