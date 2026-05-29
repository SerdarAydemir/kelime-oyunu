// lib/core/constants/app_colors.dart
import 'package:flutter/material.dart';

/// Centralised colour tokens for the Kelime Oyunu design system.
///
/// Raw `Color(0xFF...)` literals are forbidden everywhere else in the codebase.
/// Use `AppColors.x` for static/const access or
/// `Theme.of(context).colorScheme.x` in widget builds where dynamic theme
/// switching matters (architecture.md §9, CLAUDE.md §Dart Kod Stili).
abstract final class AppColors {
  // ── Brand ─────────────────────────────────────────────────────────────────
  static const Color primary = Color(0xFF1565C0);
  static const Color primaryDark = Color(0xFF0D47A1);
  static const Color accent = Color(0xFFFFA000);

  // ── Semantic feedback ──────────────────────────────────────────────────────
  static const Color success = Color(0xFF2E7D32);
  static const Color error = Color(0xFFC62828);
  static const Color warning = Color(0xFFF9A825);

  // ── Grid cell states ───────────────────────────────────────────────────────
  static const Color gridCellNormal = Color(0xFFFAFAFA);
  static const Color gridCellSelected = Color(0xFFFFE082);
  static const Color gridCellFound = Color(0xFFA5D6A7);
  static const Color gridCellLocked = Color(0xFFB0BEC5);

  // ── Economy ────────────────────────────────────────────────────────────────
  static const Color coinGold = Color(0xFFFFC107);
  static const Color star = Color(0xFFFFB300);
}
