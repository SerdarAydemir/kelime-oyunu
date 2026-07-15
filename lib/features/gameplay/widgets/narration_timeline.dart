// lib/features/gameplay/widgets/narration_timeline.dart

import 'package:kelime_oyunu/data/models/puzzle.dart';
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
    required this.absorbAt,
    this.letter,
  });

  final CueKind kind;
  final ScoreEvent event;

  /// The placed glyph for a letter cue (null for bonus cues) — the flying tile
  /// shows it as it travels from the rack / bot portrait to the cell.
  final String? letter;

  /// Points this single cue adds to the count-up. Word bonuses are split into
  /// [delta] == 1 cues (one per point) so the frame's badges cascade and the
  /// counter steps letter by letter; a letter/rack cue carries its full delta.
  final int delta;

  /// When the flying letter lifts off (normalized). Equals [landAt] for
  /// cell-less bonus cues, which have no flight.
  final double launchAt;

  /// When the badge pops on the cell (normalized).
  final double landAt;

  /// When the badge — having flown to its owner's score display — is absorbed
  /// and the counter ticks (normalized). The badge lives over [landAt,
  /// absorbAt]: it holds on the cell first, then travels to the score.
  final double absorbAt;
}

/// Maps a [MoveNarration] to an ordered list of [NarrationCue]s and the total
/// real-time duration.
///
/// The rhythm differs by actor. The PLAYER's letters are already sitting on the
/// board when the move confirms — re-flying them from the rack would visibly
/// un-place and re-place them — so they stay put and get evaluated in place,
/// one by one (pulse + badge + counter step). The BOT's letters genuinely
/// arrive from outside, so each flies in from the portrait and scores as it
/// lands. Word / rack bonuses trail the last letter for both.
class NarrationTimeline {
  NarrationTimeline._(this.cues, this.totalMs, this.flightMs);

  final List<NarrationCue> cues;
  final int totalMs;

  /// Flight span (launch→land) in real ms — the layer converts it to a
  /// normalized fraction for the per-tile flight curve.
  final int flightMs;

  // Rhythm (real ms). Steps are wide enough that each letter's score reads as
  // its own beat (~450 ms), keeping a 4-letter move around the ~2 s budget.
  static const int _stepMs = 450;
  static const int _evalDelayMs = 150;
  static const int _flightMs = 500;
  static const int _wordDelayMs = 350;
  static const int _wordStaggerMs = 250;
  static const int _rackDelayMs = 500;

  /// Badge lifetime after landing: it holds on the cell, then flies to the
  /// owner's score display and is absorbed there (the counter ticks on arrival).
  static const int _badgeMs = 600;

  /// A completed word celebrates much longer: the golden frame with its "+N"
  /// badge lingers (~1.5 s, shimmer spinning) before the badge flies off.
  static const int _wordBadgeMs = 1900;

  /// Fraction of a WORD cue's life spent holding before the badge flies
  /// (1500/1900). Letter cues use [NarrationBadge.holdEnds]-style 0.4 in the
  /// layer; exposing this here keeps timeline & layer in sync.
  static const double wordHoldFraction = 1500 / 1900;

  static const int _tailMs = 250;
  static const int _minTotalMs = 900;

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
    final isBot = narration.actor == NarrationActor.bot;
    final lastLandMs = n > 0 ? (n - 1) * _stepMs + (isBot ? _flightMs : _evalDelayMs) : 0;

    // Cell → placed glyph. Only bot cues carry it: a non-null letter is what
    // makes the layer draw a flying tile, and only the bot's letters fly.
    final letterByCell = isBot
        ? {for (final p in narration.placements) p.cell: p.letter}
        : const <WordCell, String>{};

    // kind, event, delta, launchMs, landMs
    final raw = <(CueKind, ScoreEvent, int, int, int)>[];
    for (var i = 0; i < n; i++) {
      final start = i * _stepMs;
      // Player: evaluate in place — no flight, the beat IS the landing.
      final land = start + (isBot ? _flightMs : _evalDelayMs);
      raw.add((CueKind.letter, letters[i], letters[i].delta, isBot ? start : land, land));
    }
    // One cue per completed word: the frame lights the whole word up and a
    // single "+N" badge carries the full bonus (a per-point +1 cascade read as
    // noise). Consecutive words celebrate one after another, and the rack
    // bonus waits for the last celebration to finish.
    var wordCursor = lastLandMs + _wordDelayMs;
    var lastWordAbsorbMs = 0;
    for (final e in words) {
      raw.add((CueKind.wordBonus, e, e.wordBonus ?? e.delta, wordCursor, wordCursor));
      lastWordAbsorbMs = wordCursor + _wordBadgeMs;
      wordCursor += _wordBadgeMs + _wordStaggerMs;
    }
    var rackCursor = lastLandMs + _rackDelayMs;
    if (lastWordAbsorbMs > rackCursor) rackCursor = lastWordAbsorbMs + 100;
    for (final e in racks) {
      raw.add((CueKind.rackBonus, e, e.delta, rackCursor, rackCursor));
      rackCursor += 120;
    }

    var maxMs = _minTotalMs - _tailMs;
    for (final r in raw) {
      final badgeMs = r.$1 == CueKind.wordBonus ? _wordBadgeMs : _badgeMs;
      if (r.$5 + badgeMs > maxMs) maxMs = r.$5 + badgeMs;
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
          absorbAt: (r.$5 + (r.$1 == CueKind.wordBonus ? _wordBadgeMs : _badgeMs)) / totalMs,
          letter: r.$1 == CueKind.letter ? letterByCell[r.$2.cell] : null,
        ),
    ];
    return NarrationTimeline._(cues, totalMs, _flightMs);
  }

  /// Sum of every cue delta whose badge has already been ABSORBED by the score
  /// display at [progress] — the counter ticks exactly when its badge arrives,
  /// so the number visibly "receives" each point (never jumps).
  int accumulatedDelta(double progress) {
    var sum = 0;
    for (final c in cues) {
      if (c.absorbAt <= progress) sum += c.delta;
    }
    return sum;
  }
}
