// lib/data/models/puzzle_words.dart

part of 'package:kelime_oyunu/data/models/puzzle.dart';

// ── Word and board-level models ──────────────────────────────────────────────

/// A complete word definition: answer, layout, clue, and frequency metadata.
@immutable
class WordSpec extends Equatable {
  const WordSpec({
    required this.id,
    required this.answer,
    required this.length,
    required this.direction,
    required this.clueCell,
    required this.startCell,
    required this.cells,
    required this.clue,
    required this.frequencyScore,
  });

  factory WordSpec.fromJson(Map<String, dynamic> json) => WordSpec(
    id: json['id'] as String,
    answer: json['answer'] as String,
    length: json['length'] as int,
    direction: _clueArrow(json['direction'] as String),
    clueCell: WordCell.fromJson(json['clue_cell'] as Map<String, dynamic>),
    startCell: WordCell.fromJson(json['start_cell'] as Map<String, dynamic>),
    cells: (json['cells'] as List<dynamic>)
        .map((e) => WordCell.fromJson(e as Map<String, dynamic>))
        .toList(),
    clue: ClueSpec.fromJson(json['clue'] as Map<String, dynamic>),
    frequencyScore: json['frequency_score'] as int,
  );

  final String id;
  final String answer;
  final int length;
  final ClueArrow direction;

  /// Grid coordinate of the clue cell that precedes this word.
  final WordCell clueCell;

  /// Grid coordinate of the first letter cell of this word.
  final WordCell startCell;

  /// Ordered letter cells (clue cell excluded).
  final List<WordCell> cells;

  final ClueSpec clue;

  /// 0–100 frequency rank from the word pool; lower = rarer = harder.
  final int frequencyScore;

  @override
  List<Object?> get props => [
    id,
    answer,
    length,
    direction,
    clueCell,
    startCell,
    cells,
    clue,
    frequencyScore,
  ];
}

/// Board dimensions in cells.
@immutable
class GridSize extends Equatable {
  const GridSize({required this.rows, required this.cols});

  factory GridSize.fromJson(Map<String, dynamic> json) =>
      GridSize(rows: json['rows'] as int, cols: json['cols'] as int);

  final int rows;
  final int cols;

  @override
  List<Object?> get props => [rows, cols];
}

/// Result of the post-fill profanity scan performed by the Python generator.
@immutable
class SafetyInfo extends Equatable {
  const SafetyInfo({required this.postFillScanned, required this.scannerVersion});

  factory SafetyInfo.fromJson(Map<String, dynamic> json) => SafetyInfo(
    postFillScanned: json['post_fill_scanned'] as bool,
    scannerVersion: json['scanner_version'] as String,
  );

  final bool postFillScanned;
  final String scannerVersion;

  @override
  List<Object?> get props => [postFillScanned, scannerVersion];
}
