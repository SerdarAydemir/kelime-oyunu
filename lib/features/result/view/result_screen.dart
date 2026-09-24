// lib/features/result/view/result_screen.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:kelime_oyunu/core/constants/app_dimensions.dart';
import 'package:kelime_oyunu/core/constants/app_typography.dart';
import 'package:kelime_oyunu/core/constants/game_constants.dart';
import 'package:kelime_oyunu/core/theme/app_tokens.dart';
import 'package:kelime_oyunu/features/gameplay/bloc/game_state.dart';
import 'package:kelime_oyunu/features/home/widgets/home_cards.dart';
import 'package:kelime_oyunu/features/home/widgets/mountain_backdrop.dart';
import 'package:kelime_oyunu/features/result/widgets/result_parts.dart';
import 'package:kelime_oyunu/l10n/generated/app_localizations.dart';

/// Full-screen end-of-match route (README "Result screens"): won (dawn),
/// lost (night at camp) and draw (neutral). Pure presentation of the query
/// parameters — the bloc has already persisted the outcome.
///
/// Hard progression is unchanged: only a win on a non-final level offers
/// the next level; a loss or a draw offers a retry and the map.
class ResultScreen extends StatelessWidget {
  const ResultScreen({
    required this.status,
    required this.levelId,
    required this.playerScore,
    required this.botScore,
    required this.botName,
    super.key,
  });

  final GameStatus status;
  final int levelId;
  final int playerScore;
  final int botScore;
  final String botName;

  /// Route for a finished match: `/result/{level}?status=won&p=12&b=9`.
  static String location({
    required GameStatus status,
    required int levelId,
    required int playerScore,
    required int botScore,
  }) => '/result/$levelId?status=${status.name}&p=$playerScore&b=$botScore';

  bool get _isLastLevel => levelId >= kLastLevelId;
  bool get _canAdvance => status == GameStatus.won && !_isLastLevel;
  bool get _finishedAll => status == GameStatus.won && _isLastLevel;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final l10n = AppLocalizations.of(context);
    final won = status == GameStatus.won;
    final (gradient, outcome, headline, sub) = switch (status) {
      GameStatus.won => (tokens.bgWon, l10n.won, l10n.wonH, null),
      GameStatus.lost => (tokens.bgLost, l10n.lost, l10n.lostH, l10n.lostSub),
      GameStatus.tie => (tokens.bgDraw, l10n.draw, l10n.drawH, l10n.drawSub),
      // Unreachable: the route is only reached for a finished match.
      GameStatus.playing => (tokens.bgGame, '', '', null),
    };
    // A finished board has nothing to go back to: the system back gesture is
    // disabled, the buttons are the only exits.
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: Stack(
          children: [
            Positioned.fill(
              child: DecoratedBox(decoration: BoxDecoration(gradient: gradient)),
            ),
            if (won) const Positioned(top: 80, right: 40, child: SunDisc()),
            const Positioned.fill(child: MountainBackdrop(trail: false)),
            if (!won)
              const Positioned(left: 0, right: 0, bottom: 300, child: Center(child: Campfire())),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppDimensions.space24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: AppDimensions.space40),
                    ResultTag(level: levelId, outcome: outcome),
                    const SizedBox(height: AppDimensions.space12),
                    ResultHeadline(text: headline),
                    if (sub != null) ...[
                      const SizedBox(height: AppDimensions.space12),
                      Text(
                        sub,
                        style: AppTypography.body.copyWith(
                          color: tokens.text.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                    if (won) ...[
                      const SizedBox(height: AppDimensions.space16),
                      AltitudePill(gain: kMetersPerLevel, total: levelId * kMetersPerLevel),
                    ],
                    const Spacer(),
                    ScoreCard(playerScore: playerScore, botScore: botScore, botName: botName),
                    if (_finishedAll) ...[
                      const SizedBox(height: AppDimensions.space12),
                      Text(
                        l10n.allLevelsDone,
                        style: AppTypography.body.copyWith(color: tokens.text),
                      ),
                    ],
                    const SizedBox(height: AppDimensions.space16),
                    _Actions(screen: this),
                    const SizedBox(height: AppDimensions.space16),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Won: solid "Bölüm n+1 · tırmanmaya devam" + "Tekrar oyna" / "Harita".
/// Lost / draw: amber "Tekrar dene" + "Haritaya dön".
class _Actions extends StatelessWidget {
  const _Actions({required this.screen});

  final ResultScreen screen;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final l10n = AppLocalizations.of(context);
    void replay() => context.go('/gameplay/${screen.levelId}');
    void map() => context.go('/map');
    if (screen.status == GameStatus.won) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (screen._canAdvance)
            PrimaryButton(
              label: l10n.wonCta(screen.levelId + 1),
              solid: true,
              onPressed: () => context.go('/gameplay/${screen.levelId + 1}'),
            ),
          const SizedBox(height: AppDimensions.space10),
          Row(
            children: [
              Expanded(
                child: SecondaryButton(label: l10n.again, color: tokens.solid, onPressed: replay),
              ),
              const SizedBox(width: AppDimensions.space10),
              Expanded(
                child: SecondaryButton(label: l10n.map, color: tokens.solid, onPressed: map),
              ),
            ],
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PrimaryButton(label: l10n.tryAgain, onPressed: replay),
        const SizedBox(height: AppDimensions.space10),
        SecondaryButton(label: l10n.backMap, onPressed: map),
      ],
    );
  }
}
