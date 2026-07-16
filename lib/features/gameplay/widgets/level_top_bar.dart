// lib/features/gameplay/widgets/level_top_bar.dart

import 'package:flutter/material.dart';

import 'package:kelime_oyunu/core/constants/app_dimensions.dart';
import 'package:kelime_oyunu/core/constants/app_typography.dart';
import 'package:kelime_oyunu/core/constants/game_constants.dart';

/// The thin "‹ Bölüm X / N" strip above the score header.
///
/// Deliberately not an AppBar: the grid needs every vertical pixel it can get.
/// The back arrow is the only way out of a live match — the routes are pushed
/// with `go`, which leaves no stack for the system gesture to pop.
class LevelTopBar extends StatelessWidget {
  const LevelTopBar({required this.levelId, required this.onExit, super.key});

  final int levelId;

  /// Leaves for the level grid. The match is already saved at its last turn
  /// boundary, so it will be waiting under "Devam Et".
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: AppDimensions.minTapTarget,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Text('Bölüm $levelId / $kLastLevelId', style: AppTypography.caption),
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              onPressed: onExit,
              icon: const Icon(Icons.arrow_back, size: AppDimensions.iconM),
              tooltip: 'Bölümler',
            ),
          ),
        ],
      ),
    );
  }
}
