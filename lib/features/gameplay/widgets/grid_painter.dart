// lib/features/gameplay/widgets/grid_painter.dart

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:kelime_oyunu/core/constants/app_colors.dart';
import 'package:kelime_oyunu/data/models/puzzle.dart';
import 'package:kelime_oyunu/features/gameplay/engine/score_engine.dart';
import 'package:kelime_oyunu/features/gameplay/widgets/clue_renderer.dart';

/// Fallback cell size used only when the incoming constraints are unbounded
/// (should not happen inside the bounded gameplay layout).
const double _fallbackCell = 48.0;

class GridPainter extends StatelessWidget {
  const GridPainter({
    required this.puzzle,
    required this.board,
    required this.pendingPlacements,
    required this.highlightedWordId,
    required this.revealedWordIds,
    required this.botPlacedCells,
    required this.revealMode,
    required this.onCellTap,
    super.key,
  });

  final PuzzleData puzzle;
  final Map<WordCell, String> board;
  final List<Placement> pendingPlacements;
  final String? highlightedWordId;
  final Set<String> revealedWordIds;
  final Set<WordCell> botPlacedCells;

  /// Joker mode: clue cells are highlighted as selectable reveal targets.
  final bool revealMode;

  /// [bottomHalf] tells which half of the cell was hit — it selects between
  /// the two clues of a double-clue cell while in reveal mode.
  final void Function(WordCell cell, bool bottomHalf) onCellTap;

  @override
  Widget build(BuildContext context) {
    final cols = puzzle.grid.cols;
    final rows = puzzle.grid.rows;

    return LayoutBuilder(
      builder: (context, constraints) {
        // Largest square cell that fits both axes, so the grid fills the
        // available vertical space and stays centred instead of clinging to the
        // top. Exact fit (not floored) keeps the SizedBox within the viewport,
        // so there is no overflow even under extreme/degenerate constraints.
        final raw = math.min(constraints.maxWidth / cols, constraints.maxHeight / rows);
        final cell = raw.isFinite ? math.max(0.0, raw) : _fallbackCell;
        final width = cell * cols;
        final height = cell * rows;

        return InteractiveViewer(
          minScale: 1.0,
          maxScale: 2.5,
          child: Center(
            child: SizedBox(
              width: width,
              height: height,
              child: Stack(
                children: [
                  RepaintBoundary(
                    child: CustomPaint(
                      size: Size(width, height),
                      painter: GridStaticPainter(
                        board: board,
                        revealedWordIds: revealedWordIds,
                        botPlacedCells: botPlacedCells,
                        puzzle: puzzle,
                        cellSize: cell,
                      ),
                    ),
                  ),
                  RepaintBoundary(
                    child: CustomPaint(
                      size: Size(width, height),
                      painter: GridDynamicPainter(
                        pendingPlacements: pendingPlacements,
                        highlightedWordId: highlightedWordId,
                        revealMode: revealMode,
                        puzzle: puzzle,
                        cellSize: cell,
                      ),
                    ),
                  ),
                  GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTapDown: (details) {
                      if (cell <= 0) return;
                      final col = (details.localPosition.dx / cell).floor();
                      final row = (details.localPosition.dy / cell).floor();
                      if (row >= 0 && col >= 0 && row < rows && col < cols) {
                        final bottomHalf = details.localPosition.dy - row * cell > cell / 2;
                        onCellTap(WordCell(row: row, col: col), bottomHalf);
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class GridStaticPainter extends CustomPainter {
  GridStaticPainter({
    required this.board,
    required this.revealedWordIds,
    required this.botPlacedCells,
    required this.puzzle,
    required this.cellSize,
  }) : _cellMap = {for (final c in puzzle.cells) WordCell(row: c.row, col: c.col): c},
       _revealedCells = {
         for (final w in puzzle.words)
           if (revealedWordIds.contains(w.id)) ...w.cells,
       };

  final Map<WordCell, String> board;
  final Set<String> revealedWordIds;
  final Set<WordCell> botPlacedCells;
  final PuzzleData puzzle;
  final double cellSize;

  final Map<WordCell, CellSpec> _cellMap;
  final Set<WordCell> _revealedCells;

  static const ClueRenderer _clueRenderer = ClueRenderer();

  @override
  void paint(Canvas canvas, Size size) {
    // Clue cells whose direction arrows must be drawn last so they straddle the
    // cell border on top of the neighbouring letter cell instead of under it.
    final clueCells = <(Rect, CellSpec)>[];
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
          clueCells.add((rect, spec));
        } else {
          _drawLetterCell(canvas, rect, cell);
        }
      }
    }
    _drawGridLines(canvas, size);
    // Arrows last: on top of every cell and the grid lines, on the borders.
    for (final (rect, spec) in clueCells) {
      _clueRenderer.drawArrows(canvas, rect, spec);
    }
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
    final letter = board[cell];
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
      cellSize != old.cellSize;
}

class GridDynamicPainter extends CustomPainter {
  GridDynamicPainter({
    required this.pendingPlacements,
    required this.highlightedWordId,
    required this.revealMode,
    required this.puzzle,
    required this.cellSize,
  });

  final List<Placement> pendingPlacements;
  final String? highlightedWordId;
  final bool revealMode;
  final PuzzleData puzzle;
  final double cellSize;

  @override
  void paint(Canvas canvas, Size size) {
    // Joker mode: dim every non-clue cell so the green clue cells stand out
    // as the selectable targets (spotlight). MVP look — grow+blur is F6.
    if (revealMode) {
      final dim = Paint()..color = Colors.black45;
      for (final c in puzzle.cells) {
        if (c.type == CellType.clue) continue;
        canvas.drawRect(Rect.fromLTWH(c.col * cellSize, c.row * cellSize, cellSize, cellSize), dim);
      }
    }

    if (highlightedWordId != null) {
      WordSpec? word;
      for (final w in puzzle.words) {
        if (w.id == highlightedWordId) {
          word = w;
          break;
        }
      }
      if (word != null) {
        // TODO: add AppColors.highlightOverlay token (0x22000000)
        final highlightPaint = Paint()..color = const Color(0x22000000);
        for (final cell in word.cells) {
          canvas.drawRect(
            Rect.fromLTWH(cell.col * cellSize, cell.row * cellSize, cellSize, cellSize),
            highlightPaint,
          );
        }
      }
    }

    for (final placement in pendingPlacements) {
      final rect = Rect.fromLTWH(
        placement.cell.col * cellSize,
        placement.cell.row * cellSize,
        cellSize,
        cellSize,
      );
      canvas.drawRect(rect, Paint()..color = AppColors.star);
      final tp = TextPainter(
        text: TextSpan(
          text: placement.letter,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(
        canvas,
        Offset(rect.left + (cellSize - tp.width) / 2, rect.top + (cellSize - tp.height) / 2),
      );
    }
  }

  @override
  bool shouldRepaint(covariant GridDynamicPainter old) =>
      pendingPlacements != old.pendingPlacements ||
      highlightedWordId != old.highlightedWordId ||
      revealMode != old.revealMode ||
      cellSize != old.cellSize;
}
