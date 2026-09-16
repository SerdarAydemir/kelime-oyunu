// lib/features/gameplay/widgets/grid_painter.dart

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:kelime_oyunu/data/models/puzzle.dart';
import 'package:kelime_oyunu/features/gameplay/engine/score_engine.dart';
import 'package:kelime_oyunu/features/gameplay/widgets/grid_dynamic_painter.dart';
import 'package:kelime_oyunu/features/gameplay/widgets/grid_static_painter.dart';
import 'package:kelime_oyunu/features/gameplay/widgets/pending_letter_draggable.dart';
import 'package:kelime_oyunu/features/gameplay/widgets/rack_widget.dart';

// The painters stay reachable through this file so existing imports keep
// working after the split (public API unchanged).
export 'package:kelime_oyunu/features/gameplay/widgets/grid_dynamic_painter.dart';
export 'package:kelime_oyunu/features/gameplay/widgets/grid_static_painter.dart';

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
    this.suppressedCells = const {},
    super.key,
  });

  final PuzzleData puzzle;
  final Map<WordCell, String> board;
  final List<Placement> pendingPlacements;
  final Set<String> revealedWordIds;
  final Set<WordCell> botPlacedCells;

  /// Cells whose committed glyph is hidden this frame because a narration tile
  /// is still flying toward them — the letter appears the instant it lands.
  final Set<WordCell> suppressedCells;

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
                        suppressedCells: widget.suppressedCells,
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
                      PendingLetterDraggable(
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
