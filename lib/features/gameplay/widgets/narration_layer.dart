// lib/features/gameplay/widgets/narration_layer.dart

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:kelime_oyunu/core/constants/app_dimensions.dart';
import 'package:kelime_oyunu/core/theme/app_tokens.dart';
import 'package:kelime_oyunu/data/models/puzzle.dart';
import 'package:kelime_oyunu/features/gameplay/bloc/move_narration.dart';
import 'package:kelime_oyunu/features/gameplay/widgets/narration_controller.dart';
import 'package:kelime_oyunu/features/gameplay/widgets/narration_tiles.dart';
import 'package:kelime_oyunu/features/gameplay/widgets/narration_timeline.dart';

part 'package:kelime_oyunu/features/gameplay/widgets/narration_layer_cues.dart';
part 'package:kelime_oyunu/features/gameplay/widgets/narration_layer_flights.dart';

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
///
/// The per-frame widget builders are grouped by concern in part files:
/// `narration_layer_flights.dart` (letters travelling to / from cells) and
/// `narration_layer_cues.dart` (pulses, word frames, score badges).
class NarrationLayer extends StatefulWidget {
  const NarrationLayer({
    required this.controller,
    required this.puzzle,
    required this.rackKey,
    required this.botAvatarKey,
    this.playerScoreKey,
    super.key,
  });

  final NarrationController controller;
  final PuzzleData puzzle;
  final GlobalKey rackKey;
  final GlobalKey botAvatarKey;

  /// Where a player badge flies to be absorbed (the "Sen" score pill). Bot
  /// badges fly to [botAvatarKey]. Null (tests without a header) → no flight,
  /// badges just fade in place.
  final GlobalKey? playerScoreKey;

  @override
  State<NarrationLayer> createState() => _NarrationLayerState();
}

class _NarrationLayerState extends State<NarrationLayer> {
  /// Stable anchor for global→local conversion of the flight sources.
  final GlobalKey _gridBoxKey = GlobalKey();

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
                children: [
                  ..._frames(cell),
                  ..._pulses(cell),
                  ..._flights(cell),
                  ..._returningLetters(cell),
                  ..._badges(cell),
                ],
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

  /// Centre of the widget behind [key] in this overlay's grid-box coordinates,
  /// or null while it is not laid out.
  Offset? _anchorLocal(GlobalKey? key) {
    final gridObj = _gridBoxKey.currentContext?.findRenderObject();
    final srcObj = key?.currentContext?.findRenderObject();
    if (gridObj is! RenderBox || srcObj is! RenderBox) return null;
    if (!gridObj.hasSize || !srcObj.hasSize) return null;
    final srcGlobal = srcObj.localToGlobal(srcObj.size.center(Offset.zero));
    return gridObj.globalToLocal(srcGlobal);
  }

  /// Source point of a flying LETTER (rack / bot portrait).
  Offset? _sourceLocal(NarrationActor? actor) =>
      _anchorLocal(actor == NarrationActor.bot ? widget.botAvatarKey : widget.rackKey);

  /// Target a score badge flies to: the owner's score display.
  Offset? _scoreTargetLocal(NarrationActor? actor) =>
      _anchorLocal(actor == NarrationActor.bot ? widget.botAvatarKey : widget.playerScoreKey);

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
    CueKind.letter => cue.delta >= 0 ? context.tokens.success : context.tokens.error,
    CueKind.wordBonus => context.tokens.accent,
    CueKind.rackBonus => context.tokens.accent,
  };

  /// Badge text colour: dark ink on the amber bonus pills, cream elsewhere.
  Color _ink(NarrationCue cue) =>
      cue.kind == CueKind.letter ? context.tokens.solidText : context.tokens.accentInk;
}
