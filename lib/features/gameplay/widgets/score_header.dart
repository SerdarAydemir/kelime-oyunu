// lib/features/gameplay/widgets/score_header.dart

import 'package:flutter/material.dart';
import 'package:kelime_oyunu/core/constants/app_dimensions.dart';
import 'package:kelime_oyunu/core/constants/app_typography.dart';
import 'package:kelime_oyunu/core/theme/app_tokens.dart';
import 'package:kelime_oyunu/l10n/generated/app_localizations.dart';

/// Scorebar (README "Game screen"): `1fr auto 1fr` — player avatar (amber)
/// with "Sen" + score, "VS", opponent avatar (blue) with "Rakip" + score.
/// While the bot thinks the player side dims to 55 % and the bot avatar
/// wears a pulsing 3 px blue ring.
class ScoreHeader extends StatelessWidget {
  const ScoreHeader({
    required this.playerScore,
    required this.botScore,
    required this.botName,
    required this.botThinking,
    this.avatarKey,
    this.playerScoreKey,
    super.key,
  });

  final int playerScore;
  final int botScore;
  final String botName;
  final bool botThinking;

  /// Anchors the bot's letter-flight source AND its score-badge target to the
  /// avatar portrait (F6).
  final GlobalKey? avatarKey;

  /// Anchors the player's score-badge target to the player's score: each
  /// score badge flies here and the counter ticks as it arrives.
  final GlobalKey? playerScoreKey;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppDimensions.space16),
      // Both sides get equal flex so "VS" sits at the true screen centre
      // regardless of how wide either score block is.
      child: Row(
        children: [
          Expanded(
            child: AnimatedOpacity(
              opacity: botThinking ? 0.55 : 1.0,
              duration: const Duration(milliseconds: 200),
              child: _Side(
                avatar: _Avatar(background: tokens.accent, foreground: tokens.accentInk),
                name: l10n.you,
                score: playerScore,
                scoreKey: playerScoreKey,
                alignEnd: false,
              ),
            ),
          ),
          Text(
            l10n.vs,
            style: AppTypography.overline.copyWith(
              letterSpacing: 2,
              color: tokens.text.withValues(alpha: 0.66),
            ),
          ),
          Expanded(
            child: _Side(
              avatar: _Avatar(
                key: avatarKey,
                background: tokens.bot,
                foreground: tokens.botInk,
                ring: botThinking,
              ),
              name: botName,
              score: botScore,
              alignEnd: true,
            ),
          ),
        ],
      ),
    );
  }
}

/// One half of the bar: avatar plus a name / score column. The bot side is
/// mirrored so both scores sit next to "VS".
class _Side extends StatelessWidget {
  const _Side({
    required this.avatar,
    required this.name,
    required this.score,
    required this.alignEnd,
    this.scoreKey,
  });

  final Widget avatar;
  final String name;
  final int score;
  final bool alignEnd;
  final GlobalKey? scoreKey;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final column = Column(
      crossAxisAlignment: alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          name,
          style: AppTypography.overline.copyWith(
            letterSpacing: 0,
            color: tokens.text.withValues(alpha: 0.7),
          ),
        ),
        Text(
          '$score',
          key: scoreKey,
          style: AppTypography.screenTitle.copyWith(color: tokens.text),
        ),
      ],
    );
    return Row(
      mainAxisAlignment: alignEnd ? MainAxisAlignment.end : MainAxisAlignment.start,
      children: alignEnd
          ? [column, const SizedBox(width: AppDimensions.space10), avatar]
          : [avatar, const SizedBox(width: AppDimensions.space10), column],
    );
  }
}

/// 38 dp circle with the person-silhouette placeholder (photos may replace it
/// later). [ring] draws the pulsing "thinking" ring.
class _Avatar extends StatefulWidget {
  const _Avatar({required this.background, required this.foreground, this.ring = false, super.key});

  final Color background;
  final Color foreground;
  final bool ring;

  @override
  State<_Avatar> createState() => _AvatarState();
}

class _AvatarState extends State<_Avatar> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 1),
  );

  @override
  void initState() {
    super.initState();
    _syncPulse();
  }

  @override
  void didUpdateWidget(_Avatar old) {
    super.didUpdateWidget(old);
    if (old.ring != widget.ring) _syncPulse();
  }

  // Idle: no ticking, zero repaints (CLAUDE.md animation budget).
  void _syncPulse() {
    if (widget.ring) {
      _pulse.repeat(reverse: true);
    } else {
      _pulse
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, child) => Container(
        width: AppDimensions.avatar,
        height: AppDimensions.avatar,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: widget.background,
          border: widget.ring
              ? Border.all(color: tokens.bot.withValues(alpha: 0.4 + 0.6 * _pulse.value), width: 3)
              : null,
        ),
        child: child,
      ),
      child: Icon(Icons.person, size: 22, color: widget.foreground),
    );
  }
}
