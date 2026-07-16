// test/data/progress_repository_test.dart

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:kelime_oyunu/core/constants/game_constants.dart';
import 'package:kelime_oyunu/data/repositories/progress_repository.dart';

/// Runs the shared contract against any [ProgressRepository] implementation.
/// [make] must return a fresh, empty repository.
void runContractTests(String label, Future<ProgressRepository> Function() make) {
  group('$label — progression contract', () {
    test('a fresh player has only level 1 unlocked', () async {
      final repo = await make();

      expect(repo.highestCompletedLevel, 0);
      expect(repo.nextLevelId, 1);
      expect(repo.isUnlocked(1), isTrue);
      expect(repo.isUnlocked(2), isFalse);
    });

    test('a win unlocks exactly the next level', () async {
      final repo = await make();

      await repo.recordWin(1);

      expect(repo.highestCompletedLevel, 1);
      expect(repo.nextLevelId, 2);
      expect(repo.isUnlocked(2), isTrue);
      expect(repo.isUnlocked(3), isFalse);
    });

    test('replaying an already-won level does not demote progress', () async {
      final repo = await make();
      await repo.recordWin(5);

      await repo.recordWin(2);

      expect(repo.highestCompletedLevel, 5);
      expect(repo.nextLevelId, 6);
    });

    test('progress is clamped at the last shipped level', () async {
      final repo = await make();

      await repo.recordWin(kLastLevelId);

      expect(repo.highestCompletedLevel, kLastLevelId);
      // There is no level 201 to advance to.
      expect(repo.nextLevelId, kLastLevelId);
      expect(repo.isUnlocked(kLastLevelId + 1), isFalse);
    });

    test('level 0 and negative ids are never unlocked', () async {
      final repo = await make();
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

  runContractTests('InMemoryProgressRepository', () async => InMemoryProgressRepository());

  // Unencrypted here on purpose: the cipher lives in flutter_secure_storage,
  // which needs a platform channel. This exercises the record format; the AES
  // wiring is a main() concern verified on device.
  runContractTests('HiveProgressRepository', () async {
    await Hive.deleteBoxFromDisk(HiveProgressRepository.boxName);
    return HiveProgressRepository(await Hive.openBox<String>(HiveProgressRepository.boxName));
  });

  group('HiveProgressRepository — durability', () {
    test('progress survives closing and reopening the box', () async {
      final box = await Hive.openBox<String>(HiveProgressRepository.boxName);
      await HiveProgressRepository(box).recordWin(7);
      await box.close();

      final reopened = await Hive.openBox<String>(HiveProgressRepository.boxName);

      expect(HiveProgressRepository(reopened).highestCompletedLevel, 7);
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
