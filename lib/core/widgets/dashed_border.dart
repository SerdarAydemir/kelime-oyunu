// lib/core/widgets/dashed_border.dart

import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Paints a dashed rounded-rectangle outline (the design's "dashed slot").
/// Wrap the slot in a [CustomPaint] with this as its `painter`.
class DashedBorderPainter extends CustomPainter {
  const DashedBorderPainter({
    required this.color,
    required this.radius,
    this.strokeWidth = 1.5,
    this.dash = 5,
    this.gap = 4,
  });

  final Color color;
  final double radius;
  final double strokeWidth;
  final double dash;
  final double gap;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      (Offset.zero & size).deflate(strokeWidth / 2),
      Radius.circular(radius),
    );
    final outline = Path()..addRRect(rrect);
    final dashed = Path();
    for (final ui.PathMetric metric in outline.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final end = (distance + dash).clamp(0.0, metric.length);
        dashed.addPath(metric.extractPath(distance, end), Offset.zero);
        distance += dash + gap;
      }
    }
    canvas.drawPath(
      dashed,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant DashedBorderPainter old) =>
      color != old.color ||
      radius != old.radius ||
      strokeWidth != old.strokeWidth ||
      dash != old.dash ||
      gap != old.gap;
}
