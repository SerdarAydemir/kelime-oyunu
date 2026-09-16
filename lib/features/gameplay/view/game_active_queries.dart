// lib/features/gameplay/view/game_active_queries.dart

import 'package:collection/collection.dart';
import 'package:kelime_oyunu/data/models/puzzle.dart';
import 'package:kelime_oyunu/features/gameplay/bloc/game_state.dart';

/// Read-only cell lookups the game screen needs while routing taps and drags.
/// Pure functions of the state — no bloc access, no side effects.
extension GameActiveQueries on GameActive {
  /// The clue spec at [cell], or null when the cell is not a clue cell.
  CellSpec? clueSpecAt(WordCell cell) => puzzle.cells.firstWhereOrNull(
    (c) => c.type == CellType.clue && c.row == cell.row && c.col == cell.col,
  );

  /// Whether [cell] can accept a placement: a letter cell that is not yet
  /// committed. Clue/blank cells and solved/revealed cells are not placeable.
  bool isPlaceable(WordCell cell) {
    final isLetterCell = puzzle.cells.any(
      (c) => c.type == CellType.letter && c.row == cell.row && c.col == cell.col,
    );
    return isLetterCell && !board.containsKey(cell);
  }

  /// Whether a not-yet-confirmed letter sits on [cell].
  bool isPendingAt(WordCell cell) =>
      pendingPlacements.any((p) => p.cell.row == cell.row && p.cell.col == cell.col);

  /// Rack index of the tile whose letter is pending at [cell]; -1 disables
  /// dragging that pending letter (mirrors onTileRecall's letter matching).
  int rackIndexForPending(WordCell cell) {
    final placement = pendingPlacements.firstWhereOrNull((p) => p.cell == cell);
    if (placement == null) return -1;
    return rack.indexWhere((t) => t.isPlaced && t.letter == placement.letter);
  }
}
