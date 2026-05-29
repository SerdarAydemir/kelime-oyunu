// lib/core/constants/app_typography.dart
import 'package:flutter/material.dart';

/// Text style tokens for the Kelime Oyunu design system.
///
/// Font families match the assets declared in pubspec.yaml.
/// Until the TTF files are placed in assets/fonts/, Flutter falls back to
/// the system sans-serif — layout is unaffected.
abstract final class AppTypography {
  static const String _inter = 'Inter';
  static const String _nunito = 'Nunito';

  // ── Headlines (Nunito Bold) ─────────────────────────────────────────────
  static const TextStyle headline1 = TextStyle(
    fontFamily: _nunito,
    fontSize: 32,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.5,
  );

  static const TextStyle headline2 = TextStyle(
    fontFamily: _nunito,
    fontSize: 24,
    fontWeight: FontWeight.w700,
  );

  static const TextStyle title = TextStyle(
    fontFamily: _nunito,
    fontSize: 20,
    fontWeight: FontWeight.w700,
  );

  // ── Body copy (Inter Regular / Bold) ───────────────────────────────────
  static const TextStyle bodyLarge = TextStyle(
    fontFamily: _inter,
    fontSize: 16,
    fontWeight: FontWeight.w400,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontFamily: _inter,
    fontSize: 14,
    fontWeight: FontWeight.w400,
  );

  static const TextStyle bodySmall = TextStyle(
    fontFamily: _inter,
    fontSize: 12,
    fontWeight: FontWeight.w400,
  );

  static const TextStyle caption = TextStyle(
    fontFamily: _inter,
    fontSize: 11,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.4,
  );

  // ── Specialised ────────────────────────────────────────────────────────
  /// Letter rendered inside a word-search grid cell (CustomPainter).
  static const TextStyle gridLetter = TextStyle(
    fontFamily: _nunito,
    fontSize: 18,
    fontWeight: FontWeight.w700,
  );

  /// CTA button label.
  static const TextStyle button = TextStyle(
    fontFamily: _inter,
    fontSize: 14,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.5,
  );

  /// Coin / star count in the HUD.
  static const TextStyle hudCounter = TextStyle(
    fontFamily: _nunito,
    fontSize: 16,
    fontWeight: FontWeight.w700,
  );
}
