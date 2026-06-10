// lib/features/gameplay/widgets/rack_widget.dart

import 'package:flutter/material.dart';
import 'package:kelime_oyunu/core/constants/app_colors.dart';
import 'package:kelime_oyunu/features/gameplay/engine/rack_manager.dart';

class RackWidget extends StatelessWidget {
  const RackWidget({
    required this.rack,
    required this.onTileTap,
    required this.onTileRecall,
    this.showPlusSlot = false,
    this.onPlusTap,
    super.key,
  });

  final List<RackTile> rack;
  final void Function(int rackIndex) onTileTap;
  final void Function(int rackIndex) onTileRecall;

  /// Shows the "+1 letter" joker slot at the end of the rack (until unlocked).
  final bool showPlusSlot;

  /// Tap on the joker slot; null renders it dimmed/disabled (bot's turn etc.).
  final VoidCallback? onPlusTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < rack.length; i++) ...[
          if (i > 0) const SizedBox(width: 4),
          _RackTileWidget(
            tile: rack[i],
            onTap: rack[i].isPlaced ? null : () => onTileTap(i),
            onLongPress: rack[i].isPlaced ? () => onTileRecall(i) : null,
          ),
        ],
        if (showPlusSlot) ...[const SizedBox(width: 4), _PlusSlotWidget(onTap: onPlusTap)],
      ],
    );
  }
}

/// The "+1 letter" joker slot: a tile-shaped button with an Ad badge.
class _PlusSlotWidget extends StatelessWidget {
  const _PlusSlotWidget({required this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
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
                // TODO: add AppColors.rackTileBg token (0xFFF5E6C8)
                color: const Color(0xFFF5E6C8),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppColors.accent, width: 1.5),
              ),
              alignment: Alignment.center,
              child: const Icon(Icons.add, color: AppColors.accent, size: 26),
            ),
            Positioned(
              top: -4,
              right: -4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.accent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Ad',
                  style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white),
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
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Opacity(
        opacity: tile.isPlaced ? 0.4 : 1.0,
        child: Container(
          width: _tileSize,
          height: _tileSize,
          decoration: BoxDecoration(
            // TODO: add AppColors.rackTileBg token (0xFFF5E6C8)
            color: const Color(0xFFF5E6C8),
            borderRadius: BorderRadius.circular(6),
            border: tile.isReturned ? Border.all(color: Colors.red.shade300, width: 2) : null,
            boxShadow: tile.isPlaced
                ? null
                : const [BoxShadow(color: Color(0x26000000), blurRadius: 3, offset: Offset(0, 2))],
          ),
          alignment: Alignment.center,
          child: Text(
            tile.letter,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ),
      ),
    );
  }
}
