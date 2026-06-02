// lib/data/repositories/puzzle_repository.dart

import 'dart:convert';

import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'package:kelime_oyunu/core/errors/app_exception.dart';
import 'package:kelime_oyunu/data/models/puzzle.dart';

/// A single row from the puzzle manifest, summarising one puzzle file.
@immutable
class PuzzleManifestEntry extends Equatable {
  const PuzzleManifestEntry({
    required this.puzzleId,
    required this.file,
    required this.size,
    required this.difficulty,
    required this.difficultyScore,
    required this.templateId,
  });

  factory PuzzleManifestEntry.fromJson(Map<String, dynamic> json) =>
      PuzzleManifestEntry(
        puzzleId: json['puzzle_id'] as int,
        file: json['file'] as String,
        size: json['size'] as String,
        difficulty: json['difficulty'] as String,
        difficultyScore: json['difficulty_score'] as int,
        templateId: json['template_id'] as String,
      );

  final int puzzleId;
  final String file;
  final String size;
  final String difficulty;
  final int difficultyScore;
  final String templateId;

  @override
  List<Object?> get props =>
      [puzzleId, file, size, difficulty, difficultyScore, templateId];
}

/// Source-agnostic puzzle data access contract.
abstract class PuzzleRepository {
  /// Returns all manifest entries. Implementations should cache the result.
  Future<List<PuzzleManifestEntry>> loadManifest();

  /// Returns the full [PuzzleData] for [puzzleId].
  ///
  /// Throws [PuzzleNotFoundException] if the ID is not in the manifest.
  Future<PuzzleData> loadPuzzle(int puzzleId);
}

/// Loads puzzles from the Flutter asset bundle (`assets/puzzles/`).
///
/// Pass [bundle] in tests to avoid requiring the Flutter service binding;
/// when null, falls back to [rootBundle].
class AssetPuzzleRepository implements PuzzleRepository {
  AssetPuzzleRepository({AssetBundle? bundle})
      : _bundle = bundle ?? rootBundle;

  static const String _manifestPath = 'assets/puzzles/manifest.json';
  static const String _puzzlesDir = 'assets/puzzles';

  final AssetBundle _bundle;

  // Caches the in-flight or completed manifest Future so the JSON file is
  // decoded exactly once regardless of how many callers await concurrently.
  Future<List<PuzzleManifestEntry>>? _manifestFuture;

  @override
  Future<List<PuzzleManifestEntry>> loadManifest() =>
      _manifestFuture ??= _fetchManifest();

  Future<List<PuzzleManifestEntry>> _fetchManifest() async {
    final raw = await _bundle.loadString(_manifestPath);
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    return (decoded['puzzles'] as List<dynamic>)
        .map((e) => PuzzleManifestEntry.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<PuzzleData> loadPuzzle(int puzzleId) async {
    final manifest = await loadManifest();
    final matches = manifest.where((e) => e.puzzleId == puzzleId).toList();
    if (matches.isEmpty) {
      throw PuzzleNotFoundException('Puzzle $puzzleId not found in manifest.');
    }
    final entry = matches.first;
    final raw = await _bundle.loadString('$_puzzlesDir/${entry.file}');
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    return PuzzleData.fromJson(decoded);
  }
}
