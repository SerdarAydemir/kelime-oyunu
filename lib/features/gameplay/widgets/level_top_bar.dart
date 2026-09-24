// lib/features/gameplay/widgets/level_top_bar.dart

import 'package:flutter/material.dart';

import 'package:kelime_oyunu/core/constants/app_dimensions.dart';
import 'package:kelime_oyunu/core/constants/app_typography.dart';
import 'package:kelime_oyunu/core/theme/app_tokens.dart';
import 'package:kelime_oyunu/core/widgets/circle_icon_button.dart';
import 'package:kelime_oyunu/l10n/generated/app_localizations.dart';

/// Game header (README "Game screen"): ← · "BÖLÜM" tag over the level number
/// in Lora 22 · ⋯. The total level count is never shown (design rule).
///
/// Deliberately not an AppBar: the grid needs every vertical pixel it can get.
/// The back arrow is the only way out of a live match — the routes are pushed
/// with `go`, which leaves no stack for the system gesture to pop.
class LevelTopBar extends StatelessWidget {
  const LevelTopBar({required this.levelId, required this.onExit, this.onMore, super.key});

  final int levelId;

  /// Leaves for the level grid. The match is already saved at its last turn
  /// boundary, so it will be waiting under "Yarım kalan oyun".
  final VoidCallback onExit;

  /// The ⋯ button. No menu exists yet (settings / pause arrive with the
  /// settings screen); null renders the button inert.
  final VoidCallback? onMore;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.space16,
        vertical: AppDimensions.space8,
      ),
      child: Row(
        children: [
          CircleIconButton(icon: Icons.arrow_back, onPressed: onExit, tooltip: l10n.levels),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  l10n.levelTag,
                  style: AppTypography.overline.copyWith(color: tokens.text.withValues(alpha: 0.7)),
                ),
                Text('$levelId', style: AppTypography.screenTitle.copyWith(color: tokens.text)),
              ],
            ),
          ),
          CircleIconButton(icon: Icons.more_horiz, onPressed: onMore, tooltip: l10n.settings),
        ],
      ),
    );
  }
}
