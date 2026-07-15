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

/// The word-completion highlight: a cell-aligned rounded rect that pops in with
/// an outer glow, holds, then fades. Pure function of [local] ([0,1]).
class WordFrame extends StatelessWidget {
  const WordFrame({required this.local, super.key});

  final double local;

  @override
  Widget build(BuildContext context) {
    final appear = Curves.easeOutBack.transform(math.min(1, local / 0.25));
    final fade = local < 0.65 ? 1.0 : 1.0 - (local - 0.65) / 0.35;
    final alpha = (appear * fade).clamp(0.0, 1.0);
    final scale = 0.94 + 0.06 * appear;
    return IgnorePointer(
      child: Opacity(
        opacity: alpha,
        child: Transform.scale(
          scale: scale,
          child: Container(
            margin: const EdgeInsets.all(1.5),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.accent, width: 2.5),
              boxShadow: [
                BoxShadow(
                  color: AppColors.accent.withValues(alpha: 0.55 * alpha),
                  blurRadius: 12,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A single score badge: pops in, floats up, fades out over its [local] life
/// ([0,1]). Pure function of [local] so the driving controller stays the clock.
class NarrationBadge extends StatelessWidget {
  const NarrationBadge({
    required this.text,
    required this.color,
    required this.local,
    this.big = false,
    super.key,
  });

  final String text;
  final Color color;
  final double local;

  /// The rack-empty bonus reads as a headline — a larger pill at grid centre.
  final bool big;

  @override
  Widget build(BuildContext context) {
    // Ease: quick pop (0→0.15), hold, drift up and fade out (0.6→1).
    final appear = Curves.easeOut.transform(math.min(1, local / 0.15));
    final fade = local < 0.6 ? 1.0 : 1.0 - (local - 0.6) / 0.4;
    final rise = -18.0 * Curves.easeOut.transform(local);
    final scale = (big ? 0.7 : 0.6) + 0.4 * appear;
    return Align(
      alignment: big ? Alignment.center : Alignment.topCenter,
      child: Transform.translate(
        offset: Offset(0, big ? rise * 0.5 : -6 + rise),
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
