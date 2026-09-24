// test/features/gameplay/widgets/offline_toast_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kelime_oyunu/features/gameplay/widgets/offline_toast.dart';

// Relative import — test helpers are not importable via package: path.
// ignore: always_use_package_imports
import '../../../helpers/localized_app.dart';

void main() {
  testWidgets('shows the offline message with a working Tekrar dene action', (tester) async {
    var retries = 0;
    await tester.pumpWidget(
      localizedApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showOfflineToast(context, onRetry: () => retries++),
              child: const Text('go'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('go'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Bağlantı yok · reklam yüklenemedi'), findsOneWidget);
    expect(find.byIcon(Icons.wifi_off), findsOneWidget);

    await tester.tap(find.text('Tekrar dene'));
    await tester.pumpAndSettle();
    expect(retries, 1);
    expect(find.text('Bağlantı yok · reklam yüklenemedi'), findsNothing);
  });
}
