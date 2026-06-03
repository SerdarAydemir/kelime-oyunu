// lib/core/router/app_router.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:kelime_oyunu/features/gameplay/view/game_screen.dart';

/// Centralised route configuration (architecture.md §8).
///
/// Every [GoRoute.builder] currently returns a [_PlaceholderScreen]. Replace
/// each builder with the real screen widget as the corresponding feature is
/// implemented.
abstract final class AppRouter {
  static final GoRouter router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const _QuickStartScreen(),
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
          final levelId = int.tryParse(
                state.pathParameters['levelId'] ?? '1',
              ) ??
              1;
          return GameScreen(puzzleId: levelId);
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

/// Temporary quick-start screen: shows a spinner and immediately navigates
/// to puzzle #1. Replaced by the real splash + menu flow in a later phase.
class _QuickStartScreen extends StatefulWidget {
  const _QuickStartScreen();

  @override
  State<_QuickStartScreen> createState() => _QuickStartScreenState();
}

class _QuickStartScreenState extends State<_QuickStartScreen> {
  @override
  void initState() {
    super.initState();
    // Temporary: jump straight into the game.
    // Real splash → consent → menu → packs flow comes in a later phase.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.go('/gameplay/1');
    });
  }

  @override
  Widget build(BuildContext context) => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
}
