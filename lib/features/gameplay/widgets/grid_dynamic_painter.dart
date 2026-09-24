// lib/features/gameplay/widgets/grid_dynamic_painter.dart

import 'package:flutter/material.dart';
import 'package:kelime_oyunu/core/constants/app_typography.dart';
import 'package:kelime_oyunu/features/gameplay/widgets/grid_static_painter.dart';
import 'package:kelime_oyunu/core/theme/app_tokens.dart';
import 'package:kelime_oyunu/data/models/puzzle.dart';
import 'package:kelime_oyunu/features/gameplay/engine/score_engine.dart';
import 'package:kelime_oyunu/features/gameplay/widgets/clue_renderer.dart';

/// Animated/interactive grid layer drawn above [GridStaticPainter]: the joker
/// spotlight, drag hover feedback, pending letter tiles and — as the topmost
/// pass — the clue direction arrows.
class GridDynamicPainter extends CustomPainter {
  GridDynamicPainter({
    required this.pendingPlacements,
    required this.revealMode,
    required this.puzzle,
    required this.cellSize,
    required this.tokens,
    this.hoverCell,
    this.hoverValid = false,
    this.hiddenPendingCell,
  });

  final List<Placement> pendingPlacements;
  final bool revealMode;
  final PuzzleData puzzle;
  final double cellSize;

  /// Active theme palette (the painter has no BuildContext of its own).
  final AppTokens tokens;

  /// Cell currently under a dragged tile, if any, and whether dropping there
  /// would succeed — paints the positive/negative drop-target feedback.
  final WordCell? hoverCell;
  final bool hoverValid;

  /// Pending cell whose letter is being dragged right now: skipped while
  /// painting so the letter lifts with the gesture instead of doubling.
  final WordCell? hiddenPendingCell;

  @override
  void paint(Canvas canvas, Size size) {
    // Joker mode: dim every non-clue cell so the green clue cells stand out
    // as the selectable targets (spotlight). MVP look — grow+blur is F6.
    if (revealMode) {
      final dim = Paint()..color = tokens.dim;
      for (final c in puzzle.cells) {
        if (c.type == CellType.clue) continue;
        canvas.drawRect(Rect.fromLTWH(c.col * cellSize, c.row * cellSize, cellSize, cellSize), dim);
      }
    }

    // Drag hover feedback: bright positive fill on a placeable cell, muted
    // "forbidden" red on clue/filled cells — the player sees the outcome
    // before releasing.
    final hover = hoverCell;
    if (hover != null) {
      final rect = Rect.fromLTWH(hover.col * cellSize, hover.row * cellSize, cellSize, cellSize);
      final base = hoverValid ? tokens.success : tokens.error;
      final shape = GridStaticPainter.cellShape(rect);
      canvas.drawRRect(shape, Paint()..color = base.withValues(alpha: hoverValid ? 0.35 : 0.20));
      canvas.drawRRect(
        shape.deflate(1),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = base,
      );
    }

    // Pending letters render as a full-cell rounded tile on `cellPending` with
    // `inkPending` glyph and ring: reads as "your letter, not committed yet".
    for (final placement in pendingPlacements) {
      if (placement.cell == hiddenPendingCell) continue;
      final rect = Rect.fromLTWH(
        placement.cell.col * cellSize,
        placement.cell.row * cellSize,
        cellSize,
        cellSize,
      );
      final rrect = GridStaticPainter.cellShape(rect);
      canvas.drawRRect(rrect, Paint()..color = tokens.cellPending);
      canvas.drawRRect(
        rrect.deflate(0.75),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = tokens.inkPending,
      );
      final tp = TextPainter(
        text: TextSpan(
          text: placement.letter,
          style: AppTypography.cellLetter.copyWith(color: tokens.inkPending),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(
        canvas,
        Offset(rect.left + (cellSize - tp.width) / 2, rect.top + (cellSize - tp.height) / 2),
      );
    }

    // Clue direction arrows LAST, in the topmost layer: always visible above
    // pending tiles and hover fills, whatever covers the cells below.
    for (final spec in puzzle.cells) {
      if (spec.type != CellType.clue) continue;
      final rect = Rect.fromLTWH(spec.col * cellSize, spec.row * cellSize, cellSize, cellSize);
      _clueRenderer.drawArrows(canvas, rect, spec, tokens);
    }
  }

  static const ClueRenderer _clueRenderer = ClueRenderer();

  @override
  bool shouldRepaint(covariant GridDynamicPainter old) =>
      pendingPlacements != old.pendingPlacements ||
      revealMode != old.revealMode ||
      cellSize != old.cellSize ||
      hoverCell != old.hoverCell ||
      hoverValid != old.hoverValid ||
      hiddenPendingCell != old.hiddenPendingCell ||
      tokens != old.tokens;
}
