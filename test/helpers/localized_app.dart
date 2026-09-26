// test/helpers/localized_app.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:kelime_oyunu/l10n/generated/app_localizations.dart';

/// [MaterialApp] with the app's localisation delegates, pinned to Turkish so
/// widget tests can assert on the TR strings regardless of the host locale.
/// [textScale] simulates the system font-size setting (1.0 = default).
Widget localizedApp({required Widget home, double textScale = 1.0}) => MaterialApp(
  locale: const Locale('tr'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  builder: (context, child) => _scaled(context, child, textScale),
  home: home,
);

/// Router flavour of [localizedApp].
Widget localizedRouterApp(GoRouter router, {double textScale = 1.0}) => MaterialApp.router(
  locale: const Locale('tr'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  builder: (context, child) => _scaled(context, child, textScale),
  routerConfig: router,
);

Widget _scaled(BuildContext context, Widget? child, double textScale) => MediaQuery(
  data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
  child: child ?? const SizedBox(),
);
