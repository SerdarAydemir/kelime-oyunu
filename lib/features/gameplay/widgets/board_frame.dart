// lib/features/gameplay/widgets/board_frame.dart

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:kelime_oyunu/core/constants/app_dimensions.dart';
import 'package:kelime_oyunu/core/theme/app_tokens.dart';

/// The board card (README "Board"): `board` background, r16, 6 dp inner
/// padding, 1 px `boardBorder` (transparent in the dark palette) and
/// `boardShadow`. Sizes itself to the largest whole grid that fits the
/// incoming constraints and hands its [child] EXACT grid-sized constraints,
/// so [GridPainter] and [NarrationLayer] — which both derive the cell size
/// from their constraints — agree on the cell math without sharing code.
class BoardFrame extends StatelessWidget {
  const BoardFrame({required this.rows, required this.cols, required this.child, super.key});

  final int rows;
  final int cols;
  final Widget child;

  static const double _padding = AppDimensions.boardPadding;
  static const double _border = 1;

  /// Largest cell that fits [constraints] once the frame's own chrome is taken
  /// off; 0 under degenerate constraints (never negative).
  static double cellSize(BoxConstraints constraints, {required int rows, required int cols}) {
    const chrome = 2 * (_padding + _border);
    final raw = math.min(
      (constraints.maxWidth - chrome) / cols,
      (constraints.maxHeight - chrome) / rows,
    );
    return raw.isFinite ? math.max(0.0, raw) : AppDimensions.gridCellMin;
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return LayoutBuilder(
      builder: (context, constraints) {
        final cell = cellSize(constraints, rows: rows, cols: cols);
        return Center(
          child: Container(
            width: cell * cols + 2 * (_padding + _border),
            height: cell * rows + 2 * (_padding + _border),
            decoration: BoxDecoration(
              color: tokens.board,
              borderRadius: BorderRadius.circular(AppDimensions.radiusBoard),
              border: Border.all(color: tokens.boardBorder, width: _border),
              boxShadow: [tokens.boardShadow],
            ),
            padding: const EdgeInsets.all(_padding),
            child: child,
          ),
        );
      },
    );
  }
}
