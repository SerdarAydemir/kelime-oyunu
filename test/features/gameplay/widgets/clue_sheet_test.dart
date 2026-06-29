// test/features/gameplay/widgets/clue_sheet_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kelime_oyunu/data/models/puzzle.dart';
import 'package:kelime_oyunu/features/gameplay/widgets/clue_sheet.dart';

Widget _harness(List<ClueSpec> clues) => MaterialApp(
  home: Scaffold(body: ClueSheet(clues: clues)),
);

const _down = ClueSpec(
  text: 'Farklı renklerde',
  arrow: ClueArrow.down,
  wordId: 'w1',
  source: 'test',
);
const _right = ClueSpec(
  text: 'Futbolda atlanamayan',
  arrow: ClueArrow.right,
  wordId: 'w2',
  source: 'test',
);

void main() {
  testWidgets('shows both clue texts and the plural title for a double-clue cell', (tester) async {
    await tester.pumpWidget(_harness(const [_down, _right]));

    expect(find.text('İpuçları'), findsOneWidget);
    expect(find.text('Farklı renklerde'), findsOneWidget);
    expect(find.text('Futbolda atlanamayan'), findsOneWidget);
    // One arrow per clue, matching each clue's direction.
    expect(find.byIcon(Icons.arrow_downward), findsOneWidget);
    expect(find.byIcon(Icons.arrow_forward), findsOneWidget);
  });

  testWidgets('shows the singular title and one text for a single clue', (tester) async {
    await tester.pumpWidget(_harness(const [_down]));

    expect(find.text('İpucu'), findsOneWidget);
    expect(find.text('Farklı renklerde'), findsOneWidget);
    expect(find.text('Futbolda atlanamayan'), findsNothing);
  });
}
