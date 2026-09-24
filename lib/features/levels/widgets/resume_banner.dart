// lib/features/levels/widgets/resume_banner.dart

import 'package:flutter/material.dart';

import 'package:kelime_oyunu/core/constants/app_dimensions.dart';
import 'package:kelime_oyunu/core/constants/app_typography.dart';
import 'package:kelime_oyunu/core/theme/app_tokens.dart';
import 'package:kelime_oyunu/data/models/saved_session.dart';
import 'package:kelime_oyunu/l10n/generated/app_localizations.dart';

/// The "Yarım kalan oyun" call to action for a half-played match.
///
/// Sits above the grid and outranks it visually: an interrupted match is what
/// the player most likely came back for.
class ResumeBanner extends StatelessWidget {
  const ResumeBanner({required this.summary, required this.onResume, super.key});

  final ResumeSummary summary;
  final VoidCallback onResume;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final l10n = AppLocalizations.of(context);
    return Card(
      color: tokens.accent,
      elevation: 2,
      margin: const EdgeInsets.only(bottom: AppDimensions.space16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusListCard),
      ),
      child: InkWell(
        onTap: onResume,
        borderRadius: BorderRadius.circular(AppDimensions.radiusListCard),
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.space16),
          child: Row(
            children: [
              Icon(Icons.play_circle_fill, size: AppDimensions.iconL, color: tokens.accentInk),
              const SizedBox(width: AppDimensions.space16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      l10n.resume,
                      style: AppTypography.buttonSecondary.copyWith(color: tokens.accentInk),
                    ),
                    const SizedBox(height: AppDimensions.space2),
                    Text(
                      l10n.resumeScore(summary.levelId, summary.playerScore, summary.botScore),
                      style: AppTypography.bodySmall.copyWith(color: tokens.accentInk),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, size: AppDimensions.iconM, color: tokens.accentInk),
            ],
          ),
        ),
      ),
    );
  }
}
