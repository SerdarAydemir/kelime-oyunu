// lib/features/gameplay/widgets/ad_label.dart

import 'package:flutter/material.dart';
import 'package:kelime_oyunu/core/constants/app_typography.dart';
import 'package:kelime_oyunu/core/theme/app_tokens.dart';
import 'package:kelime_oyunu/l10n/generated/app_localizations.dart';

/// The tiny "▶ reklam" sub-label under an ad-gated control (README "Global
/// rules": 7 px, 65 % opacity). Callers hide it in levels 1–3 by not
/// building it — see [showAdLabelsFor].
class AdLabel extends StatelessWidget {
  const AdLabel({this.color, super.key});

  /// Text colour; defaults to the theme's primary text.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final ink = (color ?? context.tokens.text).withValues(alpha: 0.65);
    // scaleDown: inside a 52 dp circle a wide fallback face could otherwise
    // overflow by a pixel or two; the real Nunito Sans never needs it.
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.play_arrow, size: 7, color: ink),
          const SizedBox(width: 1),
          Text(
            AppLocalizations.of(context).ad,
            textScaler: TextScaler.noScaling,
            style: AppTypography.label.copyWith(fontSize: 7, height: 1, color: ink),
          ),
        ],
      ),
    );
  }
}

/// Levels 1–3 carry no ads at all (CLAUDE.md "Monetizasyon"), so their ad
/// labels stay hidden: `showAdLabels && level > 3`.
bool showAdLabelsFor(int levelId) => levelId > 3;
