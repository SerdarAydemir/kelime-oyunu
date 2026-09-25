// lib/features/gameplay/widgets/game_menu_sheet.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:kelime_oyunu/core/constants/app_dimensions.dart';
import 'package:kelime_oyunu/core/constants/app_typography.dart';
import 'package:kelime_oyunu/core/theme/app_tokens.dart';
import 'package:kelime_oyunu/features/gameplay/widgets/sheet_shell.dart';
import 'package:kelime_oyunu/l10n/generated/app_localizations.dart';

/// The game header's ⋯ menu: Nasıl oynanır · Ayarlar · Haritaya dön (with a
/// confirmation — the half-played match is saved at its last turn boundary).
Future<void> showGameMenu(BuildContext context) {
  return showModalBottomSheet<void>(context: context, builder: (_) => const GameMenuSheet());
}

class GameMenuSheet extends StatelessWidget {
  const GameMenuSheet({super.key});

  Future<void> _leave(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final router = GoRouter.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.leaveGameTitle),
        content: Text(l10n.leaveGameBody),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.cancel)),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(l10n.backMap)),
        ],
      ),
    );
    if (confirmed != true) return;
    router.go('/map');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SheetShell(
      title: l10n.appName,
      children: [
        const SizedBox(height: AppDimensions.space12),
        _MenuRow(
          icon: Icons.help_outline,
          label: l10n.howToPlay,
          onTap: () {
            Navigator.of(context).pop();
            context.push('/onboarding');
          },
        ),
        _MenuRow(
          icon: Icons.settings_outlined,
          label: l10n.settings,
          onTap: () {
            Navigator.of(context).pop();
            context.push('/settings');
          },
        ),
        _MenuRow(icon: Icons.map_outlined, label: l10n.backMap, onTap: () => _leave(context)),
        const SizedBox(height: AppDimensions.space8),
      ],
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppDimensions.radiusBoard),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: AppDimensions.space8),
        child: Row(
          children: [
            Icon(icon, size: 22, color: tokens.sheetMuted),
            const SizedBox(width: AppDimensions.space12),
            Text(label, style: AppTypography.buttonSecondary.copyWith(color: tokens.sheetText)),
          ],
        ),
      ),
    );
  }
}
