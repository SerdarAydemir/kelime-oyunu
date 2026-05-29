// lib/core/utils/logger.dart
import 'package:flutter/foundation.dart';

/// Application-wide logging utility.
///
/// All output goes through [debugPrint] so it respects Flutter's log-throttle
/// on Android and is elided in release builds. Never call `print` directly
/// (CLAUDE.md / coding-standards.md §1.1 — `avoid_print` lint enforced).
///
/// TODO(faz-6): route [error] calls to FirebaseCrashlytics.instance.recordError.
abstract final class AppLogger {
  /// Fine-grained debug information — only emitted in debug mode.
  static void debug(String message) {
    if (kDebugMode) debugPrint('[DEBUG] $message');
  }

  /// General informational messages (all modes).
  static void info(String message) => debugPrint('[INFO] $message');

  /// Potentially harmful situations that are not yet errors.
  static void warning(String message) => debugPrint('[WARN] $message');

  /// Error events that may still allow the app to continue running.
  ///
  /// Pass [error] and [stackTrace] when available; they will be forwarded
  /// to Firebase Crashlytics in FAZ 6.
  static void error(String message, [Object? error, StackTrace? stackTrace]) {
    debugPrint('[ERROR] $message${error != null ? '\n$error' : ''}');
    if (stackTrace != null) debugPrint(stackTrace.toString());
    // TODO(faz-6): FirebaseCrashlytics.instance.recordError(error, stackTrace)
  }
}
