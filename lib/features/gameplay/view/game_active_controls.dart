// lib/features/gameplay/view/game_active_controls.dart

part of 'package:kelime_oyunu/features/gameplay/view/game_active_body.dart';

/// The controls under the board — rack and bottom bar — split out of the
/// State's build to keep the body file within the 300-line budget. Private
/// extension in the same library (the `_GameInteraction` pattern), so the
/// State's guards and handlers are used directly.
extension _GameControls on _GameActiveBodyState {
  // Rack dims to 45 % while the opponent plays (README "States").
  // The lifted selected tile needs headroom above the row.
  Widget _rackSection(BuildContext context) {
    return AnimatedOpacity(
      opacity: _botTurn ? 0.45 : 1.0,
      duration: const Duration(milliseconds: 200),
      child: Padding(
        padding: EdgeInsets.only(top: _compact ? AppDimensions.space4 : AppDimensions.space12),
        child: RackWidget(
          key: _rackKey,
          rack: state.rack,
          compact: _compact,
          selectedIndex: state.selectedRackIndex,
          // Drag mirrors the tap guards: player's turn, game running, no
          // reveal mode — the bot's turn must not accept ghost drags.
          dragEnabled: _canReveal && !_revealMode,
          onDragStarted: (_) => context.read<GameBloc>().add(const RackTileSelected(-1)),
          showPlusSlot: state.rackSize == RackManager.baseRackSize,
          showAdLabel: showAdLabelsFor(widget.puzzleId),
          onPlusTap: _canReveal && !_revealMode ? () => _confirmSixthSlot(context) : null,
          onTileTap: (i) => context.read<GameBloc>().add(RackTileSelected(i)),
          onTileRecall: (i) => _onTileRecall(context, i),
        ),
      ),
    );
  }

  Widget _actionBar(BuildContext context) {
    return ActionBar(
      compact: _compact,
      pendingPlacements: state.pendingPlacements,
      revealActive: _revealMode,
      botTurn: _botTurn,
      showAdLabel: showAdLabelsFor(widget.puzzleId),
      onConfirm: _revealMode ? null : () => context.read<GameBloc>().add(const MoveConfirmed()),
      onPass: _revealMode ? null : () => context.read<GameBloc>().add(const MovePassed()),
      onSwap: !_revealMode && state.pendingPlacements.isEmpty && state.swapQuotaRemaining > 0
          ? () => _showSwapSheet(context)
          : null,
      onReveal: _canReveal ? _toggleRevealMode : null,
    );
  }
}
