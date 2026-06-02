// test/helpers/engine_test_fixtures.dart

import 'package:kelime_oyunu/data/models/puzzle.dart';

// Programmatic PuzzleData builders for engine unit tests. Engines only consume
// letter cells and words, so clue/blank cells are omitted. This is system-under-
// test input constructed in code (cf. the Python `_crossing_template` helpers),
// not a data fixture file (coding-standards.md §4.4).

/// Builds one [WordSpec] laid out from ([startRow], [startCol]) in [direction].
///
/// Letter cells run right or down for `answer.length` cells; the clue cell sits
/// one step before the start in the reading direction.
WordSpec buildWord({
  required String id,
  required String answer,
  required int startRow,
  required int startCol,
  required ClueArrow direction,
  int frequencyScore = 50,
}) {
  final cells = <WordCell>[
    for (var i = 0; i < answer.length; i++)
      WordCell(
        row: direction == ClueArrow.down ? startRow + i : startRow,
        col: direction == ClueArrow.right ? startCol + i : startCol,
      ),
  ];
  final clueCell = direction == ClueArrow.down
      ? WordCell(row: startRow - 1, col: startCol)
      : WordCell(row: startRow, col: startCol - 1);
  return WordSpec(
    id: id,
    answer: answer,
    length: answer.length,
    direction: direction,
    clueCell: clueCell,
    startCell: WordCell(row: startRow, col: startCol),
    cells: cells,
    clue: ClueSpec(
      text: '${answer.length} harfli kelime',
      arrow: direction,
      wordId: id,
      source: 'placeholder',
    ),
    frequencyScore: frequencyScore,
  );
}

/// Derives the merged letter cells for [words], unioning [wordIds] at crossings.
List<CellSpec> letterCellsFor(List<WordSpec> words) {
  final byPos = <WordCell, CellSpec>{};
  for (final word in words) {
    for (var i = 0; i < word.cells.length; i++) {
      final cell = word.cells[i];
      final existing = byPos[cell];
      final ids = existing == null
          ? <String>[word.id]
          : <String>[...existing.wordIds, word.id];
      byPos[cell] = CellSpec(
        row: cell.row,
        col: cell.col,
        type: CellType.letter,
        solution: word.answer[i],
        wordIds: ids,
      );
    }
  }
  return byPos.values.toList();
}

/// Assembles a valid-shaped [PuzzleData] from [words] (letter cells auto-derived).
PuzzleData puzzleFromWords(
  List<WordSpec> words, {
  int rows = 8,
  int cols = 6,
  PuzzleSize size = PuzzleSize.medium,
  int puzzleId = 1,
}) {
  return PuzzleData(
    schemaVersion: 2,
    puzzleId: puzzleId,
    size: size,
    grid: GridSize(rows: rows, cols: cols),
    cells: letterCellsFor(words),
    words: words,
    difficulty: 'medium',
    difficultyScore: 30,
    templateId: 'test_template',
    safety: const SafetyInfo(postFillScanned: true, scannerVersion: '2.0.0'),
    generatedAt: '2026-01-01T00:00:00Z',
    generatorVersion: '2.0.0',
  );
}
