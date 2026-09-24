// lib/features/gameplay/widgets/score_header.dart

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:kelime_oyunu/core/constants/app_typography.dart';
import 'package:kelime_oyunu/core/theme/app_tokens.dart';
import 'package:kelime_oyunu/l10n/generated/app_localizations.dart';

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

  /// Anchors the player's score-badge target to the "Sen" pill: each score
  /// badge flies here and the counter ticks as it arrives.
  final GlobalKey? playerScoreKey;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      // Both sides get equal flex so the fixed middle child ("VS") sits at the
      // true screen centre regardless of how wide either score block is.
      child: Row(
        children: [
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: _ScorePill(key: playerScoreKey, label: '${l10n.you} $playerScore'),
            ),
          ),
          Text(l10n.vs, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          Expanded(
            child: Align(
              alignment: Alignment.centerRight,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('$botScore $botName', style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(width: 8),
                  _BotAvatar(key: avatarKey),
                  if (botThinking) ...[const SizedBox(width: 4), const _AnimatedDots()],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScorePill extends StatelessWidget {
  const _ScorePill({required this.label, super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: tokens.accent, borderRadius: BorderRadius.circular(20)),
      child: Text(label, style: AppTypography.pill.copyWith(color: tokens.accentInk)),
    );
  }
}

class _BotAvatar extends StatelessWidget {
  const _BotAvatar({super.key});

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return CircleAvatar(
      radius: 16,
      backgroundColor: tokens.bot,
      child: Icon(Icons.smart_toy, size: 16, color: tokens.botInk),
    );
  }
}

class _AnimatedDots extends StatefulWidget {
  const _AnimatedDots();

  @override
  State<_AnimatedDots> createState() => _AnimatedDotsState();
}

class _AnimatedDotsState extends State<_AnimatedDots> {
  late Timer _timer;
  int _dotCount = 1;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      setState(() => _dotCount = _dotCount % 3 + 1);
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Text('.' * _dotCount, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold));
  }
}
