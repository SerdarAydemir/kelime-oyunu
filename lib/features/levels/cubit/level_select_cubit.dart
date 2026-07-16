// lib/features/levels/cubit/level_select_cubit.dart

import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:kelime_oyunu/data/repositories/progress_repository.dart';
import 'package:kelime_oyunu/data/repositories/session_repository.dart';
import 'package:kelime_oyunu/features/levels/cubit/level_select_state.dart';

/// Reads persisted progress and the resumable match for the level grid.
///
/// A Cubit, not a Bloc: there is no event flow here, just "read what is on
/// disk" (CLAUDE.md §Durum yönetimi — Bloc is for gameplay only).
class LevelSelectCubit extends Cubit<LevelSelectState> {
  // Private field formals (as in GameBloc): call sites still write
  // `progressRepo:`, while the fields stay private to this cubit.
  LevelSelectCubit({required this._progressRepo, required this._sessionRepo})
    : super(const LevelSelectState()) {
    refresh();
  }

  final ProgressRepository _progressRepo;
  final SessionRepository _sessionRepo;

  /// Re-reads storage. Both repositories are already open, so this is a
  /// synchronous read — no loading state is needed or wanted (the grid would
  /// flash on every return from a match).
  void refresh() {
    emit(
      LevelSelectState(
        highestCompletedLevel: _progressRepo.highestCompletedLevel,
        resume: _sessionRepo.summary,
      ),
    );
  }
}
