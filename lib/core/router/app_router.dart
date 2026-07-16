// lib/core/router/app_router.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:kelime_oyunu/data/repositories/progress_repository.dart';
import 'package:kelime_oyunu/data/repositories/session_repository.dart';
import 'package:kelime_oyunu/features/gameplay/view/game_screen.dart';
import 'package:kelime_oyunu/features/levels/view/level_select_screen.dart';

/// Centralised route configuration (architecture.md §8).
///
/// A factory rather than a static `final`: the gameplay route needs the
/// persistence repositories that `main()` builds after Hive is open, and
/// widget tests need to hand in volatile fakes.
abstract final class AppRouter {
  static GoRouter build({
    required ProgressRepository progressRepo,
    required SessionRepository sessionRepo,
  }) => GoRouter(
    initialLocation: '/levels',
    routes: [
      // The app opens on the level grid, never straight into a match: the
      // player picks up where they left off (F7).
      GoRoute(path: '/', redirect: (context, state) => '/levels'),
      GoRoute(
        path: '/levels',
        builder: (context, state) =>
            LevelSelectScreen(progressRepo: progressRepo, sessionRepo: sessionRepo),
      ),
      GoRoute(
        path: '/consent',
        builder: (context, state) => const _PlaceholderScreen(label: 'Consent'),
      ),
      GoRoute(
        path: '/menu',
        builder: (context, state) => const _PlaceholderScreen(label: 'Menu'),
      ),
      GoRoute(
        path: '/packs',
        builder: (context, state) => const _PlaceholderScreen(label: 'Packs'),
      ),
      GoRoute(
        path: '/gameplay/:levelId',
        builder: (context, state) {
          final levelId = int.tryParse(state.pathParameters['levelId'] ?? '1') ?? 1;
          // Key by levelId so navigating between levels (same route pattern)
          // forces a fresh Element — otherwise GoRouter reuses the GameScreen
          // Element and its BlocProvider keeps the previous level's GameBloc,
          // leaving the board stuck on the finished puzzle.
          // ?resume=true continues the saved match instead of restarting it.
          final resume = state.uri.queryParameters['resume'] == 'true';
          return GameScreen(
            key: ValueKey(levelId),
            puzzleId: levelId,
            progressRepo: progressRepo,
            sessionRepo: sessionRepo,
            resume: resume,
          );
        },
      ),
      GoRoute(
        path: '/shop',
        builder: (context, state) => const _PlaceholderScreen(label: 'Shop'),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const _PlaceholderScreen(label: 'Settings'),
      ),
      GoRoute(
        path: '/legal/privacy',
        builder: (context, state) => const _PlaceholderScreen(label: 'Privacy Policy'),
      ),
      GoRoute(
        path: '/legal/terms',
        builder: (context, state) => const _PlaceholderScreen(label: 'Terms of Service'),
      ),
    ],
  );
}

/// Temporary placeholder rendered for every route until the real screen
/// widget is implemented. Displays the route label centred on a white
/// [Scaffold] — sufficient to verify routing without crashing.
class _PlaceholderScreen extends StatelessWidget {
  const _PlaceholderScreen({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(child: Text(label, style: Theme.of(context).textTheme.headlineMedium)),
    );
  }
}
