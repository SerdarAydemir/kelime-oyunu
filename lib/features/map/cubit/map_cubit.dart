// lib/features/map/cubit/map_cubit.dart

import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:kelime_oyunu/core/config/dev_flags.dart';
import 'package:kelime_oyunu/data/repositories/progress_repository.dart';
import 'package:kelime_oyunu/features/map/cubit/map_state.dart';

/// Reads persisted progress for the climb map. A synchronous read — the box
/// is open before the first frame, so no loading state (and no flash on
/// every return from a match).
class MapCubit extends Cubit<MapState> {
  MapCubit({required this._progressRepo, bool unlockAll = kDevUnlockAll})
    : _unlockAll = unlockAll,
      super(MapState(unlockAll: unlockAll)) {
    refresh();
  }

  final ProgressRepository _progressRepo;

  // QA override (DEV_UNLOCK_ALL); injectable so tests cover both branches.
  final bool _unlockAll;

  void refresh() {
    emit(
      MapState(highestCompletedLevel: _progressRepo.highestCompletedLevel, unlockAll: _unlockAll),
    );
  }
}
