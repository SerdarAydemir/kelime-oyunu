// lib/features/gameplay/widgets/clue_text_layout.dart

import 'package:kelime_oyunu/core/utils/tr_hyphenation.dart';

/// Measures the advance width of [text] at [fontSize] in the clue font.
typedef ClueTextMeasure = double Function(String text, double fontSize);

/// How a clue was made to fit its cell (or not).
enum ClueFitKind {
  /// Every word fits on a line at some font >= the minimum; wrapped at spaces.
  wordWrap,

  /// At the minimum font at least one word had to be split at a syllable
  /// boundary and shown with a hyphen.
  hyphenated,

  /// Even hyphenated at the minimum font the text does not fit vertically (or a
  /// single syllable is wider than the cell). Caller falls back to ellipsis.
  overflow,
}

/// Result of [layoutClueText]: the lines to paint (already broken) and the font.
class ClueTextLayout {
  const ClueTextLayout({required this.fontSize, required this.lines, required this.kind});

  final double fontSize;
  final List<String> lines;
  final ClueFitKind kind;

  String get text => lines.join('\n');
}

/// Pure line-breaking for clue cells. Tries fonts from [startFont] down to
/// [minFont]; at each size the text is wrapped ONLY at spaces and accepted when
/// no word is wider than [maxWidth] and the lines fit [maxHeight]. Only at the
/// floor are over-wide words split at Turkish syllable boundaries with a
/// trailing hyphen. Never breaks inside a syllable.
ClueTextLayout layoutClueText({
  required String text,
  required double maxWidth,
  required double maxHeight,
  required ClueTextMeasure measure,
  required double startFont,
  double minFont = 9.0,
  double lineHeight = 1.05,
}) {
  final words = text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
  var font = startFont < minFont ? minFont : startFont;
  while (true) {
    final tooWide = words.any((w) => measure(w, font) > maxWidth);
    if (!tooWide) {
      final lines = _pack(words.map(_Token.word).toList(), font, maxWidth, measure);
      if (lines.length * font * lineHeight <= maxHeight) {
        return ClueTextLayout(fontSize: font, lines: lines, kind: ClueFitKind.wordWrap);
      }
    }
    if (font <= minFont) break;
    font = (font - 1).clamp(minFont, startFont);
  }

  // Floor reached: hyphenate over-wide words at syllable boundaries.
  final tokens = <_Token>[];
  for (final w in words) {
    if (measure(w, font) <= maxWidth) {
      tokens.add(_Token.word(w));
      continue;
    }
    final chunks = _hyphenate(w, font, maxWidth, measure);
    if (chunks == null) {
      return ClueTextLayout(fontSize: font, lines: [text], kind: ClueFitKind.overflow);
    }
    tokens.addAll(chunks);
  }
  final lines = _pack(tokens, font, maxWidth, measure);
  final fits = lines.length * font * lineHeight <= maxHeight;
  return ClueTextLayout(
    fontSize: font,
    lines: lines,
    kind: fits ? ClueFitKind.hyphenated : ClueFitKind.overflow,
  );
}

class _Token {
  const _Token(this.text, {this.breakAfter = false});
  const _Token.word(this.text) : breakAfter = false;

  final String text;

  /// A hyphenated fragment must end its line so the hyphen stays meaningful.
  final bool breakAfter;
}

/// Greedy packing of tokens into lines no wider than [maxWidth]. Every token is
/// known to fit on its own, so the result never exceeds the width.
List<String> _pack(List<_Token> tokens, double font, double maxWidth, ClueTextMeasure measure) {
  final lines = <String>[];
  var current = '';
  for (final t in tokens) {
    final candidate = current.isEmpty ? t.text : '$current ${t.text}';
    if (current.isNotEmpty && measure(candidate, font) > maxWidth) {
      lines.add(current);
      current = t.text;
    } else {
      current = candidate;
    }
    if (t.breakAfter) {
      lines.add(current);
      current = '';
    }
  }
  if (current.isNotEmpty) lines.add(current);
  return lines;
}

/// Splits [word] into syllable groups, each (with its trailing hyphen) no wider
/// than [maxWidth]. Returns null when a single syllable plus hyphen is too wide.
List<_Token>? _hyphenate(String word, double font, double maxWidth, ClueTextMeasure measure) {
  final syllables = trSyllables(word);
  if (syllables.length < 2) return null;
  final out = <_Token>[];
  var current = '';
  for (var i = 0; i < syllables.length; i++) {
    final s = syllables[i];
    final last = i == syllables.length - 1;
    final candidate = '$current$s';
    final probe = last ? candidate : '$candidate-';
    if (measure(probe, font) <= maxWidth) {
      current = candidate;
      continue;
    }
    if (current.isEmpty) return null; // one syllable alone is too wide
    out.add(_Token('$current-', breakAfter: true));
    current = s;
    if (measure(last ? current : '$current-', font) > maxWidth) return null;
  }
  out.add(_Token(current));
  return out;
}
