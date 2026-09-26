// test/features/nav/back_navigation_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:kelime_oyunu/core/services/consent_service.dart';
import 'package:kelime_oyunu/data/repositories/progress_repository.dart';
import 'package:kelime_oyunu/data/repositories/settings_repository.dart';
import 'package:kelime_oyunu/features/consent/view/consent_screen.dart';
import 'package:kelime_oyunu/features/gameplay/bloc/game_state.dart';
import 'package:kelime_oyunu/features/map/view/climb_map_screen.dart';
import 'package:kelime_oyunu/features/onboarding/view/onboarding_screen.dart';
import 'package:kelime_oyunu/features/result/view/result_screen.dart';
import 'package:kelime_oyunu/features/settings/cubit/settings_cubit.dart';

// Relative import — test helpers are not importable via package: path.
// ignore: always_use_package_imports
import '../../helpers/localized_app.dart';

/// Where the system back button lands from each first-level route.
class _Harness {
  _Harness(this.initial);

  final String initial;
  final visited = <String>[];

  Widget build() {
    Widget capture(GoRouterState s) {
      visited.add(s.uri.toString());
      return const Scaffold(body: Text('elsewhere'));
    }

    final router = GoRouter(
      initialLocation: initial,
      routes: [
        GoRoute(path: '/', builder: (_, s) => capture(s)),
        GoRoute(
          path: '/map',
          builder: (_, s) => initial == '/map'
              ? ClimbMapScreen(progressRepo: InMemoryProgressRepository())
              : capture(s),
        ),
        GoRoute(
          path: '/result/:levelId',
          builder: (_, _) => const ResultScreen(
            status: GameStatus.lost,
            levelId: 3,
            playerScore: 1,
            botScore: 2,
            botName: 'Rakip',
          ),
        ),
        GoRoute(
          path: '/consent',
          builder: (_, _) =>
              const ConsentScreen(consentService: MockConsentService(), isIOS: false),
        ),
        GoRoute(path: '/onboarding', builder: (_, _) => const OnboardingScreen(firstRun: true)),
      ],
    );
    return BlocProvider(
      create: (_) => SettingsCubit(repository: InMemorySettingsRepository()),
      child: localizedRouterApp(router),
    );
  }
}

void main() {
  testWidgets('map → back → home', (tester) async {
    final h = _Harness('/map');
    await tester.pumpWidget(h.build());
    await tester.pump();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(h.visited, ['/']);
  });

  testWidgets('result → back → map', (tester) async {
    final h = _Harness('/result/3');
    await tester.pumpWidget(h.build());
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(h.visited, ['/map']);
  });

  testWidgets('consent and a first-run tutorial ignore back', (tester) async {
    final consent = _Harness('/consent');
    await tester.pumpWidget(consent.build());
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Kabul et ve başla'), findsOneWidget);
    expect(consent.visited, isEmpty);

    final onboarding = _Harness('/onboarding');
    await tester.pumpWidget(onboarding.build());
    await tester.pump();
    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(find.text('1 / 3'), findsOneWidget);
    expect(onboarding.visited, isEmpty);
  });
}
