// lib/data/models/app_settings.dart

import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart' show ThemeMode;

/// The player's device-level preferences (design README "State Management":
/// theme mode, sound, haptics, sky — all persisted).
///
/// Only the theme mode drives behaviour today; the three toggles are stored
/// so the settings screen can round-trip them before audio / haptics / the
/// progress-driven sky are wired up.
class AppSettings extends Equatable {
  const AppSettings({
    this.themeMode = ThemeMode.system,
    this.soundEnabled = true,
    this.hapticsEnabled = true,
    this.skyEnabled = true,
  });

  /// "Görünüm": Açık / Koyu / Sistem — default Sistem.
  final ThemeMode themeMode;

  /// "Ses": letter and score sounds.
  final bool soundEnabled;

  /// "Titreşim": light tap when a letter lands.
  final bool hapticsEnabled;

  /// "Gökyüzü": home / map gradient shifts with progress.
  final bool skyEnabled;

  static const AppSettings defaults = AppSettings();

  AppSettings copyWith({
    ThemeMode? themeMode,
    bool? soundEnabled,
    bool? hapticsEnabled,
    bool? skyEnabled,
  }) => AppSettings(
    themeMode: themeMode ?? this.themeMode,
    soundEnabled: soundEnabled ?? this.soundEnabled,
    hapticsEnabled: hapticsEnabled ?? this.hapticsEnabled,
    skyEnabled: skyEnabled ?? this.skyEnabled,
  );

  @override
  List<Object?> get props => [themeMode, soundEnabled, hapticsEnabled, skyEnabled];
}
