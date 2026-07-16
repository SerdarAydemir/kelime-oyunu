// lib/features/levels/cubit/level_select_state.dart

import 'package:equatable/equatable.dart';

import 'package:kelime_oyunu/core/constants/game_constants.dart';
import 'package:kelime_oyunu/data/models/saved_session.dart';

/// How one level should be drawn on the level-select grid.
enum LevelStatus {
  /// Won at least once — replayable.
  completed,

  /// The frontier: unlocked but not yet won. Highlighted as "play this".
  current,

  /// Not reached yet — not playable.
  locked,
}

/// What the level-select screen renders.
class LevelSelectState extends Equatable {
  const LevelSelectState({this.highestCompletedLevel = 0, this.resume});

  /// Highest level ever won; 0 for a new player.
  final int highestCompletedLevel;

  /// The half-played match on offer as "Devam Et", or null if there is none.
  final ResumeSummary? resume;

  /// Total levels shipped — the grid's item count.
  int get levelCount => kLastLevelId;

  /// The frontier level: the first one not yet won (clamped at the last level).
  int get currentLevel => (highestCompletedLevel + 1).clamp(1, kLastLevelId);

  /// Whether every shipped level has been won.
  bool get allCompleted => highestCompletedLevel >= kLastLevelId;

  /// How [levelId] should be drawn.
  LevelStatus statusOf(int levelId) {
    if (levelId <= highestCompletedLevel) return LevelStatus.completed;
    if (levelId == currentLevel && !allCompleted) return LevelStatus.current;
    return LevelStatus.locked;
  }

  /// Whether [levelId] can be opened: any won level, plus the frontier.
  bool isPlayable(int levelId) => statusOf(levelId) != LevelStatus.locked;

  @override
  List<Object?> get props => [highestCompletedLevel, resume];
}
