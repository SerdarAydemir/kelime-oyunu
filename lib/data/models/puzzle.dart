// lib/data/models/puzzle.dart

import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';

part 'package:kelime_oyunu/data/models/puzzle_cells.dart';
part 'package:kelime_oyunu/data/models/puzzle_words.dart';

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
// Cell-level models (ClueSpec, WordCell, CellSpec) live in puzzle_cells.dart and
// word/board-level ones (WordSpec, GridSize, SafetyInfo) in puzzle_words.dart —
// parts of this library, so `package:kelime_oyunu/data/models/puzzle.dart`
// still exposes everything and the private enum parsers stay shared.

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
  }) => PuzzleData(
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
