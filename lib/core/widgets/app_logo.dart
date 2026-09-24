// lib/core/widgets/app_logo.dart

import 'package:flutter/material.dart';
import 'package:kelime_oyunu/core/constants/app_dimensions.dart';
import 'package:kelime_oyunu/core/theme/app_tokens.dart';

/// The "1A Sıradağ + güneş" mark — a 1:1 port of `LOGO_SVG` in
/// `docs/design/kz-tokens.js` (viewBox 40×40: a 7 × 5 cell mountain, cell
/// 4.6, step 5.4, plus the amber sun). Painted, not loaded: 22 rounded rects
/// and a circle need no SVG runtime, and the same painter fills the board's
/// corner cell ([paintAppLogo]).
class AppLogo extends StatelessWidget {
  const AppLogo({required this.size, super.key});

  final double size;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(size: Size.square(size), painter: const _AppLogoPainter());
  }
}

/// The 120 dp splash / app-icon tile: the logo on the `LOGO_BG` gradient,
/// corner radius 28 (design README "Splash").
class AppLogoTile extends StatelessWidget {
  const AppLogoTile({this.size = 120, super.key});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: AppTokens.logoBg,
        borderRadius: BorderRadius.circular(size * AppDimensions.radiusSheet / 120),
      ),
      // The SVG drawing fills its 40-unit box edge to edge; ~10 % inset keeps
      // the mountain off the rounded corners of the tile.
      padding: EdgeInsets.all(size * 0.1),
      child: AppLogo(size: size * 0.8),
    );
  }
}

class _AppLogoPainter extends CustomPainter {
  const _AppLogoPainter();

  @override
  void paint(Canvas canvas, Size size) => paintAppLogo(canvas, Offset.zero & size);

  @override
  bool shouldRepaint(covariant _AppLogoPainter old) => false;
}

// LOGO_SVG geometry, in the 40 × 40 viewBox.
const double _viewBox = 40;
const double _cell = 4.6;
const double _cornerRadius = 1;

// Cell rows as (y, [x...], colour) — bottom rows are rock, the ridge is snow,
// the summit is amber. Colours are the SVG's own (theme-invariant brand
// colours, identical in both palettes: `logoSun` dark = accent, rock = arrow).
const List<(double, List<double>, Color)> _rows = [
  (34, [1.5, 6.9, 12.3, 17.7, 23.1, 28.5, 33.9], _rock),
  (28.6, [1.5, 6.9, 12.3, 17.7, 23.1, 28.5], _rock),
  (23.2, [6.9], _snowBright),
  (23.2, [17.7, 23.1, 28.5], _snow),
  (17.8, [17.7, 23.1], _snowBright),
  (12.4, [23.1], _summit),
];
const Color _rock = Color(0xFFC77A3C); // arrow
const Color _snow = Color(0xFFE9DCC1); // cellClue (dark)
const Color _snowBright = Color(0xFFF6ECD9); // logoMtn (dark)
const Color _summit = Color(0xFFF2C27A); // accent / logoSun (dark)
const Offset _sunCentre = Offset(10, 8.5);
const double _sunRadius = 3.4;

/// Paints the logo scaled into [rect] (aspect preserved, centred). Used by
/// [AppLogo] and by the grid painter for the board's corner cell.
void paintAppLogo(Canvas canvas, Rect rect) {
  final scale = rect.shortestSide / _viewBox;
  final dx = rect.left + (rect.width - _viewBox * scale) / 2;
  final dy = rect.top + (rect.height - _viewBox * scale) / 2;
  canvas.save();
  canvas.translate(dx, dy);
  canvas.scale(scale);
  canvas.drawCircle(_sunCentre, _sunRadius, Paint()..color = _summit);
  for (final (y, xs, color) in _rows) {
    final paint = Paint()..color = color;
    for (final x in xs) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, y, _cell, _cell),
          const Radius.circular(_cornerRadius),
        ),
        paint,
      );
    }
  }
  canvas.restore();
}

/// Ground behind the logo wherever it sits on the board: the design pins the
/// corner cell to `#0b1a33` in BOTH themes (README "Board"), which is the
/// dark palette's `bgFlat`.
Color get appLogoGround => AppTokens.dark.bgFlat;
