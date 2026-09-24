// lib/features/gameplay/view/game_dialogs.dart

import 'package:flutter/material.dart';
import 'package:kelime_oyunu/data/models/puzzle.dart';
import 'package:kelime_oyunu/features/gameplay/engine/rack_manager.dart';
import 'package:kelime_oyunu/features/gameplay/widgets/clue_sheet.dart';
import 'package:kelime_oyunu/features/gameplay/widgets/swap_sheet.dart';
import 'package:kelime_oyunu/l10n/generated/app_localizations.dart';

/// Modal dialogs and bottom sheets opened by the active game body. Each one
/// only collects the player's answer; dispatching to the bloc stays with the
/// caller (which also owns the `mounted` check after the await).

/// Opens the read-only clue sheet for the clue cell [spec] (free; just
/// reveals the text). Word lengths are looked up in [puzzle] for the
/// "SAĞA · 3 HARF" headings.
void showClueSheet(BuildContext context, CellSpec spec, PuzzleData puzzle) {
  final lengths = {for (final w in puzzle.words) w.id: w.length};
  showModalBottomSheet<void>(
    context: context,
    builder: (_) => ClueSheet(
      cell: WordCell(row: spec.row, col: spec.col),
      entries: [
        for (final clue in spec.clues)
          (clue: clue, length: lengths[clue.wordId] ?? clue.text.length),
      ],
    ),
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
  bool showAdLabel = false,
}) {
  return showModalBottomSheet<SwapChoice>(
    context: context,
    builder: (_) => SwapSheet(rack: rack, quotaRemaining: quotaRemaining, showAdLabel: showAdLabel),
  );
}
