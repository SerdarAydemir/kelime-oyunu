// lib/features/gameplay/widgets/swap_sheet.dart

import 'package:flutter/material.dart';
import 'package:kelime_oyunu/core/constants/app_dimensions.dart';
import 'package:kelime_oyunu/core/constants/app_typography.dart';
import 'package:kelime_oyunu/core/theme/app_tokens.dart';
import 'package:kelime_oyunu/features/gameplay/engine/rack_manager.dart';
import 'package:kelime_oyunu/features/gameplay/widgets/ad_label.dart';
import 'package:kelime_oyunu/features/gameplay/widgets/sheet_shell.dart';
import 'package:kelime_oyunu/l10n/generated/app_localizations.dart';

/// What the player chose in the swap sheet: which tiles and how to pay.
typedef SwapChoice = ({List<int> indices, bool viaAd});

/// Bottom sheet for the letter-swap joker (README "Swap sheet").
///
/// The player picks tiles, then pays one of two ways: "Şimdi değiştir"
/// (rewarded ad, turn stays) or "Değiştir ve pas" (free, costs the turn).
/// Pops with a [SwapChoice]; null when dismissed.
class SwapSheet extends StatefulWidget {
  const SwapSheet({
    required this.rack,
    required this.quotaRemaining,
    this.showAdLabel = false,
    super.key,
  });

  final List<RackTile> rack;

  /// Letters the player may still swap this match; selection is capped to it.
  final int quotaRemaining;

  /// Whether the ad-paid option carries its "▶ reklam" sub-label.
  final bool showAdLabel;

  @override
  State<SwapSheet> createState() => _SwapSheetState();
}

class _SwapSheetState extends State<SwapSheet> {
  final Set<int> _selected = {};

  void _toggle(int index) {
    setState(() {
      if (!_selected.remove(index) && _selected.length < widget.quotaRemaining) {
        _selected.add(index);
      }
    });
  }

  void _finish(bool viaAd) =>
      Navigator.pop(context, (indices: _selected.toList()..sort(), viaAd: viaAd));

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final l10n = AppLocalizations.of(context);
    final hasSelection = _selected.isNotEmpty;
    return SheetShell(
      title: l10n.swap,
      trailing: Text(
        l10n.swapLeftCount(widget.quotaRemaining),
        style: AppTypography.label.copyWith(fontWeight: FontWeight.w700, color: tokens.sheetMuted),
      ),
      children: [
        const SizedBox(height: AppDimensions.space4),
        Text(l10n.swapSub, style: AppTypography.label.copyWith(color: tokens.sheetMuted)),
        const SizedBox(height: AppDimensions.space20),
        // Lifted selected tiles need headroom; 6 dp gap between tiles.
        Padding(
          padding: const EdgeInsets.only(top: AppDimensions.space6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < widget.rack.length; i++) ...[
                if (i > 0) const SizedBox(width: AppDimensions.space6),
                _SelectableTile(
                  letter: widget.rack[i].letter,
                  selected: _selected.contains(i),
                  onTap: () => _toggle(i),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppDimensions.space12),
        Text(
          hasSelection ? l10n.swapSelected(_selected.length) : l10n.swapNone,
          textAlign: TextAlign.center,
          style: AppTypography.label.copyWith(color: tokens.sheetMuted),
        ),
        const SizedBox(height: AppDimensions.space16),
        // Both options at 40 % until a tile is picked.
        AnimatedOpacity(
          opacity: hasSelection ? 1.0 : 0.4,
          duration: const Duration(milliseconds: 150),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _OptionButton(
                primary: true,
                title: l10n.swapNow,
                subtitle: l10n.swapKeep,
                showAdLabel: widget.showAdLabel,
                onPressed: hasSelection ? () => _finish(true) : null,
              ),
              const SizedBox(height: AppDimensions.space10),
              _OptionButton(
                primary: false,
                title: l10n.swapPass,
                subtitle: l10n.swapFree,
                onPressed: hasSelection ? () => _finish(false) : null,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// 56 × 60 r10 `sheetCard` tile with the 4 dp `tileShadow` base; selected →
/// amber, 3 px `arrow` ring, lifted 6 dp.
class _SelectableTile extends StatelessWidget {
  const _SelectableTile({required this.letter, required this.selected, required this.onTap});

  final String letter;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        width: 56,
        height: 60,
        transform: Matrix4.translationValues(0, selected ? -6 : 0, 0),
        decoration: BoxDecoration(
          color: selected ? tokens.accent : tokens.sheetCard,
          borderRadius: BorderRadius.circular(AppDimensions.radiusTile),
          border: selected ? Border.all(color: tokens.arrow, width: 3) : null,
          boxShadow: [BoxShadow(color: tokens.tileShadow, offset: const Offset(0, 4))],
        ),
        alignment: Alignment.center,
        child: Text(
          letter,
          textScaler: TextScaler.noScaling,
          style: AppTypography.tileLetter.copyWith(color: tokens.tileInk),
        ),
      ),
    );
  }
}

/// "Şimdi değiştir [▶ reklam] · sıra sende kalır" (primary 56) or
/// "Değiştir ve pas · ücretsiz, sıra rakibe" (outlined 52).
class _OptionButton extends StatelessWidget {
  const _OptionButton({
    required this.primary,
    required this.title,
    required this.subtitle,
    required this.onPressed,
    this.showAdLabel = false,
  });

  final bool primary;
  final String title;
  final String subtitle;
  final VoidCallback? onPressed;
  final bool showAdLabel;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final ink = primary ? tokens.accentInk : tokens.sheetText;
    final label = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Wrap + centred text: at large system fonts the title and the ad
        // label fold instead of overflowing the button.
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: AppDimensions.space6,
          children: [
            Text(
              title,
              textAlign: TextAlign.center,
              style: (primary ? AppTypography.buttonPrimary : AppTypography.buttonSecondary)
                  .copyWith(color: ink),
            ),
            if (showAdLabel) AdLabel(color: ink),
          ],
        ),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: AppTypography.label.copyWith(color: ink.withValues(alpha: 0.75), height: 1.2),
        ),
      ],
    );
    // Minimum heights (56 / 52): the two-line label may grow them at large
    // system fonts instead of overflowing.
    if (primary) {
      return ConstrainedBox(
        constraints: const BoxConstraints(minHeight: AppDimensions.buttonPrimary),
        child: FilledButton(
          onPressed: onPressed,
          style: FilledButton.styleFrom(
            backgroundColor: tokens.accent,
            disabledBackgroundColor: tokens.accent,
            foregroundColor: tokens.accentInk,
            disabledForegroundColor: tokens.accentInk,
            shape: const StadiumBorder(),
          ),
          child: label,
        ),
      );
    }
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: AppDimensions.buttonGame),
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: tokens.sheetText,
          disabledForegroundColor: tokens.sheetText,
          side: BorderSide(color: tokens.sheetMuted.withValues(alpha: 0.4)),
          shape: const StadiumBorder(),
        ),
        child: label,
      ),
    );
  }
}
