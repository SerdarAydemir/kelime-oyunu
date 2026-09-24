// lib/core/constants/app_dimensions.dart

/// Spatial tokens of the Kelime Zirvesi design system — `RADII`, `SPACE`,
/// `BUTTONS` and `LAYOUT` in `docs/design/kz-tokens.js` (single source of
/// truth). Widgets reference these instead of raw numbers (architecture.md §9).
abstract final class AppDimensions {
  // ── SPACE ──────────────────────────────────────────────────────────────
  static const double space2 = 2.0;
  static const double space4 = 4.0;
  static const double space6 = 6.0;
  static const double space8 = 8.0;
  static const double space10 = 10.0;
  static const double space12 = 12.0;
  static const double space16 = 16.0;
  static const double space18 = 18.0;
  static const double space20 = 20.0;
  static const double space24 = 24.0;
  static const double space32 = 32.0;
  static const double space40 = 40.0;

  // ── RADII ──────────────────────────────────────────────────────────────
  /// Hücre.
  static const double radiusCell = 6.0;

  /// Taş, ikon kutusu.
  static const double radiusTile = 10.0;

  /// Tahta.
  static const double radiusBoard = 16.0;

  /// Liste kartı.
  static const double radiusListCard = 18.0;

  /// Skor kartı, sheet kartı.
  static const double radiusScoreCard = 20.0;

  /// Alt sayfa (sheet) üst köşeleri (README "Clue sheet": r28).
  static const double radiusSheet = 28.0;

  /// Pill / buton / avatar.
  static const double radiusPill = 999.0;

  // ── BUTTONS (heights) ──────────────────────────────────────────────────
  /// Birincil (CTA).
  static const double buttonPrimary = 56.0;

  /// Oyun alt barı, sheet kapat.
  static const double buttonGame = 52.0;

  /// İkincil / çerçeveli.
  static const double buttonSecondary = 48.0;

  // ── LAYOUT ─────────────────────────────────────────────────────────────
  /// Board cell range: 49–56 dp (50 dp on a 390 dp screen), gap 2 dp.
  static const double gridCellMin = 49.0;
  static const double gridCellMax = 56.0;
  static const double gridCellGap = 2.0;

  /// Board inner padding.
  static const double boardPadding = 6.0;

  /// Rack tile: 52 × 56 dp.
  static const double tileWidth = 52.0;
  static const double tileHeight = 56.0;

  /// Circular icon button (back arrow etc.) and the avatar circle.
  static const double iconButton = 40.0;
  static const double avatar = 38.0;

  // ── Icons ──────────────────────────────────────────────────────────────
  static const double iconS = 16.0;
  static const double iconM = 24.0;
  static const double iconL = 32.0;

  // ── Hit targets ────────────────────────────────────────────────────────
  /// Minimum touch target per Material / Apple HIG guidelines.
  static const double minTapTarget = 48.0;
}
