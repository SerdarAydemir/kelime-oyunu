// lib/core/constants/app_dimensions.dart

/// Spatial and size tokens for the Kelime Oyunu design system.
///
/// All values follow an 8-pt grid. Widgets must reference these constants
/// instead of raw numeric literals (architecture.md §9).
abstract final class AppDimensions {
  // ── Spacing scale (8-pt grid) ──────────────────────────────────────────
  static const double spacingXxs = 2.0;
  static const double spacingXs = 4.0;
  static const double spacingS = 8.0;
  static const double spacingM = 16.0;
  static const double spacingL = 24.0;
  static const double spacingXl = 32.0;
  static const double spacingXxl = 48.0;

  // ── Border radius ──────────────────────────────────────────────────────
  static const double radiusS = 4.0;
  static const double radiusM = 8.0;
  static const double radiusL = 16.0;
  static const double radiusXl = 24.0;

  /// Use for pill / chip shapes.
  static const double radiusFull = 999.0;

  // ── Grid ───────────────────────────────────────────────────────────────
  /// Minimum cell size on compact phones.
  static const double gridCellMin = 32.0;

  /// Maximum cell size on tablets / large phones.
  static const double gridCellMax = 48.0;

  /// Padding between cells.
  static const double gridCellGap = 2.0;

  // ── Icons ──────────────────────────────────────────────────────────────
  static const double iconS = 16.0;
  static const double iconM = 24.0;
  static const double iconL = 32.0;

  // ── Surfaces ───────────────────────────────────────────────────────────
  static const double appBarHeight = 56.0;
  static const double bottomSheetRadius = 24.0;
  static const double cardElevation = 2.0;

  // ── Hit targets ────────────────────────────────────────────────────────
  /// Minimum touch target per Material / Apple HIG guidelines.
  static const double minTapTarget = 48.0;
}
