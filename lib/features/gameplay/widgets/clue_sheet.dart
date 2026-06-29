// lib/features/gameplay/widgets/clue_sheet.dart

import 'package:flutter/material.dart';

import 'package:kelime_oyunu/core/constants/app_colors.dart';
import 'package:kelime_oyunu/core/constants/app_dimensions.dart';
import 'package:kelime_oyunu/core/constants/app_typography.dart';
import 'package:kelime_oyunu/data/models/puzzle.dart';

/// Read-only bottom sheet showing a clue cell's full text(s). Opened by tapping
/// a clue cell whose in-cell preview is truncated (double-clue or ellipsised).
/// Reading the clue is free — the reveal joker exposes the answer, not the clue.
class ClueSheet extends StatelessWidget {
  const ClueSheet({required this.clues, super.key});

  final List<ClueSpec> clues;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.spacingL),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(clues.length >= 2 ? 'İpuçları' : 'İpucu', style: AppTypography.title),
            const SizedBox(height: AppDimensions.spacingM),
            for (final clue in clues) _ClueRow(clue: clue),
          ],
        ),
      ),
    );
  }
}

/// One clue line: direction arrow + full, wrapping clue text.
class _ClueRow extends StatelessWidget {
  const _ClueRow({required this.clue});

  final ClueSpec clue;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimensions.spacingS),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            clue.arrow == ClueArrow.right ? Icons.arrow_forward : Icons.arrow_downward,
            size: AppDimensions.iconS,
            color: AppColors.accent,
          ),
          const SizedBox(width: AppDimensions.spacingS),
          Expanded(child: Text(clue.text, style: AppTypography.bodyLarge)),
        ],
      ),
    );
  }
}
