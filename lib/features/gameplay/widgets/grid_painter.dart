// lib/features/gameplay/widgets/grid_painter.dart

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:kelime_oyunu/core/constants/app_colors.dart';
import 'package:kelime_oyunu/data/models/puzzle.dart';
import 'package:kelime_oyunu/features/gameplay/engine/score_engine.dart';
import 'package:kelime_oyunu/features/gameplay/widgets/clue_renderer.dart';
import 'package:kelime_oyunu/features/gameplay/widgets/rack_widget.dart';

/// Fallback cell size used only when the incoming constraints are unbounded
/// (should not happen inside the bounded gameplay layout).
const double _fallbackCell = 48.0;

class GridPainter extends StatefulWidget {
  const GridPainter({
    required this.puzzle,
    required this.board,
    required this.pendingPlacements,
    required this.revealedWordIds,
    required this.botPlacedCells,
    required this.revealMode,
    required this.onCellTap,
    required this.onCellDrop,
    required this.isCellPlaceable,
    this.pendingDragEnabled = false,
    this.rackIndexForPending,
    this.onPendingDragCancelled,
    super.key,
  });

  final PuzzleData puzzle;
  final Map<WordCell, String> board;
  final List<Placement> pendingPlacements;
  final Set<String> revealedWordIds;
  final Set<WordCell> botPlacedCells;

  /// Joker mode: clue cells are highlighted as selectable reveal targets.
  final bool revealMode;

  /// [bottomHalf] tells which half of the cell was hit — it selects between
  /// the two clues of a double-clue cell while in reveal mode.
  final void Function(WordCell cell, bool bottomHalf) onCellTap;

  /// A dragged letter was dropped onto a placeable cell. [data.fromCell] is
  /// non-null when the drag started from a pending letter on the board (a
  /// move) rather than from the rack.
  final void Function(DragTileData data, WordCell cell) onCellDrop;

  /// Whether a drag hovering over [cell] may drop there — drives the
  /// green/red hover feedback so the player knows the outcome BEFORE
  /// releasing (the drag counterpart of the silent tap-placement guard).
  final bool Function(WordCell cell) isCellPlaceable;

  /// Whether pending letters on the board can be picked up and dragged to
  /// another cell (player's turn, no reveal mode — same guard as the rack).
  final bool pendingDragEnabled;

  /// Resolves the rack index owning the pending letter at [cell]; -1/null
  /// disables dragging that letter. Supplied by the screen (rack knowledge
  /// lives there).
  final int Function(WordCell cell)? rackIndexForPending;

  /// A pending-letter drag ended outside any droppable cell — the screen
  /// recalls the letter to the rack.
  final void Function(WordCell cell)? onPendingDragCancelled;

  @override
  State<GridPainter> createState() => _GridPainterState();
}

class _GridPainterState extends State<GridPainter> {
  /// Cell currently hovered by a drag, with its placeability verdict.
  /// Pure visual state (joker-mode precedent): a ValueNotifier repaints only
  /// the dynamic layer instead of rebuilding the whole grid subtree.
  final ValueNotifier<({WordCell cell, bool valid})?> _hover = ValueNotifier(null);

  /// Pending letter currently being dragged: its source cell stops being
  /// painted so the letter visibly LIFTS with the gesture instead of staying
  /// behind as a double image. Visual-only — the placement stays in the bloc
  /// state until the drop decides recall/move, so a cancelled drag restores
  /// the letter by simply clearing this.
  final ValueNotifier<WordCell?> _liftedPending = ValueNotifier(null);

  /// Anchors global→local conversion to the grid's own SizedBox. Converting
  /// against this widget's root box instead would miss the Center offset that
  /// appears when the grid doesn't fill the whole constrained area (the drag
  /// hover then lands a cell or more below the finger).
  final GlobalKey _gridBoxKey = GlobalKey();

  @override
  void dispose() {
    _hover.dispose();
    _liftedPending.dispose();
    super.dispose();
  }

