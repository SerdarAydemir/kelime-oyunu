// lib/app.dart
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:kelime_oyunu/core/router/app_router.dart';
import 'package:kelime_oyunu/core/theme/app_theme.dart';
import 'package:kelime_oyunu/data/repositories/progress_repository.dart';

/// Root widget of the Kelime Oyunu application.
///
/// Wires together routing, theming, and localisation.
/// Feature-level BlocProviders are added here incrementally as each feature
/// is scaffolded (skills.md §8 steps 2–5).
class KelimeOyunuApp extends StatefulWidget {
  const KelimeOyunuApp({required this.progressRepo, super.key});

  /// Persisted level progression, opened by `main()` before the first frame.
  final ProgressRepository progressRepo;

  @override
  State<KelimeOyunuApp> createState() => _KelimeOyunuAppState();
}

class _KelimeOyunuAppState extends State<KelimeOyunuApp> {
  // Built once and held: rebuilding a GoRouter would reset the navigation stack.
  late final GoRouter _router = AppRouter.build(progressRepo: widget.progressRepo);

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Kelime Oyunu',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      routerConfig: _router,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('tr', 'TR')],
    );
  }
}
