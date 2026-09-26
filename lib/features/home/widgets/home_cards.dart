// lib/features/home/widgets/home_cards.dart

import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:kelime_oyunu/core/constants/app_dimensions.dart';
import 'package:kelime_oyunu/core/constants/app_typography.dart';
import 'package:kelime_oyunu/core/theme/app_tokens.dart';
import 'package:kelime_oyunu/data/models/saved_session.dart';
import 'package:kelime_oyunu/l10n/generated/app_localizations.dart';

/// "Şu an · Bölüm n · X m" pill (`card` bg, 1 px `border`, r999).
class NowPill extends StatelessWidget {
  const NowPill({required this.level, required this.meters, super.key});

  final int level;
  final int meters;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final l10n = AppLocalizations.of(context);
    final small = AppTypography.pill.copyWith(color: tokens.text);
    return GlassSurface(
      blur: 6,
      radius: AppDimensions.radiusPill,
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.space16,
        vertical: AppDimensions.space8,
      ),
      // Wrap, not Row: at large system fonts the three parts fold onto a
      // second line instead of overflowing the pill.
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: AppDimensions.space8,
        children: [
          Text(l10n.now, style: small),
          Text(
            '${l10n.level} $level',
            style: AppTypography.screenTitle.copyWith(fontSize: 20, color: tokens.text),
          ),
          Text('· ${l10n.meters(meters)}', style: small),
        ],
      ),
    );
  }
}

/// "Bugünün serisi · n gün" / "Bulunan kelime · n".
class StatsRow extends StatelessWidget {
  const StatsRow({required this.streakDays, required this.wordsFound, super.key});

  final int streakDays;
  final int wordsFound;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final l10n = AppLocalizations.of(context);
    final style = AppTypography.label.copyWith(color: tokens.text.withValues(alpha: 0.85));
    return Wrap(
      spacing: AppDimensions.space16,
      runSpacing: AppDimensions.space4,
      children: [
        Text('${l10n.streak} · $streakDays ${l10n.day}', style: style),
        Text('${l10n.words} · $wordsFound', style: style),
      ],
    );
  }
}

/// The save card: "Yarım kalan oyun" + score line, or the empty state.
class SaveCard extends StatelessWidget {
  const SaveCard({required this.resume, super.key});

  final ResumeSummary? resume;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final l10n = AppLocalizations.of(context);
    final resume = this.resume;
    return GlassSurface(
      blur: 8,
      radius: AppDimensions.radiusListCard,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.space16,
        vertical: AppDimensions.space18,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            resume != null ? l10n.resume : l10n.noSave,
            style: AppTypography.pill.copyWith(
              fontWeight: FontWeight.w700,
              color: tokens.text.withValues(alpha: 0.75),
            ),
          ),
          const SizedBox(height: AppDimensions.space4),
          Text(
            resume != null
                ? l10n.resumeScore(resume.levelId, resume.playerScore, resume.botScore)
                : l10n.noSaveSub,
            style: resume != null
                ? AppTypography.nodeNumber.copyWith(fontSize: 18, color: tokens.text)
                : AppTypography.bodySmall.copyWith(color: tokens.text.withValues(alpha: 0.66)),
          ),
        ],
      ),
    );
  }
}

/// Translucent `card` surface with a backdrop blur and a 1 px `border`
/// (README "Home": pill blur 6, save card blur 8).
class GlassSurface extends StatelessWidget {
  const GlassSurface({
    required this.blur,
    required this.radius,
    required this.padding,
    required this.child,
    this.width,
    super.key,
  });

  final double blur;
  final double radius;
  final EdgeInsets padding;
  final Widget child;
  final double? width;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          width: width,
          padding: padding,
          decoration: BoxDecoration(
            color: tokens.card,
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: tokens.border),
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Primary CTA (56 dp, amber, amber shadow).
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    required this.label,
    required this.onPressed,
    this.solid = false,
    super.key,
  });

  final String label;
  final VoidCallback onPressed;

  /// Use the `solid` (dark) fill instead of amber (result screens).
  final bool solid;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppDimensions.radiusPill),
        boxShadow: solid
            ? null
            : [
                BoxShadow(
                  color: tokens.accent.withValues(alpha: 0.35),
                  blurRadius: 30,
                  offset: const Offset(0, 10),
                ),
              ],
      ),
      child: SizedBox(
        height: AppDimensions.buttonPrimary,
        width: double.infinity,
        child: FilledButton(
          onPressed: onPressed,
          style: FilledButton.styleFrom(
            backgroundColor: solid ? tokens.solid : tokens.accent,
            foregroundColor: solid ? tokens.solidText : tokens.accentInk,
            textStyle: AppTypography.buttonPrimary,
            shape: const StadiumBorder(),
          ),
          child: Text(label),
        ),
      ),
    );
  }
}

/// Secondary outlined button (48 dp).
class SecondaryButton extends StatelessWidget {
  const SecondaryButton({required this.label, required this.onPressed, this.color, super.key});

  final String label;
  final VoidCallback onPressed;

  /// Outline + text colour; defaults to the theme text colour.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final ink = color ?? tokens.text;
    return SizedBox(
      height: AppDimensions.buttonSecondary,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: ink,
          side: BorderSide(color: ink.withValues(alpha: 0.5), width: 1.5),
          textStyle: AppTypography.buttonSecondary,
          shape: const StadiumBorder(),
        ),
        child: Text(label),
      ),
    );
  }
}
