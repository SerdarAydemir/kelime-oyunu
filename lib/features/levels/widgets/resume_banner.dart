// lib/features/levels/widgets/resume_banner.dart

import 'package:flutter/material.dart';

import 'package:kelime_oyunu/core/constants/app_colors.dart';
import 'package:kelime_oyunu/core/constants/app_dimensions.dart';
import 'package:kelime_oyunu/core/constants/app_typography.dart';
import 'package:kelime_oyunu/data/models/saved_session.dart';

/// The "Devam Et" call to action for a half-played match.
///
/// Sits above the grid and outranks it visually: an interrupted match is what
/// the player most likely came back for.
class ResumeBanner extends StatelessWidget {
  const ResumeBanner({required this.summary, required this.onResume, super.key});

  final ResumeSummary summary;
  final VoidCallback onResume;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.accent,
      elevation: AppDimensions.cardElevation,
      margin: const EdgeInsets.only(bottom: AppDimensions.spacingM),
      child: InkWell(
        onTap: onResume,
        borderRadius: BorderRadius.circular(AppDimensions.radiusM),
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.spacingM),
          child: Row(
            children: [
              const Icon(Icons.play_circle_fill, size: AppDimensions.iconL),
              const SizedBox(width: AppDimensions.spacingM),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Devam Et', style: AppTypography.title),
                    const SizedBox(height: AppDimensions.spacingXxs),
                    Text(
                      'Bölüm ${summary.levelId} • ${summary.playerScore} - ${summary.botScore}',
                      style: AppTypography.bodySmall,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, size: AppDimensions.iconM),
            ],
          ),
        ),
      ),
    );
  }
}
