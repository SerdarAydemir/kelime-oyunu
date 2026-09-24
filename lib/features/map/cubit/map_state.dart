// lib/features/map/cubit/map_state.dart

import 'package:equatable/equatable.dart';

import 'package:kelime_oyunu/core/config/dev_flags.dart';
import 'package:kelime_oyunu/core/constants/game_constants.dart';

/// How one node on the climb map is drawn.
enum MapNodeKind {
  /// Won at least once — the 48 dp card, replayable.
  done,

  /// The frontier — "BURADASIN".
  current,

  /// The next two after the frontier — dashed lock circles.
  upcoming,

  /// Everything further — a faint dot in the fog.
  far,
}

/// What the climb map renders.
class MapState extends Equatable {
  const MapState({this.highestCompletedLevel = 0, this.unlockAll = kDevUnlockAll});

  /// Highest level ever won; 0 for a new player.
  final int highestCompletedLevel;

  /// QA override ([kDevUnlockAll]): every node opens and is numbered; nothing
  /// is written to progress and nodes keep their real look otherwise.
  final bool unlockAll;

  /// The frontier level (clamped at the last shipped level).
  int get currentLevel => (highestCompletedLevel + 1).clamp(1, kLastLevelId);

  int get altitudeMeters => highestCompletedLevel * kMetersPerLevel;

  MapNodeKind kindOf(int level) {
    if (level <= highestCompletedLevel) return MapNodeKind.done;
    if (level == currentLevel) return MapNodeKind.current;
    if (level <= currentLevel + 2) return MapNodeKind.upcoming;
    return MapNodeKind.far;
  }

  /// Whether [level] can be opened: any won level, the frontier — or, under
  /// the QA override, any shipped level.
  bool isPlayable(int level) {
    if (level < 1 || level > kLastLevelId) return false;
    if (unlockAll) return true;
    final kind = kindOf(level);
    return kind == MapNodeKind.done || kind == MapNodeKind.current;
  }

  @override
  List<Object?> get props => [highestCompletedLevel, unlockAll];
}
