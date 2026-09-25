// test/features/shop/shop_screen_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kelime_oyunu/core/services/purchase_service.dart';
import 'package:kelime_oyunu/data/repositories/progress_repository.dart';
import 'package:kelime_oyunu/features/shop/view/shop_screen.dart';

// Relative import — test helpers are not importable via package: path.
// ignore: always_use_package_imports
import '../../helpers/localized_app.dart';

Widget _harness(
  ProgressRepository repo, {
  PurchaseService purchases = const MockPurchaseService(),
}) => localizedApp(
  home: ShopScreen(progressRepo: repo, purchases: purchases),
);

void main() {
  testWidgets('renders the shop with the balance, cards and campfire', (tester) async {
    final repo = InMemoryProgressRepository(initialStats: const ProgressStats(coins: 35));
    await tester.pumpWidget(_harness(repo));
    await tester.pumpAndSettle();

    expect(find.text('Kamp dükkânı'), findsOneWidget);
    expect(find.text('35'), findsOneWidget);
    expect(find.text('TEK SEFERLİK'), findsOneWidget);
    expect(find.text('Reklamsız tırmanış'), findsOneWidget);
    expect(find.text('₺89,99'), findsOneWidget);
    expect(find.text('KAMP PARASI'), findsOneWidget);
    expect(find.text('150'), findsOneWidget);
    expect(find.text('≈ 15 harf açma'), findsOneWidget);
    expect(find.text('500'), findsOneWidget);
    expect(find.text('EN ÇOK ALINAN'), findsOneWidget);
    expect(find.text('ÜCRETSİZ'), findsOneWidget);
    expect(find.text('Günlük kamp ateşi'), findsOneWidget);
    expect(find.text('Al'), findsOneWidget);
    expect(find.text('Satın alımları geri yükle'), findsOneWidget);
  });

  testWidgets('buying a coin pack adds the coins through the mock store', (tester) async {
    final repo = InMemoryProgressRepository();
    await tester.pumpWidget(_harness(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.text('₺29,99'));
    await tester.pumpAndSettle();

    expect(repo.coins, 150);
    expect(find.text('150'), findsNWidgets(2)); // pill + card
    expect(find.text('Satın alındı'), findsOneWidget);
  });

  testWidgets('a cancelled purchase grants nothing', (tester) async {
    final repo = InMemoryProgressRepository();
    await tester.pumpWidget(
      _harness(repo, purchases: const MockPurchaseService(result: PurchaseResult.cancelled)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('₺29,99'));
    await tester.pumpAndSettle();
    expect(repo.coins, 0);
  });

  testWidgets('the ad-free unlock flips the hero card to Aktif', (tester) async {
    final repo = InMemoryProgressRepository();
    await tester.pumpWidget(_harness(repo));
    await tester.pumpAndSettle();
    await tester.tap(find.text('₺89,99'));
    await tester.pumpAndSettle();
    expect(repo.adFree, isTrue);
    expect(find.text('Aktif'), findsOneWidget);
    expect(find.text('₺89,99'), findsNothing);
  });

  testWidgets('the campfire pays once, then reads Alındı', (tester) async {
    final repo = InMemoryProgressRepository();
    await tester.pumpWidget(_harness(repo));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Al'));
    await tester.pumpAndSettle();
    expect(repo.coins, 20);
    expect(find.text('Alındı'), findsOneWidget);
    expect(find.text('Al'), findsNothing);
  });

  testWidgets('restore re-grants the ad-free unlock the store still owns', (tester) async {
    final repo = InMemoryProgressRepository();
    await tester.pumpWidget(
      _harness(repo, purchases: const MockPurchaseService(owned: [ProductIds.adFree])),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Satın alımları geri yükle'), 200);
    await tester.ensureVisible(find.text('Satın alımları geri yükle'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Satın alımları geri yükle'));
    await tester.pumpAndSettle();
    expect(repo.adFree, isTrue);
    expect(find.text('Satın alımlar geri yüklendi'), findsOneWidget);
  });
}
