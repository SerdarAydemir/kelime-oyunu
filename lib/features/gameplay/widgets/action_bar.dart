// lib/features/gameplay/widgets/action_bar.dart

import 'package:flutter/material.dart';
import 'package:kelime_oyunu/core/constants/app_colors.dart';
import 'package:kelime_oyunu/features/gameplay/engine/score_engine.dart';

class ActionBar extends StatelessWidget {
  const ActionBar({
    required this.pendingPlacements,
    required this.onConfirm,
    required this.onPass,
    required this.onSwap,
    required this.onReveal,
    super.key,
  });

  final List<Placement> pendingPlacements;
  final VoidCallback onConfirm;
  final VoidCallback onPass;
  final VoidCallback? onSwap;
  final VoidCallback? onReveal;

  @override
  Widget build(BuildContext context) {
    final hasPending = pendingPlacements.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          _CircleIconButton(
            icon: Icons.swap_horiz,
            onTap: hasPending ? null : onSwap,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _ConfirmPassButton(
              hasPending: hasPending,
              onConfirm: onConfirm,
              onPass: onPass,
            ),
          ),
          const SizedBox(width: 8),
          _RevealButton(onReveal: onReveal),
        ],
      ),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({
    required this.icon,
    required this.onTap,
  });

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isDisabled = onTap == null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          // TODO: add AppColors.circleButtonActiveBg token (0xFFE3F2FD)
          color: isDisabled ? AppColors.gridCellLocked : const Color(0xFFE3F2FD),
          border: Border.all(
            color: isDisabled ? AppColors.gridCellLocked : AppColors.primary,
            width: 1.5,
          ),
        ),
        child: Icon(
          icon,
          color: isDisabled ? Colors.grey : AppColors.primary,
          size: 22,
        ),
      ),
    );
  }
}

class _ConfirmPassButton extends StatelessWidget {
  const _ConfirmPassButton({
    required this.hasPending,
    required this.onConfirm,
    required this.onPass,
  });

  final bool hasPending;
  final VoidCallback onConfirm;
  final VoidCallback onPass;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ElevatedButton(
        onPressed: hasPending ? onConfirm : onPass,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.success,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          elevation: 2,
        ),
        child: Text(
          hasPending ? 'Onayla' : 'Pas',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
    );
  }
}

class _RevealButton extends StatelessWidget {
  const _RevealButton({required this.onReveal});

  final VoidCallback? onReveal;

  @override
  Widget build(BuildContext context) {
    final isDisabled = onReveal == null;
    return InkWell(
      onTap: onReveal,
      borderRadius: BorderRadius.circular(24),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              // TODO: add AppColors.revealActiveBg token (0xFFFFF8E1)
              color: isDisabled ? AppColors.gridCellLocked : const Color(0xFFFFF8E1),
              border: Border.all(
                color: isDisabled ? AppColors.gridCellLocked : AppColors.accent,
                width: 1.5,
              ),
            ),
            child: Icon(
              Icons.lightbulb_outline,
              color: isDisabled ? Colors.grey : AppColors.accent,
              size: 22,
            ),
          ),
          Positioned(
            top: -4,
            right: -4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.accent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Ad',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
