// lib/features/gameplay/widgets/rack_widget.dart

import 'package:flutter/material.dart';
import 'package:kelime_oyunu/core/constants/app_dimensions.dart';
import 'package:kelime_oyunu/core/constants/app_typography.dart';
import 'package:kelime_oyunu/core/theme/app_tokens.dart';
import 'package:kelime_oyunu/core/widgets/dashed_border.dart';
import 'package:kelime_oyunu/data/models/puzzle.dart';
import 'package:kelime_oyunu/features/gameplay/engine/rack_manager.dart';
import 'package:kelime_oyunu/features/gameplay/widgets/ad_label.dart';
import 'package:kelime_oyunu/l10n/generated/app_localizations.dart';

/// Payload of a letter drag: which rack tile is being dragged and, when the
/// drag started from a pending letter on the board, the cell it came from
/// (null for drags that start on the rack).
typedef DragTileData = ({int rackIndex, WordCell? fromCell});

/// Vector from the finger to the CENTRE of the floating feedback tile.
/// Drop/hover cell resolution adds this to the drag position, so the letter
/// lands on the cell the player SEES the tile over — not the cell hidden
/// under the fingertip (WYSIWYG placement).
const Offset kDragFeedbackCentreOffset = Offset(0, -DragFeedbackTile.size * 0.8);

/// The letter rack (README "Rack"): 52 × 56 tiles, r10, gap 6, plus the
/// dashed "+ HARF EKLE" slot until the sixth slot is unlocked.
class RackWidget extends StatelessWidget {
  const RackWidget({
    required this.rack,
    required this.onTileTap,
    required this.onTileRecall,
    this.selectedIndex = -1,
    this.showPlusSlot = false,
    this.showAdLabel = false,
    this.onPlusTap,
    this.dragEnabled = false,
    this.onDragStarted,
    super.key,
  });

  final List<RackTile> rack;
  final void Function(int rackIndex) onTileTap;
  final void Function(int rackIndex) onTileRecall;

  /// Tile currently selected for tap-placement (lifted, amber); -1 for none.
  final int selectedIndex;

  /// Shows the "+1 letter" joker slot at the end of the rack (until unlocked).
  final bool showPlusSlot;

  /// Whether the joker slot carries its "▶ reklam" sub-label (hidden in the
  /// ad-free first levels).
  final bool showAdLabel;

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
          if (i > 0) const SizedBox(width: AppDimensions.space6),
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
              child: _RackTileWidget(tile: rack[i], selected: false, onTap: null),
            ),
            child: _RackTileWidget(
              tile: rack[i],
              selected: i == selectedIndex,
              onTap: rack[i].isPlaced ? null : () => onTileTap(i),
              onLongPress: rack[i].isPlaced ? () => onTileRecall(i) : null,
            ),
          ),
        ],
        if (showPlusSlot) ...[
          const SizedBox(width: AppDimensions.space6),
          _PlusSlotWidget(onTap: onPlusTap, showAdLabel: showAdLabel),
        ],
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
    final tokens = context.tokens;
    // Material: the feedback lives in the root Overlay, outside the app's
    // Material ancestry — without it, Text falls back to error styling.
    return Transform.translate(
      // Centre horizontally on the finger, float above it.
      offset: const Offset(-size / 2, -size * 1.3),
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: tokens.accent,
            borderRadius: BorderRadius.circular(AppDimensions.radiusTile),
            boxShadow: [
              BoxShadow(
                color: tokens.accent.withValues(alpha: 0.4),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Text(letter, style: AppTypography.tileLetter.copyWith(color: tokens.tileInk)),
        ),
      ),
    );
  }
}

/// The "+ HARF EKLE" joker slot: a dashed accent outline with a plus icon,
/// the label and — when ads are live — the "▶ reklam" sub-label.
class _PlusSlotWidget extends StatelessWidget {
  const _PlusSlotWidget({required this.onTap, required this.showAdLabel});

  final VoidCallback? onTap;
  final bool showAdLabel;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final l10n = AppLocalizations.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: onTap == null ? 0.4 : 1.0,
        child: CustomPaint(
          painter: DashedBorderPainter(color: tokens.accent, radius: AppDimensions.radiusTile),
          child: SizedBox(
            width: AppDimensions.tileWidth,
            height: AppDimensions.tileHeight,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add, size: AppDimensions.iconS, color: tokens.accent),
                const SizedBox(height: 2),
                Text(
                  l10n.addLetter,
                  style: AppTypography.buttonPrimary.copyWith(
                    fontSize: 7.5,
                    height: 1,
                    color: tokens.accent,
                  ),
                ),
                if (showAdLabel) ...[const SizedBox(height: 2), AdLabel(color: tokens.accent)],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One rack tile in its four looks: idle (`tile` + 4 dp `tileShadow` base),
/// selected (amber, lifted 8 dp, amber glow), placed (dashed `faint` empty
/// slot — long-press recalls the letter) and wrong-return (2 px `error` ring).
class _RackTileWidget extends StatelessWidget {
  const _RackTileWidget({
    required this.tile,
    required this.selected,
    required this.onTap,
    this.onLongPress,
  });

  final RackTile tile;
  final bool selected;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final Widget body;
    if (tile.isPlaced) {
      body = CustomPaint(
        painter: DashedBorderPainter(color: tokens.faint, radius: AppDimensions.radiusTile),
        child: const SizedBox(width: AppDimensions.tileWidth, height: AppDimensions.tileHeight),
      );
    } else {
      body = AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        width: AppDimensions.tileWidth,
        height: AppDimensions.tileHeight,
        transform: Matrix4.translationValues(0, selected ? -8 : 0, 0),
        decoration: BoxDecoration(
          color: selected ? tokens.accent : tokens.tile,
          borderRadius: BorderRadius.circular(AppDimensions.radiusTile),
          border: tile.isReturned ? Border.all(color: tokens.error, width: 2) : null,
          boxShadow: [
            if (selected)
              BoxShadow(
                color: tokens.accent.withValues(alpha: 0.4),
                blurRadius: 24,
                offset: const Offset(0, 12),
              )
            else
              BoxShadow(color: tokens.tileShadow, offset: const Offset(0, 4)),
          ],
        ),
        alignment: Alignment.center,
        child: Text(tile.letter, style: AppTypography.tileLetter.copyWith(color: tokens.tileInk)),
      );
    }
    return GestureDetector(onTap: onTap, onLongPress: onLongPress, child: body);
  }
}
