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
///
/// Multiset invariant: after every rebuild (refill / ensurePlayable / swap)
/// the rack never carries more copies of a letter than there are unsolved
/// cells needing it. Every tile in hand therefore has its own target cell —
/// the player can never be stuck holding an unplaceable letter.
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
    final letters = _drawFromDemand(
      demand: _letterDemand(puzzle, board),
      count: rackSize,
      rng: rng,
      alphabetFallback: true,
    );
    return [for (final letter in letters) RackTile(letter: letter)];
  }

  /// Rebuilds the rack after a confirmed move (architecture.md §8.3, Karar 2).
  ///
  /// The next rack is the union of: tiles the player never placed this turn
  /// (their strategic carry-over), the [returnedLetters] that came back wrong
  /// (flagged [RackTile.isReturned]), and freshly drawn tiles topping the rack
  /// up to [targetSize] — 5, or 6 once the +1 letter joker is unlocked.
<<<<<<< HEAD
  ///
  /// The whole rebuild is demand-checked (multiset invariant): carry-over and
  /// returned tiles each consume one unit of their letter's demand, surplus
  /// copies and dead tiles are dropped, and the top-up draws only from the
  /// remaining demand (no alphabet padding). Near the end of the puzzle the
  /// rack therefore shrinks toward the number of remaining cells, and a wrong
  /// letter that no longer fits anywhere is replaced instead of returning as
  /// guaranteed dead weight.
=======
>>>>>>> origin/main
  List<RackTile> refill({
    required List<RackTile> currentRack,
    required PuzzleData puzzle,
    required Map<WordCell, String> board,
    required List<String> returnedLetters,
    required int seed,
    int targetSize = baseRackSize,
  }) {
    final rng = Random(seed);
    final demand = _letterDemand(puzzle, board);
    final carryOver = <RackTile>[
      for (final tile in currentRack)
        if (!tile.isPlaced && _takeDemand(demand, tile.letter)) RackTile(letter: tile.letter),
      for (final letter in returnedLetters)
        if (_takeDemand(demand, letter)) RackTile(letter: letter, isReturned: true),
    ];
<<<<<<< HEAD
=======
    final returned = <RackTile>[
      for (final letter in returnedLetters) RackTile(letter: letter, isReturned: true),
    ];
    final carryOver = [...kept, ...returned];
>>>>>>> origin/main
    final need = targetSize - carryOver.length;
    final fresh = need > 0
        ? _drawFromDemand(demand: demand, count: need, rng: rng)
        : const <String>[];
    return [...carryOver, for (final letter in fresh) RackTile(letter: letter)];
  }

  /// Replaces the tiles at [swapIndices] with freshly drawn ones; size unchanged.
  ///
  /// The discarded letters are only re-drawn when the pool offers no
  /// alternative — swapping an 'X' away and immediately getting it back
  /// would make the joker feel broken.
<<<<<<< HEAD
  ///
  /// This is the one draw path that keeps the alphabet fallback: the result is
  /// indexed positionally against [swapIndices], so the draw must return
  /// exactly as many letters as were discarded even when the pool runs dry.
