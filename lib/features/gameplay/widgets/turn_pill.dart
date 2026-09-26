// lib/features/gameplay/widgets/turn_pill.dart

import 'package:flutter/material.dart';
import 'package:kelime_oyunu/core/constants/app_dimensions.dart';
import 'package:kelime_oyunu/core/constants/app_typography.dart';
import 'package:kelime_oyunu/core/theme/app_tokens.dart';
import 'package:kelime_oyunu/data/models/puzzle.dart';
import 'package:kelime_oyunu/features/gameplay/bloc/game_state.dart';
import 'package:kelime_oyunu/features/gameplay/bloc/move_narration.dart';
import 'package:kelime_oyunu/features/gameplay/widgets/narration_controller.dart';
import 'package:kelime_oyunu/features/gameplay/widgets/narration_timeline.dart';
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

/// The story-time pill, or null when nothing is being narrated right now:
/// "{WORD} · +{n} puan" while a completed word's bonus badge holds (amber for
/// the player, blue for the opponent), "Bu harf buraya uymuyor" (red) while a
/// wrong letter sits on its cell. Reads the narration clock only — it never
/// gates or alters it.
TurnPillSpec? narrationPillFor(
  NarrationController controller,
  PuzzleData puzzle,
  AppLocalizations l10n,
) {
  final timeline = controller.currentTimeline;
  if (timeline == null) return null;
  final progress = controller.progress;
  final actorTint = controller.currentActor == NarrationActor.bot ? TurnTint.bot : TurnTint.player;
  TurnPillSpec? wrong;
  for (final cue in timeline.cues) {
    if (progress < cue.landAt || progress > cue.absorbAt) continue;
    if (cue.kind == CueKind.wordBonus && cue.event.completedWordId != null) {
      final word = puzzle.words.where((w) => w.id == cue.event.completedWordId);
      if (word.isEmpty) continue;
      // A completed word outranks a wrong letter in the same move.
      return (text: l10n.wordDone(word.first.answer, cue.delta), tint: actorTint, dots: false);
    }
    if (cue.kind == CueKind.letter && cue.delta < 0) {
      wrong = (text: l10n.wrongLetter, tint: TurnTint.wrong, dots: false);
    }
  }
  return wrong;
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
    // liveRegion: TalkBack announces each turn-state change.
    return Semantics(
      liveRegion: true,
      child: AnimatedContainer(
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
            if (spec.dots) ...[
              const SizedBox(width: AppDimensions.space6),
              _BobbingDots(color: ink),
            ],
          ],
        ),
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
