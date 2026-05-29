// lib/app.dart
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:kelime_oyunu/core/router/app_router.dart';
import 'package:kelime_oyunu/core/theme/app_theme.dart';

/// Root widget of the Kelime Oyunu application.
///
/// Wires together routing, theming, and localisation.
/// Feature-level BlocProviders are added here incrementally as each feature
/// is scaffolded (skills.md §8 steps 2–5).
class KelimeOyunuApp extends StatelessWidget {
  const KelimeOyunuApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Kelime Oyunu',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      routerConfig: AppRouter.router,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('tr', 'TR')],
    );
  }
}
