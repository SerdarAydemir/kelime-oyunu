// test/data/progress_repository_test.dart

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:kelime_oyunu/core/constants/game_constants.dart';
import 'package:kelime_oyunu/data/repositories/progress_repository.dart';

/// A settable clock for the streak rules.
class TestClock {
  DateTime value = DateTime(2026, 9, 24, 21, 30);
  DateTime call() => value;
  void advanceDays(int days) => value = value.add(Duration(days: days));
}

/// Runs the shared contract against any [ProgressRepository] implementation.
/// [make] must return a fresh, empty repository on [clock].
void runContractTests(String label, Future<ProgressRepository> Function(TestClock clock) make) {
  group('$label — home stats', () {
    test('a fresh player has no altitude, streak or words', () async {
      final repo = await make(TestClock());
      expect(repo.altitudeMeters, 0);
      expect(repo.dailyStreak, 0);
      expect(repo.wordsFound, 0);
    });

    test('altitude is derived from won levels × 40 m', () async {
      final repo = await make(TestClock());
      await repo.recordWin(1);
      await repo.recordWin(2);
      await repo.recordWin(3);
      expect(repo.altitudeMeters, 120);
    });

    test('words found accumulate over finished matches', () async {
      final repo = await make(TestClock());
      await repo.recordMatchFinished(wordsFound: 4);
      await repo.recordMatchFinished(wordsFound: 3);
      expect(repo.wordsFound, 7);
    });

    test('the streak grows on consecutive days and is idempotent within a day', () async {
      final clock = TestClock();
      final repo = await make(clock);
      await repo.recordMatchFinished(wordsFound: 1);
      await repo.recordMatchFinished(wordsFound: 1);
      expect(repo.dailyStreak, 1);
      clock.advanceDays(1);
      expect(repo.dailyStreak, 1, reason: 'yesterday keeps the streak alive');
      await repo.recordMatchFinished(wordsFound: 1);
      expect(repo.dailyStreak, 2);
      clock.advanceDays(1);
      await repo.recordMatchFinished(wordsFound: 1);
      expect(repo.dailyStreak, 3);
    });

    test('skipping a day resets the streak', () async {
      final clock = TestClock();
      final repo = await make(clock);
      await repo.recordMatchFinished(wordsFound: 1);
      clock.advanceDays(1);
      await repo.recordMatchFinished(wordsFound: 1);
      expect(repo.dailyStreak, 2);
      clock.advanceDays(2);
      expect(repo.dailyStreak, 0, reason: 'a skipped day reads as no streak');
      await repo.recordMatchFinished(wordsFound: 1);
      expect(repo.dailyStreak, 1);
    });

    test('the day boundary is the local calendar day, not 24 h', () async {
      final clock = TestClock()..value = DateTime(2026, 9, 24, 23, 50);
      final repo = await make(clock);
      await repo.recordMatchFinished(wordsFound: 1);
      clock.value = DateTime(2026, 9, 25, 0, 10);
      await repo.recordMatchFinished(wordsFound: 1);
      expect(repo.dailyStreak, 2);
    });

    test('a win does not touch the stats', () async {
      final repo = await make(TestClock());
      await repo.recordMatchFinished(wordsFound: 2);
      await repo.recordWin(1);
      expect(repo.wordsFound, 2);
      expect(repo.dailyStreak, 1);
      expect(repo.highestCompletedLevel, 1);
    });
  });

  group('$label — progression contract', () {
    test('a fresh player has only level 1 unlocked', () async {
      final repo = await make(TestClock());

      expect(repo.highestCompletedLevel, 0);
      expect(repo.nextLevelId, 1);
      expect(repo.isUnlocked(1), isTrue);
      expect(repo.isUnlocked(2), isFalse);
    });

    test('a win unlocks exactly the next level', () async {
      final repo = await make(TestClock());

      await repo.recordWin(1);

      expect(repo.highestCompletedLevel, 1);
      expect(repo.nextLevelId, 2);
      expect(repo.isUnlocked(2), isTrue);
      expect(repo.isUnlocked(3), isFalse);
    });

    test('replaying an already-won level does not demote progress', () async {
      final repo = await make(TestClock());
      await repo.recordWin(5);

      await repo.recordWin(2);

      expect(repo.highestCompletedLevel, 5);
      expect(repo.nextLevelId, 6);
    });

    test('progress is clamped at the last shipped level', () async {
      final repo = await make(TestClock());

      await repo.recordWin(kLastLevelId);

      expect(repo.highestCompletedLevel, kLastLevelId);
      // There is no level 201 to advance to.
      expect(repo.nextLevelId, kLastLevelId);
      expect(repo.isUnlocked(kLastLevelId + 1), isFalse);
    });

    test('level 0 and negative ids are never unlocked', () async {
      final repo = await make(TestClock());
      await repo.recordWin(3);

      expect(repo.isUnlocked(0), isFalse);
      expect(repo.isUnlocked(-1), isFalse);
    });
  });
}

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('kelime_progress_test');
    Hive.init(tempDir.path);
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    if (tempDir.existsSync()) await tempDir.delete(recursive: true);
  });

  runContractTests(
    'InMemoryProgressRepository',
    (clock) async => InMemoryProgressRepository(now: clock.call),
  );

  // Unencrypted here on purpose: the cipher lives in flutter_secure_storage,
  // which needs a platform channel. This exercises the record format; the AES
  // wiring is a main() concern verified on device.
  runContractTests('HiveProgressRepository', (clock) async {
    await Hive.deleteBoxFromDisk(HiveProgressRepository.boxName);
    return HiveProgressRepository(
      await Hive.openBox<String>(HiveProgressRepository.boxName),
      now: clock.call,
    );
  });

  group('HiveProgressRepository — durability', () {
    test('progress survives closing and reopening the box', () async {
      final box = await Hive.openBox<String>(HiveProgressRepository.boxName);
      await HiveProgressRepository(box).recordWin(7);
      await box.close();

      final reopened = await Hive.openBox<String>(HiveProgressRepository.boxName);

      expect(HiveProgressRepository(reopened).highestCompletedLevel, 7);
    });

    test('stats survive closing and reopening the box', () async {
      final clock = TestClock();
      final box = await Hive.openBox<String>(HiveProgressRepository.boxName);
      await HiveProgressRepository(box, now: clock.call).recordMatchFinished(wordsFound: 5);
      await box.close();

      final reopened = await Hive.openBox<String>(HiveProgressRepository.boxName);
      final repo = HiveProgressRepository(reopened, now: clock.call);

      expect(repo.wordsFound, 5);
      expect(repo.dailyStreak, 1);
    });

    test('a schema-1 record written before the stats existed opens with zeros', () async {
      final box = await Hive.openBox<String>(HiveProgressRepository.boxName);
      await box.put('progress', '{"schema_version":1,"highest_completed_level":9}');
      final repo = HiveProgressRepository(box);

      expect(repo.highestCompletedLevel, 9);
      expect(repo.altitudeMeters, 360);
      expect(repo.dailyStreak, 0);
      expect(repo.wordsFound, 0);
      // Writing stats keeps the ladder.
      await repo.recordMatchFinished(wordsFound: 2);
      expect(repo.highestCompletedLevel, 9);
      expect(repo.wordsFound, 2);
    });

    test('a record from an unknown schema is treated as a fresh player', () async {
      final box = await Hive.openBox<String>(HiveProgressRepository.boxName);
      await box.put('progress', '{"schema_version":99,"highest_completed_level":42}');

      expect(HiveProgressRepository(box).highestCompletedLevel, 0);
    });

    test('a corrupt record does not throw', () async {
      final box = await Hive.openBox<String>(HiveProgressRepository.boxName);
      await box.put('progress', 'not json at all');

      expect(HiveProgressRepository(box).highestCompletedLevel, 0);
    });
  });
}
