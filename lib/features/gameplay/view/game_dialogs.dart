// lib/features/gameplay/view/game_dialogs.dart

import 'package:flutter/material.dart';
import 'package:kelime_oyunu/data/models/puzzle.dart';
import 'package:kelime_oyunu/features/gameplay/bloc/game_state.dart';
import 'package:kelime_oyunu/features/gameplay/engine/rack_manager.dart';
import 'package:kelime_oyunu/features/gameplay/widgets/clue_sheet.dart';
import 'package:kelime_oyunu/features/gameplay/widgets/result_dialog.dart';
import 'package:kelime_oyunu/features/gameplay/widgets/swap_sheet.dart';
import 'package:kelime_oyunu/l10n/generated/app_localizations.dart';

/// Modal dialogs and bottom sheets opened by the active game body. Each one
/// only collects the player's answer; dispatching to the bloc stays with the
/// caller (which also owns the `mounted` check after the await).

/// Shows the end-of-match modal. The dialog pops itself before any of the
/// callbacks fires, so callers can navigate or reload straight away.
///
/// showDialog pushes onto the root navigator, whose context sits outside the
/// screen's BlocProvider — the caller must capture bloc/router *before* this.
Future<void> showMatchResultDialog(
  BuildContext context, {
  required GameActive state,
  required String botName,
  required int levelId,
  required VoidCallback onReplay,
  required VoidCallback onNext,
  required VoidCallback onLevels,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => ResultDialog(
      status: state.status,
      playerScore: state.playerScore,
      botScore: state.botScore,
      botName: botName,
      levelId: levelId,
      onReplay: () {
        Navigator.of(dialogContext).pop();
        onReplay();
      },
      onNext: () {
        Navigator.of(dialogContext).pop();
        onNext();
      },
      onLevels: () {
        Navigator.of(dialogContext).pop();
        onLevels();
      },
    ),
  );
}

/// Opens the read-only clue sheet for [clues] (free; just reveals the text).
void showClueSheet(BuildContext context, List<ClueSpec> clues) {
  showModalBottomSheet<void>(
    context: context,
    builder: (_) => ClueSheet(clues: clues),
  );
}

/// Asks whether to spend the reveal joker on [clue]'s word. Returns true only
/// on "Evet"; "Hayır" and dismissing the dialog both return false.
Future<bool> confirmRevealDialog(BuildContext context, ClueSpec clue) async {
  final l10n = AppLocalizations.of(context);
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(l10n.revealConfirmTitle),
      content: Text(clue.text),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.no)),
        TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(l10n.yes)),
      ],
    ),
  );
  return confirmed == true;
}

/// Asks whether to unlock the sixth rack slot (+1 letter joker). Returns true
/// only on "Evet".
Future<bool> confirmSixthSlotDialog(BuildContext context) async {
  final l10n = AppLocalizations.of(context);
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(l10n.sixthSlotTitle),
      content: Text(l10n.sixthSlotBody),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.no)),
        TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(l10n.yes)),
      ],
    ),
  );
  return confirmed == true;
}

/// Opens the swap sheet; null when the player closed it without choosing.
Future<SwapChoice?> showSwapSheet(
  BuildContext context, {
  required List<RackTile> rack,
  required int quotaRemaining,
}) {
  return showModalBottomSheet<SwapChoice>(
    context: context,
    builder: (_) => SwapSheet(rack: rack, quotaRemaining: quotaRemaining),
  );
}
