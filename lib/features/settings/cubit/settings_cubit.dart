// lib/features/settings/cubit/settings_cubit.dart

import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:kelime_oyunu/data/models/app_settings.dart';
import 'package:kelime_oyunu/data/repositories/settings_repository.dart';

/// Owns the device preferences ([AppSettings]) for the whole app: the theme
/// mode feeds `MaterialApp.themeMode`, the toggles are persisted for the
/// settings screen. Every change is written through to the repository.
///
/// A Cubit, not a Bloc: no event stream to reason about (CLAUDE.md
/// "Durum yönetimi").
class SettingsCubit extends Cubit<AppSettings> {
  SettingsCubit({required SettingsRepository repository})
    : _repository = repository,
      super(repository.read());

  final SettingsRepository _repository;

  void setThemeMode(ThemeMode mode) => _update(state.copyWith(themeMode: mode));

  void setSoundEnabled(bool enabled) => _update(state.copyWith(soundEnabled: enabled));

  void setHapticsEnabled(bool enabled) => _update(state.copyWith(hapticsEnabled: enabled));

  void setSkyEnabled(bool enabled) => _update(state.copyWith(skyEnabled: enabled));

  void _update(AppSettings next) {
    if (next == state) return;
    emit(next);
    // Persist after emitting: the UI reacts immediately, the store catches up.
    // shared_preferences writes are async but ordered, so back-to-back
    // changes land in call order.
    _repository.write(next);
  }
}
