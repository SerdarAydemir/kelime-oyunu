// lib/features/shop/cubit/shop_cubit.dart

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:kelime_oyunu/core/services/purchase_service.dart';
import 'package:kelime_oyunu/data/repositories/progress_repository.dart';

/// What the camp shop renders.
class ShopState extends Equatable {
  const ShopState({this.coins = 0, this.adFree = false, this.campfireClaimed = false});

  final int coins;
  final bool adFree;

  /// Today's campfire already taken.
  final bool campfireClaimed;

  @override
  List<Object?> get props => [coins, adFree, campfireClaimed];
}

/// Camp shop (README "Shop"): coins and the ad-free unlock live in the
/// progress record; purchases go through [PurchaseService] (mock until FAZ 6).
class ShopCubit extends Cubit<ShopState> {
  ShopCubit({required this._progressRepo, required this._purchases}) : super(const ShopState()) {
    refresh();
  }

  final ProgressRepository _progressRepo;
  final PurchaseService _purchases;

  List<ShopProduct> get products => _purchases.products;

  void refresh() => emit(
    ShopState(
      coins: _progressRepo.coins,
      adFree: _progressRepo.adFree,
      campfireClaimed: _progressRepo.campfireClaimedToday,
    ),
  );

  /// Buys [productId]; true when the store confirmed and the grant landed.
  Future<bool> buy(String productId) async {
    final result = await _purchases.buy(productId);
    if (result != PurchaseResult.purchased) return false;
    await _grant(productId);
    refresh();
    return true;
  }

  /// "Günlük kamp ateşi": true when today's coins were just added.
  Future<bool> claimCampfire() async {
    final claimed = await _progressRepo.claimDailyCampfire();
    refresh();
    return claimed;
  }

  /// "Satın alımları geri yükle": re-grants the store's non-consumables.
  Future<void> restore() async {
    for (final id in await _purchases.restore()) {
      if (id == ProductIds.adFree) await _progressRepo.setAdFree();
    }
    refresh();
  }

  Future<void> _grant(String productId) async {
    if (productId == ProductIds.adFree) return _progressRepo.setAdFree();
    final product = products.where((p) => p.id == productId);
    if (product.isNotEmpty && product.first.coins > 0) {
      await _progressRepo.addCoins(product.first.coins);
    }
  }
}
