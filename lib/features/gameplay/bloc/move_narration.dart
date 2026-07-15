// lib/features/gameplay/bloc/move_narration.dart

import 'package:equatable/equatable.dart';

import 'package:kelime_oyunu/features/gameplay/engine/score_engine.dart';

/// Who made the move a narration describes. Selects the flight source in the UI
/// layer: the rack for the player, the avatar portrait for the bot.
enum NarrationActor { player, bot }

/// An immutable, timing-free description of the move that just resolved, handed
/// to the UI narration layer to replay as an animated score story.
///
/// Scoring is unchanged — this only mirrors [ScoreEngine]'s existing output for
/// display. The widget layer owns the clock; the bloc only tags the move so the
/// UI knows *what* to narrate and *who* acted.
class MoveNarration extends Equatable {
  const MoveNarration({
    required this.id,
    required this.actor,
    required this.events,
    required this.placements,
  });

  /// Monotonic id (per bloc). Lets the UI detect a fresh narration even when two
  /// consecutive moves produce byte-identical events.
  final int id;

  final NarrationActor actor;

  /// Ordered scoring events (per-letter +1/-1, word bonus, rack-empty bonus).
  final List<ScoreEvent> events;

  /// The letters this move placed (target cell + letter + correctness) — the
  /// flight subjects. Correct ones commit to the board; wrong ones bounce back.
  final List<Placement> placements;

  /// Net score change this move carries (sum of every event delta).
  int get scoreDelta => events.fold(0, (sum, e) => sum + e.delta);

  /// Nothing to narrate (a pass, or a bot turn that placed no letters).
  bool get isEmpty => placements.isEmpty && events.isEmpty;

  @override
  List<Object?> get props => [id, actor, events, placements];
}
