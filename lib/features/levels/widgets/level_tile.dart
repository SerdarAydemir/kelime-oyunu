// lib/features/levels/widgets/level_tile.dart

import 'package:flutter/material.dart';

import 'package:kelime_oyunu/core/constants/app_colors.dart';
import 'package:kelime_oyunu/core/constants/app_dimensions.dart';
import 'package:kelime_oyunu/core/constants/app_typography.dart';
import 'package:kelime_oyunu/features/levels/cubit/level_select_state.dart';

/// One square on the level grid.
///
/// Three looks, one per [LevelStatus]: a won level is green with a tick, the
/// frontier is the accent-ringed call to action, and a locked level is grey
/// with a padlock and no tap target at all.
class LevelTile extends StatelessWidget {
  const LevelTile({required this.levelId, required this.status, this.onTap, super.key});

  final int levelId;
  final LevelStatus status;

  /// Null for a locked level — the tile is then inert, not just styled dead.
  final VoidCallback? onTap;

  bool get _locked => status == LevelStatus.locked;

  Color get _background => switch (status) {
    LevelStatus.completed => AppColors.gridCellFound,
    LevelStatus.current => AppColors.primary,
    LevelStatus.locked => AppColors.gridCellLocked,
  };

  Color get _foreground => switch (status) {
    LevelStatus.completed => AppColors.primaryDark,
    LevelStatus.current => AppColors.gridCellNormal,
    LevelStatus.locked => AppColors.gridCellNormal,
  };

  String get _semanticLabel => switch (status) {
    LevelStatus.completed => 'Bölüm $levelId, tamamlandı',
    LevelStatus.current => 'Bölüm $levelId, sıradaki bölüm',
    LevelStatus.locked => 'Bölüm $levelId, kilitli',
  };

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: !_locked,
      enabled: !_locked,
      label: _semanticLabel,
      child: Material(
        color: _background,
        // shape carries its own radius — Material forbids passing both. The
        // frontier wears the accent ring so the eye lands on it first.
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusM),
          side: status == LevelStatus.current
              ? const BorderSide(color: AppColors.accent, width: 3)
              : BorderSide.none,
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppDimensions.radiusM),
          child: Center(
            child: _locked
                ? Icon(Icons.lock, size: AppDimensions.iconS, color: _foreground)
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$levelId',
                        style: AppTypography.bodyLarge.copyWith(
                          color: _foreground,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (status == LevelStatus.completed)
                        const Icon(
                          Icons.check,
                          size: AppDimensions.iconS,
                          color: AppColors.success,
                        ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
