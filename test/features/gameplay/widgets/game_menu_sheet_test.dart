// test/features/gameplay/widgets/game_menu_sheet_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:kelime_oyunu/features/gameplay/widgets/game_menu_sheet.dart';

// Relative import — test helpers are not importable via package: path.
// ignore: always_use_package_imports
import '../../../helpers/localized_app.dart';

class _Harness {
  final visited = <String>[];

  Widget build() {
    Widget capture(GoRouterState s) {
      visited.add(s.uri.toString());
      return const Scaffold(body: Text('elsewhere'));
    }

    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => Scaffold(
            body: Builder(
              builder: (context) =>
                  TextButton(onPressed: () => showGameMenu(context), child: const Text('menu')),
            ),
          ),
        ),
        GoRoute(path: '/map', builder: (_, s) => capture(s)),
        GoRoute(path: '/settings', builder: (_, s) => capture(s)),
        GoRoute(path: '/onboarding', builder: (_, s) => capture(s)),
      ],
    );
    return localizedRouterApp(router);
  }
}

Future<void> _open(WidgetTester tester, _Harness h) async {
  await tester.pumpWidget(h.build());
  await tester.tap(find.text('menu'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('offers how-to-play, settings and back-to-map', (tester) async {
    final h = _Harness();
    await _open(tester, h);
    expect(find.text('Nasıl oynanır?'), findsOneWidget);
    expect(find.text('Ayarlar'), findsOneWidget);
    expect(find.text('Haritaya dön'), findsOneWidget);

    await tester.tap(find.text('Nasıl oynanır?'));
    await tester.pumpAndSettle();
    expect(h.visited, ['/onboarding']);
  });

  testWidgets('back to map asks first; cancel keeps the game', (tester) async {
    final h = _Harness();
    await _open(tester, h);
    await tester.tap(find.text('Haritaya dön'));
    await tester.pumpAndSettle();
    expect(find.text('Haritaya dön?'), findsOneWidget);
    expect(find.textContaining('Yarım kalan oyun kaydedilir'), findsOneWidget);

    await tester.tap(find.text('Vazgeç'));
    await tester.pumpAndSettle();
    expect(h.visited, isEmpty);
  });

  testWidgets('confirming leaves for the map', (tester) async {
    final h = _Harness();
    await _open(tester, h);
    await tester.tap(find.text('Haritaya dön'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Haritaya dön').last); // the dialog's confirm
    await tester.pumpAndSettle();
    expect(h.visited, ['/map']);
  });
}
