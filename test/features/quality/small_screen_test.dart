// test/features/quality/small_screen_test.dart
//
// 360 × 640 dp phone: the game chrome must fit with the board still getting
// a usable cell, using the compact rack / bar (README shrink order).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kelime_oyunu/core/constants/app_dimensions.dart';
import 'package:kelime_oyunu/features/gameplay/engine/rack_manager.dart';
import 'package:kelime_oyunu/features/gameplay/widgets/action_bar.dart';
import 'package:kelime_oyunu/features/gameplay/widgets/board_frame.dart';
import 'package:kelime_oyunu/features/gameplay/widgets/level_top_bar.dart';
import 'package:kelime_oyunu/features/gameplay/widgets/rack_widget.dart';
import 'package:kelime_oyunu/features/gameplay/widgets/score_header.dart';
import 'package:kelime_oyunu/features/gameplay/widgets/turn_pill.dart';

// Relative import — test helpers are not importable via package: path.
// ignore: always_use_package_imports
import '../../helpers/localized_app.dart';

const _rack = [
  RackTile(letter: 'K'),
  RackTile(letter: 'O'),
  RackTile(letter: 'L'),
  RackTile(letter: 'A'),
  RackTile(letter: 'Y'),
];

/// Mirrors GameActiveBody's column with the compact switch it makes.
Widget _chrome(BuildContext context) {
  final compact = MediaQuery.sizeOf(context).height < AppDimensions.compactHeightBreakpoint;
  return Scaffold(
    body: SafeArea(
      child: Column(
        children: [
          LevelTopBar(levelId: 3, onExit: () {}),
          const ScoreHeader(playerScore: 12, botScore: 9, botName: 'Rakip', botThinking: false),
          Padding(
            padding: EdgeInsets.symmetric(
              vertical: compact ? AppDimensions.space4 : AppDimensions.space8,
            ),
            child: const TurnPill(spec: (text: 'Sıra sende', tint: TurnTint.player, dots: false)),
          ),
          Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: AppDimensions.space16,
                vertical: compact ? AppDimensions.space4 : AppDimensions.space8,
              ),
              child: const BoardFrame(rows: 9, cols: 7, child: SizedBox.expand()),
            ),
          ),
          Padding(
            padding: EdgeInsets.only(top: compact ? AppDimensions.space4 : AppDimensions.space12),
            child: RackWidget(
              rack: _rack,
              showPlusSlot: true,
              compact: compact,
              onTileTap: (_) {},
              onTileRecall: (_) {},
            ),
          ),
          ActionBar(
            compact: compact,
            pendingPlacements: const [],
            onConfirm: () {},
            onPass: () {},
            onSwap: () {},
            onReveal: () {},
          ),
        ],
      ),
    ),
  );
}

void main() {
  testWidgets('360 × 640: no overflow, compact rack, board cell ≥ 36 dp', (tester) async {
    // ignore: deprecated_member_use
    tester.binding.window.physicalSizeTestValue = const Size(1080, 1920);
    // ignore: deprecated_member_use
    tester.binding.window.devicePixelRatioTestValue = 3;
    addTearDown(() {
      // ignore: deprecated_member_use
      tester.binding.window.clearPhysicalSizeTestValue();
      // ignore: deprecated_member_use
      tester.binding.window.clearDevicePixelRatioTestValue();
    });

    await tester.pumpWidget(localizedApp(home: const Builder(builder: _chrome)));
    await tester.pump();
    expect(tester.takeException(), isNull);

    final tile = tester.getSize(find.text('K').first);
    expect(tester.widget<RackWidget>(find.byType(RackWidget)).compact, isTrue);
    expect(tile.height, lessThanOrEqualTo(AppDimensions.tileHeightCompact));

    // The board takes what is left; 7 columns on 328 dp → cells are width-bound
    // only if the height allows ≥ 36 dp cells.
    final board = tester.getSize(find.byType(BoardFrame));
    final cell = BoardFrame.cellSize(
      BoxConstraints(maxWidth: board.width, maxHeight: board.height),
      rows: 9,
      cols: 7,
    );
    expect(cell, greaterThanOrEqualTo(36));
  });

  testWidgets('390 × 844: the regular (non-compact) rack is used', (tester) async {
    // ignore: deprecated_member_use
    tester.binding.window.physicalSizeTestValue = const Size(1170, 2532);
    // ignore: deprecated_member_use
    tester.binding.window.devicePixelRatioTestValue = 3;
    addTearDown(() {
      // ignore: deprecated_member_use
      tester.binding.window.clearPhysicalSizeTestValue();
      // ignore: deprecated_member_use
      tester.binding.window.clearDevicePixelRatioTestValue();
    });
    await tester.pumpWidget(localizedApp(home: const Builder(builder: _chrome)));
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(tester.widget<RackWidget>(find.byType(RackWidget)).compact, isFalse);
  });
}
