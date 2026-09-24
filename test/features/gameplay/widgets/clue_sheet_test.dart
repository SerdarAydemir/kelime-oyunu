// test/features/gameplay/widgets/clue_sheet_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kelime_oyunu/data/models/puzzle.dart';
import 'package:kelime_oyunu/features/gameplay/widgets/clue_sheet.dart';

// Relative import — test helpers are not importable via package: path.
// ignore: always_use_package_imports
import '../../../helpers/localized_app.dart';

Widget _harness(List<ClueSheetEntry> entries) => localizedApp(
  home: Scaffold(
    body: ClueSheet(cell: const WordCell(row: 0, col: 2), entries: entries),
  ),
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
  testWidgets('double-clue cell: plural title, position subtitle, one card per clue', (
    tester,
  ) async {
    await tester.pumpWidget(_harness(const [(clue: _down, length: 5), (clue: _right, length: 3)]));

    expect(find.text('İpuçları'), findsOneWidget);
    expect(find.text('1. satır · 3. sütun — bu hücre iki kelimeye açılıyor'), findsOneWidget);
    expect(find.text('AŞAĞI · 5 HARF'), findsOneWidget);
    expect(find.text('SAĞA · 3 HARF'), findsOneWidget);
    expect(find.text('Farklı renklerde'), findsOneWidget);
    expect(find.text('Futbolda atlanamayan'), findsOneWidget);
    // One arrow per clue, matching each clue's direction.
    expect(find.byIcon(Icons.arrow_downward), findsOneWidget);
    expect(find.byIcon(Icons.arrow_forward), findsOneWidget);
    expect(find.text('Kapat'), findsOneWidget);
  });

  testWidgets('single clue: singular title, plain position, one card', (tester) async {
    await tester.pumpWidget(_harness(const [(clue: _down, length: 5)]));

    expect(find.text('İpucu'), findsOneWidget);
    expect(find.text('1. satır · 3. sütun'), findsOneWidget);
    expect(find.text('Farklı renklerde'), findsOneWidget);
    expect(find.text('Futbolda atlanamayan'), findsNothing);
  });
}
