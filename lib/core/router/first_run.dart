// lib/core/router/first_run.dart

import 'package:kelime_oyunu/data/models/app_settings.dart';

/// Where the splash hands over (README flow: splash → consent → [ATT on iOS]
/// → onboarding → home). Pure: the settings snapshot plus the platform decide.
String firstRoute(AppSettings settings, {required bool isIOS}) {
  if (!settings.consentDone) return '/consent';
  if (isIOS && !settings.attAsked) return '/consent/att';
  return '/';
}
