// lib/features/gameplay/widgets/grid_painter.dart

import 'package:flutter/material.dart';
import 'package:kelime_oyunu/core/constants/app_colors.dart';
import 'package:kelime_oyunu/data/models/puzzle.dart';
import 'package:kelime_oyunu/features/gameplay/engine/score_engine.dart';

const double cellSize = 48.0;

class GridPainter extends StatelessWidget {
  const GridPainter({
    required this.puzzle,
    required this.board,
    required this.pendingPlacements,
    required this.highlightedWordId,
    required this.revealedWordIds,
    required this.onCellTap,
    super.key,
  });

  final PuzzleData puzzle;
  final Map<WordCell, String> board;
  final List<Placement> pendingPlacements;
  final String? highlightedWordId;
  final Set<String> revealedWordIds;
  final void Function(WordCell) onCellTap;

  @override
  Widget build(BuildContext context) {
    final width = puzzle.grid.cols * cellSize;
    final height = puzzle.grid.rows * cellSize;

    return InteractiveViewer(
      minScale: 0.7,
      maxScale: 2.0,
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
                  puzzle: puzzle,
                  cellSize: cellSize,
                ),
              ),
            ),
            RepaintBoundary(
              child: CustomPaint(
                size: Size(width, height),
                painter: GridDynamicPainter(
                  pendingPlacements: pendingPlacements,
                  highlightedWordId: highlightedWordId,
                  puzzle: puzzle,
                  cellSize: cellSize,
                ),
              ),
            ),
            GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTapDown: (details) {
                final col = (details.localPosition.dx / cellSize).floor();
                final row = (details.localPosition.dy / cellSize).floor();
                if (row >= 0 &&
                    col >= 0 &&
                    row < puzzle.grid.rows &&
                    col < puzzle.grid.cols) {
                  onCellTap(WordCell(row: row, col: col));
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

class GridStaticPainter extends CustomPainter {
  GridStaticPainter({
    required this.board,
    required this.revealedWordIds,
    required this.puzzle,
    required this.cellSize,
  })  : _cellMap = {
          for (final c in puzzle.cells) WordCell(row: c.row, col: c.col): c,
        },
        _revealedCells = {
          for (final w in puzzle.words)
            if (revealedWordIds.contains(w.id)) ...w.cells,
        };

  final Map<WordCell, String> board;
  final Set<String> revealedWordIds;
  final PuzzleData puzzle;
  final double cellSize;

  final Map<WordCell, CellSpec> _cellMap;
  final Set<WordCell> _revealedCells;

  @override
  void paint(Canvas canvas, Size size) {
    for (var row = 0; row < puzzle.grid.rows; row++) {
      for (var col = 0; col < puzzle.grid.cols; col++) {
        final cell = WordCell(row: row, col: col);
        final spec = _cellMap[cell];
        final rect = Rect.fromLTWH(
          col * cellSize,
          row * cellSize,
          cellSize,
          cellSize,
        );
        if (spec == null || spec.type == CellType.blank) {
          _drawBlankCell(canvas, rect);
        } else if (spec.type == CellType.clue) {
          _drawClueCell(canvas, rect, spec);
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

  void _drawClueCell(Canvas canvas, Rect rect, CellSpec spec) {
    // TODO: add AppColors.clueCellBg token (0xFFE8F5E9)
    canvas.drawRect(rect, Paint()..color = const Color(0xFFE8F5E9));
    if (spec.clues.length >= 2) {
      final half = rect.height / 2;
      _drawSingleClue(
        canvas,
        Rect.fromLTWH(rect.left, rect.top, rect.width, half),
        spec.clues[0],
      );
      _drawSingleClue(
        canvas,
        Rect.fromLTWH(rect.left, rect.top + half, rect.width, half),
        spec.clues[1],
      );
    } else if (spec.clues.isNotEmpty) {
      _drawSingleClue(canvas, rect, spec.clues[0]);
    }
  }

  void _drawSingleClue(Canvas canvas, Rect rect, ClueSpec clue) {
    final arrow = clue.arrow == ClueArrow.right ? '▶' : '▼';
    final textPainter = TextPainter(
      text: TextSpan(
        text: clue.text,
        style: const TextStyle(fontSize: 9, color: Colors.black),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 2,
    )..layout(maxWidth: rect.width - 4);
    textPainter.paint(canvas, Offset(rect.left + 2, rect.top + 2));

    final arrowPainter = TextPainter(
      text: TextSpan(
        text: arrow,
        style: const TextStyle(fontSize: 8, color: Colors.black),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    arrowPainter.paint(
      canvas,
      Offset(
        rect.right - arrowPainter.width - 1,
        rect.bottom - arrowPainter.height - 1,
      ),
    );
  }

  void _drawLetterCell(Canvas canvas, Rect rect, WordCell cell) {
    canvas.drawRect(rect, Paint()..color = AppColors.gridCellNormal);
    final letter = board[cell];
    if (letter == null) return;

    final isRevealed = _revealedCells.contains(cell);
    final letterPainter = TextPainter(
      text: TextSpan(
        text: letter,
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: isRevealed ? AppColors.gridCellLocked : Colors.black,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    letterPainter.paint(
      canvas,
      Offset(
        rect.left + (cellSize - letterPainter.width) / 2,
        rect.top + (cellSize - letterPainter.height) / 2,
      ),
    );
  }

  void _drawGridLines(Canvas canvas, Size size) {
    // TODO: add AppColors.gridLine token
    final paint = Paint()
      ..color = Colors.grey.shade300
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
      board != old.board || revealedWordIds != old.revealedWordIds;
}

class GridDynamicPainter extends CustomPainter {
  GridDynamicPainter({
    required this.pendingPlacements,
    required this.highlightedWordId,
    required this.puzzle,
    required this.cellSize,
  });

  final List<Placement> pendingPlacements;
  final String? highlightedWordId;
  final PuzzleData puzzle;
  final double cellSize;

  @override
  void paint(Canvas canvas, Size size) {
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
            Rect.fromLTWH(
              cell.col * cellSize,
              cell.row * cellSize,
              cellSize,
              cellSize,
            ),
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
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(
        canvas,
        Offset(
          rect.left + (cellSize - tp.width) / 2,
          rect.top + (cellSize - tp.height) / 2,
        ),
      );
    }
  }

  @override
  bool shouldRepaint(covariant GridDynamicPainter old) =>
      pendingPlacements != old.pendingPlacements ||
      highlightedWordId != old.highlightedWordId;
}
