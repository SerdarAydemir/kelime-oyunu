// lib/features/gameplay/widgets/offline_toast.dart

import 'package:flutter/material.dart';
import 'package:kelime_oyunu/core/constants/app_dimensions.dart';
import 'package:kelime_oyunu/core/constants/app_typography.dart';
import 'package:kelime_oyunu/core/theme/app_tokens.dart';
import 'package:kelime_oyunu/l10n/generated/app_localizations.dart';

/// "Bağlantı yok · reklam yüklenemedi" toast (README "Bağlantı yok"): `solid`
/// background, r14, red wifi-off icon, 600 12 text and an amber 800 12
/// "Tekrar dene" action. Floats above the rack. Gameplay is unaffected —
/// only the ad-paid action did not happen.
void showOfflineToast(BuildContext context, {required VoidCallback onRetry}) {
  final tokens = context.tokens;
  final l10n = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: tokens.solid,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        // Clears the rack + bottom bar so the toast sits above them.
        margin: const EdgeInsets.fromLTRB(
          AppDimensions.space16,
          0,
          AppDimensions.space16,
          AppDimensions.space16 + AppDimensions.tileHeight + AppDimensions.buttonGame + 40,
        ),
        duration: const Duration(seconds: 4),
        content: Row(
          children: [
            Icon(Icons.wifi_off, size: 18, color: tokens.error),
            const SizedBox(width: AppDimensions.space10),
            Expanded(
              child: Text(
                l10n.offline,
                style: AppTypography.label.copyWith(color: tokens.solidText),
              ),
            ),
            TextButton(
              onPressed: () {
                messenger.hideCurrentSnackBar();
                onRetry();
              },
              style: TextButton.styleFrom(
                foregroundColor: tokens.accent,
                textStyle: AppTypography.label.copyWith(fontWeight: FontWeight.w800),
                minimumSize: Size.zero,
                padding: const EdgeInsets.symmetric(horizontal: AppDimensions.space8),
              ),
              child: Text(l10n.retry),
            ),
          ],
        ),
      ),
    );
}
