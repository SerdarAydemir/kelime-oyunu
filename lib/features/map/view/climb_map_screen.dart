// lib/features/map/view/climb_map_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:kelime_oyunu/core/config/dev_flags.dart';
import 'package:kelime_oyunu/core/constants/app_dimensions.dart';
import 'package:kelime_oyunu/core/constants/app_typography.dart';
import 'package:kelime_oyunu/core/constants/game_constants.dart';
import 'package:kelime_oyunu/core/theme/app_tokens.dart';
import 'package:kelime_oyunu/core/theme/sky.dart';
import 'package:kelime_oyunu/core/widgets/circle_icon_button.dart';
import 'package:kelime_oyunu/data/repositories/progress_repository.dart';
import 'package:kelime_oyunu/features/map/cubit/map_cubit.dart';
import 'package:kelime_oyunu/features/map/cubit/map_state.dart';
import 'package:kelime_oyunu/features/map/map_layout.dart';
import 'package:kelime_oyunu/features/map/widgets/map_nodes.dart';
import 'package:kelime_oyunu/features/map/widgets/trail_painter.dart';
import 'package:kelime_oyunu/features/settings/cubit/settings_cubit.dart';
import 'package:kelime_oyunu/l10n/generated/app_localizations.dart';

/// The climb map (README "Climb map"): a vertical trail of camps, one per
/// level, with the player's node at 60 % of the viewport on open and ~40
/// fogged nodes above it. Replaces the old 200-tile level grid.
class ClimbMapScreen extends StatelessWidget {
  const ClimbMapScreen({required this.progressRepo, this.unlockAll = kDevUnlockAll, super.key});

  final ProgressRepository progressRepo;

  /// QA override, see [kDevUnlockAll]; injectable for tests.
  final bool unlockAll;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => MapCubit(progressRepo: progressRepo, unlockAll: unlockAll),
      child: const _MapBody(),
    );
  }
}

class _MapBody extends StatelessWidget {
  const _MapBody();

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final skyEnabled = context.watch<SettingsCubit?>()?.state.skyEnabled ?? true;
    return BlocBuilder<MapCubit, MapState>(
      // System back from the map goes home, never out of the app.
      builder: (context, state) => PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) context.go('/');
        },
        child: Scaffold(
          body: Stack(
            children: [
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: mapSky(
                      tokens,
                      progress: state.highestCompletedLevel / kLastLevelId,
                      enabled: skyEnabled,
                    ),
                  ),
                ),
              ),
              Positioned.fill(child: _Trail(state: state)),
              // Sticky fog + header over the top 200 dp. The fog itself lets
              // taps through to the nodes under it; only the back button hits.
              Positioned(top: 0, left: 0, right: 0, child: _FogHeader(state: state)),
              Positioned(
                top: 0,
                left: 0,
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppDimensions.space16,
                      vertical: AppDimensions.space8,
                    ),
                    child: CircleIconButton(
                      icon: Icons.arrow_back,
                      onPressed: () => context.go('/'),
                      tooltip: AppLocalizations.of(context).appName,
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: AppDimensions.space24,
                child: SafeArea(
                  top: false,
                  child: Center(
                    child: Text(
                      AppLocalizations.of(context).camp,
                      style: AppTypography.label.copyWith(
                        color: tokens.text.withValues(alpha: 0.66),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The scrollable trail: nodes positioned by [MapLayout], far dots painted.
class _Trail extends StatefulWidget {
  const _Trail({required this.state});

  final MapState state;

  @override
  State<_Trail> createState() => _TrailState();
}

class _TrailState extends State<_Trail> {
  ScrollController? _controller;

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final layout = MapLayout(
          currentLevel: widget.state.currentLevel,
          width: constraints.maxWidth,
        );
        // Built once the viewport is known: the initial offset puts the
        // current node at 60 % of the viewport height.
        _controller ??= ScrollController(
          initialScrollOffset: layout.initialOffset(constraints.maxHeight),
        );
        return SingleChildScrollView(
          controller: _controller,
          child: SizedBox(
            width: constraints.maxWidth,
            height: layout.contentHeight,
            child: _Nodes(state: widget.state, layout: layout),
          ),
        );
      },
    );
  }
}

class _Nodes extends StatelessWidget {
  const _Nodes({required this.state, required this.layout});

  final MapState state;
  final MapLayout layout;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final asWidget = <int>[];
    final asDot = <int>[];
    for (var n = 1; n <= layout.nodeCount; n++) {
      // Far nodes are painted dots — unless the QA override numbers them.
      final far = state.kindOf(n) == MapNodeKind.far && !state.unlockAll;
      (far ? asDot : asWidget).add(n);
    }
    return Stack(
      children: [
        Positioned.fill(
          child: CustomPaint(
            painter: TrailPainter(layout: layout, tokens: tokens, dotLevels: asDot),
          ),
        ),
        for (final n in asWidget)
          Builder(
            builder: (context) {
              final kind = state.kindOf(n);
              final size = kind == MapNodeKind.far ? 32.0 : MapNode.sizeOf(kind);
              final c = layout.center(n);
              return Positioned(
                left: c.dx - size / 2,
                top: c.dy - size / 2,
                width: size,
                height: size,
                child: MapNode(
                  level: n,
                  kind: kind,
                  showNumber: state.unlockAll,
                  onTap: state.isPlayable(n) ? () => context.go('/gameplay/$n') : null,
                ),
              );
            },
          ),
      ],
    );
  }
}

/// `fog` → transparent over the top 200 dp with ← · "TIRMANIŞ" / "Bölüm n ·
/// m m" and the caption "yukarısı sisin içinde…" (plus the DEV tag under
/// the QA override).
class _FogHeader extends StatelessWidget {
  const _FogHeader({required this.state});

  final MapState state;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final l10n = AppLocalizations.of(context);
    return IgnorePointer(
      child: Container(
        height: 200,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [tokens.fog, tokens.fog.withValues(alpha: 0)],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimensions.space16,
              vertical: AppDimensions.space8,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Keeps the text clear of the back button drawn above the fog.
                const SizedBox(width: AppDimensions.iconButton + AppDimensions.space12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            l10n.climb,
                            style: AppTypography.overline.copyWith(
                              color: tokens.text.withValues(alpha: 0.7),
                            ),
                          ),
                          if (state.unlockAll) ...[
                            const SizedBox(width: AppDimensions.space8),
                            // QA-only label, intentionally not localised.
                            Text(
                              'DEV',
                              style: AppTypography.label.copyWith(
                                color: tokens.accent,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ],
                      ),
                      Text(
                        '${l10n.level} ${state.currentLevel} · ${l10n.meters(state.altitudeMeters)}',
                        style: AppTypography.screenTitle.copyWith(color: tokens.text),
                      ),
                      const SizedBox(height: AppDimensions.space4),
                      Text(
                        l10n.fogUp,
                        style: AppTypography.label.copyWith(
                          color: tokens.text.withValues(alpha: 0.66),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
