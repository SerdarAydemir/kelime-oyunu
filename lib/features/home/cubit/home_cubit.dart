// lib/features/home/cubit/home_cubit.dart

import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:kelime_oyunu/data/repositories/progress_repository.dart';
import 'package:kelime_oyunu/data/repositories/session_repository.dart';
import 'package:kelime_oyunu/features/home/cubit/home_state.dart';

/// Reads progress and the resumable match for the home screen. Both
/// repositories are open before the first frame, so the read is synchronous
/// and there is no loading state.
class HomeCubit extends Cubit<HomeState> {
  // Private field formals (as in LevelSelectCubit): call sites still write
  // `progressRepo:`, while the fields stay private to this cubit.
  HomeCubit({required this._progressRepo, required this._sessionRepo}) : super(const HomeState()) {
    refresh();
  }

  final ProgressRepository _progressRepo;
  final SessionRepository _sessionRepo;

  void refresh() {
    emit(
      HomeState(
        nextLevel: _progressRepo.nextLevelId,
        altitudeMeters: _progressRepo.altitudeMeters,
        dailyStreak: _progressRepo.dailyStreak,
        wordsFound: _progressRepo.wordsFound,
        resume: _sessionRepo.summary,
      ),
    );
  }
}
