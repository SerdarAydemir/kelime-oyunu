// lib/features/gameplay/widgets/clue_renderer.dart

import 'dart:math' as math;

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';

import 'package:kelime_oyunu/core/constants/app_typography.dart';
import 'package:kelime_oyunu/core/theme/app_tokens.dart';
import 'package:kelime_oyunu/core/utils/logger.dart';
import 'package:kelime_oyunu/features/gameplay/widgets/grid_static_painter.dart';
import 'package:kelime_oyunu/data/models/puzzle.dart';
import 'package:kelime_oyunu/features/gameplay/widgets/clue_text_layout.dart';

/// Paints clue cells onto the grid canvas: the `cellClue` background, the clue
/// text auto-scaled to show in full, and the divider for double-clue cells. The
/// direction arrows are drawn separately by [drawArrows] in a later pass so
/// they stay on top of whatever covers the neighbouring cells. Isolated from
/// GridPainter so clue typography can evolve without touching grid geometry.
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
  void drawCell(Canvas canvas, Rect slot, CellSpec spec, AppTokens tokens) {
    final shape = GridStaticPainter.cellShape(slot);
    canvas.drawRRect(shape, Paint()..color = tokens.cellClue);
    final rect = shape.outerRect;
    final ink = tokens.clueText;
    if (spec.clues.length >= 2) {
      final half = rect.height / 2;
      _drawClueText(
        canvas,
        Rect.fromLTWH(rect.left, rect.top, rect.width, half),
        spec.clues[0],
        ink,
      );
      _drawClueText(
        canvas,
        Rect.fromLTWH(rect.left, rect.top + half, rect.width, half),
        spec.clues[1],
        ink,
      );
      // Divider between the two clues; each half is its own reveal target.
      canvas.drawLine(
        Offset(rect.left, rect.top + half),
        Offset(rect.right, rect.top + half),
        Paint()
          ..color = ink.withValues(alpha: 0.6)
          ..strokeWidth = 1,
      );
    } else if (spec.clues.isNotEmpty) {
      _drawClueText(canvas, rect, spec.clues[0], ink);
    }
  }

  /// Draws each of [spec]'s direction arrows: a small `arrow`-coloured
  /// triangle INSIDE the clue cell, hugging the edge the word runs toward
  /// (README "Board": 5 px triangles at the right / bottom edge). Called in the
  /// topmost pass so nothing covering the cell hides them.
  void drawArrows(Canvas canvas, Rect slot, CellSpec spec, AppTokens tokens) {
    final rect = GridStaticPainter.cellShape(slot).outerRect;
    for (final clue in spec.clues) {
      _drawEdgeArrow(canvas, rect, clue.arrow, tokens.arrow);
    }
  }

  /// Lays [clue].text out with [layoutClueText]: the largest font (down to
  /// [_minFont]) at which every word fits the cell width and the lines fit its
  /// height, breaking only at spaces; at the floor over-wide words are split at
  /// Turkish syllable boundaries with a hyphen. Lines come pre-broken, so the
  /// paragraph is painted with explicit newlines and never wraps mid-word. Only
  /// when even that overflows does it fall back to capped lines + ellipsis, and
  /// says so once per text in debug builds so the clue can be shortened upstream.
  void _drawClueText(Canvas canvas, Rect rect, ClueSpec clue, Color ink) {
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
        style: AppTypography.clue.copyWith(
          fontSize: layout.fontSize,
          height: _lineHeight,
          color: ink,
        ),
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
            style: AppTypography.clue.copyWith(fontSize: fontSize, height: _lineHeight),
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

  // 5 px triangle inside the cell: right arrow on the right edge (vertically
  // centred, tip toward the edge), down arrow on the bottom edge (horizontally
  // centred). The tip stops 1 px short of the edge so the cell's rounded
  // corner and the 2 px gap stay clean.
  void _drawEdgeArrow(Canvas canvas, Rect rect, ClueArrow arrow, Color color) {
    const half = 3.0; // half the triangle base
    const depth = 5.0; // base-to-tip height
    const inset = 1.0; // tip distance from the cell edge
    final paint = Paint()..color = color;
    final List<Offset> pts;
    if (arrow == ClueArrow.right) {
      final cy = rect.center.dy;
      final tip = rect.right - inset;
      pts = [Offset(tip - depth, cy - half), Offset(tip - depth, cy + half), Offset(tip, cy)];
    } else {
      final cx = rect.center.dx;
      final tip = rect.bottom - inset;
      pts = [Offset(cx - half, tip - depth), Offset(cx + half, tip - depth), Offset(cx, tip)];
    }
    canvas.drawPath(Path()..addPolygon(pts, true), paint);
  }
}
