// lib/features/gameplay/view/game_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kelime_oyunu/data/repositories/progress_repository.dart';
import 'package:kelime_oyunu/data/repositories/puzzle_repository.dart';
import 'package:kelime_oyunu/data/repositories/session_repository.dart';
import 'package:kelime_oyunu/features/gameplay/bloc/game_bloc.dart';
import 'package:kelime_oyunu/features/gameplay/bloc/game_event.dart';
import 'package:kelime_oyunu/features/gameplay/bloc/game_state.dart';
import 'package:kelime_oyunu/features/gameplay/engine/bot_engine.dart';
import 'package:kelime_oyunu/features/gameplay/engine/rack_manager.dart';
import 'package:kelime_oyunu/features/gameplay/engine/score_engine.dart';
import 'package:kelime_oyunu/features/gameplay/view/game_active_body.dart';
import 'package:kelime_oyunu/l10n/generated/app_localizations.dart';

// Bot identity used for all matches in this version of the screen. The
// opponent is simply "Rakip" (design rule: never a named persona), so the
// display name comes from the active locale.
BotProfile _botProfile(BuildContext context) {
  final l10n = AppLocalizations.of(context);
  return BotProfile(
    id: 'rakip',
    name: l10n.bot,
    avatarAsset: 'assets/images/rakip.png',
    description: l10n.botDescription,
    difficultyBand: DifficultyBand.medium,
  );
}

/// Entry point widget. Creates the [GameBloc] and provides it to the subtree.
class GameScreen extends StatelessWidget {
  const GameScreen({
    required this.puzzleId,
    required this.progressRepo,
    required this.sessionRepo,
    this.resume = false,
    super.key,
  });

  final int puzzleId;

  /// Persists the win that unlocks the next level (F7).
  final ProgressRepository progressRepo;

  /// Stores the half-played match for resume (F7).
  final SessionRepository sessionRepo;

  /// Whether to continue the saved match rather than start [puzzleId] fresh.
  /// Falls back to a fresh game when no matching record exists.
  final bool resume;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => GameBloc(
        puzzleRepo: AssetPuzzleRepository(),
        scoreEngine: const ScoreEngine(),
        rackManager: const RackManager(),
        botEngine: const BotEngine(),
        botProfile: _botProfile(context),
        puzzleIndex: puzzleId - 1,
        progressRepo: progressRepo,
        sessionRepo: sessionRepo,
      )..add(resume ? SessionResumeRequested(puzzleId) : PuzzleLoadRequested(puzzleId)),
      child: _SessionFlushListener(child: _GameBody(puzzleId: puzzleId)),
    );
  }
}

/// Writes the match down when the app leaves the foreground.
///
/// The bloc already persists at every turn boundary, so this is a safety net
/// for the states in between — and the only hook that fires when the OS is
/// about to kill the process (architecture.md §11.2).
class _SessionFlushListener extends StatefulWidget {
  const _SessionFlushListener({required this.child});

  final Widget child;

  @override
  State<_SessionFlushListener> createState() => _SessionFlushListenerState();
}

class _SessionFlushListenerState extends State<_SessionFlushListener> {
  late final AppLifecycleListener _listener;

  @override
  void initState() {
    super.initState();
    _listener = AppLifecycleListener(onPause: _flush, onDetach: _flush);
  }

  void _flush() => context.read<GameBloc>().add(const SessionFlushRequested());

  @override
  void dispose() {
    _listener.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
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
            GameActive() => GameActiveBody(
              state: state,
              puzzleId: puzzleId,
              botProfile: _botProfile(context),
            ),
          },
        );
      },
    );
  }
}
