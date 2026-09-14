// test/core/utils/tr_hyphenation_test.dart

import 'package:flutter_test/flutter_test.dart';

import 'package:kelime_oyunu/core/utils/tr_hyphenation.dart';

void main() {
  group('trSyllables', () {
    test('single consonant between vowels opens the next syllable', () {
      expect(trSyllables('ara'), ['a', 'ra']);
      expect(trSyllables('yanındaki'), ['ya', 'nın', 'da', 'ki']);
      expect(trSyllables('bulamacı'), ['bu', 'la', 'ma', 'cı']);
    });

    test('of two or more consonants all but the last close the syllable', () {
      expect(trSyllables('anne'), ['an', 'ne']);
      expect(trSyllables('Türkçe'), ['Türk', 'çe']);
      expect(trSyllables('kontrol'), ['kont', 'rol']);
    });

    test('trailing consonants stay with the last syllable', () {
      expect(trSyllables('korkmak'), ['kork', 'mak']);
      expect(trSyllables('İstanbul'), ['İs', 'tan', 'bul']);
    });

    test('adjacent vowels split between them', () {
      expect(trSyllables('aile'), ['a', 'i', 'le']);
      expect(trSyllables('saat'), ['sa', 'at']);
    });

    test('dotted and dotless i, circumflex vowels, uppercase all count', () {
      expect(trSyllables('ılık'), ['ı', 'lık']);
      expect(trSyllables('KÂĞIT'), ['KÂ', 'ĞIT']);
      expect(trSyllables('Ödünç'), ['Ö', 'dünç']);
    });

    test('apostrophe is treated like a consonant', () {
      expect(trSyllables("Rize'nin"), ['Ri', "ze'", 'nin']);
    });

    test('words with fewer than two vowels are returned whole', () {
      expect(trSyllables('at'), ['at']);
      expect(trSyllables('krş'), ['krş']);
      expect(trSyllables(''), isEmpty);
    });

    test('syllables concatenate back to the word', () {
      for (final w in ['yanındaki', 'bulamacı', 'Türkçe', 'elektrikçi', 'müzikal']) {
        expect(trSyllables(w).join(), w);
      }
    });
  });
}
