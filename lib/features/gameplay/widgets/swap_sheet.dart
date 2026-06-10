// lib/features/gameplay/widgets/swap_sheet.dart

import 'package:flutter/material.dart';
import 'package:kelime_oyunu/core/constants/app_colors.dart';
import 'package:kelime_oyunu/features/gameplay/engine/rack_manager.dart';

/// What the player chose in the swap sheet: which tiles and how to pay.
typedef SwapChoice = ({List<int> indices, bool viaAd});

/// Bottom sheet for the letter-swap joker.
///
/// The player picks tiles, then pays one of two ways: "Şimdi Değiştir"
/// (rewarded ad, turn stays) or "Değiştir ve Onayla" (free, costs the turn).
/// Pops with a [SwapChoice]; null when dismissed.
class SwapSheet extends StatefulWidget {
  const SwapSheet({required this.rack, required this.quotaRemaining, super.key});

  final List<RackTile> rack;

  /// Letters the player may still swap this match; selection is capped to it.
  final int quotaRemaining;

  @override
  State<SwapSheet> createState() => _SwapSheetState();
}

class _SwapSheetState extends State<SwapSheet> {
  final Set<int> _selected = {};

  void _toggle(int index) {
    setState(() {
      if (!_selected.remove(index) && _selected.length < widget.quotaRemaining) {
        _selected.add(index);
      }
    });
  }

  void _finish(bool viaAd) =>
      Navigator.pop(context, (indices: _selected.toList()..sort(), viaAd: viaAd));

  @override
  Widget build(BuildContext context) {
    final hasSelection = _selected.isNotEmpty;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Harf Değiştir',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text('Kalan değiştirme hakkı: ${widget.quotaRemaining} harf'),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < widget.rack.length; i++) ...[
                  if (i > 0) const SizedBox(width: 4),
                  _SelectableTile(
                    letter: widget.rack[i].letter,
                    selected: _selected.contains(i),
                    onTap: () => _toggle(i),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: hasSelection ? () => _finish(true) : null,
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Şimdi Değiştir'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: hasSelection ? () => _finish(false) : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Değiştir ve Onayla'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Şimdi Değiştir: reklam izle, sıra sende kalsın. '
              'Değiştir ve Onayla: reklamsız, sıra rakibe geçer.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}

/// A rack-look tile that toggles selection (orange border when selected).
class _SelectableTile extends StatelessWidget {
  const _SelectableTile({required this.letter, required this.selected, required this.onTap});

  final String letter;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          // TODO: add AppColors.rackTileBg token (0xFFF5E6C8)
          color: const Color(0xFFF5E6C8),
          borderRadius: BorderRadius.circular(6),
          border: selected ? Border.all(color: AppColors.accent, width: 2.5) : null,
        ),
        alignment: Alignment.center,
        child: Text(
          letter,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87),
        ),
      ),
    );
  }
}
