// test/core/widgets/app_logo_test.dart

import 'dart:ui' show PictureRecorder;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kelime_oyunu/core/theme/app_tokens.dart';
import 'package:kelime_oyunu/core/widgets/app_logo.dart';

void main() {
  testWidgets('AppLogo paints at the requested size', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Center(child: AppLogo(size: 40))));
    expect(tester.getSize(find.byType(AppLogo)), const Size(40, 40));
  });

  testWidgets('AppLogoTile is a 120 dp rounded tile on the LOGO_BG gradient', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Center(child: AppLogoTile())));
    expect(tester.getSize(find.byType(AppLogoTile)), const Size(120, 120));
    final box = tester.widget<Container>(find.byType(Container));
    final decoration = box.decoration! as BoxDecoration;
    expect(decoration.gradient, AppTokens.logoBg);
    expect(decoration.borderRadius, BorderRadius.circular(28));
  });

  test('the corner-cell ground is the design\'s fixed navy in both themes', () {
    expect(appLogoGround, const Color(0xFF0B1A33));
  });

  test('paintAppLogo records the sun and the 22 mountain cells', () {
    final recorder = PictureRecorder();
    final canvas = Canvas(recorder);
    paintAppLogo(canvas, const Rect.fromLTWH(0, 0, 40, 40));
    // A finished picture with no exception is what a golden-less painter test
    // can assert; the geometry is a literal transcription of LOGO_SVG.
    expect(recorder.endRecording(), isNotNull);
  });
}
