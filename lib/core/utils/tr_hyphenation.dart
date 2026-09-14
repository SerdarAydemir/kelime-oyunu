// lib/core/utils/tr_hyphenation.dart

/// Splits a Turkish word into syllables using the regular Turkish rules:
/// every syllable carries exactly one vowel; a single consonant between two
/// vowels opens the next syllable (a-ra); of two or more consonants between
/// vowels all but the last stay with the preceding syllable (an-ne, Türk-çe);
/// consonants after the last vowel close the final syllable (kork-mak).
///
/// Non-letter characters (apostrophes, digits) are treated as consonants, so
/// "Rize'nin" becomes ["Ri", "ze'", "nin"]. A word without a vowel is returned
/// whole. Pure and allocation-light; used only when a single word is wider
/// than a clue cell at the minimum font.
List<String> trSyllables(String word) {
  if (word.isEmpty) return const [];
  final vowelIdx = <int>[];
  for (var i = 0; i < word.length; i++) {
    if (_vowels.contains(word[i])) vowelIdx.add(i);
  }
  if (vowelIdx.length < 2) return [word];

  final out = <String>[];
  var start = 0;
  for (var k = 0; k < vowelIdx.length - 1; k++) {
    final consonants = vowelIdx[k + 1] - vowelIdx[k] - 1;
    // Cut right after this vowel (0 or 1 consonant) or before the last
    // consonant of the cluster (2+ consonants).
    final cut = consonants <= 1 ? vowelIdx[k] + 1 : vowelIdx[k + 1] - 1;
    out.add(word.substring(start, cut));
    start = cut;
  }
  out.add(word.substring(start));
  return out;
}

const Set<String> _vowels = {
  'a', 'e', 'ı', 'i', 'o', 'ö', 'u', 'ü', 'â', 'î', 'û', //
  'A', 'E', 'I', 'İ', 'O', 'Ö', 'U', 'Ü', 'Â', 'Î', 'Û',
};
