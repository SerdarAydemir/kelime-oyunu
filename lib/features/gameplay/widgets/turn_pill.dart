// lib/features/gameplay/widgets/turn_pill.dart

import 'package:flutter/material.dart';
import 'package:kelime_oyunu/core/constants/app_dimensions.dart';
import 'package:kelime_oyunu/core/constants/app_typography.dart';
import 'package:kelime_oyunu/core/theme/app_tokens.dart';
import 'package:kelime_oyunu/features/gameplay/bloc/game_state.dart';
import 'package:kelime_oyunu/l10n/generated/app_localizations.dart';

/// Which tint the turn pill wears (README "Turn pill").
enum TurnTint { player, bot, wrong }

/// What the pill says and how it is tinted.
typedef TurnPillSpec = ({String text, TurnTint tint, bool dots});

/// Derives the pill from the game state alone: "Sıra sende" / "{n} harf
/// bekliyor · onayla" / "Boş bir hücreye dokun" / "Rakip düşünüyor".
/// Narration-time texts (word done, wrong letter) are layered on by the
/// screen, which owns the narration clock.
TurnPillSpec turnPillFor(GameActive state, AppLocalizations l10n) {
  if (state.botThinking || state.phase == TurnPhase.botThinking) {
    return (text: l10n.turnBot, tint: TurnTint.bot, dots: true);
  }
  if (state.pendingPlacements.isNotEmpty) {
    return (
      text: l10n.turnPending(state.pendingPlacements.length),
      tint: TurnTint.player,
      dots: false,
    );
  }
  if (state.selectedRackIndex >= 0) {
    return (text: l10n.turnTap, tint: TurnTint.player, dots: false);
  }
  return (text: l10n.turnYou, tint: TurnTint.player, dots: false);
}

/// The r999 status pill under the scorebar: amber tint for the player's
/// states, blue tint for the bot, red tint for a wrong letter.
class TurnPill extends StatelessWidget {
  const TurnPill({required this.spec, super.key});

  final TurnPillSpec spec;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final (fill, ink) = switch (spec.tint) {
      TurnTint.player => (tokens.accent.withValues(alpha: 0.18), tokens.text),
      TurnTint.bot => (tokens.bot.withValues(alpha: 0.18), tokens.text),
      TurnTint.wrong => (tokens.error.withValues(alpha: 0.18), tokens.text),
    };
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.space12,
        vertical: AppDimensions.space6,
      ),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(AppDimensions.radiusPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            spec.text,
            style: AppTypography.overline.copyWith(
              letterSpacing: 0,
              fontWeight: FontWeight.w700,
              color: ink,
            ),
          ),
          if (spec.dots) ...[const SizedBox(width: AppDimensions.space6), _BobbingDots(color: ink)],
        ],
      ),
    );
  }
}

/// Three dots bobbing in turn (1 s loop, 0.2 s stagger) while the bot thinks.
class _BobbingDots extends StatefulWidget {
  const _BobbingDots({required this.color});

  final Color color;

  @override
  State<_BobbingDots> createState() => _BobbingDotsState();
}

class _BobbingDotsState extends State<_BobbingDots> with SingleTickerProviderStateMixin {
  late final AnimationController _loop = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 1),
  )..repeat();

  @override
  void dispose() {
    _loop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _loop,
      builder: (context, _) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < 3; i++)
            Padding(
              padding: EdgeInsets.only(left: i == 0 ? 0 : 3),
              child: Transform.translate(
                offset: Offset(0, -3 * _bob((_loop.value - i * 0.2) % 1)),
                child: Container(
                  width: 4,
                  height: 4,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: widget.color),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // A short lift in the first 40 % of each dot's cycle, rest flat.
  static double _bob(double t) => t < 0.4 ? Curves.easeInOut.transform(1 - (t / 0.2 - 1).abs()) : 0;
}
