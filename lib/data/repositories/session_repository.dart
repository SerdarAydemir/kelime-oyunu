// lib/data/repositories/session_repository.dart

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

import 'package:kelime_oyunu/data/models/saved_session.dart';

/// Storage for the one half-played match (architecture.md §11.1,
/// `active_session` box). At most one match is in flight at a time, so the box
/// holds a single record.
abstract class SessionRepository {
  /// The saved match, or null if there is none (or it was unreadable).
  SavedSession? load();

  /// Overwrites the saved match. Called at every turn boundary — no debounce,
  /// per architecture.md §11.2.
  Future<void> save(SavedSession session);

  /// Drops the saved match. Called when a match finishes.
  Future<void> clear();

  /// Cheap headline for the level-select resume entry.
  ResumeSummary? get summary => load()?.summary;
}

/// Hive-backed implementation. Stores JSON rather than a typed adapter: the
/// record is small, and JSON keeps the codec unit-testable without Hive.
class HiveSessionRepository implements SessionRepository {
  HiveSessionRepository(this._box);

  /// Box name — opened AES-encrypted by the caller.
  static const String boxName = 'active_session';

  static const String _recordKey = 'session';

  final Box<String> _box;

  @override
  SavedSession? load() {
    final raw = _box.get(_recordKey);
    if (raw == null) return null;
    try {
      return SavedSession.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } on Object catch (e) {
      debugPrint('SessionRepository: undecodable record dropped ($e).');
      return null;
    }
  }

  @override
  Future<void> save(SavedSession session) => _box.put(_recordKey, jsonEncode(session.toJson()));

  @override
  Future<void> clear() => _box.delete(_recordKey);

  @override
  ResumeSummary? get summary => load()?.summary;
}

/// Volatile implementation: the default dependency, so an unwired [GameBloc]
/// never reaches the disk, and the fake used by widget tests.
class InMemorySessionRepository implements SessionRepository {
  InMemorySessionRepository({SavedSession? initial}) : _session = initial;

  SavedSession? _session;

  @override
  SavedSession? load() => _session;

  @override
  Future<void> save(SavedSession session) async => _session = session;

  @override
  Future<void> clear() async => _session = null;

  @override
  ResumeSummary? get summary => _session?.summary;
}
