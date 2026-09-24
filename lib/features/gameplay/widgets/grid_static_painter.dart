// lib/features/gameplay/widgets/grid_static_painter.dart

import 'package:flutter/material.dart';
import 'package:kelime_oyunu/core/constants/app_dimensions.dart';
import 'package:kelime_oyunu/core/constants/app_typography.dart';
import 'package:kelime_oyunu/core/theme/app_tokens.dart';
import 'package:kelime_oyunu/core/widgets/app_logo.dart';
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
    required this.tokens,
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

  /// Active theme palette (the painter has no BuildContext of its own).
  final AppTokens tokens;

  final Map<WordCell, CellSpec> _cellMap;
  final Set<WordCell> _revealedCells;

  static const ClueRenderer _clueRenderer = ClueRenderer();

  /// Half the 2 dp gap between cells (README "Board": gap 2, cell r6). Each
  /// cell is painted inset by this inside its [cellSize] slot, so the
  /// `gridLine` fill underneath shows through as the gap. Slot geometry —
  /// and therefore hit-testing and the narration overlay — is unchanged.
  static const double _gap = AppDimensions.gridCellGap / 2;

  /// A cell's painted shape inside its slot.
  static RRect cellShape(Rect slot) =>
      RRect.fromRectAndRadius(slot.deflate(_gap), const Radius.circular(AppDimensions.radiusCell));

  @override
  void paint(Canvas canvas, Size size) {
    // NOTE: clue direction arrows are NOT drawn here — the dynamic painter
    // draws them as its final pass so they stay on top of pending tiles and
    // hover fills (this layer sits below the dynamic one).
    canvas.drawRect(Offset.zero & size, Paint()..color = tokens.gridLine);
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
          _clueRenderer.drawCell(canvas, rect, spec, tokens);
        } else {
          _drawLetterCell(canvas, rect, cell);
        }
      }
    }
  }

  void _drawBlankCell(Canvas canvas, Rect rect) {
    canvas.drawRRect(cellShape(rect), Paint()..color = tokens.surface);
  }

  // Decorative top-left corner: the Kelime Zirvesi logo on its fixed navy
  // ground (design README "Board": corner cell = logo on #0b1a33, both themes).
  void _drawBrandCorner(Canvas canvas, Rect rect) {
    canvas.drawRRect(cellShape(rect), Paint()..color = appLogoGround);
    paintAppLogo(canvas, rect.deflate(cellSize * 0.12));
  }

  void _drawLetterCell(Canvas canvas, Rect rect, WordCell cell) {
    canvas.drawRRect(cellShape(rect), Paint()..color = tokens.cellLetter);
    // Suppressed: a narration tile is still flying here — draw the cell empty
    // so the glyph pops in exactly when the tile lands (no double image).
    final letter = suppressedCells.contains(cell) ? null : board[cell];
    if (letter == null) {
      // Revealed but unplayed: draw the solution as a faint, playable ghost.
      // The cell stays empty in [board], so it remains placeable.
      if (_revealedCells.contains(cell)) {
        final ghost = _cellMap[cell]?.solution;
        if (ghost != null) {
          _paintCenteredLetter(canvas, rect, ghost, tokens.ink.withValues(alpha: 0.3));
        }
      }
      return;
    }
    // Committed letters: bot blue, player black. Revealed cells are never
    // committed in the ghost model, so there is no locked colour here.
    final color = botPlacedCells.contains(cell) ? tokens.inkBot : tokens.ink;
    _paintCenteredLetter(canvas, rect, letter, color);
  }

  // Draws [text] centred in [rect] in the board letter style (Lora 22).
  void _paintCenteredLetter(Canvas canvas, Rect rect, String text, Color color) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: AppTypography.cellLetter.copyWith(color: color),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(
      canvas,
      Offset(rect.left + (cellSize - tp.width) / 2, rect.top + (cellSize - tp.height) / 2),
    );
  }

  @override
  bool shouldRepaint(covariant GridStaticPainter old) =>
      board != old.board ||
      revealedWordIds != old.revealedWordIds ||
      botPlacedCells != old.botPlacedCells ||
      suppressedCells != old.suppressedCells ||
      cellSize != old.cellSize ||
      tokens != old.tokens;
}
