// lib/features/gameplay/widgets/clue_sheet.dart

import 'package:flutter/material.dart';

import 'package:kelime_oyunu/core/theme/app_tokens.dart';
import 'package:kelime_oyunu/core/constants/app_dimensions.dart';
import 'package:kelime_oyunu/core/constants/app_typography.dart';
import 'package:kelime_oyunu/data/models/puzzle.dart';
import 'package:kelime_oyunu/l10n/generated/app_localizations.dart';

/// Read-only bottom sheet showing a clue cell's full text(s). Opened by tapping
/// a clue cell whose in-cell preview is truncated (double-clue or ellipsised).
/// Reading the clue is free — the reveal joker exposes the answer, not the clue.
class ClueSheet extends StatelessWidget {
  const ClueSheet({required this.clues, super.key});

  final List<ClueSpec> clues;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.space24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(clues.length >= 2 ? l10n.clues : l10n.clue, style: AppTypography.screenTitle),
            const SizedBox(height: AppDimensions.space16),
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
      padding: const EdgeInsets.only(bottom: AppDimensions.space8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            clue.arrow == ClueArrow.right ? Icons.arrow_forward : Icons.arrow_downward,
            size: AppDimensions.iconS,
            color: context.tokens.arrow,
          ),
          const SizedBox(width: AppDimensions.space8),
          Expanded(child: Text(clue.text, style: AppTypography.body)),
        ],
      ),
    );
  }
}
