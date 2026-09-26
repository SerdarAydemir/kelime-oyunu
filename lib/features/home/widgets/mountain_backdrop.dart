// lib/features/home/widgets/mountain_backdrop.dart

import 'package:flutter/material.dart';
import 'package:kelime_oyunu/core/theme/app_tokens.dart';

/// Decorative mountain silhouettes (README "Home": three polygons in `mtn1`
/// 85 %, `mtn2`, `mtn3`) with a dashed amber trail climbing the near ridge and
/// an amber dot at its end. Sits behind the content; never repaints on its
/// own — the palette is the only input.
class MountainBackdrop extends StatelessWidget {
  const MountainBackdrop({
    this.trail = true,
    this.layers = 3,
    this.alphas = const [0.85, 1, 1],
    super.key,
  });

  /// Whether to draw the dashed trail + dot.
  final bool trail;

  /// How many ridges to draw (1–3), far (`mtn1`) to near (`mtn3`).
  final int layers;

  /// Opacity per drawn ridge, far to near (README "Home": `mtn1` 85 %;
  /// "Consent": `mtn1` 70 %, `mtn2` 60 %).
  final List<double> alphas;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        painter: _MountainPainter(
          tokens: context.tokens,
          trail: trail,
          layers: layers,
          alphas: alphas,
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _MountainPainter extends CustomPainter {
  const _MountainPainter({
    required this.tokens,
    required this.trail,
    required this.layers,
    required this.alphas,
  });

  final AppTokens tokens;
  final bool trail;
  final int layers;
  final List<double> alphas;

  // Ridge lines as (x, y) fractions of the canvas; each polygon closes along
  // the bottom edge.
  static const List<List<Offset>> _ridges = [
    [
      Offset(0, 0.62),
      Offset(0.18, 0.46),
      Offset(0.36, 0.56),
      Offset(0.55, 0.38),
      Offset(0.74, 0.5),
      Offset(0.9, 0.42),
      Offset(1, 0.5),
    ],
    [
      Offset(0, 0.74),
      Offset(0.22, 0.58),
      Offset(0.42, 0.68),
      Offset(0.62, 0.52),
      Offset(0.82, 0.64),
      Offset(1, 0.58),
    ],
    [
      Offset(0, 0.86),
      Offset(0.28, 0.7),
      Offset(0.5, 0.8),
      Offset(0.7, 0.64),
      Offset(0.88, 0.76),
      Offset(1, 0.7),
    ],
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final colours = [tokens.mtn1, tokens.mtn2, tokens.mtn3];
    for (var i = 0; i < layers.clamp(1, 3); i++) {
      final path = Path()..moveTo(0, size.height);
      for (final p in _ridges[i]) {
        path.lineTo(p.dx * size.width, p.dy * size.height);
      }
      path
        ..lineTo(size.width, size.height)
        ..close();
      final alpha = i < alphas.length ? alphas[i] : 1.0;
      canvas.drawPath(path, Paint()..color = colours[i].withValues(alpha: alpha));
    }
    if (!trail) return;
    // Dashed trail up the near ridge, ending in a dot near the summit.
    final ridge = _ridges[2];
    final line = Path()..moveTo(ridge[0].dx * size.width, size.height * 0.95);
    for (final p in [ridge[1], ridge[2], ridge[3]]) {
      line.lineTo(p.dx * size.width, (p.dy + 0.02) * size.height);
    }
    final paint = Paint()
      ..color = tokens.accent.withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    for (final metric in line.computeMetrics()) {
      var d = 0.0;
      while (d < metric.length) {
        canvas.drawPath(metric.extractPath(d, (d + 5).clamp(0, metric.length)), paint);
        d += 14;
      }
    }
    final end = ridge[3];
    canvas.drawCircle(
      Offset(end.dx * size.width, (end.dy + 0.02) * size.height),
      5,
      Paint()..color = tokens.accent,
    );
  }

  @override
  bool shouldRepaint(covariant _MountainPainter old) =>
      tokens != old.tokens || trail != old.trail || layers != old.layers || alphas != old.alphas;
}
