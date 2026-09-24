// test/helpers/localized_app.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:kelime_oyunu/l10n/generated/app_localizations.dart';

/// [MaterialApp] with the app's localisation delegates, pinned to Turkish so
/// widget tests can assert on the TR strings regardless of the host locale.
Widget localizedApp({required Widget home}) => MaterialApp(
  locale: const Locale('tr'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: home,
);

/// Router flavour of [localizedApp].
Widget localizedRouterApp(GoRouter router) => MaterialApp.router(
  locale: const Locale('tr'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  routerConfig: router,
);
