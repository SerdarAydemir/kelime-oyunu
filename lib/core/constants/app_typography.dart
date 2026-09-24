// lib/core/constants/app_typography.dart

import 'package:flutter/material.dart';

/// Type scale of the Kelime Zirvesi design system — `TYPE` in
/// `docs/design/kz-tokens.js` (single source of truth), plus the body styles
/// the screen specs in `docs/design/README.md` reference.
///
/// Lora (serif) carries titles, scores, level numbers and letters; Nunito Sans
/// carries everything else. Both are bundled from `assets/fonts/` — no
/// network font loading in an offline game.
abstract final class AppTypography {
  static const String lora = 'Lora';
  static const String nunitoSans = 'Nunito Sans';

  // ── Lora ───────────────────────────────────────────────────────────────

  /// Display — ana ekran adı, iki satır (62 / 700, line-height 0.95, ls −1).
  static const TextStyle display = TextStyle(
    fontFamily: lora,
    fontSize: 62,
    fontWeight: FontWeight.w700,
    height: 0.95,
    letterSpacing: -1,
  );

  /// Sonuç başlığı (40 / 700; 48 tek satır, 40 iki satır).
  static const TextStyle resultTitle = TextStyle(
    fontFamily: lora,
    fontSize: 40,
    fontWeight: FontWeight.w700,
    height: 1.05,
  );

  /// Ekran başlığı, skor, bölüm numarası (22 / 700).
  static const TextStyle screenTitle = TextStyle(
    fontFamily: lora,
    fontSize: 22,
    fontWeight: FontWeight.w700,
  );

  /// Harita düğüm numarası, liste vurgusu (15 / 600).
  static const TextStyle nodeNumber = TextStyle(
    fontFamily: lora,
    fontSize: 15,
    fontWeight: FontWeight.w600,
  );

  /// Letter committed on the board — Lora 22 (TYPE: "22 hücre").
  static const TextStyle cellLetter = TextStyle(
    fontFamily: lora,
    fontSize: 22,
    fontWeight: FontWeight.w700,
  );

  /// Letter on a rack tile — Lora 26 (TYPE: "26 taş").
  static const TextStyle tileLetter = TextStyle(
    fontFamily: lora,
    fontSize: 26,
    fontWeight: FontWeight.w700,
  );

  // ── Nunito Sans ────────────────────────────────────────────────────────

  /// Birincil buton (18 / 800).
  static const TextStyle buttonPrimary = TextStyle(
    fontFamily: nunitoSans,
    fontSize: 18,
    fontWeight: FontWeight.w800,
  );

  /// İkincil buton, liste satırı (15 / 700).
  static const TextStyle buttonSecondary = TextStyle(
    fontFamily: nunitoSans,
    fontSize: 15,
    fontWeight: FontWeight.w700,
  );

  /// Pill metni, alt bilgi (13 / 600).
  static const TextStyle pill = TextStyle(
    fontFamily: nunitoSans,
    fontSize: 13,
    fontWeight: FontWeight.w600,
  );

  /// İkincil açıklama, etiket (12 / 600).
  static const TextStyle label = TextStyle(
    fontFamily: nunitoSans,
    fontSize: 12,
    fontWeight: FontWeight.w600,
  );

  /// Büyük harf etiket (11 / 600, letter-spacing 3 px).
  static const TextStyle overline = TextStyle(
    fontFamily: nunitoSans,
    fontSize: 11,
    fontWeight: FontWeight.w600,
    letterSpacing: 3,
  );

  /// Body copy (README: Nunito 400 15 / 1.55).
  static const TextStyle body = TextStyle(
    fontFamily: nunitoSans,
    fontSize: 15,
    fontWeight: FontWeight.w400,
    height: 1.55,
  );

  /// Secondary body / row subtitle (README: Nunito 500 12).
  static const TextStyle bodySmall = TextStyle(
    fontFamily: nunitoSans,
    fontSize: 12,
    fontWeight: FontWeight.w500,
  );

  /// Clue text inside a cell (Nunito 600; size is auto-fitted by the
  /// renderer, so no fontSize here).
  static const TextStyle clue = TextStyle(fontFamily: nunitoSans, fontWeight: FontWeight.w600);
}
