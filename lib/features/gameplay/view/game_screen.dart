// lib/features/gameplay/view/game_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:kelime_oyunu/data/models/puzzle.dart';
import 'package:kelime_oyunu/data/repositories/puzzle_repository.dart';
import 'package:kelime_oyunu/features/gameplay/bloc/game_bloc.dart';
import 'package:kelime_oyunu/features/gameplay/bloc/game_event.dart';
import 'package:kelime_oyunu/features/gameplay/bloc/game_state.dart';
import 'package:kelime_oyunu/features/gameplay/engine/bot_engine.dart';
import 'package:kelime_oyunu/features/gameplay/engine/rack_manager.dart';
import 'package:kelime_oyunu/features/gameplay/engine/score_engine.dart';
import 'package:kelime_oyunu/features/gameplay/widgets/action_bar.dart';
import 'package:kelime_oyunu/features/gameplay/widgets/grid_painter.dart';
import 'package:kelime_oyunu/features/gameplay/widgets/rack_widget.dart';
import 'package:kelime_oyunu/features/gameplay/widgets/score_header.dart';

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
  const GameScreen({required this.puzzleId, super.key});

  final int puzzleId;

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
      )..add(PuzzleLoadRequested(puzzleId)),
      child: const _GameBody(),
    );
  }
}

/// Reads [GameBloc] from context; drives the [BlocConsumer] and routing.
class _GameBody extends StatelessWidget {
  const _GameBody();

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<GameBloc, GameState>(
      listenWhen: (prev, curr) =>
          curr is GameError ||
          (prev is GameActive &&
              curr is GameActive &&
              prev.status != curr.status),
      listener: (context, state) {
        if (state is GameError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.message)),
          );
        } else if (state is GameActive && state.status != GameStatus.playing) {
          context.go('/result'); // TODO: wire up result route
        }
      },
      builder: (context, state) {
        return Scaffold(
          body: switch (state) {
            GameInitial() || GameLoading() =>
              const Center(child: CircularProgressIndicator()),
            GameError(:final message) => Center(child: Text(message)),
            GameActive() => _GameActiveBody(state: state),
          },
        );
      },
    );
  }
}

/// Full game UI rendered while a match is in progress.
class _GameActiveBody extends StatelessWidget {
  const _GameActiveBody({required this.state});

  final GameActive state;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          ScoreHeader(
            playerScore: state.playerScore,
            botScore: state.botScore,
            botName: _kBotProfile.name,
            botThinking: state.botThinking,
          ),
          Expanded(
            child: Center(
              child: GridPainter(
                puzzle: state.puzzle,
                board: state.board,
                pendingPlacements: state.pendingPlacements,
                highlightedWordId: state.highlightedWordId,
                revealedWordIds: state.revealedWordIds,
                onCellTap: (cell) => _onCellTap(context, cell),
              ),
            ),
          ),
          RackWidget(
            rack: state.rack,
            onTileTap: (i) =>
                context.read<GameBloc>().add(RackTileSelected(i)),
          ),
          ActionBar(
            pendingPlacements: state.pendingPlacements,
            onConfirm: () =>
                context.read<GameBloc>().add(const MoveConfirmed()),
            onPass: () => context.read<GameBloc>().add(const MovePassed()),
            onSwap: state.pendingPlacements.isEmpty
                ? () => _showSwapSheet(context)
                : null,
            onReveal: state.highlightedWordId != null
                ? () => context.read<GameBloc>().add(
                      WordRevealed(state.highlightedWordId!),
                    )
                : null,
          ),
          const SizedBox(height: 50), // TODO: banner ad placeholder
        ],
      ),
    );
  }

  void _onCellTap(BuildContext context, WordCell cell) {
    final bloc = context.read<GameBloc>();
    if (state.selectedRackIndex != -1) {
      // A rack tile is selected — place it on the tapped cell.
      bloc.add(LetterPlaced(rackIndex: state.selectedRackIndex, cell: cell));
      bloc.add(const RackTileSelected(-1)); // clear selection
    } else {
      // No tile selected — try to highlight the word at this cell.
      var wordId = '';
      for (final w in state.puzzle.words) {
        if (w.cells.any((c) => c.row == cell.row && c.col == cell.col)) {
          wordId = w.id;
          break;
        }
      }
      if (wordId.isNotEmpty) bloc.add(WordSelected(wordId));
    }
  }

  void _showSwapSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      builder: (_) => const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('Harf değiştirme yakında'), // TODO: SwapSheet
        ),
      ),
    );
  }
}
