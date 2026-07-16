// lib/data/models/saved_session.dart

import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';

import 'package:kelime_oyunu/data/models/puzzle.dart';

/// Schema of the persisted match record. Bump when the shape changes; older
/// records are then discarded rather than misread (see [SavedSession.fromJson]).
const int kSessionSchemaVersion = 1;

/// A half-played match, reduced to what a resume actually needs.
///
/// Deliberately *not* stored (architecture.md §11.2, F7 plan §K5):
/// - the [PuzzleData] itself — an immutable ~30KB asset, reloaded by id;
/// - pending placements — an unconfirmed move; empty at a turn boundary anyway;
/// - the narration (F6) — a resume starts from the clean post-narration state;
/// - turn phase / status — a record only exists while the player is to move.
@immutable
class SavedSession extends Equatable {
  const SavedSession({
    required this.levelId,
    required this.board,
    required this.rackLetters,
    required this.playerScore,
    required this.botScore,
    required this.rackSize,
    required this.revealedWordIds,
    required this.swapQuotaRemaining,
    required this.botPlacedCells,
  });

  /// Reads a record back, or returns null if it is from another schema or is
  /// unreadable. A lost half-match is a small loss; a crash on launch is not.
  static SavedSession? fromJson(Map<String, dynamic> json) {
    try {
      if (json['schema_version'] != kSessionSchemaVersion) return null;
      return SavedSession(
        levelId: json['level_id'] as int,
        board: {
          for (final e in json['board'] as List<dynamic>)
            _cell(e as Map<String, dynamic>): (e)['letter'] as String,
        },
        rackLetters: [for (final e in json['rack'] as List<dynamic>) e as String],
        playerScore: json['player_score'] as int,
        botScore: json['bot_score'] as int,
        rackSize: json['rack_size'] as int,
        revealedWordIds: {for (final e in json['revealed_word_ids'] as List<dynamic>) e as String},
        swapQuotaRemaining: json['swap_quota_remaining'] as int,
        botPlacedCells: {
          for (final e in json['bot_placed_cells'] as List<dynamic>)
            _cell(e as Map<String, dynamic>),
        },
      );
    } on Object catch (e) {
      // Catches TypeError/CastError too — a malformed record must never throw
      // into the launch path.
      debugPrint('SavedSession: unreadable record discarded ($e).');
      return null;
    }
  }

  static WordCell _cell(Map<String, dynamic> json) =>
      WordCell(row: json['row'] as int, col: json['col'] as int);

  static Map<String, dynamic> _cellJson(WordCell c) => {'row': c.row, 'col': c.col};

  /// The puzzle / level this match belongs to.
  final int levelId;

  /// Committed letters: solved cells plus their letter.
  final Map<WordCell, String> board;

  /// The rack's letters. Per-turn flags (`isPlaced`, `isReturned`) are dropped:
  /// they describe a turn in progress, and a resume begins a fresh turn.
  final List<String> rackLetters;

  final int playerScore;
  final int botScore;

  /// Rack capacity: 5, or 6 once the +1 letter joker was bought this match.
  final int rackSize;

  /// Words already revealed with a hint — a spent joker must stay spent.
  final Set<String> revealedWordIds;

  /// Swap-joker budget left in this match.
  final int swapQuotaRemaining;

  /// Cells the bot filled, kept so its colour survives the restart.
  final Set<WordCell> botPlacedCells;

  Map<String, dynamic> toJson() => {
    'schema_version': kSessionSchemaVersion,
    'level_id': levelId,
    'board': [
      for (final entry in board.entries) {..._cellJson(entry.key), 'letter': entry.value},
    ],
    'rack': rackLetters,
    'player_score': playerScore,
    'bot_score': botScore,
    'rack_size': rackSize,
    'revealed_word_ids': revealedWordIds.toList(),
    'swap_quota_remaining': swapQuotaRemaining,
    'bot_placed_cells': [for (final c in botPlacedCells) _cellJson(c)],
  };

  /// What the level-select screen shows on its "Devam Et" entry.
  ResumeSummary get summary =>
      ResumeSummary(levelId: levelId, playerScore: playerScore, botScore: botScore);

  @override
  List<Object?> get props => [
    levelId,
    board,
    rackLetters,
    playerScore,
    botScore,
    rackSize,
    revealedWordIds,
    swapQuotaRemaining,
    botPlacedCells,
  ];
}

/// The headline of a resumable match, without loading the whole board.
@immutable
class ResumeSummary extends Equatable {
  const ResumeSummary({required this.levelId, required this.playerScore, required this.botScore});

  final int levelId;
  final int playerScore;
  final int botScore;

  @override
  List<Object?> get props => [levelId, playerScore, botScore];
}
