// test/features/gameplay/bloc/session_words_found_test.dart

import 'package:flutter_test/flutter_test.dart';

import 'package:kelime_oyunu/data/models/saved_session.dart';

void main() {
  const session = SavedSession(
    levelId: 3,
    board: {},
    rackLetters: ['A'],
    playerScore: 12,
    botScore: 8,
    rackSize: 5,
    revealedWordIds: {},
    swapQuotaRemaining: 12,
    botPlacedCells: {},
    playerWordsFound: 3,
  );

  test('playerWordsFound round-trips through JSON', () {
    final json = session.toJson();
    expect(json['player_words_found'], 3);
    expect(SavedSession.fromJson(json), session);
  });

  test('a schema-1 record without the key reads as 0 (backwards compatible)', () {
    final json = session.toJson()..remove('player_words_found');
    expect(SavedSession.fromJson(json)?.playerWordsFound, 0);
  });
}
