// lib/features/gameplay/widgets/action_bar.dart

import 'package:flutter/material.dart';
import 'package:kelime_oyunu/core/constants/app_typography.dart';
import 'package:kelime_oyunu/core/theme/app_tokens.dart';
import 'package:kelime_oyunu/features/gameplay/engine/score_engine.dart';
import 'package:kelime_oyunu/l10n/generated/app_localizations.dart';

class ActionBar extends StatelessWidget {
  const ActionBar({
    required this.pendingPlacements,
    required this.onConfirm,
    required this.onPass,
    required this.onSwap,
    required this.onReveal,
    this.revealActive = false,
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

  @override
  Widget build(BuildContext context) {
    final hasPending = pendingPlacements.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          _CircleIconButton(icon: Icons.swap_horiz, onTap: hasPending ? null : onSwap),
          const SizedBox(width: 8),
          Expanded(
            child: _ConfirmPassButton(hasPending: hasPending, onConfirm: onConfirm, onPass: onPass),
          ),
          const SizedBox(width: 8),
          _RevealButton(onReveal: onReveal, active: revealActive),
        ],
      ),
    );
  }
}

/// Swap button: a `surface` circle with a 1.5 px `faint` ring (design "Bottom
/// bar"); dims to 40 % when disabled.
class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Opacity(
        opacity: onTap == null ? 0.4 : 1.0,
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: tokens.surface,
            border: Border.all(color: tokens.faint, width: 1.5),
          ),
          child: Icon(icon, color: tokens.text, size: 22),
        ),
      ),
    );
  }
}

class _ConfirmPassButton extends StatelessWidget {
  const _ConfirmPassButton({
    required this.hasPending,
    required this.onConfirm,
    required this.onPass,
  });

  final bool hasPending;
  final VoidCallback? onConfirm;
  final VoidCallback? onPass;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final l10n = AppLocalizations.of(context);
    return SizedBox(
      height: 48,
      child: ElevatedButton(
        onPressed: hasPending ? onConfirm : onPass,
        style: ElevatedButton.styleFrom(
          backgroundColor: tokens.accent,
          foregroundColor: tokens.accentInk,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          elevation: 2,
        ),
        child: Text(hasPending ? l10n.confirm : l10n.pass, style: AppTypography.buttonPrimary),
      ),
    );
  }
}

/// Reveal (lamp) button: amber 15 % fill with an amber ring while available,
/// solid amber while reveal mode is on, 40 % dimmed when disabled.
class _RevealButton extends StatelessWidget {
  const _RevealButton({required this.onReveal, required this.active});

  final VoidCallback? onReveal;

  /// Reveal mode is on: render filled so the toggle state is obvious.
  final bool active;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return InkWell(
      onTap: onReveal,
      borderRadius: BorderRadius.circular(24),
      child: Opacity(
        opacity: onReveal == null ? 0.4 : 1.0,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: active ? tokens.accent : tokens.accent.withValues(alpha: 0.15),
                border: Border.all(color: tokens.accent, width: 1.5),
              ),
              child: Icon(
                active ? Icons.lightbulb : Icons.lightbulb_outline,
                color: active ? tokens.accentInk : tokens.accent,
                size: 22,
              ),
            ),
            Positioned(
              top: -4,
              right: -4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  color: tokens.accent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  AppLocalizations.of(context).ad,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: tokens.accentInk,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
