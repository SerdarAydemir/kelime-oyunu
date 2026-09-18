// test/features/gameplay/engine/board_ops_test.dart

import 'package:flutter_test/flutter_test.dart';

import 'package:kelime_oyunu/data/models/puzzle.dart';
import 'package:kelime_oyunu/features/gameplay/engine/board_ops.dart';
import 'package:kelime_oyunu/features/gameplay/engine/rack_manager.dart';
import 'package:kelime_oyunu/features/gameplay/engine/score_engine.dart';

const _c1 = WordCell(row: 1, col: 1);
const _c2 = WordCell(row: 1, col: 2);

const _rack = [RackTile(letter: 'K'), RackTile(letter: 'K'), RackTile(letter: 'O')];

List<bool> _placed(List<RackTile> rack) => rack.map((t) => t.isPlaced).toList();

void main() {
  group('markPlacedTiles', () {
    test('pins the exact rack slot a placement came from', () {
      final rack = markPlacedTiles(_rack, const [
        Placement(cell: _c1, letter: 'K', expected: 'K', rackIndex: 1),
      ]);
      expect(_placed(rack), [false, true, false]);
    });

    test('two same-letter placements each keep their own slot', () {
      final both = markPlacedTiles(_rack, const [
        Placement(cell: _c1, letter: 'K', expected: 'K', rackIndex: 0),
        Placement(cell: _c2, letter: 'K', expected: 'K', rackIndex: 1),
      ]);
      expect(_placed(both), [true, true, false]);

      // Recall the second: slot 0 must stay placed, slot 1 must come free.
      final afterRecall = markPlacedTiles(_rack, const [
        Placement(cell: _c1, letter: 'K', expected: 'K', rackIndex: 0),
      ]);
      expect(_placed(afterRecall), [true, false, false]);
    });

    test('index-less placements fall back to letter matching', () {
      final rack = markPlacedTiles(_rack, const [Placement(cell: _c1, letter: 'K', expected: 'K')]);
      expect(_placed(rack), [true, false, false]);
    });

    test('a stale or mismatched index falls back to letter matching', () {
      final stale = markPlacedTiles(_rack, const [
        Placement(cell: _c1, letter: 'K', expected: 'K', rackIndex: 7),
      ]);
      expect(_placed(stale), [true, false, false]);

      final mismatch = markPlacedTiles(_rack, const [
        Placement(cell: _c1, letter: 'O', expected: 'O', rackIndex: 0), // slot 0 is K
      ]);
      expect(_placed(mismatch), [false, false, true]);
    });

    test('keeps isReturned and never marks more tiles than placements', () {
      final rack = markPlacedTiles(
        const [RackTile(letter: 'K', isReturned: true), RackTile(letter: 'K')],
        const [Placement(cell: _c1, letter: 'K', expected: 'K', rackIndex: 1)],
      );
      expect(rack[0].isReturned, isTrue);
      expect(_placed(rack), [false, true]);
    });
  });
}
