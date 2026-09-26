// lib/features/gameplay/widgets/sheet_shell.dart

import 'package:flutter/material.dart';
import 'package:kelime_oyunu/core/constants/app_dimensions.dart';
import 'package:kelime_oyunu/core/constants/app_typography.dart';
import 'package:kelime_oyunu/core/theme/app_tokens.dart';

/// Common chrome of the game's bottom sheets (README "Clue sheet" / "Swap
/// sheet"): the `sheet` background and r28 top corners come from the theme;
/// this adds the 44 × 5 handle, the padded column and the sheet typography.
class SheetShell extends StatelessWidget {
  const SheetShell({required this.title, required this.children, this.trailing, super.key});

  /// Lora 24 `sheetText` title.
  final String title;

  /// Sits at the title's right edge (e.g. the remaining-swaps counter).
  final Widget? trailing;

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppDimensions.space20,
          AppDimensions.space10,
          AppDimensions.space20,
          AppDimensions.space20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: tokens.sheetMuted.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(AppDimensions.radiusPill),
                ),
              ),
            ),
            const SizedBox(height: AppDimensions.space16),
            // Wrap: the trailing counter folds under the title at large fonts.
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.end,
              spacing: AppDimensions.space12,
              children: [
                Text(
                  title,
                  style: AppTypography.screenTitle.copyWith(fontSize: 24, color: tokens.sheetText),
                ),
                ?trailing,
              ],
            ),
            // The body scrolls when it outgrows the sheet (large fonts).
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: children,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 52 dp full-width `solid` button used to dismiss a sheet ("Kapat").
class SheetSolidButton extends StatelessWidget {
  const SheetSolidButton({required this.label, required this.onPressed, super.key});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return SizedBox(
      height: AppDimensions.buttonGame,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: tokens.solid,
          foregroundColor: tokens.solidText,
          textStyle: AppTypography.buttonSecondary,
          shape: const StadiumBorder(),
        ),
        child: Text(label),
      ),
    );
  }
}
