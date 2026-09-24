// test/features/gameplay/widgets/swap_sheet_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kelime_oyunu/features/gameplay/engine/rack_manager.dart';
import 'package:kelime_oyunu/features/gameplay/widgets/ad_label.dart';
import 'package:kelime_oyunu/features/gameplay/widgets/swap_sheet.dart';

// Relative import — test helpers are not importable via package: path.
// ignore: always_use_package_imports
import '../../../helpers/localized_app.dart';

const _rack = [RackTile(letter: 'K'), RackTile(letter: 'O'), RackTile(letter: 'L')];

Widget _harness({int quota = 12, bool adLabel = true}) => localizedApp(
  home: Scaffold(
    body: SwapSheet(rack: _rack, quotaRemaining: quota, showAdLabel: adLabel),
  ),
);

void main() {
  testWidgets('shows the header, quota, tiles and both options', (tester) async {
    await tester.pumpWidget(_harness());
    expect(find.text('Harf değiştir'), findsOneWidget);
    expect(find.text('Kalan hak · 12 harf'), findsOneWidget);
    expect(find.text('Değiştirmek istediğin harflere dokun.'), findsOneWidget);
    expect(find.text('Henüz harf seçilmedi'), findsOneWidget);
    expect(find.text('Şimdi değiştir'), findsOneWidget);
    expect(find.text('sıra sende kalır'), findsOneWidget);
    expect(find.text('Değiştir ve pas'), findsOneWidget);
    expect(find.text('ücretsiz, sıra rakibe'), findsOneWidget);
    expect(find.byType(AdLabel), findsOneWidget);
    // Nothing selected: both options are inert.
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed, isNull);
    expect(tester.widget<OutlinedButton>(find.byType(OutlinedButton)).onPressed, isNull);
  });

  testWidgets('selecting tiles updates the count and enables the options', (tester) async {
    await tester.pumpWidget(_harness());
    await tester.tap(find.text('K'));
    await tester.pumpAndSettle();
    expect(find.text('1 harf seçildi'), findsOneWidget);
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed, isNotNull);

    await tester.tap(find.text('L'));
    await tester.pumpAndSettle();
    expect(find.text('2 harf seçildi'), findsOneWidget);
  });

  testWidgets('selection is capped at the remaining quota', (tester) async {
    await tester.pumpWidget(_harness(quota: 1));
    await tester.tap(find.text('K'));
    await tester.tap(find.text('O'));
    await tester.pumpAndSettle();
    expect(find.text('1 harf seçildi'), findsOneWidget);
  });

  testWidgets('no ad label in the ad-free levels', (tester) async {
    await tester.pumpWidget(_harness(adLabel: showAdLabelsFor(2)));
    expect(find.byType(AdLabel), findsNothing);
  });
}
