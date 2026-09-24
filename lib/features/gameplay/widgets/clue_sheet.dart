// lib/features/gameplay/widgets/clue_sheet.dart

import 'package:flutter/material.dart';

import 'package:kelime_oyunu/core/constants/app_dimensions.dart';
import 'package:kelime_oyunu/core/constants/app_typography.dart';
import 'package:kelime_oyunu/core/theme/app_tokens.dart';
import 'package:kelime_oyunu/data/models/puzzle.dart';
import 'package:kelime_oyunu/features/gameplay/widgets/sheet_shell.dart';
import 'package:kelime_oyunu/l10n/generated/app_localizations.dart';

/// One clue of the tapped cell with the length of its word.
typedef ClueSheetEntry = ({ClueSpec clue, int length});

/// Read-only bottom sheet showing a clue cell's full text(s) (README "Clue
/// sheet"). Opened by tapping a clue cell. Reading the clue is free — the
/// reveal joker exposes the answer, not the clue.
class ClueSheet extends StatelessWidget {
  const ClueSheet({required this.cell, required this.entries, super.key});

  /// The tapped clue cell (0-based; shown 1-based).
  final WordCell cell;

  final List<ClueSheetEntry> entries;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final l10n = AppLocalizations.of(context);
    final isDouble = entries.length >= 2;
    return SheetShell(
      title: isDouble ? l10n.clues : l10n.clue,
      children: [
        const SizedBox(height: AppDimensions.space4),
        Text(
          isDouble
              ? l10n.clueCellPositionDouble(cell.row + 1, cell.col + 1)
              : l10n.clueCellPosition(cell.row + 1, cell.col + 1),
          style: AppTypography.label.copyWith(color: tokens.sheetMuted),
        ),
        const SizedBox(height: AppDimensions.space16),
        for (final entry in entries) ...[
          _ClueCard(entry: entry),
          const SizedBox(height: AppDimensions.space10),
        ],
        const SizedBox(height: AppDimensions.space6),
        SheetSolidButton(label: l10n.close, onPressed: () => Navigator.of(context).pop()),
      ],
    );
  }
}

/// `sheetCard` r16 p16: arrow square · "SAĞA · 3 HARF" · clue text.
class _ClueCard extends StatelessWidget {
  const _ClueCard({required this.entry});

  final ClueSheetEntry entry;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final l10n = AppLocalizations.of(context);
    final isRight = entry.clue.arrow == ClueArrow.right;
    final direction = isRight ? l10n.right : l10n.down;
    return Container(
      padding: const EdgeInsets.all(AppDimensions.space16),
      decoration: BoxDecoration(
        color: tokens.sheetCard,
        borderRadius: BorderRadius.circular(AppDimensions.radiusBoard),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: tokens.arrow,
              borderRadius: BorderRadius.circular(AppDimensions.radiusTile),
            ),
            child: Icon(
              isRight ? Icons.arrow_forward : Icons.arrow_downward,
              size: 20,
              color: tokens.solidText,
            ),
          ),
          const SizedBox(width: AppDimensions.space12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$direction · ${entry.length} ${l10n.letters}',
                  style: AppTypography.overline.copyWith(
                    letterSpacing: 1,
                    color: tokens.sheetMuted,
                  ),
                ),
                const SizedBox(height: AppDimensions.space4),
                Text(
                  entry.clue.text,
                  style: AppTypography.nodeNumber.copyWith(fontSize: 18, color: tokens.sheetText),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
