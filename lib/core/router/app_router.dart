// lib/core/router/app_router.dart
import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kelime_oyunu/core/config/dev_flags.dart';
import 'package:kelime_oyunu/core/router/first_run.dart';
import 'package:kelime_oyunu/core/services/ad_service.dart';
import 'package:kelime_oyunu/core/services/consent_service.dart';
import 'package:kelime_oyunu/core/services/mock_ad_service.dart';

import 'package:kelime_oyunu/data/repositories/progress_repository.dart';
import 'package:kelime_oyunu/data/repositories/session_repository.dart';
import 'package:kelime_oyunu/data/repositories/settings_repository.dart';
import 'package:kelime_oyunu/features/consent/view/att_screen.dart';
import 'package:kelime_oyunu/features/consent/view/consent_screen.dart';
import 'package:kelime_oyunu/features/gameplay/view/game_screen.dart';
import 'package:kelime_oyunu/features/home/view/home_screen.dart';
import 'package:kelime_oyunu/features/gameplay/bloc/game_state.dart';
import 'package:kelime_oyunu/features/map/view/climb_map_screen.dart';
import 'package:kelime_oyunu/features/onboarding/view/onboarding_screen.dart';
import 'package:kelime_oyunu/features/result/view/result_screen.dart';
import 'package:kelime_oyunu/features/settings/view/settings_screen.dart';
import 'package:kelime_oyunu/l10n/generated/app_localizations.dart';
import 'package:kelime_oyunu/features/splash/view/splash_screen.dart';

/// Centralised route configuration (architecture.md §8).
///
/// A factory rather than a static `final`: the gameplay route needs the
/// persistence repositories that `main()` builds after Hive is open, and
/// widget tests need to hand in volatile fakes.
abstract final class AppRouter {
  static GoRouter build({
    required ProgressRepository progressRepo,
    required SessionRepository sessionRepo,
    required SettingsRepository settingsRepo,
    ConsentService consentService = const MockConsentService(),
  }) => GoRouter(
    initialLocation: '/splash',
    routes: [
      // Splash first, then home — never straight into a match: the player
      // picks up where they left off (F7).
      GoRoute(
        path: '/splash',
        // First run: consent (and the ATT pre-prompt on iOS) before home.
        builder: (context, state) => SplashScreen(
          next: firstRoute(settingsRepo.read(), isIOS: defaultTargetPlatform == TargetPlatform.iOS),
        ),
      ),
      GoRoute(
        path: '/',
        builder: (context, state) =>
            HomeScreen(progressRepo: progressRepo, sessionRepo: sessionRepo),
      ),
      GoRoute(
        path: '/map',
        builder: (context, state) => ClimbMapScreen(progressRepo: progressRepo),
      ),
      GoRoute(path: '/levels', redirect: (context, state) => '/map'),
      GoRoute(
        path: '/consent',
        builder: (context, state) => ConsentScreen(consentService: consentService),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) =>
            OnboardingScreen(firstRun: state.uri.queryParameters['first'] == '1'),
      ),
      GoRoute(
        path: '/consent/att',
        builder: (context, state) => AttScreen(consentService: consentService),
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
            // Mock until AdMob lands; the QA flag simulates "no ad available".
            adService: kDevAdsOffline
                ? const MockAdService(result: RewardedAdResult.unavailable)
                : const MockAdService(),
          );
        },
      ),
      GoRoute(
        path: '/result/:levelId',
        builder: (context, state) {
          final q = state.uri.queryParameters;
          return ResultScreen(
            status: GameStatus.values.asNameMap()[q['status']] ?? GameStatus.lost,
            levelId: int.tryParse(state.pathParameters['levelId'] ?? '') ?? 1,
            playerScore: int.tryParse(q['p'] ?? '') ?? 0,
            botScore: int.tryParse(q['b'] ?? '') ?? 0,
            botName: AppLocalizations.of(context).bot,
          );
        },
      ),
      GoRoute(
        path: '/shop',
        builder: (context, state) => const _PlaceholderScreen(label: 'Shop'),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => SettingsScreen(
          progressRepo: progressRepo,
          sessionRepo: sessionRepo,
          consentService: consentService,
        ),
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
