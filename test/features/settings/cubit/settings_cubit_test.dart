// test/features/settings/cubit/settings_cubit_test.dart

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_test/flutter_test.dart';

import 'package:kelime_oyunu/data/models/app_settings.dart';
import 'package:kelime_oyunu/data/repositories/settings_repository.dart';
import 'package:kelime_oyunu/features/settings/cubit/settings_cubit.dart';

void main() {
  test('starts from the stored settings, defaulting to system theme', () {
    final fresh = SettingsCubit(repository: InMemorySettingsRepository());
    expect(fresh.state, AppSettings.defaults);
    expect(fresh.state.themeMode, ThemeMode.system);
    expect(fresh.state.soundEnabled, isTrue);
    expect(fresh.state.hapticsEnabled, isTrue);
    expect(fresh.state.skyEnabled, isTrue);

    final stored = SettingsCubit(
      repository: InMemorySettingsRepository(
        initial: const AppSettings(themeMode: ThemeMode.dark, soundEnabled: false),
      ),
    );
    expect(stored.state.themeMode, ThemeMode.dark);
    expect(stored.state.soundEnabled, isFalse);
  });

  group('changes are emitted and persisted', () {
    late InMemorySettingsRepository repo;

    setUp(() => repo = InMemorySettingsRepository());

    blocTest<SettingsCubit, AppSettings>(
      'setThemeMode',
      build: () => SettingsCubit(repository: repo),
      act: (cubit) => cubit.setThemeMode(ThemeMode.light),
      expect: () => [const AppSettings(themeMode: ThemeMode.light)],
      verify: (_) => expect(repo.read().themeMode, ThemeMode.light),
    );

    blocTest<SettingsCubit, AppSettings>(
      'toggles',
      build: () => SettingsCubit(repository: repo),
      act: (cubit) => cubit
        ..setSoundEnabled(false)
        ..setHapticsEnabled(false)
        ..setSkyEnabled(false),
      expect: () => [
        const AppSettings(soundEnabled: false),
        const AppSettings(soundEnabled: false, hapticsEnabled: false),
        const AppSettings(soundEnabled: false, hapticsEnabled: false, skyEnabled: false),
      ],
      verify: (_) => expect(repo.writes.length, 3),
    );

    blocTest<SettingsCubit, AppSettings>(
      'a no-op change neither emits nor writes',
      build: () => SettingsCubit(repository: repo),
      act: (cubit) => cubit
        ..setThemeMode(ThemeMode.system)
        ..setSoundEnabled(true),
      expect: () => const <AppSettings>[],
      verify: (_) => expect(repo.writes, isEmpty),
    );
  });
}
