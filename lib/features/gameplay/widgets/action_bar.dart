// lib/features/gameplay/widgets/action_bar.dart

import 'package:flutter/material.dart';
import 'package:kelime_oyunu/core/constants/app_dimensions.dart';
import 'package:kelime_oyunu/core/constants/app_typography.dart';
import 'package:kelime_oyunu/core/theme/app_tokens.dart';
import 'package:kelime_oyunu/features/gameplay/engine/score_engine.dart';
import 'package:kelime_oyunu/features/gameplay/widgets/ad_label.dart';
import 'package:kelime_oyunu/l10n/generated/app_localizations.dart';

/// Bottom bar (README "Bottom bar"): swap circle · confirm / pass pill ·
/// hint circle, all 52 dp. During the bot's turn the bar dims to 40 % and
/// the pill turns into a `surface` "Sıra rakipte" label.
class ActionBar extends StatelessWidget {
  const ActionBar({
    required this.pendingPlacements,
    required this.onConfirm,
    required this.onPass,
    required this.onSwap,
    required this.onReveal,
    this.revealActive = false,
    this.botTurn = false,
    this.showAdLabel = false,
    this.compact = false,
    super.key,
  });

  final List<Placement> pendingPlacements;

  /// Null while reveal mode is active: gameplay actions are disabled.
  final VoidCallback? onConfirm;
  final VoidCallback? onPass;
  final VoidCallback? onSwap;

  /// Toggles reveal mode; null when revealing is not allowed (bot's turn).
  final VoidCallback? onReveal;

  /// Whether reveal mode is on — the lamp renders in its "active" look.
  final bool revealActive;

  /// The opponent is playing: dimmed bar, "Sıra rakipte" pill.
  final bool botTurn;

  /// Whether the hint button carries its "▶ reklam" sub-label.
  final bool showAdLabel;

  /// Short screens: 44 dp controls and tighter padding.
  final bool compact;

  static double sizeFor({required bool compact}) =>
      compact ? AppDimensions.buttonGameCompact : AppDimensions.buttonGame;

  @override
  Widget build(BuildContext context) {
    final hasPending = pendingPlacements.isNotEmpty;
    return AnimatedOpacity(
      opacity: botTurn ? 0.4 : 1.0,
      duration: const Duration(milliseconds: 200),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          AppDimensions.space16,
          compact ? AppDimensions.space4 : AppDimensions.space8,
          AppDimensions.space16,
          compact ? AppDimensions.space6 : AppDimensions.space12,
        ),
        child: Row(
          children: [
            _SwapButton(
              onTap: hasPending ? null : onSwap,
              size: sizeFor(compact: compact),
            ),
            const SizedBox(width: AppDimensions.space10),
            Expanded(
              child: _ConfirmPassButton(
                hasPending: hasPending,
                botTurn: botTurn,
                onConfirm: onConfirm,
                onPass: onPass,
                height: sizeFor(compact: compact),
              ),
            ),
            const SizedBox(width: AppDimensions.space10),
            _RevealButton(
              onReveal: onReveal,
              active: revealActive,
              showAdLabel: showAdLabel,
              size: sizeFor(compact: compact),
            ),
          ],
        ),
      ),
    );
  }
}

/// Swap: 52 dp circle with a 1.5 px `faint` ring; 40 % when disabled.
class _SwapButton extends StatelessWidget {
  const _SwapButton({required this.onTap, required this.size});

  final VoidCallback? onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Semantics(
      button: true,
      enabled: onTap != null,
      label: AppLocalizations.of(context).swap,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Opacity(
          opacity: onTap == null ? 0.4 : 1.0,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: tokens.faint, width: 1.5),
            ),
            child: Icon(Icons.swap_horiz, color: tokens.text, size: 22),
          ),
        ),
      ),
    );
  }
}

class _ConfirmPassButton extends StatelessWidget {
  const _ConfirmPassButton({
    required this.hasPending,
    required this.botTurn,
    required this.onConfirm,
    required this.onPass,
    required this.height,
  });

  final bool hasPending;
  final bool botTurn;
  final double height;
  final VoidCallback? onConfirm;
  final VoidCallback? onPass;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final l10n = AppLocalizations.of(context);
    final label = botTurn ? l10n.botTurnBtn : (hasPending ? l10n.confirm : l10n.pass);
    return SizedBox(
      height: height,
      child: FilledButton(
        onPressed: botTurn ? null : (hasPending ? onConfirm : onPass),
        style: FilledButton.styleFrom(
          backgroundColor: tokens.accent,
          foregroundColor: tokens.accentInk,
          disabledBackgroundColor: botTurn ? tokens.surface : tokens.accent.withValues(alpha: 0.4),
          disabledForegroundColor: botTurn ? tokens.text : tokens.accentInk,
          textStyle: AppTypography.buttonPrimary,
          shape: const StadiumBorder(),
        ),
        child: Text(label),
      ),
    );
  }
}

/// Hint (lamp): 52 dp circle, amber 15 % fill with a 1.5 px amber ring;
/// solid amber while reveal mode is on; 40 % when disabled.
class _RevealButton extends StatelessWidget {
  const _RevealButton({
    required this.onReveal,
    required this.active,
    required this.showAdLabel,
    required this.size,
  });

  final VoidCallback? onReveal;
  final double size;

  /// Reveal mode is on: render filled so the toggle state is obvious.
  final bool active;
  final bool showAdLabel;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final l10n = AppLocalizations.of(context);
    final ink = active ? tokens.accentInk : tokens.accent;
    return Semantics(
      button: true,
      enabled: onReveal != null,
      toggled: active,
      excludeSemantics: true,
      label: l10n.hint,
      child: InkWell(
        onTap: onReveal,
        customBorder: const CircleBorder(),
        child: Opacity(
          opacity: onReveal == null ? 0.4 : 1.0,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: active ? tokens.accent : tokens.accent.withValues(alpha: 0.15),
              border: Border.all(color: tokens.accent, width: 1.5),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(active ? Icons.lightbulb : Icons.lightbulb_outline, color: ink, size: 17),
                Text(
                  l10n.hint,
                  textScaler: TextScaler.noScaling,
                  style: AppTypography.buttonPrimary.copyWith(fontSize: 7, height: 1.2, color: ink),
                ),
                if (showAdLabel) AdLabel(color: ink),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
