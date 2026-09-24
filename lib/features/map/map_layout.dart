// lib/features/map/map_layout.dart

import 'dart:math' as math;

import 'package:flutter/painting.dart' show Offset;

/// Geometry of the climb map (README "Climb map"), pure and testable.
///
/// Node n (1-based level) sits at `x = w/2 + 0.3·w·sin(n·0.85)` and
/// `y = H − 140 − (n − 1)·96`; the content is `N × 96 + 240` tall where
/// `N = max(level + 40, 80)`, so ~40 nodes of fog always sit above the player
/// and the total level count is never revealed.
class MapLayout {
  const MapLayout({required this.currentLevel, required this.width});

  /// The player's current (frontier) level.
  final int currentLevel;

  /// Viewport width the x positions are scaled to (design reference 390 dp).
  final double width;

  static const double nodeStep = 96;
  static const double bottomInset = 140;
  static const double extraHeight = 240;
  static const int fogAhead = 40;
  static const int minNodes = 80;

  /// Nodes to render (levels 1..[nodeCount]).
  int get nodeCount => math.max(currentLevel + fogAhead, minNodes);

  double get contentHeight => nodeCount * nodeStep + extraHeight;

  /// Centre of level [n]'s node in content coordinates.
  Offset center(int n) => Offset(
    width / 2 + 0.3 * width * math.sin(n * 0.85),
    contentHeight - bottomInset - (n - 1) * nodeStep,
  );

  /// Scroll offset that puts the current node at 60 % of [viewportHeight].
  double initialOffset(double viewportHeight) =>
      (center(currentLevel).dy - viewportHeight * 0.6).clamp(0.0, contentHeight - viewportHeight);
}
