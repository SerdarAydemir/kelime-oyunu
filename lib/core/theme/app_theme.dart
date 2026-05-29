// lib/core/theme/app_theme.dart
import 'package:flutter/material.dart';
import 'package:kelime_oyunu/core/constants/app_colors.dart';
import 'package:kelime_oyunu/core/constants/app_typography.dart';

/// Provides light and dark [ThemeData] instances for the app.
///
/// All colour references resolve to [AppColors] tokens; raw `Color(0xFF...)`
/// literals are forbidden here (architecture.md §9, CLAUDE.md).
abstract final class AppTheme {
  // Maps AppTypography tokens onto the Material 3 TextTheme roles.
  static const TextTheme _baseTextTheme = TextTheme(
    headlineLarge: AppTypography.headline1,
    headlineMedium: AppTypography.headline2,
    headlineSmall: AppTypography.title,
    titleLarge: AppTypography.title,
    bodyLarge: AppTypography.bodyLarge,
    bodyMedium: AppTypography.bodyMedium,
    bodySmall: AppTypography.bodySmall,
    labelLarge: AppTypography.button,
    labelSmall: AppTypography.caption,
  );

  /// Light theme — primary blue seed, white surfaces.
  static ThemeData light() {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        brightness: Brightness.light,
        error: AppColors.error,
      ),
      textTheme: _baseTextTheme,
      scaffoldBackgroundColor: Colors.white,
    );
  }

  /// Dark theme — same seed, dark surfaces.
  static ThemeData dark() {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        brightness: Brightness.dark,
        error: AppColors.error,
      ),
      textTheme: _baseTextTheme,
    );
  }
}
