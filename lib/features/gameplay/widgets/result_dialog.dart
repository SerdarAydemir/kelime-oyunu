// lib/features/gameplay/widgets/result_dialog.dart

import 'package:flutter/material.dart';

import 'package:kelime_oyunu/core/theme/app_tokens.dart';
import 'package:kelime_oyunu/core/constants/app_dimensions.dart';
import 'package:kelime_oyunu/core/constants/app_typography.dart';
import 'package:kelime_oyunu/core/constants/game_constants.dart';
import 'package:kelime_oyunu/features/gameplay/bloc/game_state.dart';

/// Modal shown when the board is filled and the match ends.
///
/// Pure presentation: the three outcomes (won / lost / tie) are derived from
/// [status], and both actions are delegated to caller-supplied callbacks, so
/// this widget carries no Bloc or router dependency and stays trivially
/// testable. The caller is responsible for closing the dialog inside the
/// callbacks (the buttons only signal intent).
class ResultDialog extends StatelessWidget {
  const ResultDialog({
    required this.status,
    required this.playerScore,
    required this.botScore,
    required this.botName,
    required this.levelId,
    required this.onReplay,
    required this.onNext,
    required this.onLevels,
    super.key,
  });

  final GameStatus status;
  final int playerScore;
  final int botScore;
  final String botName;
  final int levelId;

  /// Reloads the same level with a clean state ("Tekrar Oyna").
  final VoidCallback onReplay;

  /// Advances to [levelId] + 1 ("Sonraki Bölüm"). Only reachable after a win on
  /// a non-final level — the button is hidden on a loss, a tie, or the final
  /// level — but kept non-null so the caller's wiring stays uniform.
  final VoidCallback onNext;

  /// Leaves for the level grid ("Bölümler"). Always available: with the system
  /// back gesture disabled here, this is the player's only way out of a
  /// finished board that they do not want to replay.
  final VoidCallback onLevels;

  bool get _isLastLevel => levelId >= kLastLevelId;

  // Hard progression: only a win advances the player. A loss or a tie means the
  // bot was not beaten, so the level must be replayed (product decision).
  bool get _canAdvance => status == GameStatus.won && !_isLastLevel;

  // Winning the very last level finishes the game; a loss/tie there just replays.
  bool get _finishedAll => status == GameStatus.won && _isLastLevel;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final (title, titleColor) = switch (status) {
      GameStatus.won => ('Kazandın! 🎉', tokens.success),
      GameStatus.lost => ('Kaybettin', tokens.error),
      GameStatus.tie => ('Berabere', tokens.accent),
      // Unreachable: the dialog is only shown for a finished match.
      GameStatus.playing => ('', tokens.text),
    };
    final scoreDiff = (playerScore - botScore).abs();

    // Disable the system back gesture: a finished board has no valid actions
    // behind it, so the player must pick "Sonraki Bölüm" or "Tekrar Oyna".
    return PopScope(
      canPop: false,
      child: AlertDialog(
        title: Text(
          title,
          textAlign: TextAlign.center,
          style: AppTypography.resultTitle.copyWith(color: titleColor),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Bölüm $levelId / $kLastLevelId', style: AppTypography.bodySmall),
            const SizedBox(height: AppDimensions.space16),
            _ScoreRow(label: 'Sen', score: playerScore),
            const SizedBox(height: AppDimensions.space4),
            _ScoreRow(label: botName, score: botScore),
            const SizedBox(height: AppDimensions.space8),
            Text('Fark: $scoreDiff', style: AppTypography.body),
            if (_finishedAll) ...[
              const SizedBox(height: AppDimensions.space16),
              const Text(
                'Tüm bölümleri bitirdin! 🎉',
                textAlign: TextAlign.center,
                style: AppTypography.body,
              ),
            ],
          ],
        ),
        actions: [
          TextButton(onPressed: onLevels, child: const Text('Bölümler')),
          TextButton(onPressed: onReplay, child: const Text('Tekrar Oyna')),
          if (_canAdvance) FilledButton(onPressed: onNext, child: const Text('Sonraki Bölüm')),
        ],
      ),
    );
  }
}

/// One "name … score" line in the result summary.
class _ScoreRow extends StatelessWidget {
  const _ScoreRow({required this.label, required this.score});

  final String label;
  final int score;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: AppTypography.body),
        Text('$score', style: AppTypography.screenTitle),
      ],
    );
  }
}
