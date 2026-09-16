// lib/features/gameplay/widgets/narration_layer_flights.dart

part of 'package:kelime_oyunu/features/gameplay/widgets/narration_layer.dart';

/// Letters in motion: incoming tiles flying to their cell and wrong letters
/// travelling back home. Private extension — same library as [NarrationLayer].
extension _LetterFlights on _NarrationLayerState {
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

  /// Wrong letters travel HOME: the misplaced letter stays visible on its cell
  /// through its −1 beat, then flies back to where it came from (the rack for
  /// the player, the portrait for the bot) instead of silently vanishing.
  List<Widget> _returningLetters(double cell) {
    final timeline = controller.currentTimeline;
    if (timeline == null) return const [];
    final narration = controller.currentNarration;
    if (narration == null) return const [];
    final progress = controller.progress;
    final home = _sourceLocal(controller.currentActor);
    final letterByCell = {for (final p in narration.placements) p.cell: p.letter};
    final tiles = <Widget>[];
    for (var i = 0; i < timeline.cues.length; i++) {
      final cue = timeline.cues[i];
      final cellPos = cue.event.cell;
      if (cue.kind != CueKind.letter || cue.delta >= 0 || cellPos == null) continue;
      final letter = letterByCell[cellPos];
      if (letter == null) continue;
      final span = cue.absorbAt - cue.landAt;
      final local = span <= 0 ? 2.0 : (progress - cue.landAt) / span;
      if (local > 1) continue; // trip finished — the rack shows the tile now
      final cellOrigin = Offset(cellPos.col * cell, cellPos.row * cell);
      var origin = cellOrigin;
      var fade = 1.0;
      if (local > NarrationBadge.holdEnds && home != null) {
        final t = (local - NarrationBadge.holdEnds) / (1 - NarrationBadge.holdEnds);
        final eased = Curves.easeInCubic.transform(t.clamp(0.0, 1.0));
        origin = Offset.lerp(cellOrigin, home - Offset(cell / 2, cell / 2), eased)!;
        fade = t < 0.8 ? 1.0 : 1.0 - (t - 0.8) / 0.2;
      }
      tiles.add(
        Positioned(
          left: origin.dx,
          top: origin.dy,
          width: cell,
          height: cell,
          child: GhostLetterTile(
            letter: letter,
            size: cell,
            fade: fade,
            key: ValueKey('return_${cue.landAt}_$i'),
          ),
        ),
      );
    }
    return tiles;
  }
}
