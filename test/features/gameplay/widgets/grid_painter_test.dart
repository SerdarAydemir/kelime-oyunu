// test/features/gameplay/widgets/grid_painter_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kelime_oyunu/data/models/puzzle.dart';
import 'package:kelime_oyunu/features/gameplay/widgets/grid_painter.dart';

// A 9x7 puzzle exercising every static branch: a blank top-left corner (the
// brand "K"), a single long clue (auto-scale + ellipsis path), a double-clue
// cell (split + divider), and a letter cell. (0,0) is intentionally absent so
// it renders as the brand corner.
const _puzzle = PuzzleData(
  schemaVersion: 2,
  puzzleId: 1,
  size: PuzzleSize.medium,
  grid: GridSize(rows: 9, cols: 7),
  cells: [
    CellSpec(
      row: 0,
      col: 1,
      type: CellType.clue,
      clues: [
        ClueSpec(
          text: 'Çok uzun bir ipucu metni — hücreye sığması için küçültülmeli',
          arrow: ClueArrow.down,
          wordId: 'w1',
          source: 'test',
        ),
      ],
    ),
    CellSpec(
      row: 0,
      col: 2,
      type: CellType.clue,
      clues: [
        ClueSpec(text: 'Farklı renklerde', arrow: ClueArrow.down, wordId: 'w2', source: 'test'),
        ClueSpec(
          text: 'Futbolda atlanamayan',
          arrow: ClueArrow.right,
          wordId: 'w3',
          source: 'test',
        ),
      ],
    ),
    CellSpec(row: 1, col: 1, type: CellType.letter, solution: 'A', wordIds: ['w1']),
  ],
  words: [],
  difficulty: 'medium',
  difficultyScore: 30,
  templateId: 'test_template',
  safety: SafetyInfo(postFillScanned: true, scannerVersion: '2.0.0'),
  generatedAt: '2026-01-01T00:00:00Z',
  generatorVersion: '2.0.0',
);

Widget _harness({
  required double width,
  required double height,
  void Function(WordCell, bool)? onTap,
}) {
  return MaterialApp(
    home: Scaffold(
      body: SizedBox(
        width: width,
        height: height,
        child: GridPainter(
          puzzle: _puzzle,
          board: const {},
          pendingPlacements: const [],
          highlightedWordId: null,
          revealedWordIds: const {},
          botPlacedCells: const {},
          revealMode: false,
          onCellTap: onTap ?? (_, _) {},
        ),
      ),
    ),
  );
}

void main() {
  group('GridPainter renders without overflow or exception', () {
    // Each entry is a (width, height) constraint to stress the fit math.
    const cases = <(String, double, double)>[
      ('normal portrait', 360, 640),
      ('wide and short', 720, 200),
      ('extremely narrow', 20, 20),
      ('sub-cell tiny', 6, 6),
    ];

    for (final (label, w, h) in cases) {
      testWidgets('fits $label ($w x $h)', (tester) async {
        await tester.pumpWidget(_harness(width: w, height: h));
        // No layout overflow, no painter assert, no division-by-zero, etc.
        expect(tester.takeException(), isNull);
        expect(find.byType(GridPainter), findsOneWidget);
      });
    }
  });

  testWidgets('maps a tap to the correct cell using the fitted cell size', (tester) async {
    WordCell? tapped;
    // 350x450 viewport: cell = min(350/7, 450/9) = min(50, 50) = 50.
    // The fitted grid (350x450) exactly fills the box, so a tap at (75, 75)
    // lands in column 1, row 1.
    await tester.pumpWidget(_harness(width: 350, height: 450, onTap: (cell, _) => tapped = cell));
    await tester.tapAt(const Offset(75, 75));
    await tester.pump();

    expect(tapped, const WordCell(row: 1, col: 1));
  });
}
