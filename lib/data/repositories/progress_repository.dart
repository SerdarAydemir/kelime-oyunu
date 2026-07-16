// lib/data/repositories/progress_repository.dart

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

import 'package:kelime_oyunu/core/constants/game_constants.dart';

/// Persistent level progression (architecture.md §11.1, `progress` box).
///
/// The progression rule is strictly linear — only a win advances the player —
/// so the whole model is one integer: the highest level ever *won*. A set of
/// completed levels would always equal `1..highestCompletedLevel`, i.e. the
/// same information stored 200× over.
abstract class ProgressRepository {
  /// Highest level the player has won; 0 before the first win.
  int get highestCompletedLevel;

  /// Whether [levelId] may be played: every won level, plus the next one.
  bool isUnlocked(int levelId);

  /// The level the player should play next (clamped to [kLastLevelId]).
  int get nextLevelId;

  /// Records a win on [levelId]. Progress never moves backwards, and never
  /// past [kLastLevelId]. Replaying an old level therefore cannot demote it.
  Future<void> recordWin(int levelId);
}

/// Shared progression arithmetic — the single definition of "unlocked".
mixin _ProgressRules implements ProgressRepository {
  @override
  bool isUnlocked(int levelId) =>
      levelId >= 1 && levelId <= kLastLevelId && levelId <= highestCompletedLevel + 1;

  @override
  int get nextLevelId => (highestCompletedLevel + 1).clamp(1, kLastLevelId);

  /// The value [recordWin] should store for a win on [levelId].
  int nextHighest(int levelId) =>
      levelId > highestCompletedLevel ? levelId.clamp(1, kLastLevelId) : highestCompletedLevel;
}

/// Hive-backed implementation. Stores one JSON record so the shape can grow
/// (per-level stars, streaks) without a Hive type adapter or a migration.
class HiveProgressRepository with _ProgressRules implements ProgressRepository {
  HiveProgressRepository(this._box);

  /// Box name — opened AES-encrypted by the caller.
  static const String boxName = 'progress';

  static const String _recordKey = 'progress';
  static const int _schemaVersion = 1;

  final Box<String> _box;

  @override
  int get highestCompletedLevel {
    final raw = _box.get(_recordKey);
    if (raw == null) return 0;
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      // An unknown schema is discarded rather than guessed at: restarting the
      // ladder is recoverable, misreading a future record is not.
      if (json['schema_version'] != _schemaVersion) return 0;
      final value = json['highest_completed_level'] as int;
      return value.clamp(0, kLastLevelId);
    } on Exception catch (e) {
      debugPrint('ProgressRepository: unreadable record, treating as fresh ($e).');
      return 0;
    }
  }

  @override
  Future<void> recordWin(int levelId) async {
    final next = nextHighest(levelId);
    if (next == highestCompletedLevel && _box.containsKey(_recordKey)) return;
    await _box.put(
      _recordKey,
      jsonEncode({'schema_version': _schemaVersion, 'highest_completed_level': next}),
    );
  }
}

/// Volatile implementation used by tests and as the default dependency, so a
/// [GameBloc] built without wiring never touches the disk.
class InMemoryProgressRepository with _ProgressRules implements ProgressRepository {
  InMemoryProgressRepository({int highestCompletedLevel = 0}) : _highest = highestCompletedLevel;

  int _highest;

  @override
  int get highestCompletedLevel => _highest;

  @override
  Future<void> recordWin(int levelId) async => _highest = nextHighest(levelId);
}
