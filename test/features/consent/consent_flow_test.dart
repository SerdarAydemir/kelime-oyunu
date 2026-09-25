// test/features/consent/consent_flow_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:kelime_oyunu/core/services/consent_service.dart';
import 'package:kelime_oyunu/data/models/app_settings.dart';
import 'package:kelime_oyunu/data/repositories/settings_repository.dart';
import 'package:kelime_oyunu/features/consent/view/att_screen.dart';
import 'package:kelime_oyunu/features/consent/view/consent_screen.dart';
import 'package:kelime_oyunu/features/settings/cubit/settings_cubit.dart';

// Relative import — test helpers are not importable via package: path.
// ignore: always_use_package_imports
import '../../helpers/localized_app.dart';

class _Harness {
  // The tutorial gate is covered by first_run_test; these flows start with
  // it already seen unless a test says otherwise.
  _Harness({
    required this.isIOS,
    this.initial = '/consent',
    bool consentDone = false,
    bool onboardingDone = true,
  }) : settingsRepo = InMemorySettingsRepository(
         initial: AppSettings(consentDone: consentDone, onboardingDone: onboardingDone),
       );

  final bool isIOS;
  final String initial;
  final InMemorySettingsRepository settingsRepo;
  late final cubit = SettingsCubit(repository: settingsRepo);
  final visited = <String>[];

  Widget build() {
    Widget capture(GoRouterState state) {
      visited.add(state.uri.toString());
      return const Scaffold(body: Text('elsewhere'));
    }

    final router = GoRouter(
      initialLocation: initial,
      routes: [
        GoRoute(
          path: '/consent',
          builder: (_, _) =>
              ConsentScreen(consentService: const MockConsentService(), isIOS: isIOS),
        ),
        GoRoute(
          path: '/consent/att',
          builder: (_, _) => const AttScreen(consentService: MockConsentService()),
        ),
        GoRoute(path: '/', builder: (_, s) => capture(s)),
        GoRoute(path: '/onboarding', builder: (_, s) => capture(s)),
        GoRoute(path: '/legal/:page', builder: (_, s) => capture(s)),
      ],
    );
    return BlocProvider.value(value: cubit, child: localizedRouterApp(router));
  }
}

void main() {
  testWidgets('consent shows the copy and links', (tester) async {
    final h = _Harness(isIOS: false);
    await tester.pumpWidget(h.build());
    await tester.pumpAndSettle();
    expect(find.text('HOŞ GELDİN'), findsOneWidget);
    expect(find.text('Tırmanışa başlamadan önce'), findsOneWidget);
    expect(find.text('Reklamlar ve veri'), findsOneWidget);
    expect(find.text('Kabul et ve başla'), findsOneWidget);
    expect(find.text('Seçenekleri yönet'), findsOneWidget);

    await tester.tap(find.text('Gizlilik politikası'));
    await tester.pumpAndSettle();
    expect(h.visited, ['/legal/privacy']);
  });

  testWidgets('Android: accept records consent and lands on home', (tester) async {
    final h = _Harness(isIOS: false);
    await tester.pumpWidget(h.build());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kabul et ve başla'));
    await tester.pumpAndSettle();

    expect(h.cubit.state.consentDone, isTrue);
    expect(h.settingsRepo.read().consentDone, isTrue);
    expect(h.visited, ['/']);
  });

  testWidgets('iOS: manage options records consent, then the ATT pre-prompt, then home', (
    tester,
  ) async {
    final h = _Harness(isIOS: true);
    await tester.pumpWidget(h.build());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Seçenekleri yönet'));
    await tester.pumpAndSettle();

    expect(h.cubit.state.consentDone, isTrue);
    expect(find.text('BİR ADIM KALDI'), findsOneWidget);
    expect(find.text('Takip izni hakkında'), findsOneWidget);
    expect(find.text('Şimdi değil'), findsOneWidget);

    await tester.tap(find.text('Devam'));
    await tester.pumpAndSettle();
    expect(h.cubit.state.attAsked, isTrue);
    expect(h.visited, ['/']);
  });

  testWidgets('a first run continues into the tutorial after consent', (tester) async {
    final h = _Harness(isIOS: false, onboardingDone: false);
    await tester.pumpWidget(h.build());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kabul et ve başla'));
    await tester.pumpAndSettle();
    expect(h.visited, ['/onboarding?first=1']);
  });

  testWidgets('ATT "Şimdi değil" also marks the prompt as asked', (tester) async {
    // Reached only after consent, so the harness starts consented.
    final h = _Harness(isIOS: true, initial: '/consent/att', consentDone: true);
    await tester.pumpWidget(h.build());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Şimdi değil'));
    await tester.pumpAndSettle();
    expect(h.cubit.state.attAsked, isTrue);
    expect(h.visited, ['/']);
  });
}
