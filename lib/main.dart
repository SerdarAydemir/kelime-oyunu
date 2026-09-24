// lib/main.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:kelime_oyunu/app.dart';
import 'package:kelime_oyunu/data/repositories/progress_repository.dart';
import 'package:kelime_oyunu/data/repositories/session_repository.dart';
import 'package:kelime_oyunu/data/repositories/settings_repository.dart';
import 'package:kelime_oyunu/data/sources/secure_hive.dart';

// TODO: Firebase.initializeApp() — FAZ 6'da eklenecek

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Storage comes up before the first frame: the level-select screen reads
  // progress synchronously, so the boxes must already be open (architecture.md §11).
  await SecureHive.init();
  final cipher = await SecureHive.cipher();
  final progressBox = await SecureHive.openEncryptedBox(HiveProgressRepository.boxName, cipher);
  final sessionBox = await SecureHive.openEncryptedBox(HiveSessionRepository.boxName, cipher);
  // Theme mode must be known before the first frame, or the app would flash
  // the wrong palette; SharedPreferences reads are synchronous once loaded.
  final prefs = await SharedPreferences.getInstance();

  runApp(
    KelimeOyunuApp(
      progressRepo: HiveProgressRepository(progressBox),
      sessionRepo: HiveSessionRepository(sessionBox),
      settingsRepo: SharedPrefsSettingsRepository(prefs),
    ),
  );
}
