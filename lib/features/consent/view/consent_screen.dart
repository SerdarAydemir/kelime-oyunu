// lib/features/consent/view/consent_screen.dart

import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:kelime_oyunu/core/constants/app_dimensions.dart';
import 'package:kelime_oyunu/core/constants/app_typography.dart';
import 'package:kelime_oyunu/core/router/first_run.dart';
import 'package:kelime_oyunu/core/services/consent_service.dart';
import 'package:kelime_oyunu/core/theme/app_tokens.dart';
import 'package:kelime_oyunu/features/home/widgets/home_cards.dart';
import 'package:kelime_oyunu/features/home/widgets/mountain_backdrop.dart';
import 'package:kelime_oyunu/features/settings/cubit/settings_cubit.dart';
import 'package:kelime_oyunu/l10n/generated/app_localizations.dart';

/// First-run consent (README "Consent"): `bgGame` with two faint ridges, the
/// "HOŞ GELDİN" tag and title, and the bottom card with the ads-and-data
/// copy, the legal links and the two choices. Shown once; the answer is
/// recorded in [SettingsCubit] and the consent service is asked either way.
class ConsentScreen extends StatelessWidget {
  const ConsentScreen({required this.consentService, this.isIOS, super.key});

  final ConsentService consentService;

  /// Platform override for tests; defaults to the running platform.
  final bool? isIOS;

  Future<void> _finish(BuildContext context, Future<ConsentStatus> request) async {
    final cubit = context.read<SettingsCubit>();
    final router = GoRouter.of(context);
    await request;
    cubit.markConsentDone();
    router.go(firstRoute(cubit.state, isIOS: isIOS ?? defaultTargetPlatform == TargetPlatform.iOS));
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final l10n = AppLocalizations.of(context);
    // First-run gate: back cannot skip the consent card.
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: Stack(
          children: [
            Positioned.fill(
              child: DecoratedBox(decoration: BoxDecoration(gradient: tokens.bgGame)),
            ),
            // README "Consent": two faint ridges, mtn1 at 70 %, mtn2 at 60 %.
            const Positioned.fill(
              child: MountainBackdrop(trail: false, layers: 2, alphas: [0.7, 0.6]),
            ),
            SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppDimensions.space24,
                      AppDimensions.space40,
                      AppDimensions.space24,
                      0,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.consentTag,
                          style: AppTypography.overline.copyWith(
                            color: tokens.text.withValues(alpha: 0.7),
                          ),
                        ),
                        const SizedBox(height: AppDimensions.space12),
                        Text(
                          l10n.consentH,
                          style: AppTypography.resultTitle.copyWith(color: tokens.text),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  _ConsentCard(
                    onAccept: () => _finish(context, consentService.requestConsent()),
                    onManage: () => _finish(context, consentService.showPrivacyOptions()),
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

/// Bottom card: `sheet` bg, r20, title Lora 18, body 14 / 1.55 `sheetMuted`,
/// legal links in the arrow colour, primary 56 + outlined 48.
class _ConsentCard extends StatelessWidget {
  const _ConsentCard({required this.onAccept, required this.onManage});

  final VoidCallback onAccept;
  final VoidCallback onManage;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final l10n = AppLocalizations.of(context);
    final link = AppTypography.pill.copyWith(fontWeight: FontWeight.w700, color: tokens.link);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppDimensions.space20),
      decoration: BoxDecoration(
        color: tokens.sheet,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppDimensions.radiusScoreCard),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            l10n.consentTitle,
            style: AppTypography.nodeNumber.copyWith(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: tokens.sheetText,
            ),
          ),
          const SizedBox(height: AppDimensions.space8),
          Text(
            l10n.consentBody,
            style: AppTypography.body.copyWith(fontSize: 14, color: tokens.sheetMuted),
          ),
          const SizedBox(height: AppDimensions.space12),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              GestureDetector(
                onTap: () => context.push('/legal/privacy'),
                child: Text(l10n.privacy, style: link),
              ),
              Text(' · ', style: link),
              GestureDetector(
                onTap: () => context.push('/legal/terms'),
                child: Text(l10n.terms, style: link),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.space16),
          PrimaryButton(label: l10n.accept, onPressed: onAccept),
          const SizedBox(height: AppDimensions.space10),
          SecondaryButton(label: l10n.manage, color: tokens.sheetText, onPressed: onManage),
        ],
      ),
    );
  }
}
