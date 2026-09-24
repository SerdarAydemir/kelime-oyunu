// lib/data/repositories/settings_repository.dart

import 'package:flutter/material.dart' show ThemeMode;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:kelime_oyunu/data/models/app_settings.dart';

/// Persists [AppSettings]. Plain scalar preferences — no secrets, no
/// progression — so they live in `shared_preferences`, not the encrypted
/// Hive boxes (architecture.md §5).
abstract class SettingsRepository {
  /// The stored settings; [AppSettings.defaults] for anything never written.
  AppSettings read();

  Future<void> write(AppSettings settings);
}

/// `shared_preferences`-backed store. Reads are synchronous (the instance is
/// obtained by `main()` before the first frame), writes are fire-and-forget.
class SharedPrefsSettingsRepository implements SettingsRepository {
  SharedPrefsSettingsRepository(this._prefs);

  final SharedPreferences _prefs;

  static const String themeModeKey = 'settings.theme_mode';
  static const String soundKey = 'settings.sound';
  static const String hapticsKey = 'settings.haptics';
  static const String skyKey = 'settings.sky';

  @override
  AppSettings read() => AppSettings(
    themeMode: _themeModeFrom(_prefs.getString(themeModeKey)),
    soundEnabled: _prefs.getBool(soundKey) ?? AppSettings.defaults.soundEnabled,
    hapticsEnabled: _prefs.getBool(hapticsKey) ?? AppSettings.defaults.hapticsEnabled,
    skyEnabled: _prefs.getBool(skyKey) ?? AppSettings.defaults.skyEnabled,
  );

  @override
  Future<void> write(AppSettings settings) async {
    await Future.wait([
      _prefs.setString(themeModeKey, settings.themeMode.name),
      _prefs.setBool(soundKey, settings.soundEnabled),
      _prefs.setBool(hapticsKey, settings.hapticsEnabled),
      _prefs.setBool(skyKey, settings.skyEnabled),
    ]);
  }

  // Stored by enum name; an unknown or missing value falls back on the
  // default so a renamed constant can never brick the app at start-up.
  static ThemeMode _themeModeFrom(String? raw) =>
      ThemeMode.values.where((m) => m.name == raw).firstOrNull ?? AppSettings.defaults.themeMode;
}

/// Volatile store for tests and previews.
class InMemorySettingsRepository implements SettingsRepository {
  InMemorySettingsRepository({AppSettings initial = AppSettings.defaults}) : _settings = initial;

  AppSettings _settings;

  /// Every value handed to [write], oldest first — lets a test assert that a
  /// change reached the store.
  final List<AppSettings> writes = [];

  @override
  AppSettings read() => _settings;

  @override
  Future<void> write(AppSettings settings) async {
    _settings = settings;
    writes.add(settings);
  }
}
