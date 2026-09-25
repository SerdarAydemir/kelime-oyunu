// lib/data/repositories/progress_repository.dart

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

import 'package:kelime_oyunu/core/constants/game_constants.dart';

/// Persistent level progression (architecture.md §11.1, `progress` box).
///
/// The progression rule is strictly linear — only a win advances the player —
/// so the ladder is one integer: the highest level ever *won*. Around it sit
/// the home-screen stats: the altitude (derived), the daily streak and the
/// running count of words the player found.
abstract class ProgressRepository {
  /// Highest level the player has won; 0 before the first win.
  int get highestCompletedLevel;

  /// Whether [levelId] may be played: every won level, plus the next one.
  bool isUnlocked(int levelId);

  /// The level the player should play next (clamped to [kLastLevelId]).
  int get nextLevelId;

  /// Altitude in metres: won levels × [kMetersPerLevel]. Derived, not stored.
  int get altitudeMeters;

  /// Consecutive local-calendar days with at least one finished match,
  /// counting today or yesterday as still alive; 0 once a day was skipped.
  int get dailyStreak;

  /// Words the player completed across all finished matches.
  int get wordsFound;

  /// Records a win on [levelId]. Progress never moves backwards, and never
  /// past [kLastLevelId]. Replaying an old level therefore cannot demote it.
  Future<void> recordWin(int levelId);

  /// Records that a match finished today (any outcome): extends or restarts
  /// the daily streak and adds the [wordsFound] in that match to the total.
  Future<void> recordMatchFinished({required int wordsFound});

  /// "İlerlemeyi sıfırla": back to a fresh player — ladder, stats, everything
  /// this record holds. Irreversible; the settings screen confirms first.
  Future<void> reset();
}

/// What the streak and word counters persist. Day keys are local-calendar
/// `yyyy-mm-dd` strings (the device's local time defines the day boundary).
@immutable
class ProgressStats {
  const ProgressStats({this.lastPlayedDay, this.streak = 0, this.wordsFound = 0});

  final String? lastPlayedDay;
  final int streak;
  final int wordsFound;

  static const ProgressStats empty = ProgressStats();
}

/// Shared progression arithmetic — the single definition of "unlocked", the
/// altitude and the streak rules. [now] is injectable for tests.
mixin _ProgressRules implements ProgressRepository {
  DateTime Function() get now;

  ProgressStats get stats;

  @override
  bool isUnlocked(int levelId) =>
      levelId >= 1 && levelId <= kLastLevelId && levelId <= highestCompletedLevel + 1;

  @override
  int get nextLevelId => (highestCompletedLevel + 1).clamp(1, kLastLevelId);

  @override
  int get altitudeMeters => highestCompletedLevel * kMetersPerLevel;

  @override
  int get wordsFound => stats.wordsFound;

  @override
  int get dailyStreak {
    final last = stats.lastPlayedDay;
    if (last == null) return 0;
    final today = now();
    return last == dayKey(today) || last == dayKey(today.subtract(const Duration(days: 1)))
        ? stats.streak
        : 0;
  }

  /// The value [recordWin] should store for a win on [levelId].
  int nextHighest(int levelId) =>
      levelId > highestCompletedLevel ? levelId.clamp(1, kLastLevelId) : highestCompletedLevel;

  /// The stats [recordMatchFinished] should store: same day → unchanged
  /// streak, the day after → +1, anything else → a fresh streak of 1.
  ProgressStats nextStats(int wordsFound) {
    final today = now();
    final todayKey = dayKey(today);
    final yesterdayKey = dayKey(today.subtract(const Duration(days: 1)));
    final current = stats;
    final int streak;
    if (current.lastPlayedDay == todayKey) {
      streak = current.streak == 0 ? 1 : current.streak;
    } else if (current.lastPlayedDay == yesterdayKey) {
      streak = current.streak + 1;
    } else {
      streak = 1;
    }
    return ProgressStats(
      lastPlayedDay: todayKey,
      streak: streak,
      wordsFound: current.wordsFound + wordsFound,
    );
  }

  /// Local-calendar day key, e.g. `2026-09-24`.
  static String dayKey(DateTime t) =>
      '${t.year.toString().padLeft(4, '0')}-'
      '${t.month.toString().padLeft(2, '0')}-'
      '${t.day.toString().padLeft(2, '0')}';
}

