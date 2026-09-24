// lib/app.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:kelime_oyunu/core/router/app_router.dart';
import 'package:kelime_oyunu/core/theme/app_theme.dart';
import 'package:kelime_oyunu/data/models/app_settings.dart';
import 'package:kelime_oyunu/data/repositories/progress_repository.dart';
import 'package:kelime_oyunu/data/repositories/session_repository.dart';
import 'package:kelime_oyunu/data/repositories/settings_repository.dart';
import 'package:kelime_oyunu/features/settings/cubit/settings_cubit.dart';
import 'package:kelime_oyunu/l10n/generated/app_localizations.dart';

/// Root widget of the Kelime Oyunu application.
///
/// Wires together routing, theming, and localisation.
/// Feature-level BlocProviders are added here incrementally as each feature
/// is scaffolded (skills.md §8 steps 2–5).
class KelimeOyunuApp extends StatefulWidget {
  const KelimeOyunuApp({
    required this.progressRepo,
    required this.sessionRepo,
    required this.settingsRepo,
    super.key,
  });

  /// Persisted level progression, opened by `main()` before the first frame.
  final ProgressRepository progressRepo;

  /// The half-played match store, opened by `main()` before the first frame.
  final SessionRepository sessionRepo;

  /// Device preferences (theme mode etc.), readable before the first frame.
  final SettingsRepository settingsRepo;

  @override
  State<KelimeOyunuApp> createState() => _KelimeOyunuAppState();
}

class _KelimeOyunuAppState extends State<KelimeOyunuApp> {
  // Built once and held: rebuilding a GoRouter would reset the navigation stack.
  late final GoRouter _router = AppRouter.build(
    progressRepo: widget.progressRepo,
    sessionRepo: widget.sessionRepo,
  );

  @override
  Widget build(BuildContext context) {
    // Above MaterialApp: the theme mode is read here, and every screen can
    // reach the cubit for the settings page.
    return BlocProvider(
      create: (_) => SettingsCubit(repository: widget.settingsRepo),
      child: BlocBuilder<SettingsCubit, AppSettings>(
        buildWhen: (old, next) => old.themeMode != next.themeMode,
        builder: (context, settings) => MaterialApp.router(
          title: 'Kelime Oyunu',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: settings.themeMode,
          routerConfig: _router,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          // Turkish first: it is the template ARB and the fallback for every
          // device locale that is not English (the generated list is A–Z).
          supportedLocales: const [Locale('tr'), Locale('en')],
        ),
      ),
    );
  }
}
