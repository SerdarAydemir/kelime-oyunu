// test/features/splash/splash_screen_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:kelime_oyunu/core/widgets/app_logo.dart';
import 'package:kelime_oyunu/features/splash/view/splash_screen.dart';

// Relative import — test helpers are not importable via package: path.
// ignore: always_use_package_imports
import '../../helpers/localized_app.dart';

void main() {
  testWidgets('shows the logo tile, name and tag, then moves on', (tester) async {
    var landed = 0;
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) =>
              const SplashScreen(next: '/levels', duration: Duration(milliseconds: 300)),
        ),
        GoRoute(
          path: '/levels',
          builder: (_, _) {
            landed++;
            return const Scaffold(body: Text('levels'));
          },
        ),
      ],
    );
    await tester.pumpWidget(localizedRouterApp(router));

    expect(find.byType(AppLogoTile), findsOneWidget);
    expect(find.text('Kelime Zirvesi'), findsOneWidget);
    expect(find.text('RAKİBE KARŞI ÇENGEL BULMACA'), findsOneWidget);
    expect(landed, 0);

    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    expect(landed, 1);
    expect(find.byType(SplashScreen), findsNothing);
  });
}
