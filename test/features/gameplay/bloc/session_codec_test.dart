// test/features/gameplay/bloc/session_codec_test.dart

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:kelime_oyunu/data/models/puzzle.dart';
import 'package:kelime_oyunu/data/models/saved_session.dart';
import 'package:kelime_oyunu/features/gameplay/bloc/game_state.dart';
import 'package:kelime_oyunu/features/gameplay/bloc/move_narration.dart';
import 'package:kelime_oyunu/features/gameplay/bloc/session_codec.dart';
import 'package:kelime_oyunu/features/gameplay/engine/rack_manager.dart';
import 'package:kelime_oyunu/features/gameplay/engine/score_engine.dart';

// Relative import — test helpers are not importable via package: path.
// ignore: always_use_package_imports
import '../../../helpers/engine_test_fixtures.dart';

final _puzzle = puzzleFromWords([
  buildWord(id: 'w1', answer: 'KOL', startRow: 1, startCol: 1, direction: ClueArrow.right),
  buildWord(id: 'w2', answer: 'KAR', startRow: 1, startCol: 1, direction: ClueArrow.down),
], puzzleId: 12);

/// A mid-match state carrying every field the resume must preserve, plus the
/// transient ones it must drop.
GameActive _midMatch() => GameActive(
  puzzle: _puzzle,
  // Not const: WordCell's Equatable == disqualifies it from const collections.
  board: {const WordCell(row: 1, col: 1): 'K', const WordCell(row: 1, col: 2): 'O'},
  rack: const [
    RackTile(letter: 'A'),
    RackTile(letter: 'R', isPlaced: true),
    RackTile(letter: 'L', isReturned: true),
  ],
  pendingPlacements: const [Placement(cell: WordCell(row: 1, col: 3), letter: 'R', expected: 'L')],
  playerScore: 17,
  botScore: 9,
  phase: TurnPhase.playerTurn,
  botThinking: false,
  status: GameStatus.playing,
  rackSize: RackManager.powerUpRackSize,
  revealedWordIds: const {'w2'},
  selectedRackIndex: 1,
  botPlacedCells: {const WordCell(row: 1, col: 2)},
  swapQuotaRemaining: 4,
  narration: const MoveNarration(id: 3, actor: NarrationActor.bot, events: [], placements: []),
);

void main() {
  group('sessionFromState → stateFromSession', () {
    test('round-trips every field the player would notice losing', () {
      final restored = stateFromSession(sessionFromState(_midMatch()), _puzzle);

      expect(restored.board, _midMatch().board);
      expect(restored.playerScore, 17);
      expect(restored.botScore, 9);
      expect(restored.rack.map((t) => t.letter), ['A', 'R', 'L']);
      expect(restored.rackSize, RackManager.powerUpRackSize);
      expect(restored.revealedWordIds, {'w2'});
      expect(restored.swapQuotaRemaining, 4);
      expect(restored.botPlacedCells, {const WordCell(row: 1, col: 2)});
      expect(restored.puzzle.puzzleId, 12);
    });

    test('resumes on a clean player turn, dropping every transient', () {
      final restored = stateFromSession(sessionFromState(_midMatch()), _puzzle);

      expect(restored.phase, TurnPhase.playerTurn);
      expect(restored.status, GameStatus.playing);
      expect(restored.botThinking, isFalse);
      // An unconfirmed move is not a resume point.
      expect(restored.pendingPlacements, isEmpty);
      expect(restored.selectedRackIndex, -1);
      // F6 narration is never persisted: resume starts after the story ended.
      expect(restored.narration, isNull);
      // Per-turn rack flags are rebuilt, not restored.
      expect(restored.rack.every((t) => !t.isPlaced && !t.isReturned), isTrue);
    });
  });

  group('SavedSession JSON', () {
    test('survives a trip through the string Hive actually stores', () {
      final original = sessionFromState(_midMatch());

      final decoded = SavedSession.fromJson(
        jsonDecode(jsonEncode(original.toJson())) as Map<String, dynamic>,
      );

      expect(decoded, original);
    });

    test('a record from another schema is rejected rather than misread', () {
      final json = sessionFromState(_midMatch()).toJson()..['schema_version'] = 99;

      expect(SavedSession.fromJson(json), isNull);
    });

    test('a malformed record returns null instead of throwing', () {
      expect(SavedSession.fromJson({'schema_version': kSessionSchemaVersion}), isNull);
      expect(
        SavedSession.fromJson({'schema_version': kSessionSchemaVersion, 'level_id': 'oops'}),
        isNull,
      );
    });

    test('summary carries the headline the resume banner shows', () {
      final summary = sessionFromState(_midMatch()).summary;

      expect(summary.levelId, 12);
      expect(summary.playerScore, 17);
      expect(summary.botScore, 9);
    });
  });
}
