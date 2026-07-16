// lib/features/gameplay/view/game_screen.dart

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:kelime_oyunu/core/constants/app_dimensions.dart';
import 'package:kelime_oyunu/core/constants/app_typography.dart';
import 'package:kelime_oyunu/core/constants/game_constants.dart';
import 'package:kelime_oyunu/data/models/puzzle.dart';
import 'package:kelime_oyunu/data/repositories/progress_repository.dart';
import 'package:kelime_oyunu/data/repositories/puzzle_repository.dart';
import 'package:kelime_oyunu/features/gameplay/bloc/game_bloc.dart';
import 'package:kelime_oyunu/features/gameplay/bloc/game_event.dart';
import 'package:kelime_oyunu/features/gameplay/bloc/game_state.dart';
import 'package:kelime_oyunu/features/gameplay/engine/bot_engine.dart';
import 'package:kelime_oyunu/features/gameplay/engine/rack_manager.dart';
import 'package:kelime_oyunu/features/gameplay/engine/score_engine.dart';
import 'package:kelime_oyunu/features/gameplay/widgets/action_bar.dart';
import 'package:kelime_oyunu/features/gameplay/widgets/clue_sheet.dart';
import 'package:kelime_oyunu/features/gameplay/widgets/grid_painter.dart';
import 'package:kelime_oyunu/features/gameplay/widgets/narration_controller.dart';
import 'package:kelime_oyunu/features/gameplay/widgets/narration_layer.dart';
import 'package:kelime_oyunu/features/gameplay/widgets/narration_tiles.dart';
import 'package:kelime_oyunu/features/gameplay/widgets/rack_widget.dart';
import 'package:kelime_oyunu/features/gameplay/widgets/result_dialog.dart';
import 'package:kelime_oyunu/features/gameplay/widgets/score_header.dart';
import 'package:kelime_oyunu/features/gameplay/widgets/swap_sheet.dart';

// Bot identity used for all matches in this version of the screen.
const _kBotProfile = BotProfile(
  id: 'sokrates',
  name: 'Sokrates',
  avatarAsset: 'assets/images/sokrates.png',
  description: 'Her şeyi sorgulayan filozofla akıl yarıştıracaksın.',
  difficultyBand: DifficultyBand.medium,
);

/// Entry point widget. Creates the [GameBloc] and provides it to the subtree.
class GameScreen extends StatelessWidget {
  const GameScreen({required this.puzzleId, required this.progressRepo, super.key});

  final int puzzleId;

  /// Persists the win that unlocks the next level (F7).
  final ProgressRepository progressRepo;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => GameBloc(
        puzzleRepo: AssetPuzzleRepository(),
        scoreEngine: const ScoreEngine(),
        rackManager: const RackManager(),
        botEngine: const BotEngine(),
        botProfile: _kBotProfile,
        puzzleIndex: puzzleId - 1,
        progressRepo: progressRepo,
      )..add(PuzzleLoadRequested(puzzleId)),
      child: _GameBody(puzzleId: puzzleId),
    );
  }
}

/// Reads [GameBloc] from context; drives the [BlocConsumer] and routing.
class _GameBody extends StatelessWidget {
  const _GameBody({required this.puzzleId});

  final int puzzleId;

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<GameBloc, GameState>(
      // Only surface load errors here. The end-of-match dialog is owned by
      // _GameActiveBody so it can be deferred until the final move finishes
      // narrating (the player must see the winning move play out first).
      listenWhen: (prev, curr) => curr is GameError,
      listener: (context, state) {
        if (state is GameError) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(state.message)));
        }
      },
      builder: (context, state) {
        return Scaffold(
          body: switch (state) {
            GameInitial() || GameLoading() => const Center(child: CircularProgressIndicator()),
            GameError(:final message) => Center(child: Text(message)),
            GameActive() => _GameActiveBody(state: state, puzzleId: puzzleId),
          },
        );
      },
    );
  }
}

/// Full game UI rendered while a match is in progress.
class _GameActiveBody extends StatefulWidget {
  const _GameActiveBody({required this.state, required this.puzzleId});

  final GameActive state;
  final int puzzleId;

  @override
  State<_GameActiveBody> createState() => _GameActiveBodyState();
}

class _GameActiveBodyState extends State<_GameActiveBody> with SingleTickerProviderStateMixin {
  /// Local interaction mode: the player is picking a clue cell to reveal.
  /// Gameplay actions stay disabled until the mode closes (yes / toggle /
  /// tapping a non-clue cell). Reveal itself is the existing WordRevealed.
  bool _revealMode = false;

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

