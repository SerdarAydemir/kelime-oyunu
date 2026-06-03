// lib/features/gameplay/engine/board_ops.dart

import 'package:kelime_oyunu/data/models/puzzle.dart';
import 'package:kelime_oyunu/features/gameplay/engine/rack_manager.dart';
import 'package:kelime_oyunu/features/gameplay/engine/score_engine.dart';

// Pure board helpers shared by the gameplay orchestrator. Kept dependency-free
// (only models + value types) so they are trivially unit-testable and keep
// game_bloc.dart focused on event flow.

/// Builds a cell -> solution-letter lookup for the puzzle's letter cells.
Map<WordCell, String> buildSolutionByCell(PuzzleData puzzle) {
  final map = <WordCell, String>{};
  for (final cell in puzzle.cells) {
    if (cell.type != CellType.letter) continue;
    final solution = cell.solution;
    if (solution != null) {
      map[WordCell(row: cell.row, col: cell.col)] = solution;
    }
  }
  return map;
}

/// Whether every letter cell of [puzzle] is committed to [board].
bool isBoardComplete(PuzzleData puzzle, Map<WordCell, String> board) {
  for (final cell in puzzle.cells) {
    if (cell.type != CellType.letter) continue;
    if (!board.containsKey(WordCell(row: cell.row, col: cell.col))) {
      return false;
    }
  }
  return true;
}

/// Marks rack tiles as placed to match [pending] letters, freeing the rest.
///
/// Tiles are fungible by letter, so matching by letter (rather than by index)
/// correctly handles replacing a pending letter on a cell.
List<RackTile> markPlacedTiles(List<RackTile> rack, List<Placement> pending) {
  final remaining = <String, int>{};
  for (final p in pending) {
    remaining.update(p.letter, (v) => v + 1, ifAbsent: () => 1);
  }
  final result = <RackTile>[];
  for (final tile in rack) {
    final count = remaining[tile.letter] ?? 0;
    final placed = count > 0;
    if (placed) remaining[tile.letter] = count - 1;
    result.add(
      RackTile(letter: tile.letter, isPlaced: placed, isReturned: tile.isReturned),
    );
  }
  return result;
}
