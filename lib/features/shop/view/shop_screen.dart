// lib/features/shop/view/shop_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:kelime_oyunu/core/constants/app_dimensions.dart';
import 'package:kelime_oyunu/core/constants/app_typography.dart';
import 'package:kelime_oyunu/core/services/purchase_service.dart';
import 'package:kelime_oyunu/core/theme/app_tokens.dart';
import 'package:kelime_oyunu/core/widgets/circle_icon_button.dart';
import 'package:kelime_oyunu/data/repositories/progress_repository.dart';
import 'package:kelime_oyunu/features/settings/widgets/settings_rows.dart';
import 'package:kelime_oyunu/features/shop/cubit/shop_cubit.dart';
import 'package:kelime_oyunu/features/shop/widgets/shop_cards.dart';
import 'package:kelime_oyunu/l10n/generated/app_localizations.dart';

/// Camp shop (README "Shop"): coin pill, the ad-free hero card, two coin
/// packs, the daily campfire and "Satın alımları geri yükle".
class ShopScreen extends StatelessWidget {
  const ShopScreen({required this.progressRepo, required this.purchases, super.key});

  final ProgressRepository progressRepo;
  final PurchaseService purchases;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => ShopCubit(progressRepo: progressRepo, purchases: purchases),
      child: const _ShopBody(),
    );
  }
}

class _ShopBody extends StatelessWidget {
  const _ShopBody();

  void _toast(BuildContext context, String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  Future<void> _buy(BuildContext context, String id) async {
    final l10n = AppLocalizations.of(context);
    final cubit = context.read<ShopCubit>();
    if (await cubit.buy(id) && context.mounted) _toast(context, l10n.purchased);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final l10n = AppLocalizations.of(context);
    // Placeholder prices until the store supplies localised ones (FAZ 6).
    final prices = {
      ProductIds.adFree: l10n.price1,
      ProductIds.coins150: l10n.price2,
      ProductIds.coins500: l10n.price3,
    };
    return BlocBuilder<ShopCubit, ShopState>(
      builder: (context, state) {
        final cubit = context.read<ShopCubit>();
        return Scaffold(
          backgroundColor: tokens.bgFlat,
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                AppDimensions.space16,
                AppDimensions.space8,
                AppDimensions.space16,
                AppDimensions.space24,
              ),
              children: [
                Row(
                  children: [
                    CircleIconButton(
                      icon: Icons.arrow_back,
                      onPressed: () => context.canPop() ? context.pop() : context.go('/'),
                      tooltip: l10n.settings,
                    ),
                    const SizedBox(width: AppDimensions.space12),
                    Expanded(
                      child: Text(
                        l10n.shop,
                        style: AppTypography.screenTitle.copyWith(fontSize: 20, color: tokens.text),
                      ),
                    ),
                    CoinPill(coins: state.coins),
                  ],
                ),
                const SizedBox(height: AppDimensions.space16),
                AdFreeCard(
                  owned: state.adFree,
                  price: prices[ProductIds.adFree]!,
                  onTap: () => _buy(context, ProductIds.adFree),
                ),
                SettingsSectionLabel(l10n.coins),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final product in cubit.products.where((p) => p.coins > 0)) ...[
                      if (product.id != ProductIds.coins150)
                        const SizedBox(width: AppDimensions.space10),
                      Expanded(
                        child: CoinPackCard(
                          coins: product.coins,
                          unlocks: product.coins ~/ 10,
                          price: prices[product.id] ?? '',
                          featured: product.id == ProductIds.coins500,
                          onTap: () => _buy(context, product.id),
                        ),
                      ),
                    ],
                  ],
                ),
                SettingsSectionLabel(l10n.free),
                SettingsGroup(
                  children: [
                    SettingsRow(
                      label: l10n.daily,
                      sub: l10n.dailySub,
                      trailing: state.campfireClaimed
                          ? PriceChip(label: l10n.claimed, outlined: true)
                          : GestureDetector(
                              onTap: () => cubit.claimCampfire(),
                              child: PriceChip(label: l10n.getReward),
                            ),
                    ),
                  ],
                ),
                const SizedBox(height: AppDimensions.space24),
                TextButton(
                  onPressed: () async {
                    await cubit.restore();
                    if (context.mounted) _toast(context, l10n.restored);
                  },
                  style: TextButton.styleFrom(foregroundColor: tokens.text.withValues(alpha: 0.7)),
                  child: Text(l10n.restore),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
