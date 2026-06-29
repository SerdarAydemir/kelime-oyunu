// lib/features/gameplay/widgets/clue_renderer.dart

import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:kelime_oyunu/core/constants/app_colors.dart';
import 'package:kelime_oyunu/data/models/puzzle.dart';

/// Paints clue cells onto the grid canvas: the pale background, the auto-scaled
/// and centred clue text, the divider for double-clue cells, and the arrow
/// badges. Isolated from GridPainter so clue typography (placeholder/font work)
/// can evolve without touching grid geometry.
class ClueRenderer {
  const ClueRenderer();

  // Readability bounds for auto-scaled clue text (logical px).
  static const double _minFont = 8.0;
  static const double _maxFont = 13.0;

  // Inner padding and the band reserved at the bottom for the arrow badge so
  // centred text never collides with it.
  static const double _pad = 2.0;
  static const double _badge = 12.0;

  /// Draws the full clue cell. [spec] must be a [CellType.clue] cell.
  void drawCell(Canvas canvas, Rect rect, CellSpec spec) {
    canvas.drawRect(rect, Paint()..color = AppColors.clueCellBg);
    if (spec.clues.length >= 2) {
      final half = rect.height / 2;
      _drawClueText(canvas, Rect.fromLTWH(rect.left, rect.top, rect.width, half), spec.clues[0]);
      _drawClueText(
        canvas,
        Rect.fromLTWH(rect.left, rect.top + half, rect.width, half),
        spec.clues[1],
      );
      // Divider between the two clues; each half is its own reveal target.
      canvas.drawLine(
        Offset(rect.left, rect.top + half),
        Offset(rect.right, rect.top + half),
        Paint()
          ..color = Colors.black
          ..strokeWidth = 1,
      );
    } else if (spec.clues.isNotEmpty) {
      _drawClueText(canvas, rect, spec.clues[0]);
    }
  }

  /// Auto-scales [clue].text to fit [rect] (minus padding and the badge band),
  /// then paints it centred on both axes. At the font floor it caps the line
  /// count to whatever fits and ellipsises the overflow, so text is never
  /// vertically clipped.
  void _drawClueText(Canvas canvas, Rect rect, ClueSpec clue) {
    final maxW = math.max(0.0, rect.width - _pad * 2);
    final maxH = math.max(0.0, rect.height - _pad * 2 - _badge);
    var fontSize = (rect.height * 0.26).clamp(_minFont, _maxFont);

    late TextPainter tp;
    while (true) {
      final atFloor = fontSize <= _minFont;
      final maxLines = atFloor ? math.max(1, (maxH / (fontSize * 1.35)).floor()) : null;
      tp = TextPainter(
        text: TextSpan(
          text: clue.text,
          style: TextStyle(fontSize: fontSize, color: Colors.black),
        ),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
        maxLines: maxLines,
        ellipsis: atFloor ? '…' : null,
      )..layout(maxWidth: maxW);
      if (atFloor || tp.height <= maxH) break;
      fontSize -= 1;
    }

    final dx = rect.left + _pad + (maxW - tp.width) / 2;
    final dy = rect.top + _pad + (maxH - tp.height) / 2;
    tp.paint(canvas, Offset(dx, dy));
    _drawArrowBadge(canvas, rect, clue.arrow);
  }

  // Uniform arrow badge: white triangle on an orange rounded square for BOTH
  // directions. Drawing both keeps them visually equal (a '▶' glyph rendered as
  // an emoji on Android while '▼' stayed plain text).
  void _drawArrowBadge(Canvas canvas, Rect rect, ClueArrow arrow) {
    const s = 10.0;
    final badge = Rect.fromLTWH(rect.right - s - 2, rect.bottom - s - 2, s, s);
    canvas.drawRRect(
      RRect.fromRectAndRadius(badge, const Radius.circular(2)),
      Paint()..color = AppColors.accent,
    );
    final c = badge.center;
    final pts = arrow == ClueArrow.right
        ? [Offset(c.dx - 2, c.dy - 3), Offset(c.dx - 2, c.dy + 3), Offset(c.dx + 3, c.dy)]
        : [Offset(c.dx - 3, c.dy - 2), Offset(c.dx + 3, c.dy - 2), Offset(c.dx, c.dy + 3)];
    canvas.drawPath(Path()..addPolygon(pts, true), Paint()..color = Colors.white);
  }
}