  /// Maps a grid-local offset to its cell, or null when outside the grid.
  /// Shared by the tap handler and the drag hover/drop handlers.
  WordCell? _cellAt(Offset local, double cell) {
    if (cell <= 0) return null;
    final col = (local.dx / cell).floor();
    final row = (local.dy / cell).floor();
    if (row < 0 || col < 0 || row >= widget.puzzle.grid.rows || col >= widget.puzzle.grid.cols) {
      return null;
    }
    return WordCell(row: row, col: col);
  }

  /// Converts a drag position into a grid cell. details.offset is the finger
  /// (pointerDragAnchorStrategy); adding [kDragFeedbackCentreOffset] shifts
  /// the anchor to the floating tile's visual centre, so the letter lands on
  /// the cell the player SEES it over. globalToLocal walks the full ancestor
  /// transform chain (including the InteractiveViewer's zoom/pan), so the
  /// mapping stays correct while zoomed.
  WordCell? _cellFromDrag(Offset dragGlobal, double cell) {
    final box = _gridBoxKey.currentContext?.findRenderObject();
    if (box is! RenderBox) return null;
    return _cellAt(box.globalToLocal(dragGlobal + kDragFeedbackCentreOffset), cell);
  }

  @override
  Widget build(BuildContext context) {
    final puzzle = widget.puzzle;
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
              key: _gridBoxKey,
              width: width,
              height: height,
              child: Stack(
                children: [
                  RepaintBoundary(
                    child: CustomPaint(
                      size: Size(width, height),
                      painter: GridStaticPainter(
                        board: widget.board,
                        revealedWordIds: widget.revealedWordIds,
                        botPlacedCells: widget.botPlacedCells,
                        puzzle: puzzle,
                        cellSize: cell,
                      ),
                    ),
                  ),
                  ListenableBuilder(
                    listenable: Listenable.merge([_hover, _liftedPending]),
                    builder: (_, _) => RepaintBoundary(
                      child: CustomPaint(
                        size: Size(width, height),
                        painter: GridDynamicPainter(
                          pendingPlacements: widget.pendingPlacements,
                          revealMode: widget.revealMode,
                          puzzle: puzzle,
                          cellSize: cell,
                          hoverCell: _hover.value?.cell,
                          hoverValid: _hover.value?.valid ?? false,
                          hiddenPendingCell: _liftedPending.value,
                        ),
                      ),
                    ),
                  ),
                  GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTapDown: (details) {
                      final tapped = _cellAt(details.localPosition, cell);
                      if (tapped != null) {
                        final bottomHalf = details.localPosition.dy - tapped.row * cell > cell / 2;
                        widget.onCellTap(tapped, bottomHalf);
                      }
                    },
                  ),
                  // Pending letters are grabbable: a transparent Draggable per
                  // pending cell (a handful at most — not per-cell widgets) so
                  // a misplaced letter can be dragged straight to another cell
                  // without a recall-to-rack detour.
                  if (widget.pendingDragEnabled && widget.rackIndexForPending != null)
                    for (final placement in widget.pendingPlacements)
                      _PendingLetterDraggable(
                        placement: placement,
                        cellSize: cell,
                        rackIndex: widget.rackIndexForPending!(placement.cell),
                        onCancelled: widget.onPendingDragCancelled,
                        onLifted: (cell) => _liftedPending.value = cell,
                        onSettled: () => _liftedPending.value = null,
                      ),
                  // Drag protocol only — an empty SizedBox takes no pointer
                  // hits, so taps still reach the GestureDetector below.
                  Positioned.fill(
                    child: DragTarget<DragTileData>(
                      onMove: (details) {
                        final hovered = _cellFromDrag(details.offset, cell);
                        _hover.value = hovered == null
                            ? null
                            : (cell: hovered, valid: widget.isCellPlaceable(hovered));
                      },
                      onLeave: (_) => _hover.value = null,
                      onAcceptWithDetails: (details) {
                        final dropped = _cellFromDrag(details.offset, cell);
                        _hover.value = null;
                        if (dropped != null && widget.isCellPlaceable(dropped)) {
                          widget.onCellDrop(details.data, dropped);
                        }
                      },
                      builder: (_, _, _) => const SizedBox.expand(),
                    ),
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

/// Invisible drag handle over one pending letter. Dragging it moves the
/// letter: a valid drop fires onCellDrop with fromCell set (the screen
/// recalls + re-places), an invalid in-grid drop leaves it untouched, and a
/// drop outside the grid cancels — [onCancelled] recalls it to the rack.
class _PendingLetterDraggable extends StatelessWidget {
  const _PendingLetterDraggable({
    required this.placement,
    required this.cellSize,
    required this.rackIndex,
    required this.onCancelled,
    required this.onLifted,
    required this.onSettled,
  });

  final Placement placement;
  final double cellSize;
  final int rackIndex;
  final void Function(WordCell cell)? onCancelled;

  /// Drag started: the source cell hides its painted letter so it visually
  /// lifts with the gesture.
  final void Function(WordCell cell) onLifted;

  /// Drag finished (any outcome): stop hiding — a cancelled/invalid drag
  /// shows the letter in place again, a move repaints from the new state.
  final VoidCallback onSettled;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: placement.cell.col * cellSize,
      top: placement.cell.row * cellSize,
      width: cellSize,
      height: cellSize,
      child: Draggable<DragTileData>(
        data: (rackIndex: rackIndex, fromCell: placement.cell),
        maxSimultaneousDrags: rackIndex >= 0 ? 1 : 0,
        dragAnchorStrategy: pointerDragAnchorStrategy,
        // Hit-test the DragTarget at the tile's visual centre (see the rack
        // Draggable) — otherwise the bottom row is a dead zone.
        feedbackOffset: kDragFeedbackCentreOffset,
        feedback: DragFeedbackTile(letter: placement.letter),
        onDragStarted: () => onLifted(placement.cell),
        onDragEnd: (details) {
          onSettled();
          // Not accepted by the grid's DragTarget → dropped outside the grid.
          if (!details.wasAccepted) onCancelled?.call(placement.cell);
        },
        // The letter itself stays painted in the cell (canvas layer); this
        // child only provides the hit area. A bare SizedBox takes no pointer
        // hits, so a transparent ColoredBox (which does hit-test) is required
        // for the drag to ever start.
        child: const ColoredBox(color: Colors.transparent, child: SizedBox.expand()),
      ),
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
    required this.revealMode,
    required this.puzzle,
    required this.cellSize,
    this.hoverCell,
    this.hoverValid = false,
    this.hiddenPendingCell,
  });

  final List<Placement> pendingPlacements;
  final bool revealMode;
  final PuzzleData puzzle;
  final double cellSize;

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
      final dim = Paint()..color = Colors.black45;
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
      final base = hoverValid ? AppColors.success : AppColors.error;
      canvas.drawRect(rect, Paint()..color = base.withValues(alpha: hoverValid ? 0.35 : 0.20));
      canvas.drawRect(
        rect.deflate(1),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = base,
      );
    }

    // Pending letters render as a full-cell rounded tile in rack-tile cream:
    // reads as "your letter, not committed yet" and contrasts with the accent
    // arrows (the old full-orange fill colour-matched and hid them).
    for (final placement in pendingPlacements) {
      if (placement.cell == hiddenPendingCell) continue;
      final rect = Rect.fromLTWH(
        placement.cell.col * cellSize,
        placement.cell.row * cellSize,
        cellSize,
        cellSize,
      );
      final rrect = RRect.fromRectAndRadius(rect.deflate(1), Radius.circular(cellSize * 0.12));
      canvas.drawRRect(rrect, Paint()..color = AppColors.rackTileBg);
      canvas.drawRRect(
        rrect,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = AppColors.accent,
      );
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

    // Clue direction arrows LAST, in the topmost layer: always visible above
    // pending tiles and hover fills, whatever covers the cells below.
    for (final spec in puzzle.cells) {
      if (spec.type != CellType.clue) continue;
      final rect = Rect.fromLTWH(spec.col * cellSize, spec.row * cellSize, cellSize, cellSize);
      _clueRenderer.drawArrows(canvas, rect, spec);
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
      hiddenPendingCell != old.hiddenPendingCell;
}
