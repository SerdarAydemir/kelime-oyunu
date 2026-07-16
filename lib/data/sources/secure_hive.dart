// lib/data/sources/secure_hive.dart

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// AES-encrypted Hive access (architecture.md §11.1).
///
/// The 256-bit box key is generated once and kept in the platform keystore via
/// [FlutterSecureStorage] — never in the source, never in a Hive box.
///
/// This pairs with `android:allowBackup="false"`: Android auto-backup would
/// restore the encrypted Hive file *without* the keystore key, leaving a box
/// that can never be decrypted and crashes on every launch.
abstract final class SecureHive {
  /// Secure-storage entry holding the base64 AES key.
  static const String _keyEntry = 'hive_aes_key';

  static const FlutterSecureStorage _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  /// Prepares Hive for use. Call once, before opening any box.
  static Future<void> init() => Hive.initFlutter();

  /// Returns the app's box cipher, generating and storing the key on first run.
  ///
  /// If the keystore is unreadable (rare OEM failures), a fresh key is minted
  /// rather than throwing. Any box written under the lost key then fails to
  /// open and is recreated by [openEncryptedBox] — losing local progress beats
  /// crash-looping on launch.
  static Future<HiveCipher> cipher() async {
    final key = await _readOrCreateKey();
    return HiveAesCipher(key);
  }

  static Future<List<int>> _readOrCreateKey() async {
    try {
      final stored = await _storage.read(key: _keyEntry);
      if (stored != null) return base64Decode(stored);
    } on Exception catch (e) {
      debugPrint('SecureHive: key read failed, minting a new one ($e).');
    }
    final fresh = Hive.generateSecureKey();
    try {
      await _storage.write(key: _keyEntry, value: base64Encode(fresh));
    } on Exception catch (e) {
      // The key is unusable next launch, so the box will be recreated then.
      debugPrint('SecureHive: key write failed ($e).');
    }
    return fresh;
  }

  /// Opens [name] as an encrypted `Box<String>`, recreating it if it cannot be
  /// decrypted or parsed (corrupt file, lost key, restored backup).
  static Future<Box<String>> openEncryptedBox(String name, HiveCipher cipher) async {
    try {
      return await Hive.openBox<String>(name, encryptionCipher: cipher);
    } on Exception catch (e) {
      debugPrint('SecureHive: box "$name" unreadable, recreating ($e).');
      await Hive.deleteBoxFromDisk(name);
      return Hive.openBox<String>(name, encryptionCipher: cipher);
    }
  }
}