/// Hive-backed implementation. Stores one JSON record so the shape can grow
/// without a Hive type adapter or a migration: keys added later (streak,
/// words) read back as their zero defaults from older records.
class HiveProgressRepository with _ProgressRules implements ProgressRepository {
  HiveProgressRepository(this._box, {DateTime Function()? now}) : now = now ?? DateTime.now;

  /// Box name — opened AES-encrypted by the caller.
  static const String boxName = 'progress';

  static const String _recordKey = 'progress';
  static const int _schemaVersion = 1;

  final Box<String> _box;

  @override
  final DateTime Function() now;

  Map<String, dynamic>? _read() {
    final raw = _box.get(_recordKey);
    if (raw == null) return null;
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      // An unknown schema is discarded rather than guessed at: restarting the
      // ladder is recoverable, misreading a future record is not.
      if (json['schema_version'] != _schemaVersion) return null;
      return json;
    } on Exception catch (e) {
      debugPrint('ProgressRepository: unreadable record, treating as fresh ($e).');
      return null;
    }
  }

  @override
  int get highestCompletedLevel {
    final value = _read()?['highest_completed_level'];
    return value is int ? value.clamp(0, kLastLevelId) : 0;
  }

  @override
  ProgressStats get stats {
    final json = _read();
    if (json == null) return ProgressStats.empty;
    final last = json['last_played_day'];
    final streak = json['streak'];
    final words = json['words_found'];
    return ProgressStats(
      lastPlayedDay: last is String ? last : null,
      streak: streak is int ? streak : 0,
      wordsFound: words is int ? words : 0,
    );
  }

  Future<void> _write({required int highest, required ProgressStats stats}) => _box.put(
    _recordKey,
    jsonEncode({
      'schema_version': _schemaVersion,
      'highest_completed_level': highest,
      'last_played_day': stats.lastPlayedDay,
      'streak': stats.streak,
      'words_found': stats.wordsFound,
    }),
  );

  @override
  Future<void> recordWin(int levelId) async {
    final next = nextHighest(levelId);
    if (next == highestCompletedLevel && _box.containsKey(_recordKey)) return;
    await _write(highest: next, stats: stats);
  }

  @override
  Future<void> recordMatchFinished({required int wordsFound}) =>
      _write(highest: highestCompletedLevel, stats: nextStats(wordsFound));

  @override
  Future<void> reset() => _box.delete(_recordKey);
}

/// Volatile implementation used by tests and as the default dependency, so a
/// [GameBloc] built without wiring never touches the disk.
class InMemoryProgressRepository with _ProgressRules implements ProgressRepository {
  InMemoryProgressRepository({
    int highestCompletedLevel = 0,
    ProgressStats initialStats = ProgressStats.empty,
    DateTime Function()? now,
  }) : _highest = highestCompletedLevel,
       _stats = initialStats,
       now = now ?? DateTime.now;

  int _highest;
  ProgressStats _stats;

  @override
  final DateTime Function() now;

  @override
  int get highestCompletedLevel => _highest;

  @override
  ProgressStats get stats => _stats;

  @override
  Future<void> recordWin(int levelId) async => _highest = nextHighest(levelId);

  @override
  Future<void> recordMatchFinished({required int wordsFound}) async =>
      _stats = nextStats(wordsFound);

  @override
  Future<void> reset() async {
    _highest = 0;
    _stats = ProgressStats.empty;
  }
}
