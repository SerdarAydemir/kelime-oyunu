// lib/features/gameplay/widgets/word_frame.dart

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:kelime_oyunu/core/constants/app_colors.dart';

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
