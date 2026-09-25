// lib/features/shop/widgets/shop_cards.dart

import 'package:flutter/material.dart';
import 'package:kelime_oyunu/core/constants/app_dimensions.dart';
import 'package:kelime_oyunu/core/constants/app_typography.dart';
import 'package:kelime_oyunu/core/theme/app_tokens.dart';
import 'package:kelime_oyunu/l10n/generated/app_localizations.dart';

/// Coin pill in the header: amber 18 % bg, arrow ink, coin icon, 800 13.
class CoinPill extends StatelessWidget {
  const CoinPill({required this.coins, super.key});

  final int coins;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.space12,
        vertical: AppDimensions.space6,
      ),
      decoration: BoxDecoration(
        color: tokens.accent.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(AppDimensions.radiusPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.monetization_on_outlined, size: 16, color: tokens.arrow),
          const SizedBox(width: AppDimensions.space4),
          Text(
            '$coins',
            style: AppTypography.pill.copyWith(fontWeight: FontWeight.w800, color: tokens.arrow),
          ),
        ],
      ),
    );
  }
}

/// Hero card: 135° accent → arrow gradient, r20, "TEK SEFERLİK" /
/// "Reklamsız tırmanış" Lora 26 / body / price chip (or "Aktif").
class AdFreeCard extends StatelessWidget {
  const AdFreeCard({required this.owned, required this.price, required this.onTap, super.key});

  final bool owned;
  final String price;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final l10n = AppLocalizations.of(context);
    return GestureDetector(
      onTap: owned ? null : onTap,
      child: Container(
        padding: const EdgeInsets.all(AppDimensions.space20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [tokens.accent, tokens.arrow],
          ),
          borderRadius: BorderRadius.circular(AppDimensions.radiusScoreCard),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.oneTime,
              style: AppTypography.overline.copyWith(
                color: tokens.accentInk.withValues(alpha: 0.75),
              ),
            ),
            const SizedBox(height: AppDimensions.space6),
            Text(
              l10n.adFree,
              style: AppTypography.screenTitle.copyWith(fontSize: 26, color: tokens.accentInk),
            ),
            const SizedBox(height: AppDimensions.space6),
            Text(
              l10n.adFreeSub,
              style: AppTypography.bodySmall.copyWith(fontSize: 13, color: tokens.accentInk),
            ),
            const SizedBox(height: AppDimensions.space12),
            PriceChip(label: owned ? l10n.owned : price, dark: true),
          ],
        ),
      ),
    );
  }
}

/// Price chip: `solid` fill on the hero, amber on the coin cards.
class PriceChip extends StatelessWidget {
  const PriceChip({required this.label, this.dark = false, this.outlined = false, super.key});

  final String label;
  final bool dark;
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final (bg, ink, border) = dark
        ? (tokens.solid, tokens.solidText, null)
        : outlined
        ? (null, tokens.text, Border.all(color: tokens.border, width: 1.5))
        : (tokens.accent, tokens.accentInk, null);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.space12,
        vertical: AppDimensions.space6,
      ),
      decoration: BoxDecoration(
        color: bg,
        border: border,
        borderRadius: BorderRadius.circular(AppDimensions.radiusPill),
      ),
      child: Text(
        label,
        style: AppTypography.pill.copyWith(fontWeight: FontWeight.w800, color: ink),
      ),
    );
  }
}

/// Coin pack card (`surface`, r18): amount Lora 26, "≈ n harf açma", price
/// chip; the featured pack carries the "EN ÇOK ALINAN" badge and amber border.
class CoinPackCard extends StatelessWidget {
  const CoinPackCard({
    required this.coins,
    required this.unlocks,
    required this.price,
    required this.featured,
    required this.onTap,
    super.key,
  });

  final int coins;
  final int unlocks;
  final String price;
  final bool featured;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final l10n = AppLocalizations.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppDimensions.space16),
        decoration: BoxDecoration(
          color: tokens.surface,
          borderRadius: BorderRadius.circular(AppDimensions.radiusListCard),
          border: Border.all(color: featured ? tokens.accent : tokens.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (featured)
              Text(
                l10n.mostBought,
                style: AppTypography.overline.copyWith(letterSpacing: 1, color: tokens.accent),
              ),
            Text(
              '$coins',
              style: AppTypography.screenTitle.copyWith(fontSize: 26, color: tokens.text),
            ),
            Text(
              l10n.unlockN(unlocks),
              style: AppTypography.bodySmall.copyWith(color: tokens.text.withValues(alpha: 0.6)),
            ),
            const SizedBox(height: AppDimensions.space12),
            PriceChip(label: price, outlined: !featured),
          ],
        ),
      ),
    );
  }
}
