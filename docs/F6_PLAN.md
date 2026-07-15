# F6 — Puan Anlatısı + Harf Uçuşu (Score Narration + Letter Flight)

Status: in progress. Owner: gameplay. Depends on F3 (GameBloc), F4 (GridPainter),
drag&drop groundwork (Draggable.feedback flying-tile, visual-centre↔cell math,
GridDynamicPainter hover layer).

## 1. Goal (approved design, verbatim intent)

When the player confirms (or the bot moves), the score is **not written silently**
into `ScoreHeader`. Instead a **queue of score events** is played:

- **a)** Each placed letter is judged one by one: correct → green **+1** badge over
  the cell, wrong → red **−1**.
- **b)** If the move completed a word: a modern frame/glow around the word (cell-aligned
  rounded rect) + one badge per point (word length).
- **c)** Rack-empty bonus (+5/+6), if any, appears **last**.
- **d)** The `ScoreHeader` counter **counts up** (12→13→14→15, never snaps 12→15).

**Wave flight (parallel, not one-at-a-time):** letters lift 80–100 ms apart — the
first lands while the second is mid-air. A 4-letter move finishes in ~1 s yet each
letter is individually trackable. Badges appear on the same wave.

**Visible source:** player letters fly from the **rack**, bot letters from the **bot
avatar portrait** (a second visual layer on top of the existing colour coding).

**Budget:** ~1.5–2 s narration per move; ≤3–5 s total per round.

**Un-skippable but fast-forwardable:** tapping the screen does not cancel the
narration, it **doubles the speed** (2×). The player never misses the bot's move.

## 2. Where it fits (diagnosis)

- `ScoreEngine.resolveMove` **already** returns an ordered `events: List<ScoreEvent>`
  (per-letter ±1 with cell, word-completion bonus with `completedWordId`/`wordBonus`,
  rack-empty bonus). This is the queue source — no scoring math changes (forbidden).
- `GameBloc._onMoveConfirmed` / `_onBotMoveCompleted` resolve the move and apply
  board+score immediately. The turn sequencing (player→botThinking→bot→player) must
  not change — bloc phase flow stays byte-for-byte compatible so the 102 tests hold.
- The drag layer already solved: floating tile via `Draggable.feedback`
  (`DragFeedbackTile`), visual-centre↔cell mapping (`kDragFeedbackCentreOffset`,
  `box.globalToLocal`/`localToGlobal` walking the `InteractiveViewer` transform),
  and a dynamic repaint layer (`GridDynamicPainter` + `ValueNotifier`).

### Design: UI-layer narration, additive bloc plumbing

The narration engine lives in the **widget layer** (like the hover layer). The bloc
only gains an **additive** `MoveNarration?` on `GameActive` describing the move that
just resolved (actor + ordered events + placements + a monotonic id). No new phases,
no gating events → existing bloc tests untouched.

Turn synchronisation is preserved for free: the player-move narration plays during
the bot's existing 2–5 s "thinking" delay; the bot-move narration is **queued** by
the controller so it always plays after the player's, with input locked throughout.
The controller (not the bloc) owns the animation clock, the displayed score, the
suppressed-cell set and the speed multiplier.

## 3. State machine (UI)

`NarrationController` (ChangeNotifier, driven by an `AnimationController`, vsync from
`_GameActiveBodyState`):

- Queue of `MoveNarration`; dedupe by monotonic `id` (`_lastPlayedId`).
- Per narration: build a **cue timeline** (fractions of [0,1]):
  - letter *i* launches at `i*stagger`, lands at `i*stagger + flightDur` (stagger
    ≈90 ms, flightDur ≈450 ms);
  - word frame appears when its last letter lands;
  - rack-empty bonus badge appears after the last letter;
  - total ≈ `(n-1)*stagger + flightDur + 600ms`, clamped to ~1.2–2.0 s at 1×.
- Displayed score held at the **pre-move** value (`blocScore − Σ event deltas`), then
  raised as each cue fires; `ScoreHeader` tweens between targets (count-up).
- `suppressed`: correct target cells hidden in `GridStaticPainter` until their letter
  lands (avoids a double image with the mid-air tile).
- `speed` ∈ {1,2}; a tap toggles to 2× by rescaling the controller duration and
  continuing from the current value. Never cancels.
- On completion: pop queue; if empty and `phase == finished`, release the result
  dialog (deferred until narration ends).

Input is locked while `narrating` (reveal/drag/action callbacks gated); a
transparent catcher over the board swallows taps and feeds the 2× toggle.

## 4. Files

New:
- `lib/features/gameplay/bloc/move_narration.dart` — `MoveNarration`, `NarrationActor`.
- `lib/features/gameplay/widgets/narration_controller.dart` — clock, queue, timeline,
  displayed scores, suppressed set, speed.
- `lib/features/gameplay/widgets/narration_layer.dart` — visual overlay: flying tiles,
  ±badges, word frames, tap catcher.

Modified (additive):
- `bloc/game_state.dart` — `narration` field (+copyWith/props).
- `bloc/game_bloc.dart` — build+attach `MoveNarration` (monotonic id).
- `view/game_screen.dart` — host controller + overlay; feed geometry; gate input;
  drive displayed score + suppression; defer result dialog.
- `widgets/score_header.dart` — count-up animation; avatar `GlobalKey` (bot launch).
- `widgets/grid_painter.dart` — optional `suppressedCells` passthrough to static painter.
- `widgets/rack_widget.dart` — optional `GlobalKey` for the rack launch point.

## 5. Phases (each: own English conventional commit; analyze 0-error + tests + format)

1. **Score events queue + badges + counter** — bloc plumbing, controller skeleton,
   ±badges popping on the wave, header count-up, input lock, deferred result dialog.
   (Letters still appear instantly; no flight yet.)
2. **Word-completion frame/glow** — cell-aligned rounded rect + glow on the wave,
   word-bonus badge.
3. **Letter flight** — flying tiles rack→cell and portrait→cell; cell suppression
   until landing.
4. **Fast-forward touch** — tap = 2× (never cancel).

Each phase: `flutter analyze` (0), `flutter test` (102 + new stay green),
`dart format --line-length 100`, then live emulator check (play a move + let the bot
move, screenshot, judge timing feel, tune).

## 6. Constraints honoured

- No scoring-math change (display only). No Python/content changes. No `git push`.
- No architecture change (bloc flow identical; narration is additive widget layer).
- `debugPrint` only; `package:` imports; `AppColors`/`AppDimensions` tokens; files ≤300
  lines. (Note: the feature legitimately spans >3 files across the 4 commits; each
  commit stays focused and every file stays under the 300-line cap.)
