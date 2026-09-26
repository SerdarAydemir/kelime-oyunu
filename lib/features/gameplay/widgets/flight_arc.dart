// lib/features/gameplay/widgets/flight_arc.dart

import 'package:flutter/material.dart';

/// Dashed arc a flying letter follows (README "Harf uçuşu": dashed blue arc
/// from the avatar to the target cell; "Yanlış harf": red dashed arc back to
/// the rack). Pure geometry over the narration overlay; [from] / [to] are in
/// the overlay's grid-box coordinates and the arc bows [lift] px upward.
class FlightArc extends StatelessWidget {
  const FlightArc({
    required this.from,
    required this.to,
    required this.color,
    this.lift = 40,
    this.opacity = 1,
    super.key,
  });

  final Offset from;
  final Offset to;
  final Color color;
  final double lift;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        painter: _ArcPainter(
          from: from,
          to: to,
          color: color.withValues(alpha: opacity.clamp(0.0, 1.0)),
          lift: lift,
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _ArcPainter extends CustomPainter {
  const _ArcPainter({
    required this.from,
    required this.to,
    required this.color,
    required this.lift,
  });

  final Offset from;
  final Offset to;
  final Color color;
  final double lift;

  @override
  void paint(Canvas canvas, Size size) {
    final mid = Offset((from.dx + to.dx) / 2, (from.dy + to.dy) / 2 - lift);
    final path = Path()
      ..moveTo(from.dx, from.dy)
      ..quadraticBezierTo(mid.dx, mid.dy, to.dx, to.dy);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    for (final metric in path.computeMetrics()) {
      var d = 0.0;
      while (d < metric.length) {
        canvas.drawPath(metric.extractPath(d, (d + 5).clamp(0, metric.length)), paint);
        d += 11;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ArcPainter old) =>
      from != old.from || to != old.to || color != old.color || lift != old.lift;
}
