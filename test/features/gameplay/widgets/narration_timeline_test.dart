// test/features/gameplay/widgets/narration_timeline_test.dart

import 'package:flutter_test/flutter_test.dart';

import 'package:kelime_oyunu/data/models/puzzle.dart';
import 'package:kelime_oyunu/features/gameplay/bloc/move_narration.dart';
import 'package:kelime_oyunu/features/gameplay/engine/score_engine.dart';
import 'package:kelime_oyunu/features/gameplay/widgets/narration_timeline.dart';

const _c1 = WordCell(row: 1, col: 1);
const _c2 = WordCell(row: 1, col: 2);
const _c3 = WordCell(row: 1, col: 3);

MoveNarration _narration(List<ScoreEvent> events, {List<Placement> placements = const []}) {
  return MoveNarration(id: 0, actor: NarrationActor.player, events: events, placements: placements);
}

void main() {
  group('NarrationTimeline.build', () {
    test('staggers letters so later letters land after earlier ones', () {
      final timeline = NarrationTimeline.build(
        _narration(const [
          ScoreEvent(cell: _c1, delta: 1),
          ScoreEvent(cell: _c2, delta: 1),
          ScoreEvent(cell: _c3, delta: 1),
        ]),
      );
      expect(timeline.cues.length, 3);
      expect(timeline.cues.every((c) => c.kind == CueKind.letter), isTrue);
      // Wave: each letter lifts and lands strictly after the previous one.
      expect(timeline.cues[0].launchAt, lessThan(timeline.cues[1].launchAt));
      expect(timeline.cues[1].launchAt, lessThan(timeline.cues[2].launchAt));
      expect(timeline.cues[0].landAt, lessThan(timeline.cues[2].landAt));
      // A letter lands after it launches (there is a flight span).
      expect(timeline.cues[0].landAt, greaterThan(timeline.cues[0].launchAt));
    });

    test('word and rack bonuses trail the last letter', () {
      final timeline = NarrationTimeline.build(
        _narration(const [
          ScoreEvent(cell: _c1, delta: 1),
          ScoreEvent(cell: _c2, delta: 1),
          ScoreEvent(delta: 2, completedWordId: 'w1', wordBonus: 2),
          ScoreEvent(delta: 5),
        ]),
      );
      final lastLetterLand = timeline.cues
          .where((c) => c.kind == CueKind.letter)
          .map((c) => c.landAt)
          .reduce((a, b) => a > b ? a : b);
      final word = timeline.cues.firstWhere((c) => c.kind == CueKind.wordBonus);
      final rack = timeline.cues.firstWhere((c) => c.kind == CueKind.rackBonus);
      expect(word.landAt, greaterThan(lastLetterLand));
      expect(rack.landAt, greaterThan(word.landAt));
    });

    test('accumulatedDelta counts up cue by cue and never overshoots', () {
      final timeline = NarrationTimeline.build(
        _narration(const [
          ScoreEvent(cell: _c1, delta: 1),
          ScoreEvent(cell: _c2, delta: -1),
          ScoreEvent(delta: 2, completedWordId: 'w1', wordBonus: 2),
        ]),
      );
      expect(timeline.accumulatedDelta(0), 0);
      expect(timeline.accumulatedDelta(1), 2); // 1 - 1 + 2
      // Monotonic-ish: partway through, the running total is between 0 and 2.
      final mid = timeline.accumulatedDelta(0.5);
      expect(mid, inInclusiveRange(-1, 2));
    });

    test('all cue times stay within [0, 1]', () {
      final timeline = NarrationTimeline.build(
        _narration(const [ScoreEvent(cell: _c1, delta: 1), ScoreEvent(delta: 6)]),
      );
      for (final cue in timeline.cues) {
        expect(cue.launchAt, inInclusiveRange(0.0, 1.0));
        expect(cue.landAt, inInclusiveRange(0.0, 1.0));
      }
    });
  });
}
