// lib/features/settings/view/settings_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'package:kelime_oyunu/core/constants/app_dimensions.dart';
import 'package:kelime_oyunu/core/constants/app_typography.dart';
import 'package:kelime_oyunu/core/services/consent_service.dart';
import 'package:kelime_oyunu/core/theme/app_tokens.dart';
import 'package:kelime_oyunu/core/widgets/circle_icon_button.dart';
import 'package:kelime_oyunu/data/models/app_settings.dart';
import 'package:kelime_oyunu/data/repositories/progress_repository.dart';
import 'package:kelime_oyunu/data/repositories/session_repository.dart';
import 'package:kelime_oyunu/features/settings/cubit/settings_cubit.dart';
import 'package:kelime_oyunu/features/settings/widgets/settings_rows.dart';
import 'package:kelime_oyunu/l10n/generated/app_localizations.dart';

/// Settings (README "Settings"): OYUN (appearance, sound, haptics, sky) and
/// HESAP (shop, ad preferences, reset, legal) on `bgFlat`, with the version
/// footer. Reads and writes the app-wide [SettingsCubit].
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({
    required this.progressRepo,
    required this.sessionRepo,
    required this.consentService,
    super.key,
  });

  final ProgressRepository progressRepo;
  final SessionRepository sessionRepo;
  final ConsentService consentService;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final l10n = AppLocalizations.of(context);
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
                  tooltip: l10n.appName,
                ),
                const SizedBox(width: AppDimensions.space12),
                Text(
                  l10n.settings,
                  style: AppTypography.screenTitle.copyWith(fontSize: 20, color: tokens.text),
                ),
              ],
            ),
            SettingsSectionLabel(l10n.game),
            const _GameGroup(),
            SettingsSectionLabel(l10n.account),
            _AccountGroup(
              progressRepo: progressRepo,
              sessionRepo: sessionRepo,
              consentService: consentService,
            ),
            const SizedBox(height: AppDimensions.space24),
            const _VersionFooter(),
          ],
        ),
      ),
    );
  }
}

/// Görünüm segmented pill + Ses / Titreşim / Gökyüzü toggles.
class _GameGroup extends StatelessWidget {
  const _GameGroup();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return BlocBuilder<SettingsCubit, AppSettings>(
      builder: (context, settings) {
        final cubit = context.read<SettingsCubit>();
        return SettingsGroup(
          children: [
            SettingsRow(
              label: l10n.appearance,
              trailing: SegmentedPill<ThemeMode>(
                options: [
                  (ThemeMode.light, l10n.appLight),
                  (ThemeMode.dark, l10n.appDark),
                  (ThemeMode.system, l10n.appSystem),
                ],
                selected: settings.themeMode,
                onSelected: cubit.setThemeMode,
              ),
            ),
            SettingsRow(
              label: l10n.sound,
              sub: l10n.soundSub,
              trailing: SettingsToggle(
                value: settings.soundEnabled,
                onChanged: cubit.setSoundEnabled,
              ),
            ),
            SettingsRow(
              label: l10n.haptic,
              sub: l10n.hapticSub,
              trailing: SettingsToggle(
                value: settings.hapticsEnabled,
                onChanged: cubit.setHapticsEnabled,
              ),
            ),
            SettingsRow(
              label: l10n.sky,
              sub: l10n.skySub,
              trailing: SettingsToggle(value: settings.skyEnabled, onChanged: cubit.setSkyEnabled),
            ),
            SettingsRow(label: l10n.howToPlay, onTap: () => context.push('/onboarding')),
          ],
        );
      },
    );
  }
}

/// Reklamları kaldır → Mağaza · Reklam tercihleri › · İlerlemeyi sıfırla →
/// Sil · Gizlilik › · Koşullar ›.
class _AccountGroup extends StatelessWidget {
  const _AccountGroup({
    required this.progressRepo,
    required this.sessionRepo,
    required this.consentService,
  });

  final ProgressRepository progressRepo;
  final SessionRepository sessionRepo;
  final ConsentService consentService;

  Future<void> _adPrefs(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    await consentService.showPrivacyOptions();
    messenger.showSnackBar(SnackBar(content: Text(l10n.adPrefsDone)));
  }

  Future<void> _reset(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final tokens = context.tokens;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.resetConfirmTitle),
        content: Text(l10n.resetConfirmBody),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.cancel)),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: tokens.error),
            child: Text(l10n.del),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await progressRepo.reset();
    await sessionRepo.clear();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final l10n = AppLocalizations.of(context);
    return SettingsGroup(
      children: [
        SettingsRow(
          label: l10n.removeAds,
          trailing: Text(
            l10n.shopLink,
            style: AppTypography.pill.copyWith(fontWeight: FontWeight.w700, color: tokens.arrow),
          ),
          onTap: () => context.push('/shop'),
        ),
        SettingsRow(label: l10n.adPrefs, onTap: () => _adPrefs(context)),
        SettingsRow(
          label: l10n.reset,
          trailing: Text(
            l10n.del,
            style: AppTypography.pill.copyWith(fontWeight: FontWeight.w700, color: tokens.error),
          ),
          onTap: () => _reset(context),
        ),
        SettingsRow(label: l10n.privacy, onTap: () => context.push('/legal/privacy')),
        SettingsRow(label: l10n.terms, onTap: () => context.push('/legal/terms')),
      ],
    );
  }
}

/// "Kelime Zirvesi 1.0.0" — the real version from the platform.
class _VersionFooter extends StatelessWidget {
  const _VersionFooter();

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final l10n = AppLocalizations.of(context);
    return FutureBuilder<PackageInfo>(
      future: PackageInfo.fromPlatform(),
      builder: (context, snapshot) {
        final version = snapshot.data?.version;
        return Text(
          version == null ? l10n.appName : '${l10n.appName} $version',
          textAlign: TextAlign.center,
          style: AppTypography.bodySmall.copyWith(color: tokens.text.withValues(alpha: 0.45)),
        );
      },
    );
  }
}
