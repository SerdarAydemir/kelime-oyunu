// lib/features/gameplay/widgets/clue_renderer.dart

import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:kelime_oyunu/core/constants/app_colors.dart';
import 'package:kelime_oyunu/data/models/puzzle.dart';

/// Paints clue cells onto the grid canvas: the pale background, the clue text
/// auto-scaled to show in full, the divider for double-clue cells, and a small
/// direction arrow on the cell edge. Isolated from GridPainter so clue
/// typography can evolve without touching grid geometry.
///
/// The arrow sits on the edge the word runs toward (right → right edge, down →
/// bottom edge) and reserves only a thin strip there, so the text keeps almost
/// the whole cell — the rest fills with wrapped text at the largest font that
/// fits, mirroring how reference crosswords keep long clues fully readable.
class ClueRenderer {
  const ClueRenderer();

  // Readability bounds for the auto-scaled clue text (logical px).
  static const double _minFont = 7.0;
  static const double _maxFont = 14.0;

  // Inner padding and the strip reserved on the arrow's edge.
  static const double _pad = 1.0;
  static const double _strip = 7.0;

  /// Draws the full clue cell. [spec] must be a [CellType.clue] cell.
  void drawCell(Canvas canvas, Rect rect, CellSpec spec) {
    canvas.drawRect(rect, Paint()..color = AppColors.clueCellBg);
    var truncated = false;
    if (spec.clues.length >= 2) {
      final half = rect.height / 2;
      truncated |= _drawClueText(
        canvas,
        Rect.fromLTWH(rect.left, rect.top, rect.width, half),
        spec.clues[0],
      );
      truncated |= _drawClueText(
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
      truncated = _drawClueText(canvas, rect, spec.clues[0]);
    }
    // Only the rare clue that overflows even at the font floor still needs the
    // "tap to read" hint.
    if (truncated) _drawTapIndicator(canvas, rect);
  }

  /// Picks the largest font (down to [_minFont]) at which [clue].text fits the
  /// cell in full, wrapping across as many lines as needed, then paints it
  /// centred. The direction arrow reserves only a thin strip on its own edge,
  /// so the text keeps the rest of the cell. Returns true only if the text was
  /// ellipsised (overflowed even at the floor) — those cells get the tap hint.
  bool _drawClueText(Canvas canvas, Rect rect, ClueSpec clue) {
    final isDown = clue.arrow == ClueArrow.down;
    final textW = math.max(0.0, rect.width - _pad * 2 - (isDown ? 0.0 : _strip));
    final textH = math.max(0.0, rect.height - _pad * 2 - (isDown ? _strip : 0.0));
    var fontSize = (rect.height * 0.30).clamp(_minFont, _maxFont);

    late TextPainter tp;
    while (true) {
      final atFloor = fontSize <= _minFont;
      // Tight line height so more lines fit; cap + ellipsise only at the floor.
      final maxLines = atFloor ? math.max(1, (textH / (fontSize * 1.15)).floor()) : null;
      tp = TextPainter(
        text: TextSpan(
          text: clue.text,
          style: TextStyle(fontSize: fontSize, height: 1.05, color: Colors.black),
        ),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
        maxLines: maxLines,
        ellipsis: atFloor ? '…' : null,
      )..layout(maxWidth: textW);
      if (atFloor || tp.height <= textH) break;
      fontSize -= 1;
    }

    final dx = rect.left + _pad + (textW - tp.width) / 2;
    final dy = rect.top + _pad + (textH - tp.height) / 2;
    tp.paint(canvas, Offset(dx, dy));
    _drawEdgeArrow(canvas, rect, clue.arrow);
    return tp.didExceedMaxLines;
  }

  // Small accent triangle on the edge the word runs toward: right arrow on the
  // right edge (vertically centred), down arrow on the bottom edge (centred).
  void _drawEdgeArrow(Canvas canvas, Rect rect, ClueArrow arrow) {
    const a = 4.0; // half base / tip extent
    final paint = Paint()..color = AppColors.accent;
    final List<Offset> pts;
    if (arrow == ClueArrow.right) {
      final cy = rect.center.dy;
      final base = rect.right - _strip + 1.5;
      pts = [Offset(base, cy - a), Offset(base, cy + a), Offset(rect.right - 1.5, cy)];
    } else {
      final cx = rect.center.dx;
      final base = rect.bottom - _strip + 1.5;
      pts = [Offset(cx - a, base), Offset(cx + a, base), Offset(cx, rect.bottom - 1.5)];
    }
    canvas.drawPath(Path()..addPolygon(pts, true), paint);
  }

  // Three small dots in the top-left corner signalling that the clue overflowed
  // and its full text opens on tap. Top-left stays clear of the edge arrow and
  // the double-clue divider.
  void _drawTapIndicator(Canvas canvas, Rect rect) {
    const r = 0.9;
    const gap = 2.6;
    final cy = rect.top + 3.5;
    final x0 = rect.left + 3.5;
    final paint = Paint()..color = Colors.black54;
    for (var i = 0; i < 3; i++) {
      canvas.drawCircle(Offset(x0 + i * gap, cy), r, paint);
    }
  }
}
