// lib/features/gameplay/widgets/word_frame.dart

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:kelime_oyunu/core/theme/app_tokens.dart';

/// The word-completion celebration (README "Kelime tamamlandı"): a 3 px amber
/// ring around the word with a pulsing amber glow and a bright shimmer
/// travelling around the border while it holds (the "+N" badge sits over
/// it), fading only at the end as the badge flies to the score. Pure
/// function of [local] over the word cue's land→absorb window.
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
            painter: _GoldenFramePainter(
              sweep: local * 2 * 2 * math.pi,
              alpha: alpha,
              tokens: context.tokens,
            ),
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
  _GoldenFramePainter({required this.sweep, required this.alpha, required this.tokens});

  final double sweep;
  final double alpha;
  final AppTokens tokens;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      (Offset.zero & size).deflate(2),
      const Radius.circular(8),
    );
    // Glow `0 0 30 6 rgba(242,194,122,.55)`, pulsing (≈ 1.2 s over the
    // 1.9 s hold): spread 6 → stroke 12 under a 15 px blur.
    final pulse = 0.7 + 0.3 * math.sin(sweep / 4 * 1.6);
    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 12
        ..color = tokens.accent.withValues(alpha: 0.55 * pulse * alpha)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 15),
    );
    // 3 px amber ring.
    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = tokens.accent,
    );
    // Travelling shimmer: a bright arc sweeping around the border.
    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5
        ..shader = SweepGradient(
          transform: GradientRotation(sweep),
          colors: [
            tokens.cellLetter.withValues(alpha: 0),
            tokens.cellLetter,
            tokens.cellLetter.withValues(alpha: 0),
            tokens.cellLetter.withValues(alpha: 0),
          ],
          stops: const [0.0, 0.08, 0.2, 1.0],
        ).createShader(Offset.zero & size),
    );
  }

  @override
  bool shouldRepaint(covariant _GoldenFramePainter old) =>
      sweep != old.sweep || alpha != old.alpha || tokens != old.tokens;
}
