// test/features/onboarding/onboarding_screen_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:kelime_oyunu/data/repositories/settings_repository.dart';
import 'package:kelime_oyunu/features/onboarding/view/onboarding_screen.dart';
import 'package:kelime_oyunu/features/settings/cubit/settings_cubit.dart';

// Relative import — test helpers are not importable via package: path.
// ignore: always_use_package_imports
import '../../helpers/localized_app.dart';

class _Harness {
  _Harness({required this.initial});

  final String initial;
  final settingsRepo = InMemorySettingsRepository();
  late final cubit = SettingsCubit(repository: settingsRepo);
  final visited = <String>[];

  Widget build() {
    final router = GoRouter(
      initialLocation: initial,
      routes: [
        GoRoute(
          path: '/',
          builder: (_, s) {
            visited.add('/');
            return const Scaffold(body: Text('home'));
          },
        ),
        GoRoute(
          path: '/settings',
          builder: (_, _) => Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => context.push('/onboarding'),
                child: const Text('open'),
              ),
            ),
          ),
        ),
        GoRoute(
          path: '/onboarding',
          builder: (_, s) => OnboardingScreen(firstRun: s.uri.queryParameters['first'] == '1'),
        ),
      ],
    );
    return BlocProvider.value(value: cubit, child: localizedRouterApp(router));
  }
}

void main() {
  testWidgets('three cards, then Devam finishes on home for a first run', (tester) async {
    final h = _Harness(initial: '/onboarding?first=1');
    await tester.pumpWidget(h.build());
    await tester.pump();

    expect(find.text('1 / 3'), findsOneWidget);
    expect(find.text('İpucunu oku, harfi yerleştir'), findsOneWidget);
    for (final chip in ['İpucu', 'Harf koy', 'Onayla', 'Rakip cevap verir']) {
      expect(find.text(chip), findsOneWidget, reason: chip);
    }
    expect(find.text('Atla'), findsOneWidget);

    await tester.tap(find.text('Devam'));
    await tester.pump();
    expect(find.text('2 / 3'), findsOneWidget);
    expect(find.text('Harfi koy, onayla'), findsOneWidget);

    await tester.tap(find.text('Devam'));
    await tester.pump();
    expect(find.text('3 / 3'), findsOneWidget);
    expect(find.text('Rakip cevap verir'), findsNWidgets(2)); // title + chip

    await tester.tap(find.text('Devam'));
    await tester.pumpAndSettle();
    expect(h.cubit.state.onboardingDone, isTrue);
    expect(h.settingsRepo.read().onboardingDone, isTrue);
    expect(h.visited, ['/']);
  });

  testWidgets('Atla marks the tutorial as seen and leaves', (tester) async {
    final h = _Harness(initial: '/onboarding?first=1');
    await tester.pumpWidget(h.build());
    await tester.pump();
    await tester.tap(find.text('Atla'));
    await tester.pumpAndSettle();
    expect(h.cubit.state.onboardingDone, isTrue);
    expect(h.visited, ['/']);
  });

  testWidgets('opened from settings it pops back instead of going home', (tester) async {
    final h = _Harness(initial: '/settings');
    await tester.pumpWidget(h.build());
    await tester.pump();
    await tester.tap(find.text('open'));
    // The strip's tile bobs forever: settle would never return.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('1 / 3'), findsOneWidget);

    await tester.tap(find.text('Atla'));
    await tester.pumpAndSettle();
    expect(find.text('open'), findsOneWidget);
    expect(h.visited, isEmpty);
  });
}
