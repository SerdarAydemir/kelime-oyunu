// lib/features/home/view/home_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:kelime_oyunu/core/constants/app_dimensions.dart';
import 'package:kelime_oyunu/core/constants/app_typography.dart';
import 'package:kelime_oyunu/core/theme/app_tokens.dart';
import 'package:kelime_oyunu/core/theme/sky.dart';
import 'package:kelime_oyunu/data/repositories/progress_repository.dart';
import 'package:kelime_oyunu/data/repositories/session_repository.dart';
import 'package:kelime_oyunu/features/home/cubit/home_cubit.dart';
import 'package:kelime_oyunu/features/home/cubit/home_state.dart';
import 'package:kelime_oyunu/features/home/widgets/home_cards.dart';
import 'package:kelime_oyunu/features/home/widgets/mountain_backdrop.dart';
import 'package:kelime_oyunu/features/settings/cubit/settings_cubit.dart';
import 'package:kelime_oyunu/l10n/generated/app_localizations.dart';

/// The app's front door (README "Home"): sky gradient + mountains, the name,
/// the "Şu an" pill, the stats row, the save card and the calls to action.
class HomeScreen extends StatelessWidget {
  const HomeScreen({required this.progressRepo, required this.sessionRepo, super.key});

  final ProgressRepository progressRepo;
  final SessionRepository sessionRepo;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => HomeCubit(progressRepo: progressRepo, sessionRepo: sessionRepo),
      child: const _HomeBody(),
    );
  }
}

class _HomeBody extends StatelessWidget {
  const _HomeBody();

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final l10n = AppLocalizations.of(context);
    // The sky toggle may be absent in tests that pump the screen alone.
    final skyEnabled = context.watch<SettingsCubit?>()?.state.skyEnabled ?? true;
    return BlocBuilder<HomeCubit, HomeState>(
      builder: (context, state) => Scaffold(
        body: Stack(
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: homeSky(tokens, progress: state.climbProgress, enabled: skyEnabled),
                ),
              ),
            ),
            const Positioned.fill(child: MountainBackdrop()),
            SafeArea(
              // Scrolls only when large system fonts push the content past the
              // screen; otherwise the Spacer keeps the cards at the bottom.
              child: CustomScrollView(
                slivers: [
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: AppDimensions.space24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: AppDimensions.space24),
                          Text(
                            l10n.homeTag,
                            style: AppTypography.label.copyWith(
                              letterSpacing: 3,
                              color: tokens.text.withValues(alpha: 0.8),
                            ),
                          ),
                          const SizedBox(height: AppDimensions.space12),
                          // The brand mark scales a little, never 1.6× (it is a logo).
                          MediaQuery.withClampedTextScaling(
                            maxScaleFactor: 1.2,
                            child: Text(
                              l10n.appNameStacked,
                              style: AppTypography.display.copyWith(color: tokens.text),
                            ),
                          ),
                          const SizedBox(height: AppDimensions.space20),
                          NowPill(level: state.nextLevel, meters: state.altitudeMeters),
                          const SizedBox(height: AppDimensions.space12),
                          StatsRow(streakDays: state.dailyStreak, wordsFound: state.wordsFound),
                          const Spacer(),
                          SaveCard(resume: state.resume),
                          const SizedBox(height: AppDimensions.space16),
                          _PrimaryCta(state: state),
                          const SizedBox(height: AppDimensions.space10),
                          Row(
                            children: [
                              Expanded(
                                child: SecondaryButton(
                                  label: l10n.map,
                                  onPressed: () => context.go('/map'),
                                ),
                              ),
                              const SizedBox(width: AppDimensions.space10),
                              Expanded(
                                child: SecondaryButton(
                                  label: l10n.settings,
                                  onPressed: () => context.push('/settings'),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppDimensions.space16),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "Tırmanışa devam et" when a match is waiting, else "Bölüm n ile başla".
class _PrimaryCta extends StatelessWidget {
  const _PrimaryCta({required this.state});

  final HomeState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final resume = state.resume;
    return PrimaryButton(
      label: resume != null ? l10n.continueClimb : l10n.startLevel(state.nextLevel),
      onPressed: () => context.go(
        resume != null ? '/gameplay/${resume.levelId}?resume=true' : '/gameplay/${state.nextLevel}',
      ),
    );
  }
}
