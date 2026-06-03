// lib/features/gameplay/widgets/score_header.dart

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:kelime_oyunu/core/constants/app_colors.dart';

class ScoreHeader extends StatelessWidget {
  const ScoreHeader({
    required this.playerScore,
    required this.botScore,
    required this.botName,
    required this.botThinking,
    super.key,
  });

  final int playerScore;
  final int botScore;
  final String botName;
  final bool botThinking;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _ScorePill(label: 'Sen $playerScore'),
          const Text(
            'VS',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$botScore $botName',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(width: 8),
              const _BotAvatar(),
              if (botThinking) ...[
                const SizedBox(width: 4),
                const _AnimatedDots(),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _ScorePill extends StatelessWidget {
  const _ScorePill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.success,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      ),
    );
  }
}

class _BotAvatar extends StatelessWidget {
  const _BotAvatar();

  @override
  Widget build(BuildContext context) {
    return const CircleAvatar(
      radius: 16,
      backgroundColor: AppColors.primary,
      child: Icon(Icons.smart_toy, size: 16, color: Colors.white),
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
    return Text(
      '.' * _dotCount,
      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
    );
  }
}
