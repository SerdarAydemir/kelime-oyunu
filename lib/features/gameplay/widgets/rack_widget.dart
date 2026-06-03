// lib/features/gameplay/widgets/rack_widget.dart

import 'package:flutter/material.dart';
import 'package:kelime_oyunu/features/gameplay/engine/rack_manager.dart';

class RackWidget extends StatelessWidget {
  const RackWidget({
    required this.rack,
    required this.onTileTap,
    super.key,
  });

  final List<RackTile> rack;
  final void Function(int rackIndex) onTileTap;

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
          ),
        ],
      ],
    );
  }
}

class _RackTileWidget extends StatelessWidget {
  const _RackTileWidget({
    required this.tile,
    required this.onTap,
  });

  final RackTile tile;
  final VoidCallback? onTap;

  static const double _tileSize = 48.0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: tile.isPlaced ? 0.4 : 1.0,
        child: Container(
          width: _tileSize,
          height: _tileSize,
          decoration: BoxDecoration(
            // TODO: add AppColors.rackTileBg token (0xFFF5E6C8)
            color: const Color(0xFFF5E6C8),
            borderRadius: BorderRadius.circular(6),
            border: tile.isReturned
                ? Border.all(color: Colors.red.shade300, width: 2)
                : null,
            boxShadow: tile.isPlaced
                ? null
                : const [
                    BoxShadow(
                      color: Color(0x26000000),
                      blurRadius: 3,
                      offset: Offset(0, 2),
                    ),
                  ],
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
