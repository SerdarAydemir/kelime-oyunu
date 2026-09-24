// lib/core/theme/app_theme.dart

import 'package:flutter/material.dart';
import 'package:kelime_oyunu/core/constants/app_dimensions.dart';
import 'package:kelime_oyunu/core/constants/app_typography.dart';
import 'package:kelime_oyunu/core/theme/app_tokens.dart';

/// Builds the light and dark [ThemeData] from the design tokens.
///
/// Every colour comes from [AppTokens] (attached as a [ThemeExtension] so
/// widgets read it via `context.tokens`); the Material [ColorScheme] is only
/// derived from it so stock widgets (dialogs, buttons, sheets) blend in.
abstract final class AppTheme {
  static ThemeData light() => _build(AppTokens.light, Brightness.light);

  static ThemeData dark() => _build(AppTokens.dark, Brightness.dark);

  static ThemeData _build(AppTokens t, Brightness brightness) {
    final scheme = ColorScheme(
      brightness: brightness,
      primary: t.accent,
      onPrimary: t.accentInk,
      secondary: t.bot,
      onSecondary: t.botInk,
      tertiary: t.arrow,
      onTertiary: t.solidText,
      error: t.error,
      onError: t.solidText,
      surface: t.bgFlat,
      onSurface: t.text,
      surfaceContainerHighest: t.surface,
      onSurfaceVariant: t.muted,
      outline: t.border,
      outlineVariant: t.faint,
      inverseSurface: t.solid,
      onInverseSurface: t.solidText,
      shadow: t.boardShadow.color,
      scrim: t.dim,
    );
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      extensions: [t],
      fontFamily: AppTypography.nunitoSans,
      textTheme: _textTheme(t.text),
      scaffoldBackgroundColor: t.bgFlat,
      appBarTheme: AppBarTheme(
        backgroundColor: t.bgFlat,
        foregroundColor: t.text,
        centerTitle: true,
        titleTextStyle: AppTypography.screenTitle.copyWith(color: t.text),
      ),
      iconTheme: IconThemeData(color: t.text),
      dividerColor: t.border,
      dialogTheme: DialogThemeData(
        backgroundColor: t.sheet,
        titleTextStyle: AppTypography.screenTitle.copyWith(color: t.sheetText),
        contentTextStyle: AppTypography.body.copyWith(color: t.sheetMuted),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(AppDimensions.radiusScoreCard)),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: t.sheet,
        modalBackgroundColor: t.sheet,
        modalBarrierColor: t.dim,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppDimensions.radiusSheet)),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: t.accent,
          foregroundColor: t.accentInk,
          textStyle: AppTypography.buttonSecondary,
          minimumSize: const Size(0, AppDimensions.buttonSecondary),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: t.arrow,
          textStyle: AppTypography.buttonSecondary,
          minimumSize: const Size(0, AppDimensions.buttonSecondary),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: t.text,
          side: BorderSide(color: t.border),
          textStyle: AppTypography.buttonSecondary,
          minimumSize: const Size(0, AppDimensions.buttonSecondary),
        ),
      ),
    );
  }

  /// Maps the design type scale onto the Material roles so stock widgets
  /// (AppBar, dialogs, ListTile) pick up Lora / Nunito Sans automatically.
  static TextTheme _textTheme(Color ink) => const TextTheme(
    displayLarge: AppTypography.display,
    headlineLarge: AppTypography.resultTitle,
    headlineMedium: AppTypography.screenTitle,
    titleLarge: AppTypography.screenTitle,
    titleMedium: AppTypography.buttonSecondary,
    titleSmall: AppTypography.nodeNumber,
    bodyLarge: AppTypography.body,
    bodyMedium: AppTypography.body,
    bodySmall: AppTypography.bodySmall,
    labelLarge: AppTypography.buttonSecondary,
    labelMedium: AppTypography.pill,
    labelSmall: AppTypography.overline,
  ).apply(bodyColor: ink, displayColor: ink);
}
