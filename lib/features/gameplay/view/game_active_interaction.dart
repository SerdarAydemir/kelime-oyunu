// lib/features/gameplay/view/game_active_interaction.dart

part of 'package:kelime_oyunu/features/gameplay/view/game_active_body.dart';

/// Input handling for [GameActiveBody]: tap/drag routing on the grid and rack,
/// the reveal mode, and the joker confirmations. The layout lives in the
/// State class; this mixin only turns gestures into bloc events.
mixin _GameInteraction on State<GameActiveBody> {
  /// Local interaction mode: the player is picking a clue cell to reveal.
  /// Gameplay actions stay disabled until the mode closes (yes / toggle /
  /// tapping a non-clue cell). Reveal itself is the existing WordRevealed.
  bool _revealMode = false;

  GameActive get state => widget.state;

  /// A dragged tile landed on a placeable cell. A drag that started on a
  /// pending letter is a MOVE: free the source cell first, then place on the
  /// target.
  void _onCellDrop(BuildContext context, DragTileData data, WordCell cell) {
    final bloc = context.read<GameBloc>();
    final from = data.fromCell;
    if (from != null && from != cell) bloc.add(LetterRecalled(from));
    if (from != cell) {
      bloc.add(LetterPlaced(rackIndex: data.rackIndex, cell: cell));
    }
    bloc.add(const RackTileSelected(-1));
  }

  /// Long-press on a placed rack tile: recall ITS pending letter to the rack —
  /// the placement made from this slot, not the first one with the same letter.
  void _onTileRecall(BuildContext context, int index) {
    final placement = state.pendingForRackIndex(index);
    if (placement != null) {
      context.read<GameBloc>().add(LetterRecalled(placement.cell));
    }
  }

  void _onCellTap(BuildContext context, WordCell cell, bool bottomHalf) {
    final clueSpec = state.clueSpecAt(cell);
    if (_revealMode) {
      if (clueSpec == null || clueSpec.clues.isEmpty) {
        // Tapping anything that is not a clue cell silently cancels the mode.
        setState(() => _revealMode = false);
      } else {
        _confirmReveal(context, clueSpec, bottomHalf);
      }
      return;
    }
    // A clue cell holds no rack action — tapping it opens the full clue text
    // (free read). Works for single and double-clue cells alike.
    if (clueSpec != null && clueSpec.clues.isNotEmpty) {
      showClueSheet(context, clueSpec.clues);
      return;
    }
    final bloc = context.read<GameBloc>();
    if (state.selectedRackIndex != -1) {
      // A rack tile is selected — place it only on a valid empty letter cell.
      // Invalid targets are ignored; the selection is kept so the player can
      // tap a different cell without re-selecting the tile.
      if (state.isPlaceable(cell)) {
        bloc.add(LetterPlaced(rackIndex: state.selectedRackIndex, cell: cell));
        bloc.add(const RackTileSelected(-1)); // clear selection
      }
    } else {
      // Tapping a pending letter recalls it to the rack; any other cell tap
      // is inert (the old grey word-highlight was dropped as noise).
      if (state.isPendingAt(cell)) bloc.add(LetterRecalled(cell));
    }
  }

  /// Asks for confirmation, then reveals the chosen clue's word as a ghost.
  /// On a double-clue cell [bottomHalf] picks the lower clue.
  Future<void> _confirmReveal(BuildContext context, CellSpec spec, bool bottomHalf) async {
    final clue = spec.clues.length >= 2 && bottomHalf ? spec.clues[1] : spec.clues[0];
    final bloc = context.read<GameBloc>();
    final confirmed = await confirmRevealDialog(context, clue);
    // "Hayır" (or dismissing the dialog) keeps the player in reveal mode.
    if (!mounted || !confirmed) return;
    bloc.add(WordRevealed(clue.wordId));
    setState(() => _revealMode = false);
  }

  /// Confirms the +1 letter joker; "Evet" unlocks the sixth rack slot.
  Future<void> _confirmSixthSlot(BuildContext context) async {
    final bloc = context.read<GameBloc>();
    final confirmed = await confirmSixthSlotDialog(context);
    if (!mounted || !confirmed) return;
    // TODO: gate behind a real rewarded ad once AdService lands (mock for MVP).
    bloc.add(const SixthSlotUnlocked());
  }

  /// Opens the swap sheet; dispatches the swap with the chosen payment.
  Future<void> _showSwapSheet(BuildContext context) async {
    final bloc = context.read<GameBloc>();
    final choice = await showSwapSheet(
      context,
      rack: state.rack,
      quotaRemaining: state.swapQuotaRemaining,
    );
    if (!mounted || choice == null) return;
    // TODO: gate the viaAd path behind a real rewarded ad (AdService phase).
    bloc.add(LettersSwapped(choice.indices, viaAd: choice.viaAd));
  }
}
