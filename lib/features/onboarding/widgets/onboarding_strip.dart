// lib/features/onboarding/widgets/onboarding_strip.dart

import 'package:flutter/material.dart';
import 'package:kelime_oyunu/core/constants/app_dimensions.dart';
import 'package:kelime_oyunu/core/constants/app_typography.dart';
import 'package:kelime_oyunu/core/theme/app_tokens.dart';
import 'package:kelime_oyunu/l10n/generated/app_localizations.dart';

/// The mini board strip of the tutorial cards (README "Onboarding"): clue
/// cell → pending amber "İ" → highlighted empty cell → empty cell, with a
/// floating amber tile "L" tilted −8° and bobbing over 2.4 s. [stage] picks
/// what the strip shows: 0 = read the clue, 1 = place + confirm, 2 = the
/// opponent's letter lands.
class OnboardingStrip extends StatefulWidget {
  const OnboardingStrip({required this.stage, super.key});

  final int stage;

  @override
  State<OnboardingStrip> createState() => _OnboardingStripState();
}

class _OnboardingStripState extends State<OnboardingStrip> with SingleTickerProviderStateMixin {
  late final AnimationController _bob = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _bob.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final l10n = AppLocalizations.of(context);
    const cell = 52.0;
    Widget box(Color color, {Widget? child, Border? border}) => Container(
      width: cell,
      height: cell,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(AppDimensions.radiusCell),
        border: border,
      ),
      alignment: Alignment.center,
      child: child,
    );
    const letter = AppTypography.cellLetter;
    final cells = <Widget>[
      box(
        tokens.cellClue,
        child: Text(
          l10n.onbDemoClue,
          style: AppTypography.clue.copyWith(fontSize: 10, color: tokens.clueText),
        ),
      ),
      box(
        widget.stage == 0 ? tokens.cellPending : tokens.cellLetter,
        child: Text(
          l10n.onbDemoPending,
          style: letter.copyWith(color: widget.stage == 0 ? tokens.inkPending : tokens.ink),
        ),
      ),
      box(
        tokens.cellLetter,
        border: widget.stage == 0 ? Border.all(color: tokens.accent, width: 2) : null,
        child: widget.stage >= 1
            ? Text(
                l10n.onbDemoTile,
                style: letter.copyWith(color: widget.stage == 1 ? tokens.inkPending : tokens.ink),
              )
            : null,
      ),
      box(
        tokens.cellLetter,
        border: widget.stage == 2 ? Border.all(color: tokens.inkBot, width: 2) : null,
        child: widget.stage == 2
            ? Text(l10n.onbDemoBot, style: letter.copyWith(fontSize: 16, color: tokens.inkBot))
            : null,
      ),
    ];
    return SizedBox(
      height: 120,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(AppDimensions.space6),
            decoration: BoxDecoration(
              color: tokens.board,
              borderRadius: BorderRadius.circular(AppDimensions.radiusBoard),
              boxShadow: [tokens.boardShadow],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < cells.length; i++) ...[
                  if (i > 0) const SizedBox(width: AppDimensions.space2),
                  cells[i],
                ],
              ],
            ),
          ),
          if (widget.stage == 0)
            AnimatedBuilder(
              animation: _bob,
              builder: (context, child) =>
                  Transform.translate(offset: Offset(70, -34 - 6 * _bob.value), child: child),
              child: Transform.rotate(
                angle: -8 * 3.14159 / 180,
                child: Container(
                  width: AppDimensions.tileWidth,
                  height: AppDimensions.tileHeight,
                  decoration: BoxDecoration(
                    color: tokens.accent,
                    borderRadius: BorderRadius.circular(AppDimensions.radiusTile),
                    boxShadow: [
                      BoxShadow(
                        color: tokens.accent.withValues(alpha: 0.4),
                        blurRadius: 24,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    l10n.onbDemoTile,
                    style: AppTypography.tileLetter.copyWith(color: tokens.tileInk),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
