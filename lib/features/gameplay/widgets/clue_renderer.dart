// lib/features/gameplay/widgets/clue_renderer.dart

import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:kelime_oyunu/core/constants/app_colors.dart';
import 'package:kelime_oyunu/data/models/puzzle.dart';

/// Paints clue cells onto the grid canvas: the pale background, the clue text
/// auto-scaled to show in full, and the divider for double-clue cells. The
/// direction arrows are drawn separately by [drawArrows] in a later pass so they
/// sit on the cell border (pointing into the word's first cell) without eating
/// any of the text area. Isolated from GridPainter so clue typography can evolve
/// without touching grid geometry.
class ClueRenderer {
  const ClueRenderer();

  // Readability bounds for the auto-scaled clue text (logical px). Below the
  // floor the text is not legible, so it ellipsises rather than shrink further.
  static const double _minFont = 9.0;
  static const double _maxFont = 14.0;

  static const double _pad = 1.0;

  /// Draws a clue cell's background, text and divider. [spec] must be a
  /// [CellType.clue] cell. Arrows are NOT drawn here — see [drawArrows].
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

  /// Draws each of [spec]'s direction arrows straddling the cell border on the
  /// edge the word runs toward. Call this AFTER every cell is painted so the
  /// arrows are not overdrawn by the neighbouring letter cell.
  void drawArrows(Canvas canvas, Rect rect, CellSpec spec) {
    for (final clue in spec.clues) {
      _drawEdgeArrow(canvas, rect, clue.arrow);
    }
  }

  /// Picks the largest font (down to [_minFont]) at which [clue].text fits the
  /// cell in full, wrapping across as many lines as needed, then paints it
  /// centred using the whole cell interior. Below the floor it caps the lines
  /// and ellipsises so text is never vertically clipped.
  void _drawClueText(Canvas canvas, Rect rect, ClueSpec clue) {
    final textW = math.max(0.0, rect.width - _pad * 2);
    final textH = math.max(0.0, rect.height - _pad * 2);
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
  }

  // Small accent triangle straddling the border the word runs toward: right
  // arrow on the right edge (vertically centred), down arrow on the bottom edge
  // (horizontally centred). Mostly outside the clue cell so it costs no text
  // space; drawn in a later pass so the neighbour cell does not overdraw it.
  void _drawEdgeArrow(Canvas canvas, Rect rect, ClueArrow arrow) {
    const half = 4.0; // half the triangle base
    const out = 5.0; // how far the tip pokes past the border
    const back = 1.5; // how far the base sits inside the border
    final paint = Paint()..color = AppColors.accent;
    final List<Offset> pts;
    if (arrow == ClueArrow.right) {
      final cy = rect.center.dy;
      pts = [
        Offset(rect.right - back, cy - half),
        Offset(rect.right - back, cy + half),
        Offset(rect.right + out, cy),
      ];
    } else {
      final cx = rect.center.dx;
      pts = [
        Offset(cx - half, rect.bottom - back),
        Offset(cx + half, rect.bottom - back),
        Offset(cx, rect.bottom + out),
      ];
    }
    canvas.drawPath(Path()..addPolygon(pts, true), paint);
  }
}
