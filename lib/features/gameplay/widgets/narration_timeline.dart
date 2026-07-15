// lib/features/gameplay/widgets/narration_timeline.dart

import 'package:kelime_oyunu/features/gameplay/bloc/move_narration.dart';
import 'package:kelime_oyunu/features/gameplay/engine/score_engine.dart';

/// The visual role a cue plays in the score story.
enum CueKind { letter, wordBonus, rackBonus }

/// One timed beat of a move's narration: a scoring [event] mapped onto a
/// normalized launch/land moment. Pure timing data — no Flutter, no colours
/// (the widget layer owns rendering). Times are fractions of the whole
/// narration in [0, 1] so a single [AnimationController.value] drives them.
class NarrationCue {
  const NarrationCue({
    required this.kind,
    required this.event,
    required this.delta,
    required this.launchAt,
    required this.landAt,
  });

  final CueKind kind;
  final ScoreEvent event;

  /// Points this single cue adds to the count-up. Word bonuses are split into
  /// [delta] == 1 cues (one per point) so the frame's badges cascade and the
  /// counter steps letter by letter; a letter/rack cue carries its full delta.
  final int delta;

  /// When the flying letter lifts off (normalized). Equals [landAt] for
  /// cell-less bonus cues, which have no flight.
  final double launchAt;

  /// When the badge pops and the score counter absorbs this cue (normalized).
  final double landAt;
}

/// Maps a [MoveNarration] to an ordered list of [NarrationCue]s and the total
/// real-time duration. Letters lift in a wave ([_staggerMs] apart) so the first
/// lands while the next is airborne; word / rack bonuses trail the last letter.
class NarrationTimeline {
  NarrationTimeline._(this.cues, this.totalMs, this.flightMs);

  final List<NarrationCue> cues;
  final int totalMs;

  /// Flight span (launch→land) in real ms — the layer converts it to a
  /// normalized fraction for the per-tile flight curve.
  final int flightMs;

  // Wave rhythm (real ms). Tuned so a 4-letter move reads as ~1.2 s at 1×,
  // inside the ~1.5–2 s per-move budget, with each letter still separable.
  static const int _staggerMs = 90;
  static const int _flightMs = 360;
  static const int _wordDelayMs = 170;
  static const int _wordStaggerMs = 70;
  static const int _rackDelayMs = 340;
  static const int _tailMs = 360;
  static const int _minTotalMs = 700;

  factory NarrationTimeline.build(MoveNarration narration) {
    final letters = <ScoreEvent>[];
    final words = <ScoreEvent>[];
    final racks = <ScoreEvent>[];
    for (final e in narration.events) {
      if (e.cell != null) {
        letters.add(e);
      } else if (e.completedWordId != null) {
        words.add(e);
      } else {
        racks.add(e);
      }
    }

    final n = letters.length;
    final lastLandMs = n > 0 ? (n - 1) * _staggerMs + _flightMs : 0;

    // kind, event, delta, launchMs, landMs
    final raw = <(CueKind, ScoreEvent, int, int, int)>[];
    for (var i = 0; i < n; i++) {
      final launch = i * _staggerMs;
      raw.add((CueKind.letter, letters[i], letters[i].delta, launch, launch + _flightMs));
    }
    // Split each word bonus into one +1 cue per point so the frame's badges
    // cascade across the word and the counter steps letter by letter.
    var wordCursor = lastLandMs + _wordDelayMs;
    for (final e in words) {
      final count = e.wordBonus ?? e.delta;
      for (var k = 0; k < count; k++) {
        raw.add((CueKind.wordBonus, e, 1, wordCursor, wordCursor));
        wordCursor += _wordStaggerMs;
      }
    }
    var rackCursor = lastLandMs + _rackDelayMs;
    if (wordCursor > rackCursor) rackCursor = wordCursor + 80;
    for (final e in racks) {
      raw.add((CueKind.rackBonus, e, e.delta, rackCursor, rackCursor));
      rackCursor += 120;
    }

    var maxMs = _minTotalMs - _tailMs;
    for (final r in raw) {
      if (r.$5 > maxMs) maxMs = r.$5;
    }
    final totalMs = maxMs + _tailMs;

    final cues = [
      for (final r in raw)
        NarrationCue(
          kind: r.$1,
          event: r.$2,
          delta: r.$3,
          launchAt: r.$4 / totalMs,
          landAt: r.$5 / totalMs,
        ),
    ];
    return NarrationTimeline._(cues, totalMs, _flightMs);
  }

  /// Sum of every cue delta whose badge has already landed at [progress] — the
  /// count-up value the score counter shows (never jumps: it steps per cue).
  int accumulatedDelta(double progress) {
    var sum = 0;
    for (final c in cues) {
      if (c.landAt <= progress) sum += c.delta;
    }
    return sum;
  }
}
