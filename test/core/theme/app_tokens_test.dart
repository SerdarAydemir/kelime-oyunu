// test/core/theme/app_tokens_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kelime_oyunu/core/constants/app_typography.dart';
import 'package:kelime_oyunu/core/theme/app_theme.dart';
import 'package:kelime_oyunu/core/theme/app_tokens.dart';

void main() {
  group('AppTokens — 1:1 port of kz-tokens.js THEMES', () {
    test('spot-checks dark values against the JS source', () {
      const t = AppTokens.dark;
      expect(t.bgFlat, const Color(0xFF0B1A33));
      expect(t.surface, const Color.fromRGBO(255, 255, 255, .10));
      expect(t.boardBorder.a, 0); // 'transparent'
      expect(t.boardShadow.offset, const Offset(0, 20));
      expect(t.boardShadow.blurRadius, 50);
      expect(t.boardShadow.color, const Color.fromRGBO(0, 0, 0, .40));
      expect(t.dim, const Color.fromRGBO(5, 16, 31, .55));
    });

    test('Flutter-only additions and deviations (README "Flutter sapmaları")', () {
      expect(AppTokens.dark.gridLine, AppTokens.dark.cellClue);
      expect(AppTokens.light.gridLine, AppTokens.light.boardBorder);
      expect(AppTokens.light.cellLetter, const Color(0xFFFFFDF7));
      expect(AppTokens.light.cellLetter, isNot(AppTokens.light.board));
      // Contrast deviations (session E).
      expect(AppTokens.light.link, AppTokens.dark.link);
      expect(AppTokens.light.error, const Color(0xFFAD3F2B));
      expect(AppTokens.dark.sheetMuted, const Color(0xFF7E6045));
    });

    test('spot-checks light values against the JS source', () {
      const t = AppTokens.light;
      expect(t.bgFlat, const Color(0xFFF3EAD8));
      expect(t.boardBorder, const Color(0xFFE3D5B6));
      expect(t.text, const Color(0xFF0B1A33));
      expect(t.logoSun, const Color(0xFFC77A3C));
    });

    test('CSS 180deg gradients run top → bottom with the JS stops', () {
      final g = AppTokens.dark.bgHome;
      expect(g.begin, Alignment.topCenter);
      expect(g.end, Alignment.bottomCenter);
      expect(g.colors, const [
        Color(0xFF0B1A33),
        Color(0xFF1C3358),
        Color(0xFF5A3D3A),
        Color(0xFFC77A3C),
      ]);
      expect(g.stops, const [0, 0.45, 0.78, 1]);
    });

    test('theme-invariant tokens are identical in both palettes', () {
      for (final (a, b) in [
        (AppTokens.dark.accent, AppTokens.light.accent),
        (AppTokens.dark.arrow, AppTokens.light.arrow),
        (AppTokens.dark.ink, AppTokens.light.ink),
        (AppTokens.dark.inkBot, AppTokens.light.inkBot),
        (AppTokens.dark.inkPending, AppTokens.light.inkPending),
        (AppTokens.dark.cellPending, AppTokens.light.cellPending),
        (AppTokens.dark.cellWrong, AppTokens.light.cellWrong),
        (AppTokens.dark.clueText, AppTokens.light.clueText),
      ]) {
        expect(a, b);
      }
    });

    test('lerp returns the endpoints at t = 0 / 1 and blends in between', () {
      const dark = AppTokens.dark;
      const light = AppTokens.light;
      expect(dark.lerp(light, 0).bgFlat, dark.bgFlat);
      expect(dark.lerp(light, 1).bgFlat, light.bgFlat);
      expect(dark.lerp(light, 1).bgHome.colors, light.bgHome.colors);
      expect(dark.lerp(light, 1).boardShadow, light.boardShadow);
      final mid = dark.lerp(light, 0.5).bgFlat;
      expect(mid, isNot(dark.bgFlat));
      expect(mid, isNot(light.bgFlat));
      expect(dark.lerp(null, 0.5), same(dark));
    });
  });

  group('AppTheme', () {
    test('attaches the matching palette as a ThemeExtension', () {
      expect(AppTheme.dark().extension<AppTokens>(), same(AppTokens.dark));
      expect(AppTheme.light().extension<AppTokens>(), same(AppTokens.light));
      expect(AppTheme.dark().scaffoldBackgroundColor, AppTokens.dark.bgFlat);
      expect(AppTheme.light().colorScheme.primary, AppTokens.light.accent);
    });

    test('uses the bundled families from the design type scale', () {
      final text = AppTheme.light().textTheme;
      expect(text.displayLarge?.fontFamily, AppTypography.lora);
      expect(text.displayLarge?.fontSize, 62);
      expect(text.bodyLarge?.fontFamily, AppTypography.nunitoSans);
      expect(text.labelSmall?.letterSpacing, 3);
    });

    testWidgets('context.tokens resolves the palette attached to the theme', (tester) async {
      AppTokens? seen;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark(),
          home: Builder(
            builder: (context) {
              seen = context.tokens;
              return const SizedBox();
            },
          ),
        ),
      );
      expect(seen, same(AppTokens.dark));
    });

    testWidgets('context.tokens falls back on brightness without the extension', (tester) async {
      AppTokens? seen;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(brightness: Brightness.dark),
          home: Builder(
            builder: (context) {
              seen = context.tokens;
              return const SizedBox();
            },
          ),
        ),
      );
      expect(seen, same(AppTokens.dark));
    });
  });
}
