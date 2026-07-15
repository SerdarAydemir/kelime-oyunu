// lib/features/gameplay/widgets/narration_layer.dart

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:kelime_oyunu/core/constants/app_colors.dart';
import 'package:kelime_oyunu/data/models/puzzle.dart';
import 'package:kelime_oyunu/features/gameplay/widgets/narration_controller.dart';
import 'package:kelime_oyunu/features/gameplay/widgets/narration_timeline.dart';

/// Transient overlay that draws the score-story visuals — per-letter badges,
/// the word-completion frame/glow, and the word/rack bonus cascade — over the
/// grid, in lock-step with [NarrationController.progress]. It centres itself on
/// the grid with the SAME cell math as [GridPainter] so everything lands on the
/// right cells (it does not follow the InteractiveViewer zoom, but input — and
/// therefore zoom — is locked while narrating).
class NarrationLayer extends StatelessWidget {
  const NarrationLayer({required this.controller, required this.puzzle, super.key});

  final NarrationController controller;
  final PuzzleData puzzle;

  /// Normalized on-screen lifespan of one badge (fraction of the narration).
  static const double _badgeLife = 0.42;

  /// Normalized lifespan of a word-completion frame — longer than a badge so
  /// the highlight lingers while its point badges cascade.
  static const double _frameLife = 0.5;

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
              builder: (context, _) =>
                  Stack(clipBehavior: Clip.none, children: [..._frames(cell), ..._badges(cell)]),
            ),
          ),
        );
      },
    );
  }

  /// Letter cells of a word, resolved once from the puzzle.
  List<WordCell> _wordCells(String wordId) {
    final match = puzzle.words.where((w) => w.id == wordId);
    return match.isEmpty ? const [] : match.first.cells;
  }

  /// A frame/glow around each word completed this move, timed to its first
  /// bonus point landing. Sits under the badges.
  List<Widget> _frames(double cell) {
    final timeline = controller.currentTimeline;
    if (timeline == null) return const [];
    final progress = controller.progress;
    final firstLandByWord = <String, double>{};
    for (final cue in timeline.cues) {
      if (cue.kind != CueKind.wordBonus) continue;
      final id = cue.event.completedWordId;
      if (id == null) continue;
      firstLandByWord[id] = math.min(firstLandByWord[id] ?? 1.0, cue.landAt);
    }
    final frames = <Widget>[];
    firstLandByWord.forEach((id, start) {
      final local = (progress - start) / _frameLife;
      if (local < 0 || local > 1) return;
      final cells = _wordCells(id);
      if (cells.isEmpty) return;
      var minR = cells.first.row, maxR = cells.first.row;
      var minC = cells.first.col, maxC = cells.first.col;
      for (final c in cells) {
        minR = math.min(minR, c.row);
        maxR = math.max(maxR, c.row);
        minC = math.min(minC, c.col);
        maxC = math.max(maxC, c.col);
      }
      frames.add(
        Positioned(
          left: minC * cell,
          top: minR * cell,
          width: (maxC - minC + 1) * cell,
          height: (maxR - minR + 1) * cell,
          child: _WordFrame(local: local, key: ValueKey('frame_$id')),
        ),
      );
    });
    return frames;
  }

  List<Widget> _badges(double cell) {
    final timeline = controller.currentTimeline;
    if (timeline == null) return const [];
    final progress = controller.progress;
    final widgets = <Widget>[];
    final wordSeen = <String, int>{}; // per-word cue index → which cell to anchor
    for (var i = 0; i < timeline.cues.length; i++) {
      final cue = timeline.cues[i];
      // Advance the per-word index even for not-yet-visible cues so each point
      // keeps a stable cell as the cascade plays.
      final anchor = _anchorCell(cue, wordSeen);
      final local = (progress - cue.landAt) / _badgeLife;
      if (local < 0 || local > 1 || anchor == null) continue;
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
            big: cue.kind == CueKind.rackBonus,
            key: ValueKey('badge_${cue.landAt}_$i'),
          ),
        ),
      );
    }
    return widgets;
  }

  /// The cell a cue's badge floats above. Word-bonus points cascade across the
  /// word's cells (index tracked in [wordSeen]); a rack bonus sits at centre.
  WordCell? _anchorCell(NarrationCue cue, Map<String, int> wordSeen) {
    if (cue.event.cell != null) return cue.event.cell;
    if (cue.kind == CueKind.wordBonus && cue.event.completedWordId != null) {
      final id = cue.event.completedWordId!;
      final cells = _wordCells(id);
      final index = wordSeen.update(id, (v) => v + 1, ifAbsent: () => 0);
      if (cells.isEmpty) return null;
      return cells[math.min(index, cells.length - 1)];
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

/// The word-completion highlight: a cell-aligned rounded rect that pops in with
/// an outer glow, holds, then fades. Pure function of [local] ([0,1]).
class _WordFrame extends StatelessWidget {
  const _WordFrame({required this.local, super.key});

  final double local;

  @override
  Widget build(BuildContext context) {
    final appear = Curves.easeOutBack.transform(math.min(1, local / 0.25));
    final fade = local < 0.65 ? 1.0 : 1.0 - (local - 0.65) / 0.35;
    final alpha = (appear * fade).clamp(0.0, 1.0);
    final scale = 0.94 + 0.06 * appear;
    return IgnorePointer(
      child: Opacity(
        opacity: alpha,
        child: Transform.scale(
          scale: scale,
          child: Container(
            margin: const EdgeInsets.all(1.5),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.accent, width: 2.5),
              boxShadow: [
                BoxShadow(
                  color: AppColors.accent.withValues(alpha: 0.55 * alpha),
                  blurRadius: 12,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A single score badge: pops in, floats up, fades out over its [local] life
/// ([0,1]). Pure function of [local] so the driving controller stays the clock.
class _Badge extends StatelessWidget {
  const _Badge({
    required this.text,
    required this.color,
    required this.local,
    this.big = false,
    super.key,
  });

  final String text;
  final Color color;
  final double local;

  /// The rack-empty bonus reads as a headline — a larger pill at grid centre.
  final bool big;

  @override
  Widget build(BuildContext context) {
    // Ease: quick pop (0→0.15), hold, drift up and fade out (0.6→1).
    final appear = Curves.easeOut.transform(math.min(1, local / 0.15));
    final fade = local < 0.6 ? 1.0 : 1.0 - (local - 0.6) / 0.4;
    final rise = -18.0 * Curves.easeOut.transform(local);
    final scale = (big ? 0.7 : 0.6) + 0.4 * appear;
    return Align(
      alignment: big ? Alignment.center : Alignment.topCenter,
      child: Transform.translate(
        offset: Offset(0, big ? rise * 0.5 : -6 + rise),
        child: Opacity(
          opacity: (appear * fade).clamp(0.0, 1.0),
          child: Transform.scale(
            scale: scale,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: big ? 14 : 8, vertical: big ? 6 : 3),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(big ? 16 : 12),
                boxShadow: const [
                  BoxShadow(color: Color(0x40000000), blurRadius: 4, offset: Offset(0, 2)),
                ],
              ),
              child: Text(
                text,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: big ? 22 : 15,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
