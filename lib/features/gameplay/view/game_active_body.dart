// lib/features/gameplay/view/game_active_body.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:kelime_oyunu/core/constants/app_dimensions.dart';
import 'package:kelime_oyunu/core/theme/app_tokens.dart';
import 'package:kelime_oyunu/data/models/puzzle.dart';
import 'package:kelime_oyunu/features/gameplay/bloc/game_bloc.dart';
import 'package:kelime_oyunu/features/gameplay/bloc/game_event.dart';
import 'package:kelime_oyunu/features/gameplay/bloc/game_state.dart';
import 'package:kelime_oyunu/features/gameplay/engine/bot_engine.dart';
import 'package:kelime_oyunu/features/gameplay/engine/rack_manager.dart';
import 'package:kelime_oyunu/features/gameplay/view/game_active_queries.dart';
import 'package:kelime_oyunu/features/gameplay/view/game_dialogs.dart';
import 'package:kelime_oyunu/features/gameplay/widgets/action_bar.dart';
import 'package:kelime_oyunu/features/gameplay/widgets/ad_label.dart';
import 'package:kelime_oyunu/features/gameplay/widgets/board_frame.dart';
import 'package:kelime_oyunu/features/gameplay/widgets/grid_painter.dart';
import 'package:kelime_oyunu/features/gameplay/widgets/level_top_bar.dart';
import 'package:kelime_oyunu/features/gameplay/widgets/narration_controller.dart';
import 'package:kelime_oyunu/features/gameplay/widgets/narration_layer.dart';
import 'package:kelime_oyunu/features/gameplay/widgets/narration_tiles.dart';
import 'package:kelime_oyunu/features/gameplay/widgets/rack_widget.dart';
import 'package:kelime_oyunu/features/gameplay/widgets/score_header.dart';
import 'package:kelime_oyunu/features/gameplay/widgets/turn_pill.dart';
import 'package:kelime_oyunu/l10n/generated/app_localizations.dart';

part 'package:kelime_oyunu/features/gameplay/view/game_active_interaction.dart';

/// Full game UI rendered while a match is in progress. Reads [GameBloc] from
/// context; [GameScreen] is the only intended host.
class GameActiveBody extends StatefulWidget {
  const GameActiveBody({
    required this.state,
    required this.puzzleId,
    required this.botProfile,
    super.key,
  });

  final GameActive state;
  final int puzzleId;
  final BotProfile botProfile;

  @override
  State<GameActiveBody> createState() => _GameActiveBodyState();
}

