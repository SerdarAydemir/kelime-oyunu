// lib/features/splash/view/splash_screen.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:kelime_oyunu/core/constants/app_dimensions.dart';
import 'package:kelime_oyunu/core/constants/app_typography.dart';
import 'package:kelime_oyunu/core/theme/app_tokens.dart';
import 'package:kelime_oyunu/core/widgets/app_logo.dart';
import 'package:kelime_oyunu/l10n/generated/app_localizations.dart';

/// First route (design README "Splash"): flat `bgFlat`, the 120 dp logo tile,
/// the app name, the tag line and a thin 120 × 3 progress bar 64 dp from the
/// bottom. Purely cosmetic — storage is already open when the app starts, so
/// the bar simply fills over [duration] and then hands over to [next].
class SplashScreen extends StatefulWidget {
  const SplashScreen({
    this.next = '/levels',
    this.duration = const Duration(milliseconds: 1400),
    super.key,
  });

  /// Route to `go` to once the bar has filled.
  final String next;

  final Duration duration;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _progress = AnimationController(
    vsync: this,
    duration: widget.duration,
  );

  @override
  void initState() {
    super.initState();
    _progress
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed && mounted) context.go(widget.next);
      })
      ..forward();
  }

  @override
  void dispose() {
    _progress.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: tokens.bgFlat,
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const AppLogoTile(),
                  const SizedBox(height: AppDimensions.space24),
                  Text(l10n.appName, style: AppTypography.resultTitle.copyWith(color: tokens.text)),
                  const SizedBox(height: AppDimensions.space8),
                  Text(
                    l10n.homeTag,
                    textAlign: TextAlign.center,
                    style: AppTypography.overline.copyWith(
                      color: tokens.text.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 64,
              child: Center(child: _ProgressBar(progress: _progress)),
            ),
          ],
        ),
      ),
    );
  }
}

/// 120 × 3 dp bar: accent fill over `surface`.
class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.progress});

  final Animation<double> progress;

  static const double _width = 120;
  static const double _height = 3;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return ClipRRect(
      borderRadius: BorderRadius.circular(_height),
      child: SizedBox(
        width: _width,
        height: _height,
        child: ColoredBox(
          color: tokens.surface,
          child: AnimatedBuilder(
            animation: progress,
            builder: (_, _) => Align(
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: progress.value,
                child: ColoredBox(color: tokens.accent),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
