// lib/features/gameplay/widgets/rack_widget.dart

import 'package:flutter/material.dart';
import 'package:kelime_oyunu/core/constants/app_typography.dart';
import 'package:kelime_oyunu/core/theme/app_tokens.dart';
import 'package:kelime_oyunu/data/models/puzzle.dart';
import 'package:kelime_oyunu/features/gameplay/engine/rack_manager.dart';

/// Payload of a letter drag: which rack tile is being dragged and, when the
/// drag started from a pending letter on the board, the cell it came from
/// (null for drags that start on the rack).
typedef DragTileData = ({int rackIndex, WordCell? fromCell});

/// Vector from the finger to the CENTRE of the floating feedback tile.
/// Drop/hover cell resolution adds this to the drag position, so the letter
/// lands on the cell the player SEES the tile over — not the cell hidden
/// under the fingertip (WYSIWYG placement).
const Offset kDragFeedbackCentreOffset = Offset(0, -DragFeedbackTile.size * 0.8);

class RackWidget extends StatelessWidget {
  const RackWidget({
    required this.rack,
    required this.onTileTap,
    required this.onTileRecall,
    this.showPlusSlot = false,
    this.onPlusTap,
    this.dragEnabled = false,
    this.onDragStarted,
    super.key,
  });

  final List<RackTile> rack;
  final void Function(int rackIndex) onTileTap;
  final void Function(int rackIndex) onTileRecall;

  /// Shows the "+1 letter" joker slot at the end of the rack (until unlocked).
  final bool showPlusSlot;

  /// Tap on the joker slot; null renders it dimmed/disabled (bot's turn etc.).
  final VoidCallback? onPlusTap;

  /// Whether tiles can be dragged onto the grid. Off during the bot's turn,
  /// in reveal mode, and after the match finishes — mirrors the tap guards.
  final bool dragEnabled;

  /// Fired when a tile drag begins (e.g. to clear a pending tap-selection).
  final void Function(int rackIndex)? onDragStarted;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < rack.length; i++) ...[
          if (i > 0) const SizedBox(width: 4),
          Draggable<DragTileData>(
            data: (rackIndex: i, fromCell: null),
            // 0 disables dragging while keeping tap/long-press intact.
            maxSimultaneousDrags: dragEnabled && !rack[i].isPlaced ? 1 : 0,
            // Anchor the drag position to the pointer itself so DragTarget's
            // details.offset is the finger position — the grid derives the
            // hovered cell from it (plus kDragFeedbackCentreOffset).
            dragAnchorStrategy: pointerDragAnchorStrategy,
            // Find the DragTarget at the tile's visual centre too. Without
            // this, Flutter hit-tests at the finger: aiming the tile at the
            // grid's BOTTOM row leaves the finger below the grid, no target
            // is found, and the bottom row becomes an unreachable dead zone.
            feedbackOffset: kDragFeedbackCentreOffset,
            onDragStarted: () => onDragStarted?.call(i),
            feedback: DragFeedbackTile(letter: rack[i].letter),
            childWhenDragging: Opacity(
              opacity: 0.35,
              child: _RackTileWidget(tile: rack[i], onTap: null),
            ),
            child: _RackTileWidget(
              tile: rack[i],
              onTap: rack[i].isPlaced ? null : () => onTileTap(i),
              onLongPress: rack[i].isPlaced ? () => onTileRecall(i) : null,
            ),
          ),
        ],
        if (showPlusSlot) ...[const SizedBox(width: 4), _PlusSlotWidget(onTap: onPlusTap)],
      ],
    );
  }
}

/// The lifted tile rendered during a drag: slightly larger, stronger shadow,
/// floated above the pointer so the finger never hides it. Shared by rack
/// drags and pending-letter (on-board) drags. Its visual centre sits at
/// pointer + [kDragFeedbackCentreOffset]; keep the two in sync.
class DragFeedbackTile extends StatelessWidget {
  const DragFeedbackTile({required this.letter, super.key});

  final String letter;

  static const double size = 56.0;

  @override
  Widget build(BuildContext context) {
    // Material: the feedback lives in the root Overlay, outside the app's
    // Material ancestry — without it, Text falls back to error styling.
    final tokens = context.tokens;
    return Transform.translate(
      // Centre horizontally on the finger, float above it.
      offset: const Offset(-size / 2, -size * 1.3),
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: tokens.tile,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [BoxShadow(color: tokens.dim, blurRadius: 10, offset: const Offset(0, 5))],
          ),
          alignment: Alignment.center,
          child: Text(letter, style: AppTypography.tileLetter.copyWith(color: tokens.tileInk)),
        ),
      ),
    );
  }
}

/// The "+1 letter" joker slot: a tile-shaped button with an Ad badge.
class _PlusSlotWidget extends StatelessWidget {
  const _PlusSlotWidget({required this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: onTap == null ? 0.4 : 1.0,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: tokens.tile,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: tokens.accent, width: 1.5),
              ),
              alignment: Alignment.center,
              child: Icon(Icons.add, color: tokens.accent, size: 26),
            ),
            Positioned(
              top: -4,
              right: -4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  color: tokens.accent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Ad',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: tokens.accentInk,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RackTileWidget extends StatelessWidget {
  const _RackTileWidget({required this.tile, required this.onTap, this.onLongPress});

  final RackTile tile;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  static const double _tileSize = 48.0;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Opacity(
        opacity: tile.isPlaced ? 0.4 : 1.0,
        child: Container(
          width: _tileSize,
          height: _tileSize,
          decoration: BoxDecoration(
            color: tokens.tile,
            borderRadius: BorderRadius.circular(6),
            border: tile.isReturned ? Border.all(color: tokens.error, width: 2) : null,
            // Design: "0 4 0 tileShadow" — a hard 4 dp base under an idle tile.
            boxShadow: tile.isPlaced
                ? null
                : [BoxShadow(color: tokens.tileShadow, offset: const Offset(0, 4))],
          ),
          alignment: Alignment.center,
          child: Text(tile.letter, style: AppTypography.tileLetter.copyWith(color: tokens.tileInk)),
        ),
      ),
    );
  }
}
