// lib/features/levels/view/level_select_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:kelime_oyunu/core/constants/app_dimensions.dart';
import 'package:kelime_oyunu/core/constants/app_typography.dart';
import 'package:kelime_oyunu/data/repositories/progress_repository.dart';
import 'package:kelime_oyunu/data/repositories/session_repository.dart';
import 'package:kelime_oyunu/features/levels/cubit/level_select_cubit.dart';
import 'package:kelime_oyunu/features/levels/cubit/level_select_state.dart';
import 'package:kelime_oyunu/features/levels/widgets/level_tile.dart';
import 'package:kelime_oyunu/features/levels/widgets/resume_banner.dart';

/// The app's entry screen: pick a level, or continue the interrupted match.
///
/// Replaces the old auto-jump into `/gameplay/1`, which silently discarded
/// every bit of progress the player had made.
class LevelSelectScreen extends StatelessWidget {
  const LevelSelectScreen({required this.progressRepo, required this.sessionRepo, super.key});

  final ProgressRepository progressRepo;
  final SessionRepository sessionRepo;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => LevelSelectCubit(progressRepo: progressRepo, sessionRepo: sessionRepo),
      child: const _LevelSelectBody(),
    );
  }
}

class _LevelSelectBody extends StatelessWidget {
  const _LevelSelectBody();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Bölümler'), centerTitle: true),
      body: SafeArea(
        child: BlocBuilder<LevelSelectCubit, LevelSelectState>(
          builder: (context, state) => Padding(
            padding: const EdgeInsets.all(AppDimensions.spacingM),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (state.resume case final resume?)
                  ResumeBanner(
                    summary: resume,
                    // ?resume=true tells GameScreen to restore rather than restart.
                    onResume: () => context.go('/gameplay/${resume.levelId}?resume=true'),
                  ),
                _ProgressLine(state: state),
                const SizedBox(height: AppDimensions.spacingS),
                Expanded(child: _LevelGrid(state: state)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One-line summary above the grid: how far the player has come.
class _ProgressLine extends StatelessWidget {
  const _ProgressLine({required this.state});

  final LevelSelectState state;

  @override
  Widget build(BuildContext context) {
    final String text = state.allCompleted
        ? 'Tüm bölümler tamamlandı! (${state.levelCount}/${state.levelCount})'
        : '${state.highestCompletedLevel}/${state.levelCount} bölüm tamamlandı';
    return Text(text, style: AppTypography.bodySmall, textAlign: TextAlign.center);
  }
}

/// The 200-level grid.
///
/// A lazy [GridView.builder]: only the visible tiles are built, so the widget
/// count stays bounded. (The no-widgets-per-cell rule of ADR-0004 governs the
/// game board's repaint budget; this is a static, scrollable list.)
class _LevelGrid extends StatefulWidget {
  const _LevelGrid({required this.state});

  final LevelSelectState state;

  @override
  State<_LevelGrid> createState() => _LevelGridState();
}

class _LevelGridState extends State<_LevelGrid> {
  /// Owned here, not built in `build`: a controller created per rebuild would
  /// leak and would yank the grid back to the frontier on every repaint.
  late final ScrollController _controller;

  LevelSelectState get state => widget.state;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Built once, here rather than in initState: the initial offset needs the
    // screen width, and MediaQuery is only reachable once dependencies resolve.
    // Runs before the first build, so _controller is always ready in time.
    if (_built) return;
    _built = true;
    // Scroll straight to the frontier: with 200 levels, a returning player
    // should not have to hunt for the one level they can actually play.
    _controller = ScrollController(
      initialScrollOffset: _initialOffset(MediaQuery.sizeOf(context).width),
    );
  }

  bool _built = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      controller: _controller,
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: _tileExtent,
        mainAxisSpacing: AppDimensions.spacingS,
        crossAxisSpacing: AppDimensions.spacingS,
      ),
      itemCount: state.levelCount,
      itemBuilder: (context, index) {
        final levelId = index + 1;
        final status = state.statusOf(levelId);
        return LevelTile(
          levelId: levelId,
          status: status,
          onTap: state.isPlayable(levelId) ? () => context.go('/gameplay/$levelId') : null,
        );
      },
    );
  }

  /// Tile edge target — [SliverGridDelegateWithMaxCrossAxisExtent] fits as many
  /// columns as this allows, so phones and tablets both get sensible squares
  /// without a hard-coded column count.
  static const double _tileExtent = 72.0;

  /// Puts the frontier row roughly two rows down from the top.
  double _initialOffset(double width) {
    final columns = (width / _tileExtent).ceil().clamp(1, 12);
    final row = (state.currentLevel - 1) ~/ columns;
    const rowHeight = _tileExtent + AppDimensions.spacingS;
    return ((row - 2) * rowHeight).clamp(0.0, double.infinity);
  }
}