=======
>>>>>>> origin/main
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
<<<<<<< HEAD
    final demand = _letterDemand(puzzle, board);
    // Tiles the player keeps consume their letters' demand first, so the
    // fresh draw cannot push any letter beyond the number of cells needing it.
    for (var i = 0; i < currentRack.length; i++) {
      if (!swapSet.contains(i)) _takeDemand(demand, currentRack[i].letter);
    }
    final fresh = _drawFromDemand(
      demand: demand,
      count: swapSet.length,
      rng: rng,
      exclude: discarded,
      alphabetFallback: true,
=======
    final fresh = _drawFillLetters(
      count: swapSet.length,
      puzzle: puzzle,
      board: board,
      rng: rng,
      exclude: discarded,
>>>>>>> origin/main
    );
    var freshIndex = 0;
    return [
      for (var i = 0; i < currentRack.length; i++)
        if (swapSet.contains(i)) RackTile(letter: fresh[freshIndex++]) else currentRack[i],
    ];
  }

  /// Whether any rack tile is the correct solution for an unsolved letter cell.
  ///
  /// Cheap query kept for callers and tests; the refresh policy itself lives in
  /// [ensurePlayable], which no longer waits for the rack to be fully dead.
  bool hasPlayableMove({
    required List<RackTile> rack,
    required PuzzleData puzzle,
    required Map<WordCell, String> board,
  }) {
    final needed = _unsolvedLetters(puzzle, board).toSet();
    return rack.any((tile) => needed.contains(tile.letter));
  }

  /// Replaces every "dead" tile with a board-aware draw; live tiles are kept
  /// untouched, in place.
  ///
  /// A tile is live only while its letter still has unconsumed demand — so
  /// surplus copies (a third 'A' against two unsolved A-cells) count as dead,
  /// not just letters absent from the board (multiset invariant). Deadness is
  /// monotone: the board only ever fills up, so a dead letter can never
  /// become useful again, and refreshing it costs the player nothing
  /// strategically. Design note (accepted trade-off): dead letters refresh
  /// for free, which repositions the ad-paid swap joker as a "live but
  /// unwanted letter" tool. A refresh-highlight animation is deferred to F6.
  ///
  /// The draw skips the alphabet fallback; when less demand remains than
  /// there are dead tiles, the surplus dead tiles are dropped and the rack
  /// shrinks toward the remaining cell count (endgame behaviour, mirrors
  /// [refill]).
  List<RackTile> ensurePlayable({
    required List<RackTile> currentRack,
    required PuzzleData puzzle,
    required Map<WordCell, String> board,
    required int seed,
  }) {
    final demand = _letterDemand(puzzle, board);
    final isLive = [
      for (final tile in currentRack) _takeDemand(demand, tile.letter),
    ];
    if (!isLive.contains(false)) return currentRack;
    final rng = Random(seed);
    final deadCount = isLive.where((live) => !live).length;
    final fresh = _drawFromDemand(demand: demand, count: deadCount, rng: rng);
    var fi = 0;
    return [
      for (var i = 0; i < currentRack.length; i++)
        if (isLive[i])
          currentRack[i]
        else if (fi < fresh.length)
          RackTile(letter: fresh[fi++]),
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

<<<<<<< HEAD
  // Per-letter demand: how many unsolved cells still need each letter.
  Map<String, int> _letterDemand(PuzzleData puzzle, Map<WordCell, String> board) {
    final demand = <String, int>{};
    for (final letter in _unsolvedLetters(puzzle, board)) {
      demand.update(letter, (v) => v + 1, ifAbsent: () => 1);
    }
    return demand;
  }

  // Consumes one unit of [letter]'s demand; false when none remains.
  static bool _takeDemand(Map<String, int> demand, String letter) {
    final remaining = demand[letter] ?? 0;
    if (remaining <= 0) return false;
    demand[letter] = remaining - 1;
    return true;
  }

  // Draws up to [count] letters from the remaining per-letter [demand]
  // (mutated: every drawn letter consumes one unit, keeping the multiset
  // invariant). When demand runs short, [alphabetFallback] decides the
  // behaviour: true pads with random alphabet letters (callers that must
  // preserve the rack size: initial draw, swap); false returns fewer letters
  // (refill/ensurePlayable — alphabet padding would mint dead-on-arrival
  // tiles, so those racks shrink instead). Letters in [exclude] are pushed to
  // the back of the queue so they are only drawn when no alternative remains
  // (used by swapLetters for discards).
  List<String> _drawFromDemand({
    required Map<String, int> demand,
=======
  // Draws [count] letters: first from the shuffled unsolved-cell pool (so the
  // player can always make progress), then from the Turkish alphabet fallback.
  // Letters in [exclude] are pushed to the back of the queue so they are only
  // drawn when no alternative remains (used by swapLetters for discards).
  List<String> _drawFillLetters({
>>>>>>> origin/main
    required int count,
    required Random rng,
    Set<String> exclude = const {},
<<<<<<< HEAD
    bool alphabetFallback = false,
  }) {
    final pool = <String>[
      for (final entry in demand.entries)
        for (var i = 0; i < entry.value; i++) entry.key,
    ]..shuffle(rng);
=======
  }) {
    final pool = _unsolvedLetters(puzzle, board)..shuffle(rng);
>>>>>>> origin/main
    final ordered = [...pool.where((l) => !exclude.contains(l)), ...pool.where(exclude.contains)];
    final alphabet = [
      for (final l in _turkishAlphabet)
        if (!exclude.contains(l)) l,
<<<<<<< HEAD
=======
    ];
    return [
      for (var i = 0; i < count; i++)
        if (i < ordered.length) ordered[i] else alphabet[rng.nextInt(alphabet.length)],
>>>>>>> origin/main
    ];
    final target = alphabetFallback ? count : min(count, ordered.length);
    final drawn = [
      for (var i = 0; i < target; i++)
        if (i < ordered.length) ordered[i] else alphabet[rng.nextInt(alphabet.length)],
    ];
    for (final letter in drawn) {
      _takeDemand(demand, letter);
    }
    return drawn;
  }
}
