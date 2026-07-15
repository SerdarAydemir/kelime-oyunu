// lib/features/gameplay/widgets/narration_layer.dart

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:kelime_oyunu/core/constants/app_colors.dart';
import 'package:kelime_oyunu/data/models/puzzle.dart';
import 'package:kelime_oyunu/features/gameplay/widgets/narration_controller.dart';
import 'package:kelime_oyunu/features/gameplay/widgets/narration_timeline.dart';

/// Transient overlay that draws the score-story badges (+1 / −1 / word / rack
/// bonus) over the grid, in lock-step with [NarrationController.progress]. It
/// centres itself on the grid with the SAME cell math as [GridPainter] so the
/// badges land on the right cells (it does not follow the InteractiveViewer
/// zoom, but input — and therefore zoom — is locked while narrating).
class NarrationLayer extends StatelessWidget {
  const NarrationLayer({required this.controller, required this.puzzle, super.key});

  final NarrationController controller;
  final PuzzleData puzzle;

  /// Normalized on-screen lifespan of one badge (fraction of the narration).
  static const double _badgeLife = 0.42;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cols = puzzle.grid.cols;
        final rows = puzzle.grid.rows;
        final raw = math.min(constraints.maxWidth / cols, constraints.maxHeight / rows);
        final cell = raw.isFinite ? math.max(0.0, raw) : 48.0;
        return Center(
          child: SizedBox(
            width: cell * cols,
            height: cell * rows,
            child: AnimatedBuilder(
              animation: controller,
              builder: (context, _) => Stack(clipBehavior: Clip.none, children: _badges(cell)),
            ),
          ),
        );
      },
    );
  }

  List<Widget> _badges(double cell) {
    final timeline = controller.currentTimeline;
    if (timeline == null) return const [];
    final progress = controller.progress;
    final widgets = <Widget>[];
    for (var i = 0; i < timeline.cues.length; i++) {
      final cue = timeline.cues[i];
      final local = (progress - cue.landAt) / _badgeLife;
      if (local < 0 || local > 1) continue;
      final anchor = _anchorCell(cue);
      if (anchor == null) continue;
      widgets.add(
        Positioned(
          left: anchor.col * cell,
          top: anchor.row * cell,
          width: cell,
          height: cell,
          child: _Badge(
            text: _label(cue),
            color: _color(cue),
            local: local,
            key: ValueKey('badge_${cue.landAt}_$i'),
          ),
        ),
      );
    }
    return widgets;
  }

  /// The cell a cue's badge floats above: the letter's own cell, the middle of
  /// a completed word, or the grid centre for a rack-empty bonus.
  WordCell? _anchorCell(NarrationCue cue) {
    if (cue.event.cell != null) return cue.event.cell;
    if (cue.kind == CueKind.wordBonus && cue.event.completedWordId != null) {
      final word = puzzle.words.where((w) => w.id == cue.event.completedWordId);
      if (word.isNotEmpty && word.first.cells.isNotEmpty) {
        final cells = word.first.cells;
        return cells[cells.length ~/ 2];
      }
    }
    return WordCell(row: puzzle.grid.rows ~/ 2, col: puzzle.grid.cols ~/ 2);
  }

  String _label(NarrationCue cue) => cue.delta >= 0 ? '+${cue.delta}' : '${cue.delta}';

  Color _color(NarrationCue cue) => switch (cue.kind) {
    CueKind.letter => cue.delta >= 0 ? AppColors.success : AppColors.error,
    CueKind.wordBonus => AppColors.accent,
    CueKind.rackBonus => AppColors.accent,
  };
}

/// A single score badge: pops in, floats up, fades out over its [local] life
/// ([0,1]). Pure function of [local] so the driving controller stays the clock.
class _Badge extends StatelessWidget {
  const _Badge({required this.text, required this.color, required this.local, super.key});

  final String text;
  final Color color;
  final double local;

  @override
  Widget build(BuildContext context) {
    // Ease: quick pop (0→0.15), hold, drift up and fade out (0.6→1).
    final appear = Curves.easeOut.transform(math.min(1, local / 0.15));
    final fade = local < 0.6 ? 1.0 : 1.0 - (local - 0.6) / 0.4;
    final rise = -18.0 * Curves.easeOut.transform(local);
    final scale = 0.6 + 0.4 * appear;
    return Align(
      alignment: Alignment.topCenter,
      child: Transform.translate(
        offset: Offset(0, -6 + rise),
        child: Opacity(
          opacity: (appear * fade).clamp(0.0, 1.0),
          child: Transform.scale(
            scale: scale,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(12),
                boxShadow: const [
                  BoxShadow(color: Color(0x40000000), blurRadius: 4, offset: Offset(0, 2)),
                ],
              ),
              child: Text(
                text,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
