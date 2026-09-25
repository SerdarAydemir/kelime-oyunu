// test/data/repositories/settings_repository_test.dart

import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:kelime_oyunu/data/models/app_settings.dart';
import 'package:kelime_oyunu/data/repositories/settings_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('reads defaults from an empty store', () async {
    SharedPreferences.setMockInitialValues({});
    final repo = SharedPrefsSettingsRepository(await SharedPreferences.getInstance());
    expect(repo.read(), AppSettings.defaults);
  });

  test('round-trips every field', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final repo = SharedPrefsSettingsRepository(prefs);
    const settings = AppSettings(
      themeMode: ThemeMode.dark,
      soundEnabled: false,
      hapticsEnabled: true,
      skyEnabled: false,
      consentDone: true,
      attAsked: true,
      onboardingDone: true,
    );

    await repo.write(settings);

    expect(repo.read(), settings);
    expect(prefs.getString(SharedPrefsSettingsRepository.themeModeKey), 'dark');
    // A fresh repository over the same store sees the same values.
    expect(SharedPrefsSettingsRepository(await SharedPreferences.getInstance()).read(), settings);
  });

  test('an unknown theme-mode string falls back on the default', () async {
    SharedPreferences.setMockInitialValues({
      SharedPrefsSettingsRepository.themeModeKey: 'sepia',
      SharedPrefsSettingsRepository.soundKey: false,
    });
    final repo = SharedPrefsSettingsRepository(await SharedPreferences.getInstance());
    expect(repo.read().themeMode, ThemeMode.system);
    expect(repo.read().soundEnabled, isFalse);
  });
}
