// lib/features/gameplay/widgets/narration_layer.dart

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:kelime_oyunu/core/constants/app_colors.dart';
import 'package:kelime_oyunu/data/models/puzzle.dart';
import 'package:kelime_oyunu/features/gameplay/bloc/move_narration.dart';
import 'package:kelime_oyunu/features/gameplay/widgets/narration_controller.dart';
import 'package:kelime_oyunu/features/gameplay/widgets/narration_tiles.dart';
import 'package:kelime_oyunu/features/gameplay/widgets/narration_timeline.dart';

/// Transient overlay that draws the score-story visuals — flying letters, the
/// word-completion frame/glow, per-letter and bonus badges — over the grid, in
/// lock-step with [NarrationController.progress]. It centres itself on the grid
/// with the SAME cell math as [GridPainter] so everything lands on the right
/// cells (it does not follow the InteractiveViewer zoom, but input — and so
/// zoom — is locked while narrating).
///
/// Letters fly in from a visible source: the rack for the player ([rackKey]),
/// the bot's avatar for the bot ([botAvatarKey]). Their global positions are
/// converted into this overlay's grid-box coordinate space each frame.
class NarrationLayer extends StatefulWidget {
  const NarrationLayer({
    required this.controller,
    required this.puzzle,
    required this.rackKey,
    required this.botAvatarKey,
    super.key,
  });

  final NarrationController controller;
  final PuzzleData puzzle;
  final GlobalKey rackKey;
  final GlobalKey botAvatarKey;

  @override
  State<NarrationLayer> createState() => _NarrationLayerState();
}

class _NarrationLayerState extends State<NarrationLayer> {
  /// Stable anchor for global→local conversion of the flight sources.
  final GlobalKey _gridBoxKey = GlobalKey();

  /// Normalized on-screen lifespan of one badge (fraction of the narration).
  static const double _badgeLife = 0.42;

  /// Normalized lifespan of a word-completion frame — longer than a badge so
  /// the highlight lingers while its point badges cascade.
  static const double _frameLife = 0.5;

  NarrationController get controller => widget.controller;
  PuzzleData get puzzle => widget.puzzle;

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
            key: _gridBoxKey,
            width: cell * cols,
            height: cell * rows,
            child: AnimatedBuilder(
              animation: controller,
              builder: (context, _) => Stack(
                clipBehavior: Clip.none,
                children: [..._frames(cell), ..._pulses(cell), ..._flights(cell), ..._badges(cell)],
              ),
            ),
          ),
        );
      },
    );
  }

  /// Letter cells of a word, resolved from the puzzle.
  List<WordCell> _wordCells(String wordId) {
    final match = puzzle.words.where((w) => w.id == wordId);
    return match.isEmpty ? const [] : match.first.cells;
  }

  /// Source point (rack or bot avatar) in this overlay's grid-box coordinates,
  /// or null while a key is not yet laid out (fall back to no flight).
  Offset? _sourceLocal(NarrationActor? actor) {
    final key = actor == NarrationActor.bot ? widget.botAvatarKey : widget.rackKey;
    final gridObj = _gridBoxKey.currentContext?.findRenderObject();
    final srcObj = key.currentContext?.findRenderObject();
    if (gridObj is! RenderBox || srcObj is! RenderBox) return null;
    if (!gridObj.hasSize || !srcObj.hasSize) return null;
    final srcGlobal = srcObj.localToGlobal(srcObj.size.center(Offset.zero));
    return gridObj.globalToLocal(srcGlobal);
  }

  /// Evaluation pulses: as each letter cue lands, its cell flashes a coloured
  /// border (green correct / red wrong) so the one-by-one scoring beat has a
  /// clear spatial anchor — the letter itself never moves.
  List<Widget> _pulses(double cell) {
    final timeline = controller.currentTimeline;
    if (timeline == null) return const [];
    final progress = controller.progress;
    final pulses = <Widget>[];
    for (var i = 0; i < timeline.cues.length; i++) {
      final cue = timeline.cues[i];
      final cellPos = cue.event.cell;
      if (cue.kind != CueKind.letter || cellPos == null) continue;
      final local = (progress - cue.landAt) / _badgeLife;
      if (local < 0 || local > 1) continue;
      pulses.add(
        Positioned(
          left: cellPos.col * cell,
          top: cellPos.row * cell,
          width: cell,
          height: cell,
          child: CellPulse(
            color: cue.delta >= 0 ? AppColors.success : AppColors.error,
            local: local,
            key: ValueKey('pulse_${cue.landAt}_$i'),
          ),
        ),
      );
    }
    return pulses;
  }

  /// Flying letters: each tile travels from the source to its cell over the
  /// cue's launch→land window, easing in and out. Only visible while airborne.
  List<Widget> _flights(double cell) {
    final timeline = controller.currentTimeline;
    if (timeline == null) return const [];
    final src = _sourceLocal(controller.currentActor);
    if (src == null) return const [];
    final progress = controller.progress;
    final tiles = <Widget>[];
    for (var i = 0; i < timeline.cues.length; i++) {
      final cue = timeline.cues[i];
      final letter = cue.letter;
      final cellPos = cue.event.cell;
      if (cue.kind != CueKind.letter || letter == null || cellPos == null) continue;
      final span = cue.landAt - cue.launchAt;
      final t = span <= 0 ? 1.0 : (progress - cue.launchAt) / span;
      if (t < 0 || t >= 1) continue; // not launched yet, or already landed
      final target = Offset((cellPos.col + 0.5) * cell, (cellPos.row + 0.5) * cell);
      final pos = Offset.lerp(src, target, Curves.easeInOut.transform(t))!;
      tiles.add(
        Positioned(
          left: pos.dx - cell / 2,
          top: pos.dy - cell / 2,
          width: cell,
          height: cell,
          child: FlyingTile(letter: letter, size: cell, phase: t),
        ),
      );
    }
    return tiles;
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
          child: WordFrame(local: local, key: ValueKey('frame_$id')),
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
    for (var i = 0; i < timeline.cues.length; i++) {
      final cue = timeline.cues[i];
      final anchor = _anchorCell(cue);
      final local = (progress - cue.landAt) / _badgeLife;
      if (local < 0 || local > 1 || anchor == null) continue;
      widgets.add(
        Positioned(
          left: anchor.col * cell,
          top: anchor.row * cell,
          width: cell,
          height: cell,
          child: NarrationBadge(
            text: _label(cue),
            color: _color(cue),
            local: local,
            // Bonuses (word total "+N", rack empty) read as headlines.
            big: cue.kind != CueKind.letter,
            key: ValueKey('badge_${cue.landAt}_$i'),
          ),
        ),
      );
    }
    return widgets;
  }

  /// The cell a cue's badge floats above: the letter's own cell, the middle of
  /// a completed word (its single "+N" badge sits over the lit frame), or the
  /// grid centre for a rack-empty bonus.
  WordCell? _anchorCell(NarrationCue cue) {
    if (cue.event.cell != null) return cue.event.cell;
    if (cue.kind == CueKind.wordBonus && cue.event.completedWordId != null) {
      final cells = _wordCells(cue.event.completedWordId!);
      if (cells.isEmpty) return null;
      return cells[cells.length ~/ 2];
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
