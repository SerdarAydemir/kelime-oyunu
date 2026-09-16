// lib/data/models/puzzle_cells.dart

part of 'package:kelime_oyunu/data/models/puzzle.dart';

// ── Cell-level models ────────────────────────────────────────────────────────

/// A single clue pointing at one word, carrying its display text and direction.
@immutable
class ClueSpec extends Equatable {
  const ClueSpec({
    required this.text,
    required this.arrow,
    required this.wordId,
    required this.source,
    this.imageId,
  });

  factory ClueSpec.fromJson(Map<String, dynamic> json) => ClueSpec(
    text: json['text'] as String,
    arrow: _clueArrow(json['arrow'] as String),
    wordId: json['word_id'] as String,
    source: json['source'] as String,
    imageId: json['image_id'] as String?,
  );

  final String text;
  final ClueArrow arrow;
  final String wordId;

  /// Optional image asset identifier (null until visual clues are implemented).
  final String? imageId;

  /// Provenance of the clue text: "tdk" | "llm" | "placeholder".
  final String source;

  @override
  List<Object?> get props => [text, arrow, wordId, imageId, source];
}

/// A single grid coordinate that belongs to a word's answer path.
@immutable
class WordCell extends Equatable {
  const WordCell({required this.row, required this.col});

  factory WordCell.fromJson(Map<String, dynamic> json) =>
      WordCell(row: json['row'] as int, col: json['col'] as int);

  final int row;
  final int col;

  @override
  List<Object?> get props => [row, col];
}

/// A single grid cell with its role-specific payload.
///
/// - [CellType.letter] — carries [solution] and [wordIds].
/// - [CellType.clue]   — carries 1–2 [clues] (double-clue cells have 2).
/// - [CellType.blank]  — all payload fields are empty / null.
@immutable
class CellSpec extends Equatable {
  const CellSpec({
    required this.row,
    required this.col,
    required this.type,
    this.solution,
    this.wordIds = const [],
    this.clues = const [],
  });

  factory CellSpec.fromJson(Map<String, dynamic> json) => CellSpec(
    row: json['row'] as int,
    col: json['col'] as int,
    type: _cellType(json['type'] as String),
    solution: json['solution'] as String?,
    wordIds: (json['word_ids'] as List<dynamic>).map((e) => e as String).toList(),
    clues: (json['clues'] as List<dynamic>)
        .map((e) => ClueSpec.fromJson(e as Map<String, dynamic>))
        .toList(),
  );

  final int row;
  final int col;
  final CellType type;

  /// The correct Turkish upper-case letter; null for clue / blank cells.
  final String? solution;

  /// IDs of every word that occupies this cell (≥ 2 at intersections).
  final List<String> wordIds;

  /// Clue specs attached to this cell; empty for letter / blank cells.
  final List<ClueSpec> clues;

  @override
  List<Object?> get props => [row, col, type, solution, wordIds, clues];
}
