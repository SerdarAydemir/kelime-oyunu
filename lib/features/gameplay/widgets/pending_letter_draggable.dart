// lib/features/gameplay/widgets/pending_letter_draggable.dart

import 'package:flutter/material.dart';
import 'package:kelime_oyunu/data/models/puzzle.dart';
import 'package:kelime_oyunu/features/gameplay/engine/score_engine.dart';
import 'package:kelime_oyunu/features/gameplay/widgets/rack_widget.dart';

/// Invisible drag handle over one pending letter (used by [GridPainter]). Dragging it moves the
/// letter: a valid drop fires onCellDrop with fromCell set (the screen
/// recalls + re-places), an invalid in-grid drop leaves it untouched, and a
/// drop outside the grid cancels — [onCancelled] recalls it to the rack.
class PendingLetterDraggable extends StatelessWidget {
  const PendingLetterDraggable({
    required this.placement,
    required this.cellSize,
    required this.rackIndex,
    required this.onCancelled,
    required this.onLifted,
    required this.onSettled,
    super.key,
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
