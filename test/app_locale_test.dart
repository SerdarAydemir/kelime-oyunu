// test/app_locale_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kelime_oyunu/app.dart';
import 'package:kelime_oyunu/data/repositories/progress_repository.dart';
import 'package:kelime_oyunu/data/repositories/session_repository.dart';
import 'package:kelime_oyunu/data/repositories/settings_repository.dart';
import 'package:kelime_oyunu/features/splash/view/splash_screen.dart';

void main() {
  testWidgets('the app runs in Turkish even when the device locale is English', (tester) async {
    // Puzzle packs exist only in Turkish, so the UI is pinned to tr until an
    // EN pack ships (see the localeResolutionCallback in app.dart).
    tester.platformDispatcher.localesTestValue = const [Locale('en', 'US'), Locale('en')];
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);

    await tester.pumpWidget(
      KelimeOyunuApp(
        progressRepo: InMemoryProgressRepository(highestCompletedLevel: 0),
        sessionRepo: InMemorySessionRepository(),
        settingsRepo: InMemorySettingsRepository(),
      ),
    );

    final context = tester.element(find.byType(SplashScreen));
    expect(Localizations.localeOf(context), const Locale('tr'));
    expect(find.text('RAKİBE KARŞI ÇENGEL BULMACA'), findsOneWidget);
    expect(find.text('CROSSWORD DUEL AGAINST AN OPPONENT'), findsNothing);
  });
}
