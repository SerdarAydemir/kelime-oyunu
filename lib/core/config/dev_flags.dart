// lib/core/config/dev_flags.dart

import 'package:flutter/foundation.dart';

/// QA switch: `flutter run --dart-define=DEV_UNLOCK_ALL=true` makes every level
/// playable on the level-select screen without touching saved progress.
///
/// AND-ed with [kDebugMode] so it can never leak into a release build even if
/// the define is passed by mistake; in release the whole expression folds to a
/// compile-time `false` and the dependent UI is tree-shaken away.
const bool kDevUnlockAll = kDebugMode && bool.fromEnvironment('DEV_UNLOCK_ALL');
