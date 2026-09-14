// test/tooling/clue_fit_report_test.dart
//
// Measurement, not a behaviour test: lays out every clue of the shipped pack
// (assets/puzzles) at realistic 9×7 cell sizes with the real Roboto face and
// reports how many clues (a) wrap cleanly at word boundaries, (b) need a
// syllable hyphen at the minimum font, or (c) cannot fit at all — plus how
// many the CURRENT renderer breaks mid-word. Run on its own:
//   flutter test test/tooling/clue_fit_report_test.dart
// It always passes; read the printed report.

import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kelime_oyunu/data/models/puzzle.dart';
import 'package:kelime_oyunu/features/gameplay/widgets/clue_text_layout.dart';

// Mirrors ClueRenderer's constants.
const _minFont = 9.0;
const _maxFont = 14.0;
const _pad = 1.0;
const _lineHeight = 1.05;
const _family = 'Roboto';

// 8 dp side padding around the grid (game_screen) on 360 / 393 / 411 dp phones
// gives 49 / 54 / 56 dp cells; 44 is a pessimistic small/landscape case.
const _cellSizes = [44.0, 49.0, 54.0, 56.0];

class _Instance {
  _Instance(this.text, this.puzzleId, this.isDouble);
  final String text;
  final int puzzleId;
  final bool isDouble;
}

Future<void> _loadRoboto() async {
  final root =
      Platform.environment['FLUTTER_ROOT'] ??
      File(Platform.resolvedExecutable).parent.parent.parent.parent.parent.path;
  final file = File('$root/bin/cache/artifacts/material_fonts/Roboto-Regular.ttf');
  final bytes = file.readAsBytesSync();
  final loader = FontLoader(_family)..addFont(Future.value(ByteData.sublistView(bytes)));
  await loader.load();
}

List<_Instance> _loadClues() {
  final out = <_Instance>[];
  final files = Directory(
    'assets/puzzles',
  ).listSync().whereType<File>().where((f) => RegExp(r'puzzle_\d{4}\.json$').hasMatch(f.path));
  for (final f in files) {
    final puzzle = PuzzleData.fromJson(jsonDecode(f.readAsStringSync()) as Map<String, dynamic>);
    for (final cell in puzzle.cells) {
      if (cell.type != CellType.clue) continue;
      for (final clue in cell.clues) {
        out.add(_Instance(clue.text, puzzle.puzzleId, cell.clues.length >= 2));
      }
    }
  }
  return out;
}

final Map<String, double> _widthCache = {};

double _measure(String text, double font) => _widthCache.putIfAbsent('$font|$text', () {
  final tp = TextPainter(
    text: TextSpan(
      text: text,
      style: const TextStyle(fontFamily: _family, height: _lineHeight).copyWith(fontSize: font),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  return tp.width;
});

/// Replicates ClueRenderer._drawClueText's current font choice and reports
/// whether Flutter had to break inside a word at that font.
bool _currentBreaksMidWord(String text, double textW, double textH, double startFont) {
  var font = startFont;
  while (true) {
    final atFloor = font <= _minFont;
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(fontFamily: _family, fontSize: font, height: _lineHeight),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
      maxLines: atFloor ? math.max(1, (textH / (font * 1.15)).floor()) : null,
      ellipsis: atFloor ? '…' : null,
    )..layout(maxWidth: textW);
    if (atFloor || tp.height <= textH) {
      return text.split(' ').any((w) => _measure(w, font) > textW);
    }
    font -= 1;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('clue fit report (measurement only)', () async {
    await _loadRoboto();
    final clues = _loadClues();
    final unique = clues.map((c) => c.text).toSet().length;
    final buf = StringBuffer()
      ..writeln('\n=== CLUE FIT REPORT: ${clues.length} clue instances, $unique unique texts ===');

    for (final cell in _cellSizes) {
      final counts = <String, Map<ClueFitKind, int>>{'single': {}, 'double': {}};
      final midWord = <String, int>{'single': 0, 'double': 0};
      final overflow = <String>{};
      for (final c in clues) {
        final h = c.isDouble ? cell / 2 : cell;
        final textW = cell - _pad * 2;
        final textH = h - _pad * 2;
        final startFont = (h * 0.30).clamp(_minFont, _maxFont);
        final key = c.isDouble ? 'double' : 'single';
        if (_currentBreaksMidWord(c.text, textW, textH, startFont)) {
          midWord[key] = midWord[key]! + 1;
        }
        final r = layoutClueText(
          text: c.text,
          maxWidth: textW,
          maxHeight: textH,
          measure: _measure,
          startFont: startFont,
          minFont: _minFont,
          lineHeight: _lineHeight,
        );
        counts[key]![r.kind] = (counts[key]![r.kind] ?? 0) + 1;
        if (r.kind == ClueFitKind.overflow) overflow.add('${c.text} [$key, p${c.puzzleId}]');
      }
      buf.writeln('--- cell ${cell.toStringAsFixed(0)} dp ---');
      for (final key in ['single', 'double']) {
        final k = counts[key]!;
        buf.writeln(
          '$key: current mid-word breaks=${midWord[key]}  '
          'wordWrap=${k[ClueFitKind.wordWrap] ?? 0}  '
          'hyphenated=${k[ClueFitKind.hyphenated] ?? 0}  '
          'overflow=${k[ClueFitKind.overflow] ?? 0}',
        );
      }
      if (overflow.isNotEmpty) buf.writeln('overflow: ${overflow.join('; ')}');
    }
    // ignore: avoid_print
    print(buf);
  });
}
