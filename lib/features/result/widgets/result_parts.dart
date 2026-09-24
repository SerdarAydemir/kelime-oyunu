// lib/features/result/widgets/result_parts.dart

import 'package:flutter/material.dart';
import 'package:kelime_oyunu/core/constants/app_dimensions.dart';
import 'package:kelime_oyunu/core/constants/app_typography.dart';
import 'package:kelime_oyunu/core/theme/app_tokens.dart';
import 'package:kelime_oyunu/l10n/generated/app_localizations.dart';

/// "BÖLÜM n · KAZANDIN" tag (600 12, letter-spacing 4).
class ResultTag extends StatelessWidget {
  const ResultTag({required this.level, required this.outcome, super.key});

  final int level;
  final String outcome;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final l10n = AppLocalizations.of(context);
    return Text(
      '${l10n.levelTag} $level · $outcome',
      style: AppTypography.label.copyWith(
        letterSpacing: 4,
        color: tokens.text.withValues(alpha: 0.8),
      ),
    );
  }
}

/// Lora 44 / 1.05 two-line headline.
class ResultHeadline extends StatelessWidget {
  const ResultHeadline({required this.text, super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: AppTypography.resultTitle.copyWith(fontSize: 44, color: context.tokens.text),
    );
  }
}

/// Score card (`card`, r20, 1fr auto 1fr): "Sen 12" · "fark 3" · "9 Rakip",
/// scores in Lora 40 — the player's in amber, the opponent's in blue.
class ScoreCard extends StatelessWidget {
  const ScoreCard({
    required this.playerScore,
    required this.botScore,
    required this.botName,
    super.key,
  });

  final int playerScore;
  final int botScore;
  final String botName;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final l10n = AppLocalizations.of(context);
    final label = AppTypography.overline.copyWith(
      letterSpacing: 0,
      color: tokens.text.withValues(alpha: 0.7),
    );
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.space20,
        vertical: AppDimensions.space16,
      ),
      decoration: BoxDecoration(
        color: tokens.card,
        borderRadius: BorderRadius.circular(AppDimensions.radiusScoreCard),
        border: Border.all(color: tokens.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.you, style: label),
                Text(
                  '$playerScore',
                  style: AppTypography.resultTitle.copyWith(color: tokens.accent),
                ),
              ],
            ),
          ),
          Text(l10n.scoreGap((playerScore - botScore).abs()), style: label),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(botName, style: label),
                Text('$botScore', style: AppTypography.resultTitle.copyWith(color: tokens.bot)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// "+40 m → 200 m" pill on a dark translucent ground, amber number.
class AltitudePill extends StatelessWidget {
  const AltitudePill({required this.gain, required this.total, super.key});

  final int gain;
  final int total;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final l10n = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.space16,
        vertical: AppDimensions.space8,
      ),
      decoration: BoxDecoration(
        color: tokens.solid.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(AppDimensions.radiusPill),
      ),
      child: Text.rich(
        TextSpan(
          style: AppTypography.pill.copyWith(color: tokens.solidText),
          children: [
            TextSpan(text: '+${l10n.meters(gain)} → '),
            TextSpan(
              text: l10n.meters(total),
              style: AppTypography.buttonSecondary.copyWith(color: tokens.accent),
            ),
          ],
        ),
      ),
    );
  }
}

/// Dawn sun (won): r70 warm disc at 90 %.
class SunDisc extends StatelessWidget {
  const SunDisc({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 140,
      height: 140,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        // Design: #fff3d6 — the light palette's board cream is the closest
        // token (README "Flutter sapmaları").
        color: AppTokens.light.board.withValues(alpha: 0.9),
      ),
    );
  }
}

/// Campfire (lost / draw): r9 amber core inside an r22 15 % halo.
class Campfire extends StatelessWidget {
  const Campfire({super.key});

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: tokens.accent.withValues(alpha: 0.15),
      ),
      alignment: Alignment.center,
      child: Container(
        width: 18,
        height: 18,
        decoration: BoxDecoration(shape: BoxShape.circle, color: tokens.accent),
      ),
    );
  }
}
