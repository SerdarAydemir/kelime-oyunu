// test/features/map/map_state_test.dart

import 'package:flutter_test/flutter_test.dart';

import 'package:kelime_oyunu/core/constants/game_constants.dart';
import 'package:kelime_oyunu/features/map/cubit/map_state.dart';
import 'package:kelime_oyunu/features/map/map_layout.dart';

void main() {
  group('MapState', () {
    test('a new player: level 1 is current, 2–3 upcoming, the rest far', () {
      const s = MapState();
      expect(s.currentLevel, 1);
      expect(s.kindOf(1), MapNodeKind.current);
      expect(s.kindOf(2), MapNodeKind.upcoming);
      expect(s.kindOf(3), MapNodeKind.upcoming);
      expect(s.kindOf(4), MapNodeKind.far);
      expect(s.isPlayable(1), isTrue);
      expect(s.isPlayable(2), isFalse);
    });

    test('won levels are done and replayable; the frontier is highlighted', () {
      const s = MapState(highestCompletedLevel: 3);
      expect(s.kindOf(1), MapNodeKind.done);
      expect(s.kindOf(3), MapNodeKind.done);
      expect(s.kindOf(4), MapNodeKind.current);
      expect(s.kindOf(6), MapNodeKind.upcoming);
      expect(s.kindOf(7), MapNodeKind.far);
      expect(s.isPlayable(3), isTrue);
      expect(s.isPlayable(4), isTrue);
      expect(s.isPlayable(5), isFalse);
      expect(s.altitudeMeters, 120);
    });

    test('the last level stays current once everything else is won', () {
      const s = MapState(highestCompletedLevel: kLastLevelId - 1);
      expect(s.currentLevel, kLastLevelId);
      expect(s.kindOf(kLastLevelId), MapNodeKind.current);
    });

    test('unlockAll makes every shipped level playable without changing its kind', () {
      const s = MapState(unlockAll: true);
      expect(s.kindOf(kLastLevelId), MapNodeKind.far);
      expect(s.isPlayable(kLastLevelId), isTrue);
      expect(s.isPlayable(kLastLevelId + 1), isFalse);
      expect(s.isPlayable(0), isFalse);
    });
  });

  group('MapLayout', () {
    test('always renders ~40 nodes of fog above the player, at least 80', () {
      expect(const MapLayout(currentLevel: 1, width: 390).nodeCount, 80);
      expect(const MapLayout(currentLevel: 50, width: 390).nodeCount, 90);
      expect(const MapLayout(currentLevel: 1, width: 390).contentHeight, 80 * 96 + 240);
    });

    test('nodes climb 96 dp per level from 140 dp above the bottom', () {
      const layout = MapLayout(currentLevel: 1, width: 390);
      expect(layout.center(1).dy, layout.contentHeight - 140);
      expect(layout.center(2).dy, layout.contentHeight - 140 - 96);
      // x sways around the centre within ±30 % of the width.
      for (var n = 1; n <= 80; n++) {
        expect(layout.center(n).dx, inInclusiveRange(195 - 118, 195 + 118));
      }
    });

    test('the initial offset puts the current node at 60 % of the viewport', () {
      const layout = MapLayout(currentLevel: 10, width: 390);
      final offset = layout.initialOffset(800);
      expect(layout.center(10).dy - offset, 480);
    });
  });
}
