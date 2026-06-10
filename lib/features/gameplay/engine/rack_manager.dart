// lib/features/gameplay/engine/rack_manager.dart

import 'dart:math';

import 'package:equatable/equatable.dart';

import 'package:kelime_oyunu/data/models/puzzle.dart';

// Pure Dart rack manager (architecture.md §8.3). No Flutter imports so it stays
// unit-testable. All randomness is seeded for reproducibility.

/// One tile in the player's letter rack.
class RackTile extends Equatable {
  const RackTile({required this.letter, this.isPlaced = false, this.isReturned = false});

  final String letter;

  /// Whether the tile is currently placed on the board this turn (pending).
  final bool isPlaced;

  /// Whether the tile came back this turn because it was placed incorrectly.
  final bool isReturned;

  @override
  List<Object?> get props => [letter, isPlaced, isReturned];
}

/// Builds and refills the player's rack from the puzzle's unsolved cells.
class RackManager {
  const RackManager();

  static const int baseRackSize = 5;
  static const int powerUpRackSize = 6;

  // Full 29-letter Turkish alphabet (no Q/W/X) used as a fallback source when
  // the puzzle has too few unsolved cells to fill the rack (architecture.md §14).
  static const List<String> _turkishAlphabet = [
    'A', 'B', 'C', 'Ç', 'D', 'E', 'F', 'G', 'Ğ', 'H', 'I', 'İ', //
    'J', 'K', 'L', 'M', 'N', 'O', 'Ö', 'P', 'R', 'S', 'Ş', 'T', //
    'U', 'Ü', 'V', 'Y', 'Z',
  ];

  /// Builds the opening rack of [rackSize] tiles.
  List<RackTile> initialRack({
    required PuzzleData puzzle,
    required Map<WordCell, String> board,
    required int rackSize,
    required int seed,
  }) {
    final rng = Random(seed);
    final letters = _drawFillLetters(count: rackSize, puzzle: puzzle, board: board, rng: rng);
    return [for (final letter in letters) RackTile(letter: letter)];
  }

  /// Rebuilds the rack after a confirmed move (architecture.md §8.3, Karar 2).
  ///
  /// The next rack is the union of: tiles the player never placed this turn
  /// (their strategic carry-over), the [returnedLetters] that came back wrong
  /// (flagged [RackTile.isReturned]), and freshly drawn tiles topping the rack
  /// up to [targetSize] — 5, or 6 once the +1 letter joker is unlocked.
  List<RackTile> refill({
    required List<RackTile> currentRack,
    required PuzzleData puzzle,
    required Map<WordCell, String> board,
    required List<String> returnedLetters,
    required int seed,
    int targetSize = baseRackSize,
  }) {
    final rng = Random(seed);
    final kept = <RackTile>[
      for (final tile in currentRack)
        if (!tile.isPlaced) RackTile(letter: tile.letter),
    ];
    final returned = <RackTile>[
      for (final letter in returnedLetters) RackTile(letter: letter, isReturned: true),
    ];
    final carryOver = [...kept, ...returned];
    final need = targetSize - carryOver.length;
    final fresh = need > 0
        ? _drawFillLetters(count: need, puzzle: puzzle, board: board, rng: rng)
        : const <String>[];
    return [...carryOver, for (final letter in fresh) RackTile(letter: letter)];
  }

  /// Replaces the tiles at [swapIndices] with freshly drawn ones; size unchanged.
  ///
  /// The discarded letters are only re-drawn when the pool offers no
  /// alternative — swapping an 'X' away and immediately getting it back
  /// would make the joker feel broken.
  List<RackTile> swapLetters({
    required List<RackTile> currentRack,
    required List<int> swapIndices,
    required PuzzleData puzzle,
    required Map<WordCell, String> board,
    required int seed,
  }) {
    final rng = Random(seed);
    final swapSet = swapIndices.toSet();
    final discarded = {for (final i in swapSet) currentRack[i].letter};
    final fresh = _drawFillLetters(
      count: swapSet.length,
      puzzle: puzzle,
      board: board,
      rng: rng,
      exclude: discarded,
    );
    var freshIndex = 0;
    return [
      for (var i = 0; i < currentRack.length; i++)
        if (swapSet.contains(i)) RackTile(letter: fresh[freshIndex++]) else currentRack[i],
    ];
  }

  /// Whether any rack tile is the correct solution for an unsolved letter cell.
  ///
  /// When false the player has no scoring move and the rack must be refreshed
  /// (see [ensurePlayable]); otherwise the game soft-locks (architecture.md §8.3).
  bool hasPlayableMove({
    required List<RackTile> rack,
    required PuzzleData puzzle,
    required Map<WordCell, String> board,
  }) {
    final needed = _unsolvedLetters(puzzle, board).toSet();
    return rack.any((tile) => needed.contains(tile.letter));
  }

  /// Returns [currentRack] unchanged when it already has a playable move;
  /// otherwise replaces every "dead" tile (letter not matching any unsolved
  /// cell) with a board-aware draw. This is a replace, not a top-up: it breaks
  /// the soft-lock where a full rack of dead tiles can never be refilled because
  /// returned tiles keep the rack at baseRackSize (need == 0). While the board
  /// is incomplete the unsolved pool is non-empty, so the result always holds at
  /// least one playable tile.
  List<RackTile> ensurePlayable({
    required List<RackTile> currentRack,
    required PuzzleData puzzle,
    required Map<WordCell, String> board,
    required int seed,
  }) {
    if (hasPlayableMove(rack: currentRack, puzzle: puzzle, board: board)) {
      return currentRack;
    }
    final rng = Random(seed);
    final needed = _unsolvedLetters(puzzle, board).toSet();
    final deadCount = currentRack.where((t) => !needed.contains(t.letter)).length;
    final fresh = _drawFillLetters(count: deadCount, puzzle: puzzle, board: board, rng: rng);
    var i = 0;
    return [
      for (final tile in currentRack)
        if (needed.contains(tile.letter)) tile else RackTile(letter: fresh[i++]),
    ];
  }

  // Collects the solution letters of every still-unsolved letter cell.
  List<String> _unsolvedLetters(PuzzleData puzzle, Map<WordCell, String> board) {
    final letters = <String>[];
    for (final cell in puzzle.cells) {
      if (cell.type != CellType.letter) continue;
      final position = WordCell(row: cell.row, col: cell.col);
      if (board.containsKey(position)) continue;
      final solution = cell.solution;
      if (solution != null) letters.add(solution);
    }
    return letters;
  }

  // Draws [count] letters: first from the shuffled unsolved-cell pool (so the
  // player can always make progress), then from the Turkish alphabet fallback.
  // Letters in [exclude] are pushed to the back of the queue so they are only
  // drawn when no alternative remains (used by swapLetters for discards).
  List<String> _drawFillLetters({
    required int count,
    required PuzzleData puzzle,
    required Map<WordCell, String> board,
    required Random rng,
    Set<String> exclude = const {},
  }) {
    final pool = _unsolvedLetters(puzzle, board)..shuffle(rng);
    final ordered = [...pool.where((l) => !exclude.contains(l)), ...pool.where(exclude.contains)];
    final alphabet = [
      for (final l in _turkishAlphabet)
        if (!exclude.contains(l)) l,
    ];
    return [
      for (var i = 0; i < count; i++)
        if (i < ordered.length) ordered[i] else alphabet[rng.nextInt(alphabet.length)],
    ];
  }
}
