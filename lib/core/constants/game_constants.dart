// lib/core/constants/game_constants.dart

// Gameplay-wide numeric constants.

/// The highest puzzle / level id that ships with the app.
///
/// Kept in sync with the 200/200 puzzle production; update this if the
/// generated puzzle count changes. Used as the denominator of the
/// "Bölüm X / N" progress label and to detect the final level.
const int kLastLevelId = 200;

/// Metres of altitude one won level is worth on the climb (README: "every
/// win is +40 m"). Altitude is derived, never stored.
const int kMetersPerLevel = 40;
