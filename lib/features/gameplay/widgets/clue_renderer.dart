// lib/features/gameplay/widgets/clue_renderer.dart

import 'dart:math' as math;

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';

import 'package:kelime_oyunu/core/constants/app_colors.dart';
import 'package:kelime_oyunu/core/utils/logger.dart';
import 'package:kelime_oyunu/data/models/puzzle.dart';
import 'package:kelime_oyunu/features/gameplay/widgets/clue_text_layout.dart';

/// Paints clue cells onto the grid canvas: the pale background, the clue text
/// auto-scaled to show in full, and the divider for double-clue cells. The
/// direction arrows are drawn separately by [drawArrows] in a later pass so they
/// sit on the cell border (pointing into the word's first cell) without eating
/// any of the text area. Isolated from GridPainter so clue typography can evolve
/// without touching grid geometry.
class ClueRenderer {
  const ClueRenderer();

  // Readability bounds for the auto-scaled clue text (logical px). Below the
  // floor the text is not legible, so it hyphenates, then ellipsises, rather
  // than shrink further.
  static const double _minFont = 9.0;
  static const double _maxFont = 14.0;

  static const double _pad = 1.0;
  static const double _lineHeight = 1.05;

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

  /// Lays [clue].text out with [layoutClueText]: the largest font (down to
  /// [_minFont]) at which every word fits the cell width and the lines fit its
  /// height, breaking only at spaces; at the floor over-wide words are split at
  /// Turkish syllable boundaries with a hyphen. Lines come pre-broken, so the
  /// paragraph is painted with explicit newlines and never wraps mid-word. Only
  /// when even that overflows does it fall back to capped lines + ellipsis, and
  /// says so once per text in debug builds so the clue can be shortened upstream.
  void _drawClueText(Canvas canvas, Rect rect, ClueSpec clue) {
    final textW = math.max(0.0, rect.width - _pad * 2);
    final textH = math.max(0.0, rect.height - _pad * 2);
    final startFont = (rect.height * 0.30).clamp(_minFont, _maxFont);

    final layout = layoutClueText(
      text: clue.text,
      maxWidth: textW,
      maxHeight: textH,
      measure: _measure,
      startFont: startFont,
      minFont: _minFont,
      lineHeight: _lineHeight,
    );
    final overflow = layout.kind == ClueFitKind.overflow;
    if (overflow) _warnOverflow(clue.text, rect);

    final tp = TextPainter(
      text: TextSpan(
        text: overflow ? clue.text : layout.text,
        style: TextStyle(fontSize: layout.fontSize, height: _lineHeight, color: Colors.black),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
      maxLines: overflow ? math.max(1, (textH / (layout.fontSize * _lineHeight)).floor()) : null,
      ellipsis: overflow ? '…' : null,
    )..layout(maxWidth: textW);

    final dx = rect.left + _pad + (textW - tp.width) / 2;
    final dy = rect.top + _pad + (textH - tp.height) / 2;
    tp.paint(canvas, Offset(dx, dy));
  }

  // Advance width of [text] at [fontSize] in the clue style. Memoised: the
  // static grid layer repaints rarely, but each clue probes several fonts.
  static final Map<String, double> _widthCache = {};

  static double _measure(String text, double fontSize) =>
      _widthCache.putIfAbsent('$fontSize|$text', () {
        final tp = TextPainter(
          text: TextSpan(
            text: text,
            style: TextStyle(fontSize: fontSize, height: _lineHeight),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        return tp.width;
      });

  // Debug-only, once per text: an overflowing clue is a content problem (the
  // generator budget), not something the renderer should keep squeezing.
  static final Set<String> _warnedOverflow = {};

  static void _warnOverflow(String text, Rect rect) {
    if (!kDebugMode || !_warnedOverflow.add(text)) return;
    AppLogger.warning(
      'Clue overflows its cell '
      '(${rect.width.toStringAsFixed(0)}×${rect.height.toStringAsFixed(0)} px): "$text"',
    );
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
