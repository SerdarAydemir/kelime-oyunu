// lib/features/gameplay/widgets/narration_tiles.dart

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:kelime_oyunu/core/constants/app_colors.dart';

/// Presentational pieces of the score story. Each is a pure function of its
/// normalized inputs so [NarrationController] stays the single clock — no
/// widget here owns a timer or animation.

/// Small "2×" pill shown while the narration is fast-forwarding — confirms the
/// player's tap registered without ever cancelling the story.
class NarrationSpeedChip extends StatelessWidget {
  const NarrationSpeedChip({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.fast_forward, size: 16, color: Colors.white),
          SizedBox(width: 4),
          Text(
            '2×',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

/// A brief evaluation flash on the cell whose letter is being scored right
/// now: a coloured (green = correct, red = wrong) rounded border that pops and
/// fades. Gives the "letters score one by one" beat a spatial anchor without
/// moving the letter itself. Pure function of [local] ([0, 1]).
class CellPulse extends StatelessWidget {
  const CellPulse({required this.color, required this.local, super.key});

  final Color color;
  final double local;

  @override
  Widget build(BuildContext context) {
    final appear = Curves.easeOutBack.transform(math.min(1, local / 0.3));
    final fade = local < 0.55 ? 1.0 : 1.0 - (local - 0.55) / 0.45;
    final alpha = (appear * fade).clamp(0.0, 1.0);
    return IgnorePointer(
      child: Opacity(
        opacity: alpha,
        child: Container(
          margin: const EdgeInsets.all(1),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(7),
            border: Border.all(color: color, width: 2.5),
            color: color.withValues(alpha: 0.15 * alpha),
          ),
        ),
      ),
    );
  }
}

/// A letter mid-flight from its source (rack / bot portrait) to a cell. Fades
/// in on launch and out on arrival; the layer positions it and picks [phase]
/// (0 = just launched, 1 = landing).
class FlyingTile extends StatelessWidget {
  const FlyingTile({required this.letter, required this.size, required this.phase, super.key});

  final String letter;
  final double size;

  /// Flight progress in [0, 1]. Drives a gentle lift-then-settle scale and the
  /// fade in/out so the hand-off to the committed glyph is seamless.
  final double phase;

  @override
  Widget build(BuildContext context) {
    final fadeIn = math.min(1, phase / 0.12);
    final fadeOut = phase < 0.85 ? 1.0 : 1.0 - (phase - 0.85) / 0.15;
    final opacity = (fadeIn * fadeOut).clamp(0.0, 1.0);
    // Slight overshoot in scale mid-flight, settling to 1 on arrival.
    final scale = 1.0 + 0.12 * math.sin(phase * math.pi);
    return Opacity(
      opacity: opacity,
      child: Transform.scale(
        scale: scale,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: AppColors.rackTileBg,
            borderRadius: BorderRadius.circular(size * 0.14),
            boxShadow: const [
              BoxShadow(color: Color(0x40000000), blurRadius: 8, offset: Offset(0, 4)),
            ],
          ),
          alignment: Alignment.center,
          child: Text(
            letter,
            style: TextStyle(
              fontSize: size * 0.5,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ),
      ),
    );
  }
}

/// The word-completion celebration: a golden cell-aligned rounded frame with a
/// bright shimmer travelling around its border while it holds (the "+N" badge
/// sits over it), fading only at the end as the badge flies to the score.
/// Pure function of [local] over the word cue's land→absorb window.
class WordFrame extends StatelessWidget {
  const WordFrame({required this.local, super.key});

  final double local;

  @override
  Widget build(BuildContext context) {
    final appear = Curves.easeOutBack.transform(math.min(1, local / 0.12));
    final fade = local < 0.82 ? 1.0 : 1.0 - (local - 0.82) / 0.18;
    final alpha = (appear * fade).clamp(0.0, 1.0);
    final scale = 0.94 + 0.06 * appear;
    return IgnorePointer(
      child: Opacity(
        opacity: alpha,
        child: Transform.scale(
          scale: scale,
          child: CustomPaint(
            // Two full laps of shimmer over the celebration.
            painter: _GoldenFramePainter(sweep: local * 2 * 2 * math.pi, alpha: alpha),
            child: const SizedBox.expand(),
          ),
        ),
      ),
    );
  }
}

/// Paints the golden rounded border with a travelling highlight (a sweep
/// gradient rotated by [sweep]) plus a soft outer glow.
class _GoldenFramePainter extends CustomPainter {
  _GoldenFramePainter({required this.sweep, required this.alpha});

  final double sweep;
  final double alpha;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      (Offset.zero & size).deflate(2),
      const Radius.circular(8),
    );
    // Soft golden glow behind the border.
    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..color = AppColors.coinGold.withValues(alpha: 0.35 * alpha)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    // Base golden border.
    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..color = AppColors.coinGold,
    );
    // Travelling shimmer: a bright arc sweeping around the border.
    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5
        ..shader = SweepGradient(
          transform: GradientRotation(sweep),
          colors: const [
            Color(0x00FFFFFF),
            Color(0xFFFFF3C4),
            Color(0x00FFFFFF),
            Color(0x00FFFFFF),
          ],
          stops: const [0.0, 0.08, 0.2, 1.0],
        ).createShader(Offset.zero & size),
    );
  }

  @override
  bool shouldRepaint(covariant _GoldenFramePainter old) => sweep != old.sweep || alpha != old.alpha;
}

