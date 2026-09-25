// lib/features/gameplay/widgets/narration_layer_cues.dart

part of 'package:kelime_oyunu/features/gameplay/widgets/narration_layer.dart';

/// Score cues anchored to cells: evaluation pulses, word-completion frames and
/// the flying score badges. Private extension — same library as [NarrationLayer].
extension _ScoreCues on _NarrationLayerState {
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
      // The pulse lives on the cell while the badge holds there (before it
      // flies off to the score), so the flash and the pill read as one beat.
      final window = (cue.absorbAt - cue.landAt) * NarrationBadge.holdEnds;
      final local = window <= 0 ? 1.1 : (progress - cue.landAt) / window;
      if (local < 0 || local > 1) continue;
      pulses.add(
        Positioned(
          left: cellPos.col * cell,
          top: cellPos.row * cell,
          width: cell,
          height: cell,
          child: CellPulse(
            color: cue.delta >= 0 ? context.tokens.success : context.tokens.error,
            local: local,
            key: ValueKey('pulse_${cue.landAt}_$i'),
          ),
        ),
      );
    }
    return pulses;
  }

  /// A frame/glow around each word completed this move, timed to its first
  /// bonus point landing. Sits under the badges.
  List<Widget> _frames(double cell) {
    final timeline = controller.currentTimeline;
    if (timeline == null) return const [];
    final progress = controller.progress;
    // The frame lives exactly as long as its word cue's badge: it appears as
    // the "+N" lands and fades as the badge is absorbed by the score.
    final windowByWord = <String, (double, double)>{};
    for (final cue in timeline.cues) {
      if (cue.kind != CueKind.wordBonus) continue;
      final id = cue.event.completedWordId;
      if (id == null) continue;
      windowByWord[id] = (cue.landAt, cue.absorbAt);
    }
    final frames = <Widget>[];
    windowByWord.forEach((id, window) {
      final (start, end) = window;
      final span = end - start;
      final local = span <= 0 ? 2.0 : (progress - start) / span;
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
    final target = _scoreTargetLocal(controller.currentActor);
    for (var i = 0; i < timeline.cues.length; i++) {
      final cue = timeline.cues[i];
      final anchor = _anchorCell(cue);
      final span = cue.absorbAt - cue.landAt;
      final local = span <= 0 ? 2.0 : (progress - cue.landAt) / span;
      if (local < 0 || local > 1 || anchor == null) continue;
      // Phase 1 (hold): the badge pops and sits on its cell — a word badge
      // holds much longer, over its spinning golden frame. Phase 2 (fly): it
      // travels to the owner's score display and is absorbed on arrival — the
      // exact moment the counter ticks (absorbAt drives accumulatedDelta).
      final hold = cue.kind == CueKind.wordBonus
          ? NarrationTimeline.wordHoldFraction
          : NarrationBadge.holdEnds;
      final cellOrigin = Offset(anchor.col * cell, anchor.row * cell);
      var origin = cellOrigin;
      if (target != null && local > hold) {
        final t = (local - hold) / (1 - hold);
        final eased = Curves.easeInCubic.transform(t.clamp(0.0, 1.0));
        // Aim the badge's centre at the score display's centre.
        final targetOrigin = target - Offset(cell / 2, cell / 2);
        origin = Offset.lerp(cellOrigin, targetOrigin, eased)!;
      }
      // The badge box is three cells wide, centred on the cell: a "+12"
      // headline pill is wider than one cell and would otherwise wrap to
      // "+" / "12" inside a cell-tight box.
      widgets.add(
        Positioned(
          left: origin.dx - cell,
          top: origin.dy,
          width: cell * 3,
          height: cell,
          child: NarrationBadge(
            text: _label(cue),
            color: _color(cue),
            ink: _ink(cue),
            local: local,
            // Bonuses (word total "+N", rack empty) read as headlines.
            big: cue.kind != CueKind.letter,
            hold: hold,
            key: ValueKey('badge_${cue.landAt}_$i'),
          ),
        ),
      );
    }
    return widgets;
  }
}
