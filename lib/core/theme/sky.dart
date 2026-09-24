// lib/core/theme/sky.dart

import 'package:flutter/material.dart';
import 'package:kelime_oyunu/core/theme/app_tokens.dart';

/// The "Gökyüzü" rule (README "Interactions"): with the sky setting on, the
/// home and map gradients shift night → dawn → day as the player climbs;
/// off, they stay at the theme's fixed gradient.
///
/// [progress] is the climb fraction (won levels / total). Night is the
/// theme's own gradient, dawn is its `bgWon` and day is the light palette's
/// gradient — so a dark-theme player literally sees the sky brighten.
LinearGradient skyGradient({
  required AppTokens tokens,
  required LinearGradient night,
  required LinearGradient day,
  required double progress,
  required bool enabled,
}) {
  if (!enabled) return night;
  final t = progress.clamp(0.0, 1.0);
  final dawn = tokens.bgWon;
  // Exact endpoints: LinearGradient.lerp merges the stop lists even at t = 0
  // or 1, which would hand back an equivalent-but-not-equal gradient.
  if (t <= 0) return night;
  if (t == 0.5) return dawn;
  if (t >= 1) return day;
  return t < 0.5
      ? LinearGradient.lerp(night, dawn, t * 2)!
      : LinearGradient.lerp(dawn, day, (t - 0.5) * 2)!;
}

/// Home sky for [tokens] at [progress].
LinearGradient homeSky(AppTokens tokens, {required double progress, required bool enabled}) =>
    skyGradient(
      tokens: tokens,
      night: tokens.bgHome,
      day: AppTokens.light.bgHome,
      progress: progress,
      enabled: enabled,
    );

/// Map sky for [tokens] at [progress].
LinearGradient mapSky(AppTokens tokens, {required double progress, required bool enabled}) =>
    skyGradient(
      tokens: tokens,
      night: tokens.bgMap,
      day: AppTokens.light.bgMap,
      progress: progress,
      enabled: enabled,
    );
