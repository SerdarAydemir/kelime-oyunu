// lib/features/gameplay/widgets/narration_controller.dart

import 'dart:collection';

import 'package:flutter/widgets.dart';
import 'package:kelime_oyunu/data/models/puzzle.dart';
import 'package:kelime_oyunu/features/gameplay/bloc/game_state.dart';
import 'package:kelime_oyunu/features/gameplay/bloc/move_narration.dart';
import 'package:kelime_oyunu/features/gameplay/widgets/narration_timeline.dart';

/// One narration waiting in (or currently on) the clock, paired with the score
/// totals it lands on so the counter can walk up from the pre-move value.
class _Queued {
  _Queued(this.narration, this.timeline, this.targetPlayer, this.targetBot);

  final MoveNarration narration;
  final NarrationTimeline timeline;
  final int targetPlayer;
  final int targetBot;
}

/// Owns the narration clock, queue, lagging display scores, and speed. It is a
/// [ChangeNotifier] driven by one [AnimationController]: every visual (badges,
/// count-up, later the letter flight) is a pure function of [progress], so the
/// bloc never waits on the animation (turn sequencing stays untouched — the
/// widget layer owns timing, per move_narration.dart).
class NarrationController extends ChangeNotifier {
  NarrationController({required TickerProvider vsync})
    : _anim = AnimationController(vsync: vsync, duration: Duration.zero) {
    _anim.addListener(notifyListeners);
    _anim.addStatusListener(_onStatus);
  }

  final AnimationController _anim;
  final Queue<_Queued> _queue = Queue<_Queued>();
  _Queued? _current;

  int _lastSeenId = -1;
  int _displayPlayer = 0;
  int _displayBot = 0;
  bool _initialized = false;
  int _speed = 1;

  /// Fired once whenever the queue empties and the clock stops — the view uses
  /// it to release a deferred end-of-match dialog after the last move narrates.
  VoidCallback? onDrained;

  double get progress => _anim.value;
  bool get narrating => _current != null;
  NarrationActor? get currentActor => _current?.narration.actor;
  NarrationTimeline? get currentTimeline => _current?.timeline;

  /// The player score to show right now: the walked-up value while the player's
  /// move narrates, otherwise the last settled total.
  int get displayPlayerScore =>
      _displayScore(NarrationActor.player, _displayPlayer, (q) => q.targetPlayer);

  int get displayBotScore => _displayScore(NarrationActor.bot, _displayBot, (q) => q.targetBot);

  int _displayScore(NarrationActor actor, int settled, int Function(_Queued) target) {
    final c = _current;
    if (c == null || c.narration.actor != actor) return settled;
    final pre = target(c) - c.narration.scoreDelta;
    return pre + c.timeline.accumulatedDelta(_anim.value);
  }

  /// Absorbs a fresh [GameActive]: enqueues its narration once (deduped by id)
  /// and keeps the settled display scores in step. Safe to call every build.
  void sync(GameActive state) {
    if (!_initialized) {
      _displayPlayer = state.playerScore;
      _displayBot = state.botScore;
      _initialized = true;
    }
    final n = state.narration;
    if (n == null || n.id == _lastSeenId) return;
    _lastSeenId = n.id;
    if (n.isEmpty) {
      // A pass or an empty bot turn: nothing to animate, but keep the display
      // faithful to the (unchanged) totals in case of any drift.
      _displayPlayer = state.playerScore;
      _displayBot = state.botScore;
      return;
    }
    _queue.add(_Queued(n, NarrationTimeline.build(n), state.playerScore, state.botScore));
    if (_current == null) _startNext();
  }

  void _startNext() {
    _current = _queue.removeFirst();
    _anim
      ..duration = Duration(milliseconds: (_current!.timeline.totalMs / _speed).round())
      ..forward(from: 0);
    notifyListeners();
  }

  void _onStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    final done = _current!;
    _displayPlayer = done.targetPlayer;
    _displayBot = done.targetBot;
    _current = null;
    if (_queue.isNotEmpty) {
      _startNext();
    } else {
      _speed = 1; // fresh turns start at 1× again
      notifyListeners();
      onDrained?.call();
    }
  }

  /// A screen tap: play the remainder at 2× without ever cancelling. Idempotent
  /// while already at 2×; the speed persists across the rest of the queued
  /// turn so the player fast-forwards the whole exchange with one touch.
  void toggleSpeed() {
    final c = _current;
    if (c == null || _speed == 2) return;
    _speed = 2;
    final remainingMs = (c.timeline.totalMs * (1 - _anim.value) / 2).round();
    _anim.animateTo(1.0, duration: Duration(milliseconds: remainingMs.clamp(1, 1 << 30)));
  }

  /// Cells whose flying letter has not yet landed — the grid hides the committed
  /// glyph there so the mid-air tile is not doubled, then reveals it exactly as
  /// the tile arrives. Only correct placements commit to the board, so only
  /// those are suppressed; wrong letters never reach it.
  Set<WordCell> get suppressedCells {
    final c = _current;
    if (c == null) return const {};
    final p = _anim.value;
    final cells = <WordCell>{};
    for (final cue in c.timeline.cues) {
      if (cue.kind != CueKind.letter || cue.delta <= 0) continue;
      final cell = cue.event.cell;
      if (cell != null && p < cue.landAt) cells.add(cell);
    }
    return cells;
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }
}
