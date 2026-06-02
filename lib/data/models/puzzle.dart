// lib/data/models/puzzle.dart

import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';

// ── Enums ─────────────────────────────────────────────────────────────────────

/// Reading direction of a word: right (→) or down (↓).
enum ClueArrow { right, down }

/// The role a grid cell plays in the puzzle layout.
enum CellType { letter, clue, blank }

/// Named grid-size tier matching the Python schema (architecture.md §5.3).
enum PuzzleSize { small, medium, large }

// ── Enum parsers (package-private) ───────────────────────────────────────────

ClueArrow _clueArrow(String v) => switch (v) {
      'right' => ClueArrow.right,
      'down' => ClueArrow.down,
      _ => throw ArgumentError('Unknown ClueArrow: $v'),
    };

CellType _cellType(String v) => switch (v) {
      'letter' => CellType.letter,
      'clue' => CellType.clue,
      'blank' => CellType.blank,
      _ => throw ArgumentError('Unknown CellType: $v'),
    };

PuzzleSize _puzzleSize(String v) => switch (v) {
      'small' => PuzzleSize.small,
      'medium' => PuzzleSize.medium,
      'large' => PuzzleSize.large,
      _ => throw ArgumentError('Unknown PuzzleSize: $v'),
    };

// ── Models ────────────────────────────────────────────────────────────────────

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
        wordIds:
            (json['word_ids'] as List<dynamic>).map((e) => e as String).toList(),
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
  const SafetyInfo({
    required this.postFillScanned,
    required this.scannerVersion,
  });

  factory SafetyInfo.fromJson(Map<String, dynamic> json) => SafetyInfo(
        postFillScanned: json['post_fill_scanned'] as bool,
        scannerVersion: json['scanner_version'] as String,
      );

  final bool postFillScanned;
  final String scannerVersion;

  @override
  List<Object?> get props => [postFillScanned, scannerVersion];
}

/// Top-level puzzle model — the v2 JSON contract (architecture.md §4).
///
/// Immutable Dart mirror of the Python PuzzleData Pydantic model. The Python
/// generator is the single source of truth; this class only parses and holds.
/// No validation is performed here — all invariants are guaranteed at
/// generation time and enforced by the Python schema.
@immutable
class PuzzleData extends Equatable {
  const PuzzleData({
    required this.schemaVersion,
    required this.puzzleId,
    required this.size,
    required this.grid,
    required this.cells,
    required this.words,
    required this.difficulty,
    required this.difficultyScore,
    required this.templateId,
    required this.safety,
    required this.generatedAt,
    required this.generatorVersion,
  });

  factory PuzzleData.fromJson(Map<String, dynamic> json) => PuzzleData(
        schemaVersion: json['schema_version'] as int,
        puzzleId: json['puzzle_id'] as int,
        size: _puzzleSize(json['size'] as String),
        grid: GridSize.fromJson(json['grid'] as Map<String, dynamic>),
        cells: (json['cells'] as List<dynamic>)
            .map((e) => CellSpec.fromJson(e as Map<String, dynamic>))
            .toList(),
        words: (json['words'] as List<dynamic>)
            .map((e) => WordSpec.fromJson(e as Map<String, dynamic>))
            .toList(),
        difficulty: json['difficulty'] as String,
        difficultyScore: json['difficulty_score'] as int,
        templateId: json['template_id'] as String,
        safety: SafetyInfo.fromJson(json['safety'] as Map<String, dynamic>),
        generatedAt: json['generated_at'] as String,
        generatorVersion: json['generator_version'] as String,
      );

  final int schemaVersion;
  final int puzzleId;
  final PuzzleSize size;
  final GridSize grid;
  final List<CellSpec> cells;
  final List<WordSpec> words;
  final String difficulty;
  final int difficultyScore;
  final String templateId;
  final SafetyInfo safety;
  final String generatedAt;
  final String generatorVersion;

  /// Returns a shallow copy with the specified fields replaced.
  PuzzleData copyWith({
    int? schemaVersion,
    int? puzzleId,
    PuzzleSize? size,
    GridSize? grid,
    List<CellSpec>? cells,
    List<WordSpec>? words,
    String? difficulty,
    int? difficultyScore,
    String? templateId,
    SafetyInfo? safety,
    String? generatedAt,
    String? generatorVersion,
  }) =>
      PuzzleData(
        schemaVersion: schemaVersion ?? this.schemaVersion,
        puzzleId: puzzleId ?? this.puzzleId,
        size: size ?? this.size,
        grid: grid ?? this.grid,
        cells: cells ?? this.cells,
        words: words ?? this.words,
        difficulty: difficulty ?? this.difficulty,
        difficultyScore: difficultyScore ?? this.difficultyScore,
        templateId: templateId ?? this.templateId,
        safety: safety ?? this.safety,
        generatedAt: generatedAt ?? this.generatedAt,
        generatorVersion: generatorVersion ?? this.generatorVersion,
      );

  @override
  List<Object?> get props => [
        schemaVersion,
        puzzleId,
        size,
        grid,
        cells,
        words,
        difficulty,
        difficultyScore,
        templateId,
        safety,
        generatedAt,
        generatorVersion,
      ];
}
