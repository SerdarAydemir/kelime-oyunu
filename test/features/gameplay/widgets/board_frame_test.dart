// test/features/gameplay/widgets/board_frame_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kelime_oyunu/features/gameplay/widgets/board_frame.dart';

void main() {
  test('cellSize takes the 6 dp padding and 1 px border off both axes', () {
    // 9 × 7 grid in a 364 × 800 box: width-bound → (364 − 14) / 7 = 50.
    final cell = BoardFrame.cellSize(
      const BoxConstraints(maxWidth: 364, maxHeight: 800),
      rows: 9,
      cols: 7,
    );
    expect(cell, 50);
    // Height-bound: (464 − 14) / 9 = 50.
    expect(
      BoardFrame.cellSize(const BoxConstraints(maxWidth: 800, maxHeight: 464), rows: 9, cols: 7),
      50,
    );
  });

  testWidgets('the child receives exact grid-sized constraints', (tester) async {
    BoxConstraints? seen;
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: SizedBox(
            width: 364,
            height: 800,
            child: BoardFrame(
              rows: 9,
              cols: 7,
              child: LayoutBuilder(
                builder: (_, constraints) {
                  seen = constraints;
                  return const SizedBox.expand();
                },
              ),
            ),
          ),
        ),
      ),
    );
    expect(seen, const BoxConstraints.tightFor(width: 350, height: 450));
    // The frame itself is grid + 2 × (6 + 1) on each axis.
    expect(tester.getSize(find.byType(Container)), const Size(364, 464));
  });
}
