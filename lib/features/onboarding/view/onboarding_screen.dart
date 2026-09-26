// lib/features/onboarding/view/onboarding_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:kelime_oyunu/core/constants/app_dimensions.dart';
import 'package:kelime_oyunu/core/constants/app_typography.dart';
import 'package:kelime_oyunu/core/theme/app_tokens.dart';
import 'package:kelime_oyunu/features/home/widgets/home_cards.dart';
import 'package:kelime_oyunu/features/onboarding/widgets/onboarding_strip.dart';
import 'package:kelime_oyunu/features/settings/cubit/settings_cubit.dart';
import 'package:kelime_oyunu/l10n/generated/app_localizations.dart';

/// Three-card tutorial (README "Onboarding"): read the clue → place and
/// confirm → the opponent replies. Skippable; seen once on first run
/// ([firstRun] lands on home afterwards), re-openable from Settings and the
/// game menu (then it pops back).
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({this.firstRun = false, super.key});

  final bool firstRun;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  int _page = 0;

  static const int _pages = 3;

  void _finish() {
    context.read<SettingsCubit>().markOnboardingDone();
    if (widget.firstRun || !context.canPop()) {
      context.go('/');
    } else {
      context.pop();
    }
  }

  void _next() {
    if (_page == _pages - 1) {
      _finish();
    } else {
      setState(() => _page++);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final l10n = AppLocalizations.of(context);
    final titles = [l10n.onb1, l10n.onb2, l10n.onb3];
    final bodies = [l10n.onb1Sub, l10n.onb2Sub, l10n.onb3Sub];
    final steps = [l10n.onbSteps1, l10n.onbSteps2, l10n.onbSteps3, l10n.onbSteps4];
    // Card 1 lights "İpucu", card 2 "Harf koy" + "Onayla", card 3 the reply.
    final activeSteps = switch (_page) {
      0 => const {0},
      1 => const {1, 2},
      _ => const {3},
    };
    return Scaffold(
      backgroundColor: tokens.bgFlat,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppDimensions.space24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _finish,
                  style: TextButton.styleFrom(foregroundColor: tokens.text),
                  child: Text(l10n.onbSkip),
                ),
              ),
              const SizedBox(height: AppDimensions.space24),
              OnboardingStrip(stage: _page, key: ValueKey(_page)),
              const SizedBox(height: AppDimensions.space32),
              Text(
                l10n.onbProgress(_page + 1),
                style: AppTypography.overline.copyWith(color: tokens.text.withValues(alpha: 0.66)),
              ),
              const SizedBox(height: AppDimensions.space8),
              Text(
                titles[_page],
                style: AppTypography.resultTitle.copyWith(fontSize: 28, color: tokens.text),
              ),
              const SizedBox(height: AppDimensions.space8),
              Text(
                bodies[_page],
                style: AppTypography.body.copyWith(color: tokens.text.withValues(alpha: 0.72)),
              ),
              const SizedBox(height: AppDimensions.space16),
              Wrap(
                spacing: AppDimensions.space6,
                runSpacing: AppDimensions.space6,
                children: [
                  for (var i = 0; i < steps.length; i++)
                    _StepChip(label: steps[i], active: activeSteps.contains(i)),
                ],
              ),
              const Spacer(),
              Row(
                children: [
                  for (var i = 0; i < _pages; i++) ...[
                    if (i > 0) const SizedBox(width: AppDimensions.space6),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: i == _page ? 22 : 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: i == _page ? tokens.accent : tokens.faint,
                        borderRadius: BorderRadius.circular(AppDimensions.radiusPill),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: AppDimensions.space16),
              PrimaryButton(label: l10n.onbNext, onPressed: _next),
              const SizedBox(height: AppDimensions.space16),
            ],
          ),
        ),
      ),
    );
  }
}

/// Step chip: amber when active, `surface` otherwise.
class _StepChip extends StatelessWidget {
  const _StepChip({required this.label, required this.active});

  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.space12,
        vertical: AppDimensions.space6,
      ),
      decoration: BoxDecoration(
        color: active ? tokens.accent : tokens.surface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusPill),
        border: Border.all(color: active ? tokens.accent : tokens.border),
      ),
      child: Text(
        label,
        style: AppTypography.pill.copyWith(color: active ? tokens.accentInk : tokens.text),
      ),
    );
  }
}
