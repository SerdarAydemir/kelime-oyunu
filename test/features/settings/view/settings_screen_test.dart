// test/features/settings/view/settings_screen_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'package:kelime_oyunu/core/services/consent_service.dart';
import 'package:kelime_oyunu/core/theme/app_theme.dart';
import 'package:kelime_oyunu/data/models/app_settings.dart';
import 'package:kelime_oyunu/data/repositories/progress_repository.dart';
import 'package:kelime_oyunu/data/repositories/session_repository.dart';
import 'package:kelime_oyunu/data/repositories/settings_repository.dart';
import 'package:kelime_oyunu/features/settings/cubit/settings_cubit.dart';
import 'package:kelime_oyunu/features/settings/view/settings_screen.dart';
import 'package:kelime_oyunu/features/settings/widgets/settings_rows.dart';
import 'package:kelime_oyunu/l10n/generated/app_localizations.dart';

class _Harness {
  _Harness({int highestCompletedLevel = 0})
    : settingsRepo = InMemorySettingsRepository(),
      progressRepo = InMemoryProgressRepository(highestCompletedLevel: highestCompletedLevel),
      sessionRepo = InMemorySessionRepository();

  final InMemorySettingsRepository settingsRepo;
  final InMemoryProgressRepository progressRepo;
  final InMemorySessionRepository sessionRepo;
  late final SettingsCubit cubit = SettingsCubit(repository: settingsRepo);
  String? destination;

  Widget build() {
    Widget capture(GoRouterState state) {
      destination = state.uri.toString();
      return const Scaffold(body: Text('elsewhere'));
    }

    final router = GoRouter(
      initialLocation: '/settings',
      routes: [
        GoRoute(
          path: '/settings',
          builder: (_, _) => SettingsScreen(
            progressRepo: progressRepo,
            sessionRepo: sessionRepo,
            consentService: const MockConsentService(),
          ),
        ),
        GoRoute(path: '/shop', builder: (_, s) => capture(s)),
        GoRoute(path: '/legal/:page', builder: (_, s) => capture(s)),
        GoRoute(path: '/', builder: (_, s) => capture(s)),
      ],
    );
    // Mirrors app.dart: the theme mode follows the cubit.
    return BlocProvider.value(
      value: cubit,
      child: BlocBuilder<SettingsCubit, AppSettings>(
        builder: (_, settings) => MaterialApp.router(
          locale: const Locale('tr'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: settings.themeMode,
          routerConfig: router,
        ),
      ),
    );
  }
}

void main() {
  setUp(() {
    PackageInfo.setMockInitialValues(
      appName: 'kelime_oyunu',
      packageName: 'com.kelimeoyunu.kelime_oyunu',
      version: '1.0.0',
      buildNumber: '1',
      buildSignature: '',
      installerStore: null,
    );
  });

  testWidgets('renders both groups and the version footer', (tester) async {
    final h = _Harness();
    await tester.pumpWidget(h.build());
    await tester.pumpAndSettle();

    expect(find.text('Ayarlar'), findsOneWidget);
    expect(find.text('OYUN'), findsOneWidget);
    expect(find.text('HESAP'), findsOneWidget);
    for (final t in ['Görünüm', 'Açık', 'Koyu', 'Sistem', 'Ses', 'Titreşim', 'Gökyüzü']) {
      expect(find.text(t), findsOneWidget, reason: t);
    }
    await tester.scrollUntilVisible(find.text('Kullanım koşulları'), 200);
    for (final t in [
      'Reklamları kaldır',
      'Mağaza →',
      'Reklam tercihleri',
      'İlerlemeyi sıfırla',
      'Sil',
      'Gizlilik politikası',
      'Kullanım koşulları',
    ]) {
      expect(find.text(t), findsOneWidget, reason: t);
    }
    // The list is lazy: bring the footer into view before looking for it.
    await tester.scrollUntilVisible(find.text('Kelime Zirvesi 1.0.0'), 200);
    expect(find.text('Kelime Zirvesi 1.0.0'), findsOneWidget);
    expect(find.byType(SettingsToggle), findsNWidgets(3));
  });

  testWidgets('the appearance pill changes the theme mode immediately and persists it', (
    tester,
  ) async {
    final h = _Harness();
    await tester.pumpWidget(h.build());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Koyu'));
    await tester.pumpAndSettle();

    expect(h.cubit.state.themeMode, ThemeMode.dark);
    expect(h.settingsRepo.read().themeMode, ThemeMode.dark);
    expect(Theme.of(tester.element(find.text('Ayarlar'))).brightness, Brightness.dark);
  });

  testWidgets('toggles flip and persist', (tester) async {
    final h = _Harness();
    await tester.pumpWidget(h.build());
    await tester.pumpAndSettle();

    await tester.tap(find.byType(SettingsToggle).at(2)); // Gökyüzü
    await tester.pumpAndSettle();

    expect(h.cubit.state.skyEnabled, isFalse);
    expect(h.settingsRepo.read(), const AppSettings(skyEnabled: false));
  });

  testWidgets('reset asks first, then wipes progress and the saved match', (tester) async {
    final h = _Harness(highestCompletedLevel: 7);
    await tester.pumpWidget(h.build());
    await tester.pumpAndSettle();

    await tester.tap(find.text('İlerlemeyi sıfırla'));
    await tester.pumpAndSettle();
    expect(find.text('İlerlemeyi sıfırla?'), findsOneWidget);
    await tester.tap(find.text('Vazgeç'));
    await tester.pumpAndSettle();
    expect(h.progressRepo.highestCompletedLevel, 7);

    await tester.tap(find.text('İlerlemeyi sıfırla'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sil').last);
    await tester.pumpAndSettle();
    expect(h.progressRepo.highestCompletedLevel, 0);
  });

  testWidgets('shop and legal rows navigate; ad preferences confirm', (tester) async {
    final h = _Harness();
    await tester.pumpWidget(h.build());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reklamları kaldır'));
    await tester.pumpAndSettle();
    expect(h.destination, '/shop');

    final h2 = _Harness();
    await tester.pumpWidget(h2.build());
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Kullanım koşulları'), 200);
    await tester.ensureVisible(find.text('Kullanım koşulları'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kullanım koşulları'));
    await tester.pumpAndSettle();
    expect(h2.destination, '/legal/terms');

    final h3 = _Harness();
    await tester.pumpWidget(h3.build());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reklam tercihleri'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Reklam tercihleri güncellendi'), findsOneWidget);
  });
}
