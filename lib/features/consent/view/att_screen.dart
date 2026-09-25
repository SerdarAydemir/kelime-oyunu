// lib/features/consent/view/att_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:kelime_oyunu/core/constants/app_dimensions.dart';
import 'package:kelime_oyunu/core/constants/app_typography.dart';
import 'package:kelime_oyunu/core/router/first_run.dart';
import 'package:kelime_oyunu/core/services/consent_service.dart';
import 'package:kelime_oyunu/core/theme/app_tokens.dart';
import 'package:kelime_oyunu/features/home/widgets/home_cards.dart';
import 'package:kelime_oyunu/features/settings/cubit/settings_cubit.dart';
import 'package:kelime_oyunu/l10n/generated/app_localizations.dart';

/// iOS-only ATT pre-prompt (README "ATT interstitial"): explains the system
/// tracking dialog that follows "Devam" without mimicking it. Reached only
/// through [firstRoute] on iOS, once; "Şimdi değil" skips the system dialog.
class AttScreen extends StatelessWidget {
  const AttScreen({required this.consentService, super.key});

  final ConsentService consentService;

  Future<void> _finish(BuildContext context, {required bool ask}) async {
    final cubit = context.read<SettingsCubit>();
    final router = GoRouter.of(context);
    if (ask) await consentService.requestTracking();
    cubit.markAttAsked();
    // Past the ATT step now; the platform no longer matters for the route.
    router.go(firstRoute(cubit.state, isIOS: false));
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: tokens.bgFlat,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppDimensions.space24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AppDimensions.space40),
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(shape: BoxShape.circle, color: tokens.surface),
                child: Icon(Icons.verified_user_outlined, size: 30, color: tokens.accent),
              ),
              const SizedBox(height: AppDimensions.space20),
              Text(
                l10n.attTag,
                style: AppTypography.overline.copyWith(color: tokens.text.withValues(alpha: 0.7)),
              ),
              const SizedBox(height: AppDimensions.space8),
              Text(
                l10n.attH,
                style: AppTypography.resultTitle.copyWith(fontSize: 36, color: tokens.text),
              ),
              const SizedBox(height: AppDimensions.space12),
              Text(
                l10n.attBody,
                style: AppTypography.body.copyWith(
                  height: 1.6,
                  color: tokens.text.withValues(alpha: 0.75),
                ),
              ),
              const SizedBox(height: AppDimensions.space20),
              _BulletList(lines: [l10n.attBullet1, l10n.attBullet2]),
              const Spacer(),
              PrimaryButton(label: l10n.attCta, onPressed: () => _finish(context, ask: true)),
              const SizedBox(height: AppDimensions.space4),
              SizedBox(
                height: AppDimensions.buttonSecondary,
                child: TextButton(
                  onPressed: () => _finish(context, ask: false),
                  style: TextButton.styleFrom(foregroundColor: tokens.text),
                  child: Text(l10n.attLater),
                ),
              ),
              const SizedBox(height: AppDimensions.space16),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bordered r18 list with green-dot bullets.
class _BulletList extends StatelessWidget {
  const _BulletList({required this.lines});

  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.space16,
        vertical: AppDimensions.space12,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppDimensions.radiusListCard),
        border: Border.all(color: tokens.border),
      ),
      child: Column(
        children: [
          for (final line in lines)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppDimensions.space4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 7, right: AppDimensions.space10),
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(shape: BoxShape.circle, color: tokens.success),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      line,
                      style: AppTypography.bodySmall.copyWith(fontSize: 14, color: tokens.text),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
