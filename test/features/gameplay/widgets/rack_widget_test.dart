// test/features/gameplay/widgets/rack_widget_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kelime_oyunu/core/widgets/dashed_border.dart';
import 'package:kelime_oyunu/features/gameplay/engine/rack_manager.dart';
import 'package:kelime_oyunu/features/gameplay/widgets/action_bar.dart';
import 'package:kelime_oyunu/features/gameplay/widgets/ad_label.dart';
import 'package:kelime_oyunu/features/gameplay/widgets/rack_widget.dart';

// Relative import — test helpers are not importable via package: path.
// ignore: always_use_package_imports
import '../../../helpers/localized_app.dart';

const _rack = [RackTile(letter: 'K'), RackTile(letter: 'O', isPlaced: true), RackTile(letter: 'L')];

Widget _rackHarness({int selected = -1, bool plus = false, bool adLabel = false}) => localizedApp(
  home: Scaffold(
    body: Center(
      child: RackWidget(
        rack: _rack,
        selectedIndex: selected,
        showPlusSlot: plus,
        showAdLabel: adLabel,
        onPlusTap: () {},
        onTileTap: (_) {},
        onTileRecall: (_) {},
      ),
    ),
  ),
);

void main() {
  testWidgets('a placed tile becomes a dashed empty slot, its letter hidden', (tester) async {
    await tester.pumpWidget(_rackHarness());
    expect(find.text('K'), findsOneWidget);
    expect(find.text('L'), findsOneWidget);
    expect(find.text('O'), findsNothing);
    expect(
      find.byWidgetPredicate((w) => w is CustomPaint && w.painter is DashedBorderPainter),
      findsOneWidget,
    );
  });

  testWidgets('tiles and the joker slot are labelled for TalkBack', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_rackHarness(selected: 2, plus: true));
    expect(find.bySemanticsLabel('Harf K'), findsOneWidget);
    expect(find.bySemanticsLabel('Yerleştirildi; geri almak için basılı tut'), findsOneWidget);
    expect(find.bySemanticsLabel('Harf L, seçili'), findsOneWidget);
    expect(find.bySemanticsLabel('HARF EKLE'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('the selected tile is lifted 8 dp', (tester) async {
    await tester.pumpWidget(_rackHarness(selected: 2));
    await tester.pumpAndSettle();
    final idle = tester.getTopLeft(find.text('K'));
    final lifted = tester.getTopLeft(find.text('L'));
    expect(idle.dy - lifted.dy, 8);
  });

  testWidgets('the joker slot shows HARF EKLE, and the ad label only past level 3', (tester) async {
    await tester.pumpWidget(_rackHarness(plus: true, adLabel: showAdLabelsFor(2)));
    expect(find.text('HARF EKLE'), findsOneWidget);
    expect(find.byType(AdLabel), findsNothing);

    await tester.pumpWidget(_rackHarness(plus: true, adLabel: showAdLabelsFor(4)));
    expect(find.byType(AdLabel), findsOneWidget);
    expect(find.text('reklam'), findsOneWidget);
  });

  testWidgets('action bar reads Sıra rakipte during the bot turn', (tester) async {
    Widget bar({required bool botTurn}) => localizedApp(
      home: Scaffold(
        body: ActionBar(
          pendingPlacements: const [],
          onConfirm: () {},
          onPass: () {},
          onSwap: () {},
          onReveal: () {},
          botTurn: botTurn,
          showAdLabel: true,
        ),
      ),
    );
    await tester.pumpWidget(bar(botTurn: false));
    expect(find.text('Pas'), findsOneWidget);
    expect(find.text('İPUCU AL'), findsOneWidget);
    expect(find.byType(AdLabel), findsOneWidget);

    await tester.pumpWidget(bar(botTurn: true));
    expect(find.text('Sıra rakipte'), findsOneWidget);
    expect(find.text('Pas'), findsNothing);
  });
}
