// lib/features/gameplay/widgets/grid_static_painter.dart

import 'package:flutter/material.dart';
import 'package:kelime_oyunu/core/constants/app_colors.dart';
import 'package:kelime_oyunu/data/models/puzzle.dart';
import 'package:kelime_oyunu/features/gameplay/widgets/clue_renderer.dart';

/// Static grid layer: cell backgrounds, committed letters, clue text and grid
/// lines. Repaints only when the board or its reveal/suppression sets change;
/// per-frame visuals (hover, pending tiles) live in [GridDynamicPainter].
class GridStaticPainter extends CustomPainter {
  GridStaticPainter({
    required this.board,
    required this.revealedWordIds,
    required this.botPlacedCells,
    required this.puzzle,
    required this.cellSize,
    this.suppressedCells = const {},
  }) : _cellMap = {for (final c in puzzle.cells) WordCell(row: c.row, col: c.col): c},
       _revealedCells = {
         for (final w in puzzle.words)
           if (revealedWordIds.contains(w.id)) ...w.cells,
       };

  final Map<WordCell, String> board;
  final Set<String> revealedWordIds;
  final Set<WordCell> botPlacedCells;

  /// Committed cells hidden this frame while a narration tile flies to them.
  final Set<WordCell> suppressedCells;
  final PuzzleData puzzle;
  final double cellSize;

  final Map<WordCell, CellSpec> _cellMap;
  final Set<WordCell> _revealedCells;

  static const ClueRenderer _clueRenderer = ClueRenderer();

  @override
  void paint(Canvas canvas, Size size) {
    // NOTE: clue direction arrows are NOT drawn here — the dynamic painter
    // draws them as its final pass so they stay on top of pending tiles and
    // hover fills (this layer sits below the dynamic one).
    for (var row = 0; row < puzzle.grid.rows; row++) {
      for (var col = 0; col < puzzle.grid.cols; col++) {
        final cell = WordCell(row: row, col: col);
        final spec = _cellMap[cell];
        final rect = Rect.fromLTWH(col * cellSize, row * cellSize, cellSize, cellSize);
        final isBlank = spec == null || spec.type == CellType.blank;
        if (row == 0 && col == 0 && isBlank) {
          _drawBrandCorner(canvas, rect);
        } else if (isBlank) {
          _drawBlankCell(canvas, rect);
        } else if (spec.type == CellType.clue) {
          _clueRenderer.drawCell(canvas, rect, spec);
        } else {
          _drawLetterCell(canvas, rect, cell);
        }
      }
    }
    _drawGridLines(canvas, size);
  }

  void _drawBlankCell(Canvas canvas, Rect rect) {
    canvas.drawRect(rect, Paint()..color = AppColors.gridCellLocked);
  }

  // Decorative top-left corner: a green brand tile with a centred "K".
  // Painter-only placeholder for a real logo asset later.
  void _drawBrandCorner(Canvas canvas, Rect rect) {
    canvas.drawRect(rect, Paint()..color = AppColors.brandCorner);
    _paintCenteredLetter(canvas, rect, 'K', Colors.white, fontSize: cellSize * 0.5);
  }

  void _drawLetterCell(Canvas canvas, Rect rect, WordCell cell) {
    canvas.drawRect(rect, Paint()..color = AppColors.gridCellNormal);
    // Suppressed: a narration tile is still flying here — draw the cell empty
    // so the glyph pops in exactly when the tile lands (no double image).
    final letter = suppressedCells.contains(cell) ? null : board[cell];
    if (letter == null) {
      // Revealed but unplayed: draw the solution as a faint, playable ghost.
      // The cell stays empty in [board], so it remains placeable.
      if (_revealedCells.contains(cell)) {
        final ghost = _cellMap[cell]?.solution;
        if (ghost != null) _paintCenteredLetter(canvas, rect, ghost, AppColors.ghost);
      }
      return;
    }
    // Committed letters: bot blue, player black. Revealed cells are never
    // committed in the ghost model, so there is no locked colour here.
    final color = botPlacedCells.contains(cell) ? AppColors.botLetter : Colors.black;
    _paintCenteredLetter(canvas, rect, letter, color);
  }

  // Draws [text] centred in [rect]. [fontSize] defaults to the standard cell
  // letter size; the brand corner passes a larger value.
  void _paintCenteredLetter(
    Canvas canvas,
    Rect rect,
    String text,
    Color color, {
    double fontSize = 20,
  }) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.bold, color: color),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(
      canvas,
      Offset(rect.left + (cellSize - tp.width) / 2, rect.top + (cellSize - tp.height) / 2),
    );
  }

  void _drawGridLines(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.gridLine
      ..strokeWidth = 0.5;
    for (var col = 0; col <= puzzle.grid.cols; col++) {
      final x = col * cellSize;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (var row = 0; row <= puzzle.grid.rows; row++) {
      final y = row * cellSize;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant GridStaticPainter old) =>
      board != old.board ||
      revealedWordIds != old.revealedWordIds ||
      botPlacedCells != old.botPlacedCells ||
      suppressedCells != old.suppressedCells ||
      cellSize != old.cellSize;
}
