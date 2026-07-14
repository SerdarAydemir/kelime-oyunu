// test/features/gameplay/widgets/grid_painter_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kelime_oyunu/data/models/puzzle.dart';
import 'package:kelime_oyunu/features/gameplay/engine/rack_manager.dart';
import 'package:kelime_oyunu/features/gameplay/engine/score_engine.dart';
import 'package:kelime_oyunu/features/gameplay/widgets/grid_painter.dart';
import 'package:kelime_oyunu/features/gameplay/widgets/rack_widget.dart';

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
  void Function(DragTileData, WordCell)? onDrop,
  bool Function(WordCell)? isPlaceable,
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
          onCellDrop: onDrop ?? (_, _) {},
          isCellPlaceable: isPlaceable ?? (_) => true,
        ),
      ),
    ),
  );
}

/// Grid + a one-tile rack in the same tree, so a real Draggable/DragTarget
/// round-trip can be driven with test gestures.
///
/// [outerHeight] > 450 leaves vertical slack around the 350x450 grid, so the
/// Center inside GridPainter offsets the grid downward — the regression case
/// where drag coordinates were converted against the wrong render box and
/// drops landed a cell below the finger.
Widget _dragHarness({
  required void Function(DragTileData, WordCell) onDrop,
  bool Function(WordCell)? isPlaceable,
  bool dragEnabled = true,
  double outerHeight = 450,
  List<Placement> pending = const [],
  void Function(WordCell)? onPendingCancelled,
}) {
  return MaterialApp(
    home: Scaffold(
      body: Column(
        children: [
          SizedBox(
            width: 350,
            height: outerHeight, // grid itself: cell = min(350/7, 450/9) = 50
            child: GridPainter(
              puzzle: _puzzle,
              board: const {},
              pendingPlacements: pending,
              highlightedWordId: null,
              revealedWordIds: const {},
              botPlacedCells: const {},
              revealMode: false,
              onCellTap: (_, _) {},
              onCellDrop: onDrop,
              isCellPlaceable: isPlaceable ?? (_) => true,
              pendingDragEnabled: pending.isNotEmpty,
              rackIndexForPending: (_) => 0,
              onPendingDragCancelled: onPendingCancelled,
            ),
          ),
          RackWidget(
            rack: const [RackTile(letter: 'K')],
            onTileTap: (_) {},
            onTileRecall: (_) {},
            dragEnabled: dragEnabled,
          ),
        ],
      ),
    ),
  );
}

/// Drags from [source] and releases so the floating tile's VISUAL CENTRE sits
/// on [target] — mirroring how the player aims: the finger itself ends up
/// kDragFeedbackCentreOffset below the shown tile (WYSIWYG placement).
Future<void> _dragFromTo(WidgetTester tester, Offset source, Offset target) async {
  final gesture = await tester.startGesture(source);
  await tester.pump(const Duration(milliseconds: 50));
  await gesture.moveTo(target - kDragFeedbackCentreOffset);
  await tester.pump();
  await gesture.up();
  await tester.pumpAndSettle();
}

/// Drives a full drag gesture from the rack tile, aiming the tile at [target].
Future<void> _dragTileTo(WidgetTester tester, Offset target) async {
  await _dragFromTo(tester, tester.getCenter(find.text('K')), target);
}

