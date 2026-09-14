// test/features/gameplay/widgets/clue_text_layout_test.dart

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kelime_oyunu/features/gameplay/widgets/clue_text_layout.dart';

// Monospace stand-in: every glyph is half the font size wide.
double _mono(String text, double font) => text.length * font * 0.5;

const _family = 'Roboto';

Future<void> _loadRoboto() async {
  final root =
      Platform.environment['FLUTTER_ROOT'] ??
      File(Platform.resolvedExecutable).parent.parent.parent.parent.parent.path;
  final bytes = File(
    '$root/bin/cache/artifacts/material_fonts/Roboto-Regular.ttf',
  ).readAsBytesSync();
  await (FontLoader(_family)..addFont(Future.value(ByteData.sublistView(bytes)))).load();
}

double _roboto(String text, double font) => (TextPainter(
  text: TextSpan(
    text: text,
    style: TextStyle(fontFamily: _family, fontSize: font, height: 1.05),
  ),
  textDirection: TextDirection.ltr,
)..layout()).width;

void main() {
  group('layoutClueText with a monospace measure', () {
    test('keeps the start font when everything fits on one line', () {
      final r = layoutClueText(
        text: 'Kedi',
        maxWidth: 100,
        maxHeight: 100,
        measure: _mono,
        startFont: 14,
      );
      expect(r.kind, ClueFitKind.wordWrap);
      expect(r.fontSize, 14);
      expect(r.lines, ['Kedi']);
    });

    test('wraps at spaces, never inside a word, shrinking the font as needed', () {
      // 'yanındaki' = 9 chars -> fits 47 px only at font <= 10 (9*10*0.5=45).
      final r = layoutClueText(
        text: 'Usta yanındaki',
        maxWidth: 47,
        maxHeight: 47,
        measure: _mono,
        startFont: 14,
      );
      expect(r.kind, ClueFitKind.wordWrap);
      expect(r.fontSize, 10);
      expect(r.lines, ['Usta', 'yanındaki']);
    });

    test('hyphenates at syllable boundaries only at the minimum font', () {
      // 'Elektrikçilik' (13 chars) never fits 40 px; at font 9 a chunk may be
      // at most 8 chars including the hyphen (8*9*0.5 = 36 <= 40). Syllables
      // E-lekt-rik-çi-lik pack greedily: 'Elekt-' (adding 'rik' would exceed),
      // then 'rikçilik' fits whole, so no second hyphen.
      final r = layoutClueText(
        text: 'Elektrikçilik',
        maxWidth: 40,
        maxHeight: 60,
        measure: _mono,
        startFont: 14,
      );
      expect(r.kind, ClueFitKind.hyphenated);
      expect(r.fontSize, 9);
      expect(r.lines, ['Elekt-', 'rikçilik']);
      for (final line in r.lines) {
        expect(_mono(line, 9), lessThanOrEqualTo(40));
      }
    });

    test('reports overflow when the lines do not fit vertically', () {
      final r = layoutClueText(
        text: 'Romen rakamıyla elli',
        maxWidth: 47,
        maxHeight: 22,
        measure: _mono,
        startFont: 9,
      );
      expect(r.kind, ClueFitKind.overflow);
    });

    test('reports overflow when a single syllable is wider than the cell', () {
      final r = layoutClueText(
        text: 'Strüktür',
        maxWidth: 20,
        maxHeight: 100,
        measure: _mono,
        startFont: 9,
      );
      expect(r.kind, ClueFitKind.overflow);
    });
  });

  group('layoutClueText with the real Roboto face (49 dp cell)', () {
    setUpAll(_loadRoboto);

    // 49 dp cell minus 1 px padding each side, as in ClueRenderer.
    const w = 47.0;
    const h = 47.0;

    for (final text in ['Usta yanındaki', 'Hayvan bulamacı']) {
      test('"$text" wraps at the space, not mid-word', () {
        final r = layoutClueText(
          text: text,
          maxWidth: w,
          maxHeight: h,
          measure: _roboto,
          startFont: (h * 0.30).clamp(9.0, 14.0),
        );
        expect(r.kind, ClueFitKind.wordWrap);
        expect(r.lines.join(' '), text);
        for (final line in r.lines) {
          expect(_roboto(line, r.fontSize), lessThanOrEqualTo(w));
        }
      });
    }
  });
}
