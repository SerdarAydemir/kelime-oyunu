// lib/core/services/purchase_service.dart

/// Store product ids (the same ids are registered in Play / App Store).
abstract final class ProductIds {
  static const String adFree = 'kz_ad_free';
  static const String coins150 = 'kz_coins_150';
  static const String coins500 = 'kz_coins_500';
}

/// A purchasable item as the shop renders it. Prices come from the store at
/// runtime; the arb `price1..3` strings are placeholders until then.
class ShopProduct {
  const ShopProduct({required this.id, required this.coins});

  final String id;

  /// Coins granted; 0 for the ad-free unlock.
  final int coins;
}

/// Outcome of a purchase attempt.
enum PurchaseResult { purchased, cancelled, failed }

/// Store gate (CLAUDE.md: `in_app_purchase` is forbidden for now; the real
/// billing implementation lands in FAZ 6 behind this same interface).
abstract class PurchaseService {
  List<ShopProduct> get products;

  Future<PurchaseResult> buy(String productId);

  /// Ids of non-consumable purchases the store still knows about.
  Future<List<String>> restore();
}

/// Stand-in: every purchase succeeds instantly; restore returns [owned].
class MockPurchaseService implements PurchaseService {
  const MockPurchaseService({this.result = PurchaseResult.purchased, this.owned = const []});

  final PurchaseResult result;
  final List<String> owned;

  @override
  List<ShopProduct> get products => const [
    ShopProduct(id: ProductIds.adFree, coins: 0),
    ShopProduct(id: ProductIds.coins150, coins: 150),
    ShopProduct(id: ProductIds.coins500, coins: 500),
  ];

  @override
  Future<PurchaseResult> buy(String productId) async => result;

  @override
  Future<List<String>> restore() async => owned;
}
