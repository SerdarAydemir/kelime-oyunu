// lib/features/levels/widgets/level_tile.dart

import 'package:flutter/material.dart';

import 'package:kelime_oyunu/core/constants/app_dimensions.dart';
import 'package:kelime_oyunu/core/constants/app_typography.dart';
import 'package:kelime_oyunu/core/theme/app_tokens.dart';
import 'package:kelime_oyunu/features/levels/cubit/level_select_state.dart';

/// One square on the level grid.
///
/// Three looks, one per [LevelStatus]: a won level is a `board` card with a
/// tick and an amber ring (the map's "done" node), the frontier is the solid
/// amber call to action, and a locked level is a muted `surface` square with a
/// padlock and no tap target at all. Under the QA unlock override
/// ([showNumberWhenLocked]) a locked tile keeps its grey look but shows its
/// number instead of the padlock, so testers can aim for a specific level.
class LevelTile extends StatelessWidget {
  const LevelTile({
    required this.levelId,
    required this.status,
    this.onTap,
    this.showNumberWhenLocked = false,
    super.key,
  });

  final int levelId;
  final LevelStatus status;

  /// Null for a locked level — the tile is then inert, not just styled dead.
  final VoidCallback? onTap;

  /// DEV_UNLOCK_ALL: draw the level number on locked tiles (style unchanged).
  final bool showNumberWhenLocked;

  bool get _locked => status == LevelStatus.locked;

  bool get _showsPadlock => _locked && !showNumberWhenLocked;

  Color _background(AppTokens t) => switch (status) {
    LevelStatus.completed => t.board,
    LevelStatus.current => t.accent,
    LevelStatus.locked => t.surface,
  };

  Color _foreground(AppTokens t) => switch (status) {
    LevelStatus.completed => t.ink,
    LevelStatus.current => t.accentInk,
    LevelStatus.locked => t.faint,
  };

  String get _semanticLabel => switch (status) {
    LevelStatus.completed => 'Bölüm $levelId, tamamlandı',
    LevelStatus.current => 'Bölüm $levelId, sıradaki bölüm',
    LevelStatus.locked => 'Bölüm $levelId, kilitli',
  };

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final foreground = _foreground(tokens);
    return Semantics(
      button: onTap != null,
      enabled: onTap != null,
      label: _semanticLabel,
      child: Material(
        color: _background(tokens),
        // shape carries its own radius — Material forbids passing both. Done
        // nodes wear the 2 px amber ring of the climb map's "done" state.
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusTile),
          side: status == LevelStatus.completed
              ? BorderSide(color: tokens.accent, width: 2)
              : BorderSide.none,
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppDimensions.radiusTile),
          child: Center(
            child: _showsPadlock
                ? Icon(Icons.lock, size: AppDimensions.iconS, color: foreground)
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('$levelId', style: AppTypography.nodeNumber.copyWith(color: foreground)),
                      if (status == LevelStatus.completed)
                        Icon(Icons.check, size: AppDimensions.iconS, color: tokens.success),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