/// A returning letter tile: the wrong letter, shown sitting on its cell during
/// the narration and then carried back to the rack by the layer. Fades out
/// only in the last stretch of the return trip.
class GhostLetterTile extends StatelessWidget {
  const GhostLetterTile({required this.letter, required this.size, this.fade = 1.0, super.key});

  final String letter;
  final double size;
  final double fade;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: fade.clamp(0.0, 1.0),
      child: Container(
        width: size,
        height: size,
        margin: EdgeInsets.all(size * 0.08),
        decoration: BoxDecoration(
          color: AppColors.rackTileBg,
          borderRadius: BorderRadius.circular(size * 0.12),
          border: Border.all(color: AppColors.error, width: 1.5),
        ),
        alignment: Alignment.center,
        child: Text(
          letter,
          style: TextStyle(
            fontSize: size * 0.42,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
      ),
    );
  }
}

/// A single score badge over its [local] life ([0,1]): pops in on the cell,
/// holds, then — while the layer carries it toward its owner's score display —
/// shrinks slightly and is swallowed on arrival (the counter ticks that same
/// instant). Pure function of [local] so the driving controller stays the clock.
class NarrationBadge extends StatelessWidget {
  const NarrationBadge({
    required this.text,
    required this.color,
    required this.local,
    this.big = false,
    this.hold = holdEnds,
    super.key,
  });

  final String text;
  final Color color;
  final double local;

  /// The rack-empty bonus reads as a headline — a larger pill at grid centre.
  final bool big;

  /// Fraction of THIS badge's life spent holding before it flies to the score
  /// (word badges hold much longer — see NarrationTimeline.wordHoldFraction).
  final double hold;

  /// Default hold split for letter/rack badges.
  static const double holdEnds = 0.4;

  @override
  Widget build(BuildContext context) {
    // Quick pop (0→0.15), hold on the cell, stay fully visible in flight and
    // vanish only in the last stretch as the score display swallows it.
    final appear = Curves.easeOut.transform(math.min(1, local / 0.15));
    final fade = local < 0.85 ? 1.0 : 1.0 - (local - 0.85) / 0.15;
    // Slightly shrink while flying so the pill reads as "condensing" into the
    // counter; no vertical drift — the layer owns the travel path.
    final flight = local <= hold ? 0.0 : (local - hold) / (1 - hold);
    final scale = ((big ? 0.7 : 0.6) + 0.4 * appear) * (1.0 - 0.35 * flight);
    return Align(
      alignment: big ? Alignment.center : Alignment.topCenter,
      child: Transform.translate(
        offset: const Offset(0, -6),
        child: Opacity(
          opacity: (appear * fade).clamp(0.0, 1.0),
          child: Transform.scale(
            scale: scale,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: big ? 14 : 8, vertical: big ? 6 : 3),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(big ? 16 : 12),
                boxShadow: const [
                  BoxShadow(color: Color(0x40000000), blurRadius: 4, offset: Offset(0, 2)),
                ],
              ),
              child: Text(
                text,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: big ? 22 : 15,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