/// Top-left of the painted grid itself (the inner SizedBox), NOT of the
/// GridPainter widget — when the outer box is larger than the grid, Center
/// offsets the grid and the two differ. Drop targets must use this origin.
Offset _gridOrigin(WidgetTester tester) => tester.getTopLeft(
  find.descendant(of: find.byType(GridPainter), matching: find.byType(CustomPaint)).first,
);

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

  group('drag and drop', () {
    testWidgets('dropping a rack tile on a placeable cell fires onCellDrop', (tester) async {
      (DragTileData, WordCell)? dropped;
      await tester.pumpWidget(_dragHarness(onDrop: (d, cell) => dropped = (d, cell)));

      // Cell (1,1) centre in global coordinates: grid origin + (75, 75).
      await _dragTileTo(tester, _gridOrigin(tester) + const Offset(75, 75));

      expect(dropped, ((rackIndex: 0, fromCell: null), const WordCell(row: 1, col: 1)));
    });

    testWidgets('drop lands on the aimed cell when the grid is centred in a larger box', (
      tester,
    ) async {
      // Regression: 100px of vertical slack centres the grid 50px (a full
      // cell) below the GridPainter's top-left. Converting drag coordinates
      // against the wrong render box made drops land a cell below the finger.
      // 550 keeps grid+rack inside the 600px test viewport.
      (DragTileData, WordCell)? dropped;
      await tester.pumpWidget(
        _dragHarness(onDrop: (d, cell) => dropped = (d, cell), outerHeight: 550),
      );

      await _dragTileTo(tester, _gridOrigin(tester) + const Offset(75, 75));

      expect(dropped, ((rackIndex: 0, fromCell: null), const WordCell(row: 1, col: 1)));
    });

    testWidgets('dropping on a non-placeable cell does not fire onCellDrop', (tester) async {
      (DragTileData, WordCell)? dropped;
      await tester.pumpWidget(
        _dragHarness(onDrop: (d, cell) => dropped = (d, cell), isPlaceable: (_) => false),
      );

      await _dragTileTo(tester, _gridOrigin(tester) + const Offset(75, 75));

      expect(dropped, isNull);
    });

    testWidgets('drop maps to the correct cell while the grid is pinch-zoomed', (tester) async {
      (DragTileData, WordCell)? dropped;
      await tester.pumpWidget(_dragHarness(onDrop: (d, cell) => dropped = (d, cell)));

      // Two-finger pinch-out focused ON cell (1,1): the InteractiveViewer
      // keeps the focal point stationary, so that cell stays visible at the
      // same screen position while the grid zooms around it.
      final cellCentre = _gridOrigin(tester) + const Offset(75, 75);
      final finger1 = await tester.createGesture();
      final finger2 = await tester.createGesture();
      await finger1.down(cellCentre - const Offset(20, 0));
      await finger2.down(cellCentre + const Offset(20, 0));
      await tester.pump();
      await finger1.moveBy(const Offset(-60, 0));
      await finger2.moveBy(const Offset(60, 0));
      await tester.pump();
      await finger1.up();
      await finger2.up();
      await tester.pumpAndSettle();

      // Measure the zoomed grid (getRect applies the IV transform) and aim
      // for the centre of cell (1,1) in zoomed screen coordinates. Thanks to
      // the focal-point pinch, that cell is still inside the viewport.
      final paintRect = tester.getRect(
        find.descendant(of: find.byType(GridPainter), matching: find.byType(CustomPaint)).first,
      );
      final zoomedCell = paintRect.width / 7;
      expect(zoomedCell, greaterThan(51.0), reason: 'pinch should have zoomed the grid');
      await _dragTileTo(tester, paintRect.topLeft + Offset(zoomedCell * 1.5, zoomedCell * 1.5));

      expect(dropped, ((rackIndex: 0, fromCell: null), const WordCell(row: 1, col: 1)));
    });

    testWidgets('aiming the tile at the BOTTOM row drops there (finger below the grid)', (
      tester,
    ) async {
      // Regression: the DragTarget used to be hit-tested at the finger, so
      // aiming the floating tile at the bottom row — which leaves the finger
      // below the grid — found no target and made the row an unreachable
      // dead zone. feedbackOffset moves the hit test to the tile's centre.
      (DragTileData, WordCell)? dropped;
      await tester.pumpWidget(_dragHarness(onDrop: (d, cell) => dropped = (d, cell)));

      // Bottom row (8) centre: origin + (75, 8*50+25). The finger ends up
      // ~45px lower — outside the grid, over the rack area.
      await _dragTileTo(tester, _gridOrigin(tester) + const Offset(75, 425));

      expect(dropped, ((rackIndex: 0, fromCell: null), const WordCell(row: 8, col: 1)));
    });

    testWidgets('drag is inert when dragEnabled is false (bot turn / reveal mode)', (tester) async {
      (DragTileData, WordCell)? dropped;
      await tester.pumpWidget(
        _dragHarness(onDrop: (d, cell) => dropped = (d, cell), dragEnabled: false),
      );

      await _dragTileTo(tester, _gridOrigin(tester) + const Offset(75, 75));

      expect(dropped, isNull);
    });
  });

  group('pending letter drag (move without recall detour)', () {
    const pendingCell = WordCell(row: 1, col: 1);
    const pending = [Placement(cell: pendingCell, letter: 'K', expected: 'A')];

    testWidgets('dragging a pending letter to another cell reports fromCell', (tester) async {
      (DragTileData, WordCell)? dropped;
      await tester.pumpWidget(
        _dragHarness(onDrop: (d, cell) => dropped = (d, cell), pending: pending),
      );

      // Grab the pending letter at its cell centre, aim the tile at (2,2).
      final origin = _gridOrigin(tester);
      await _dragFromTo(tester, origin + const Offset(75, 75), origin + const Offset(125, 125));

      expect(dropped, ((rackIndex: 0, fromCell: pendingCell), const WordCell(row: 2, col: 2)));
    });

    testWidgets('dropping a pending letter outside the grid cancels (recall)', (tester) async {
      (DragTileData, WordCell)? dropped;
      WordCell? cancelled;
      await tester.pumpWidget(
        _dragHarness(
          onDrop: (d, cell) => dropped = (d, cell),
          pending: pending,
          onPendingCancelled: (cell) => cancelled = cell,
        ),
      );

      // Release below the grid (over the rack area), outside the DragTarget.
      final origin = _gridOrigin(tester);
      await _dragFromTo(tester, origin + const Offset(75, 75), origin + const Offset(75, 500));

      expect(dropped, isNull);
      expect(cancelled, pendingCell);
    });
  });
}
