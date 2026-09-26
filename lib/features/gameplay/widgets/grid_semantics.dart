// lib/features/gameplay/widgets/grid_semantics.dart

import 'package:flutter/material.dart';
import 'package:kelime_oyunu/data/models/puzzle.dart';
import 'package:kelime_oyunu/features/gameplay/engine/score_engine.dart';
import 'package:kelime_oyunu/l10n/generated/app_localizations.dart';

/// Screen-reader layer over the painted board: one semantics node per cell
/// (clue text + direction, committed letter, pending letter, empty cell),
/// positioned with the same slot geometry as the painters. Pointer-inert —
/// taps still reach the grid's own GestureDetector — and cheap: the nodes
/// carry no paint.
class GridSemantics extends StatelessWidget {
  const GridSemantics({
    required this.puzzle,
    required this.board,
    required this.pendingPlacements,
    required this.cellSize,
    super.key,
  });

  final PuzzleData puzzle;
  final Map<WordCell, String> board;
  final List<Placement> pendingPlacements;
  final double cellSize;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final specs = {for (final c in puzzle.cells) WordCell(row: c.row, col: c.col): c};
    final pending = {for (final p in pendingPlacements) p.cell: p.letter};
    return IgnorePointer(
      child: Stack(
        children: [
          for (var row = 0; row < puzzle.grid.rows; row++)
            for (var col = 0; col < puzzle.grid.cols; col++)
              Positioned(
                left: col * cellSize,
                top: row * cellSize,
                width: cellSize,
                height: cellSize,
                child: Semantics(
                  container: true,
                  label: _label(l10n, WordCell(row: row, col: col), specs, pending),
                  child: const SizedBox.expand(),
                ),
              ),
        ],
      ),
    );
  }

  String _label(
    AppLocalizations l10n,
    WordCell cell,
    Map<WordCell, CellSpec> specs,
    Map<WordCell, String> pending,
  ) {
    final spec = specs[cell];
    final row = cell.row + 1;
    final col = cell.col + 1;
    if (spec == null || spec.type == CellType.blank) {
      return cell.row == 0 && cell.col == 0 ? l10n.a11yCorner : l10n.a11yEmptyCell(row, col);
    }
    if (spec.type == CellType.clue) {
      return [
        for (final clue in spec.clues)
          l10n.a11yClueCell(clue.text, clue.arrow == ClueArrow.right ? l10n.right : l10n.down),
      ].join('; ');
    }
    final pendingLetter = pending[cell];
    if (pendingLetter != null) return l10n.a11yPendingCell(pendingLetter, row, col);
    final letter = board[cell];
    if (letter != null) return l10n.a11yLetterCell(letter, row, col);
    return l10n.a11yEmptyCell(row, col);
  }
}
