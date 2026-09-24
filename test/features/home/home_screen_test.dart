// test/features/home/home_screen_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:kelime_oyunu/data/models/saved_session.dart';
import 'package:kelime_oyunu/data/repositories/progress_repository.dart';
import 'package:kelime_oyunu/data/repositories/session_repository.dart';
import 'package:kelime_oyunu/features/home/view/home_screen.dart';

// Relative import — test helpers are not importable via package: path.
// ignore: always_use_package_imports
import '../../helpers/localized_app.dart';

SavedSession _session() => const SavedSession(
  levelId: 3,
  board: {},
  rackLetters: ['A'],
  playerScore: 12,
  botScore: 9,
  rackSize: 5,
  revealedWordIds: {},
  swapQuotaRemaining: 12,
  botPlacedCells: {},
);

/// Pumps the home screen in a router that records where a tap navigates to.
Future<String?> _pump(
  WidgetTester tester, {
  required ProgressRepository progress,
  SavedSession? saved,
  Future<void> Function(WidgetTester tester)? act,
}) async {
  String? destination;
  Widget capture(GoRouterState state) {
    destination = state.uri.toString();
    return const Scaffold(body: Text('elsewhere'));
  }

  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => HomeScreen(
          progressRepo: progress,
          sessionRepo: InMemorySessionRepository(initial: saved),
        ),
      ),
      GoRoute(path: '/gameplay/:levelId', builder: (_, s) => capture(s)),
      GoRoute(path: '/map', builder: (_, s) => capture(s)),
      GoRoute(path: '/settings', builder: (_, s) => capture(s)),
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
  testWidgets('a new player sees level 1, 0 m, empty stats and the start CTA', (tester) async {
    await _pump(tester, progress: InMemoryProgressRepository());

    expect(find.text('RAKİBE KARŞI ÇENGEL BULMACA'), findsOneWidget);
    expect(find.text('Kelime\nZirvesi'), findsOneWidget);
    expect(find.text('Şu an'), findsOneWidget);
    expect(find.text('Bölüm 1'), findsOneWidget);
    expect(find.text('· 0 m'), findsOneWidget);
    expect(find.text('Bugünün serisi · 0 gün'), findsOneWidget);
    expect(find.text('Bulunan kelime · 0'), findsOneWidget);
    expect(find.text('Kaydedilmiş oyun yok'), findsOneWidget);
    expect(find.text('Yeni bölüme başlamak için aşağıya dokun'), findsOneWidget);
    expect(find.text('Bölüm 1 ile başla'), findsOneWidget);
    expect(find.text('Harita'), findsOneWidget);
    expect(find.text('Ayarlar'), findsOneWidget);
  });

  testWidgets('progress feeds the pill and stats; the CTA opens the next level', (tester) async {
    final progress = InMemoryProgressRepository(
      highestCompletedLevel: 4,
      initialStats: ProgressStats(
        lastPlayedDay: _ProgressRulesDay.today(),
        streak: 3,
        wordsFound: 27,
      ),
    );
    await _pump(tester, progress: progress);
    expect(find.text('Bölüm 5'), findsOneWidget);
    expect(find.text('· 160 m'), findsOneWidget);
    expect(find.text('Bugünün serisi · 3 gün'), findsOneWidget);
    expect(find.text('Bulunan kelime · 27'), findsOneWidget);

    final destination = await _pump(
      tester,
      progress: progress,
      act: (t) => t.tap(find.text('Bölüm 5 ile başla')),
    );
    expect(destination, '/gameplay/5');
  });

  testWidgets('a saved match shows the save card and resumes from the CTA', (tester) async {
    await _pump(
      tester,
      progress: InMemoryProgressRepository(highestCompletedLevel: 2),
      saved: _session(),
    );
    expect(find.text('Yarım kalan oyun'), findsOneWidget);
    expect(find.text('Bölüm 3 · Sen 12 – Rakip 9'), findsOneWidget);

    final destination = await _pump(
      tester,
      progress: InMemoryProgressRepository(highestCompletedLevel: 2),
      saved: _session(),
      act: (t) => t.tap(find.text('Tırmanışa devam et')),
    );
    expect(destination, '/gameplay/3?resume=true');
  });

  testWidgets('Harita and Ayarlar navigate', (tester) async {
    expect(
      await _pump(
        tester,
        progress: InMemoryProgressRepository(),
        act: (t) => t.tap(find.text('Harita')),
      ),
      '/map',
    );
    expect(
      await _pump(
        tester,
        progress: InMemoryProgressRepository(),
        act: (t) => t.tap(find.text('Ayarlar')),
      ),
      '/settings',
    );
  });
}

/// Today's local day key, matching the repository's own format.
abstract final class _ProgressRulesDay {
  static String today() {
    final t = DateTime.now();
    return '${t.year.toString().padLeft(4, '0')}-'
        '${t.month.toString().padLeft(2, '0')}-'
        '${t.day.toString().padLeft(2, '0')}';
  }
}