class _GameActiveBodyState extends State<GameActiveBody>
    with SingleTickerProviderStateMixin, _GameInteraction {
  /// Owns the score-story clock: enqueues each resolved move's narration and
  /// exposes the lagging display scores. The bloc never waits on it.
  late final NarrationController _narration;

  /// Flight-source anchors: the player's letters lift from the rack, the bot's
  /// from its avatar portrait. The narration overlay converts these into its
  /// own coordinate space (F6 phase 3).
  final GlobalKey _rackKey = GlobalKey();
  final GlobalKey _avatarKey = GlobalKey();

  /// Score-badge flight target for the player's points (the "Sen" pill); bot
  /// badges fly to [_avatarKey].
  final GlobalKey _playerScoreKey = GlobalKey();

  /// The match has finished but its final move may still be narrating; the
  /// result dialog is held until [_narration] drains (see [_onNarrationDrained]).
  bool _finishPending = false;
  bool _resultShown = false;

  /// The opponent is playing (or its move is still being narrated): the
  /// rack and bar wear their dimmed looks.
  bool get _botTurn => state.phase == TurnPhase.botThinking || state.botThinking;

  /// The lamp only works on the player's turn while the game is running.
  bool get _canReveal =>
      state.phase == TurnPhase.playerTurn &&
      state.status == GameStatus.playing &&
      !_narration.narrating;

  @override
  void initState() {
    super.initState();
    _narration = NarrationController(vsync: this)..onDrained = _onNarrationDrained;
    _narration.sync(widget.state);
  }

  @override
  void didUpdateWidget(GameActiveBody old) {
    super.didUpdateWidget(old);
    final justFinished =
        old.state.phase != TurnPhase.finished && widget.state.phase == TurnPhase.finished;
    _narration.sync(widget.state);
    if (justFinished) {
      _finishPending = true;
      // Nothing left to narrate → show immediately; otherwise wait for onDrained.
      if (!_narration.narrating) _onNarrationDrained();
    }
  }

  @override
  void dispose() {
    _narration.dispose();
    super.dispose();
  }

  /// The narration queue emptied: release a deferred end-of-match dialog.
  void _onNarrationDrained() {
    if (!_finishPending || _resultShown || !mounted) return;
    _resultShown = true;
    _showResultDialog(context, state);
  }

  /// Shows the end-of-match modal once the final move has finished narrating.
  /// The bloc and router are captured from [context] *before* the dialog opens
  /// (see [showMatchResultDialog] for why).
  Future<void> _showResultDialog(BuildContext context, GameActive state) {
    final bloc = context.read<GameBloc>();
    final router = GoRouter.of(context);
    return showMatchResultDialog(
      context,
      state: state,
      botName: widget.botProfile.name,
      levelId: widget.puzzleId,
      // Restart the same level: reloading passes through GameLoading, which
      // unmounts the grid and resets the InteractiveViewer zoom for free.
      onReplay: () => bloc.add(PuzzleLoadRequested(widget.puzzleId)),
      // Hard progression: only reachable after a win on a non-final level.
      onNext: () => router.go('/gameplay/${widget.puzzleId + 1}'),
      // Back to the grid, where the win is now reflected as unlocked.
      onLevels: () => router.go('/levels'),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final l10n = AppLocalizations.of(context);
    return AnimatedBuilder(
      animation: _narration,
      builder: (context, _) => Stack(
        children: [
          // bgGame gradient behind everything (README "Game screen").
          Positioned.fill(
            child: DecoratedBox(decoration: BoxDecoration(gradient: tokens.bgGame)),
          ),
          SafeArea(
            child: Column(
              children: [
                // Level header + the way out. Kept above ScoreHeader as its
                // own child so it never disturbs the "VS" centring in the header.
                LevelTopBar(
                  levelId: widget.puzzleId,
                  // Leaving is safe: the match is saved at every turn boundary
                  // and comes back as "Yarım kalan oyun" on the grid.
                  onExit: () => context.go('/levels'),
                ),
                ScoreHeader(
                  // Lagging display scores: the counter walks up as the narration
                  // lands each cue (12→13→14→15), it never snaps to the bloc total.
                  playerScore: _narration.displayPlayerScore,
                  botScore: _narration.displayBotScore,
                  botName: widget.botProfile.name,
                  botThinking: state.botThinking,
                  avatarKey: _avatarKey,
                  playerScoreKey: _playerScoreKey,
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppDimensions.space8),
                  child: TurnPill(spec: turnPillFor(state, l10n)),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppDimensions.space16,
                      vertical: AppDimensions.space8,
                    ),
                    // BoardFrame picks the largest grid that fits and gives both
                    // layers EXACT grid-sized constraints, so GridPainter and the
                    // narration overlay derive the same cell size — badges land on
                    // the right cells. No scroll view.
                    child: BoardFrame(
                      rows: state.puzzle.grid.rows,
                      cols: state.puzzle.grid.cols,
                      child: Stack(
                        // Score badges fly OUT of the grid area up to the header
                        // (the score / bot avatar) — don't clip them mid-path.
                        clipBehavior: Clip.none,
                        children: [
                          GridPainter(
                            puzzle: state.puzzle,
                            board: state.board,
                            pendingPlacements: state.pendingPlacements,
                            revealedWordIds: state.revealedWordIds,
                            botPlacedCells: state.botPlacedCells,
                            // Hide letters mid-flight so they pop in as their tile lands.
                            suppressedCells: _narration.suppressedCells,
                            revealMode: _revealMode,
                            onCellTap: (cell, bottomHalf) => _onCellTap(context, cell, bottomHalf),
                            isCellPlaceable: state.isPlaceable,
                            onCellDrop: (data, cell) => _onCellDrop(context, data, cell),
                            pendingDragEnabled: _canReveal && !_revealMode,
                            rackIndexForPending: state.rackIndexForPending,
                            onPendingDragCancelled: (cell) =>
                                context.read<GameBloc>().add(LetterRecalled(cell)),
                          ),
                          // Non-interactive: badges only. The narrating tap-catcher
                          // (above the whole body) owns input while a story plays.
                          Positioned.fill(
                            child: IgnorePointer(
                              child: NarrationLayer(
                                controller: _narration,
                                puzzle: state.puzzle,
                                rackKey: _rackKey,
                                botAvatarKey: _avatarKey,
                                playerScoreKey: _playerScoreKey,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                // Rack dims to 45 % while the opponent plays (README "States").
                // The lifted selected tile needs headroom above the row.
                AnimatedOpacity(
                  opacity: _botTurn ? 0.45 : 1.0,
                  duration: const Duration(milliseconds: 200),
                  child: Padding(
                    padding: const EdgeInsets.only(top: AppDimensions.space12),
                    child: RackWidget(
                      key: _rackKey,
                      rack: state.rack,
                      selectedIndex: state.selectedRackIndex,
                      // Drag mirrors the tap guards: player's turn, game running, no
                      // reveal mode — the bot's turn must not accept ghost drags.
                      dragEnabled: _canReveal && !_revealMode,
                      onDragStarted: (_) =>
                          context.read<GameBloc>().add(const RackTileSelected(-1)),
                      showPlusSlot: state.rackSize == RackManager.baseRackSize,
                      showAdLabel: showAdLabelsFor(widget.puzzleId),
                      onPlusTap: _canReveal && !_revealMode
                          ? () => _confirmSixthSlot(context)
                          : null,
                      onTileTap: (i) => context.read<GameBloc>().add(RackTileSelected(i)),
                      onTileRecall: (i) => _onTileRecall(context, i),
                    ),
                  ),
                ),
                ActionBar(
                  pendingPlacements: state.pendingPlacements,
                  revealActive: _revealMode,
                  botTurn: _botTurn,
                  showAdLabel: showAdLabelsFor(widget.puzzleId),
                  onConfirm: _revealMode
                      ? null
                      : () => context.read<GameBloc>().add(const MoveConfirmed()),
                  onPass: _revealMode
                      ? null
                      : () => context.read<GameBloc>().add(const MovePassed()),
                  onSwap:
                      !_revealMode &&
                          state.pendingPlacements.isEmpty &&
                          state.swapQuotaRemaining > 0
                      ? () => _showSwapSheet(context)
                      : null,
                  onReveal: _canReveal ? () => setState(() => _revealMode = !_revealMode) : null,
                ),
              ],
            ),
          ),
          // Input lock + fast-forward. While a narration plays, an opaque
          // catcher covers everything: it swallows all gameplay input and
          // turns any tap into a 2× speed-up (never a cancel — the player must
          // not miss a move). It vanishes the instant the queue drains.
          if (_narration.narrating)
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: (_) => _narration.toggleSpeed(),
                child: _narration.isSpedUp
                    ? const SafeArea(
                        child: Align(
                          alignment: Alignment.topRight,
                          child: Padding(padding: EdgeInsets.all(12), child: NarrationSpeedChip()),
                        ),
                      )
                    : const SizedBox.expand(),
              ),
            ),
        ],
      ),
    );
  }
}
