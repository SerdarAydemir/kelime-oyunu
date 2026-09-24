// lib/features/map/widgets/trail_painter.dart

import 'package:flutter/material.dart';
import 'package:kelime_oyunu/core/theme/app_tokens.dart';
import 'package:kelime_oyunu/features/map/map_layout.dart';

/// The dashed amber trail through every node centre (3 px, dash 5 / gap 9,
/// 60 %) plus the 14 dp `faint` dots of the far nodes, painted rather than
/// built: a couple of hundred dots as widgets would be pure overhead.
class TrailPainter extends CustomPainter {
  const TrailPainter({required this.layout, required this.tokens, required this.dotLevels});

  final MapLayout layout;
  final AppTokens tokens;

  /// Levels drawn as far dots (the rest are widgets on top).
  final List<int> dotLevels;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()..moveTo(layout.center(1).dx, layout.center(1).dy);
    for (var n = 2; n <= layout.nodeCount; n++) {
      final c = layout.center(n);
      path.lineTo(c.dx, c.dy);
    }
    final paint = Paint()
      ..color = tokens.accent.withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    for (final metric in path.computeMetrics()) {
      var d = 0.0;
      while (d < metric.length) {
        canvas.drawPath(metric.extractPath(d, (d + 5).clamp(0, metric.length)), paint);
        d += 14;
      }
    }
    final dot = Paint()..color = tokens.faint;
    for (final n in dotLevels) {
      canvas.drawCircle(layout.center(n), 7, dot);
    }
  }

  @override
  bool shouldRepaint(covariant TrailPainter old) =>
      layout.currentLevel != old.layout.currentLevel ||
      layout.width != old.layout.width ||
      tokens != old.tokens ||
      dotLevels != old.dotLevels;
}