  GameActive get state => widget.state;

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
  void didUpdateWidget(_GameActiveBody old) {
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
  /// The bloc and router are captured from [context] *before* the dialog opens:
  /// showDialog pushes onto the root navigator, whose context sits outside this
  /// screen's BlocProvider, so reading the GameBloc from the dialog would fail.
  Future<void> _showResultDialog(BuildContext context, GameActive state) {
    final bloc = context.read<GameBloc>();
    final router = GoRouter.of(context);
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => ResultDialog(
        status: state.status,
        playerScore: state.playerScore,
        botScore: state.botScore,
        botName: _kBotProfile.name,
        levelId: widget.puzzleId,
        // Restart the same level: reloading passes through GameLoading, which
        // unmounts the grid and resets the InteractiveViewer zoom for free.
        onReplay: () {
          Navigator.of(dialogContext).pop();
          bloc.add(PuzzleLoadRequested(widget.puzzleId));
        },
        // Hard progression: only reachable after a win on a non-final level.
        onNext: () {
          Navigator.of(dialogContext).pop();
          router.go('/gameplay/${widget.puzzleId + 1}');
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _narration,
      builder: (context, _) => Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                // Lightweight progress label. Kept above ScoreHeader as its own
                // centred child so it never disturbs the "VS" centring in the header.
                // Minimal top padding so the grid below claims the most vertical room.
                Padding(
                  padding: const EdgeInsets.only(top: AppDimensions.spacingXxs),
                  child: Text(
                    'Bölüm ${widget.puzzleId} / $kLastLevelId',
                    style: AppTypography.caption,
                  ),
                ),
                ScoreHeader(
                  // Lagging display scores: the counter walks up as the narration
                  // lands each cue (12→13→14→15), it never snaps to the bloc total.
                  playerScore: _narration.displayPlayerScore,
                  botScore: _narration.displayBotScore,
                  botName: _kBotProfile.name,
                  botThinking: state.botThinking,
                  avatarKey: _avatarKey,
                  playerScoreKey: _playerScoreKey,
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    // GridPainter sizes itself to fill this bounded area (largest
                    // square cells that fit) and centres the grid — no scroll view.
                    // The narration overlay stacks on top with the SAME cell math so
                    // its badges land on the right cells.
                    child: Stack(
                      // Score badges fly OUT of the grid area up to the header
                      // (the "Sen" pill / bot avatar) — don't clip them mid-path.
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
                          isCellPlaceable: _isPlaceable,
                          onCellDrop: (data, cell) {
                            final bloc = context.read<GameBloc>();
                            // A drag that started on a pending letter is a MOVE: free
                            // the source cell first, then place on the target.
                            final from = data.fromCell;
                            if (from != null && from != cell) bloc.add(LetterRecalled(from));
                            if (from != cell) {
                              bloc.add(LetterPlaced(rackIndex: data.rackIndex, cell: cell));
                            }
                            bloc.add(const RackTileSelected(-1));
                          },
                          pendingDragEnabled: _canReveal && !_revealMode,
                          rackIndexForPending: _rackIndexForPending,
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
                RackWidget(
                  key: _rackKey,
                  rack: state.rack,
                  // Drag mirrors the tap guards: player's turn, game running, no
                  // reveal mode — the bot's turn must not accept ghost drags.
                  dragEnabled: _canReveal && !_revealMode,
                  onDragStarted: (_) => context.read<GameBloc>().add(const RackTileSelected(-1)),
                  showPlusSlot: state.rackSize == RackManager.baseRackSize,
                  onPlusTap: _canReveal && !_revealMode ? () => _confirmSixthSlot(context) : null,
                  onTileTap: (i) => context.read<GameBloc>().add(RackTileSelected(i)),
                  onTileRecall: (i) {
                    final tile = state.rack[i];
                    final placement = state.pendingPlacements.firstWhereOrNull(
                      (p) => p.letter == tile.letter,
                    );
                    if (placement != null) {
                      context.read<GameBloc>().add(LetterRecalled(placement.cell));
                    }
                  },
                ),
                ActionBar(
                  pendingPlacements: state.pendingPlacements,
                  revealActive: _revealMode,
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

  /// Rack index of the tile whose letter is pending at [cell]; -1 disables
  /// dragging that pending letter (mirrors onTileRecall's letter matching).
  int _rackIndexForPending(WordCell cell) {
    final placement = state.pendingPlacements.firstWhereOrNull((p) => p.cell == cell);
    if (placement == null) return -1;
    return state.rack.indexWhere((t) => t.isPlaced && t.letter == placement.letter);
  }

  // Whether [cell] can accept a placement: a letter cell that is not yet
  // committed. Clue/blank cells and solved/revealed cells are not placeable.
  bool _isPlaceable(WordCell cell) {
    final isLetterCell = state.puzzle.cells.any(
      (c) => c.type == CellType.letter && c.row == cell.row && c.col == cell.col,
    );
    return isLetterCell && !state.board.containsKey(cell);
  }

  void _onCellTap(BuildContext context, WordCell cell, bool bottomHalf) {
    if (_revealMode) {
      final spec = state.puzzle.cells.firstWhereOrNull(
        (c) => c.type == CellType.clue && c.row == cell.row && c.col == cell.col,
      );
      if (spec == null || spec.clues.isEmpty) {
        // Tapping anything that is not a clue cell silently cancels the mode.
        setState(() => _revealMode = false);
      } else {
        _confirmReveal(context, spec, bottomHalf);
      }
      return;
    }
    // A clue cell holds no rack action — tapping it opens the full clue text
    // (free read). Works for single and double-clue cells alike.
    final clueSpec = state.puzzle.cells.firstWhereOrNull(
      (c) => c.type == CellType.clue && c.row == cell.row && c.col == cell.col,
    );
    if (clueSpec != null && clueSpec.clues.isNotEmpty) {
      _showClueSheet(context, clueSpec.clues);
      return;
    }
    final bloc = context.read<GameBloc>();
    if (state.selectedRackIndex != -1) {
      // A rack tile is selected — place it only on a valid empty letter cell.
      // Invalid targets are ignored; the selection is kept so the player can
      // tap a different cell without re-selecting the tile.
      if (_isPlaceable(cell)) {
        bloc.add(LetterPlaced(rackIndex: state.selectedRackIndex, cell: cell));
        bloc.add(const RackTileSelected(-1)); // clear selection
      }
    } else {
      // Tapping a pending letter recalls it to the rack; any other cell tap
      // is inert (the old grey word-highlight was dropped as noise).
      final isPending = state.pendingPlacements.any(
        (p) => p.cell.row == cell.row && p.cell.col == cell.col,
      );
      if (isPending) bloc.add(LetterRecalled(cell));
    }
  }

  /// Opens the read-only clue sheet for [clues] (free; just reveals the text).
  void _showClueSheet(BuildContext context, List<ClueSpec> clues) {
    showModalBottomSheet<void>(
      context: context,
      builder: (_) => ClueSheet(clues: clues),
    );
  }

  /// Asks for confirmation, then reveals the chosen clue's word as a ghost.
  /// On a double-clue cell [bottomHalf] picks the lower clue.
  Future<void> _confirmReveal(BuildContext context, CellSpec spec, bool bottomHalf) async {
    final clue = spec.clues.length >= 2 && bottomHalf ? spec.clues[1] : spec.clues[0];
    final bloc = context.read<GameBloc>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Bu kelimeyi açmak istediğinize emin misiniz?'),
        content: Text(clue.text),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hayır')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Evet')),
        ],
      ),
    );
    // "Hayır" (or dismissing the dialog) keeps the player in reveal mode.
    if (!mounted || confirmed != true) return;
    bloc.add(WordRevealed(clue.wordId));
    setState(() => _revealMode = false);
  }

  /// Confirms the +1 letter joker; "Evet" unlocks the sixth rack slot.
  Future<void> _confirmSixthSlot(BuildContext context) async {
    final bloc = context.read<GameBloc>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('+1 harf jokeri'),
        content: const Text(
          'Reklam izleyerek 6. harf yuvasını açmak ister misin? '
          'Bu maç boyunca her el 6 harfle oynarsın; eli boşaltırsan +6 bonus!',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hayır')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Evet')),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;
    // TODO: gate behind a real rewarded ad once AdService lands (mock for MVP).
    bloc.add(const SixthSlotUnlocked());
  }

  /// Opens the swap sheet; dispatches the swap with the chosen payment.
  Future<void> _showSwapSheet(BuildContext context) async {
    final bloc = context.read<GameBloc>();
    final choice = await showModalBottomSheet<SwapChoice>(
      context: context,
      builder: (_) => SwapSheet(rack: state.rack, quotaRemaining: state.swapQuotaRemaining),
    );
    if (!mounted || choice == null) return;
    // TODO: gate the viaAd path behind a real rewarded ad (AdService phase).
    bloc.add(LettersSwapped(choice.indices, viaAd: choice.viaAd));
  }
}
