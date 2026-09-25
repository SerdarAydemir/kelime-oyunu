// test/features/legal/legal_test.dart

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:kelime_oyunu/features/legal/legal_document.dart';
import 'package:kelime_oyunu/features/legal/view/legal_screen.dart';

// Relative import — test helpers are not importable via package: path.
// ignore: always_use_package_imports
import '../../helpers/localized_app.dart';

void main() {
  test('parseLegalDocument splits meta, headings and joined paragraphs', () {
    const src = '''
_Son güncelleme · 20 Eylül 2026_

## Başlık

satır bir
satır iki

ikinci paragraf
''';
    final blocks = parseLegalDocument(src);
    expect(blocks.map((b) => b.kind), [
      LegalBlockKind.meta,
      LegalBlockKind.heading,
      LegalBlockKind.paragraph,
      LegalBlockKind.paragraph,
    ]);
    expect(blocks[0].text, 'Son güncelleme · 20 Eylül 2026');
    expect(blocks[1].text, 'Başlık');
    expect(blocks[2].text, 'satır bir satır iki');
  });

  test('the shipped assets carry the README headings and placeholders', () {
    final privacy = parseLegalDocument(File('assets/legal/privacy_tr.md').readAsStringSync());
    expect(privacy.where((b) => b.kind == LegalBlockKind.heading).map((b) => b.text), [
      'Hangi verileri topluyoruz',
      'Reklam ortakları',
      'Cihazda saklanan veriler',
    ]);
    expect(privacy.where((b) => b.text == '[gerçek metin buraya]').length, 3);
    final terms = parseLegalDocument(File('assets/legal/terms_tr.md').readAsStringSync());
    expect(terms.where((b) => b.kind == LegalBlockKind.heading).length, 3);
  });

  testWidgets('the privacy page renders the asset with the page tokens', (tester) async {
    await tester.pumpWidget(localizedApp(home: const LegalScreen(page: LegalPage.privacy)));
    await tester.pumpAndSettle();

    expect(find.text('Gizlilik politikası'), findsOneWidget);
    expect(find.text('Son güncelleme · 20 Eylül 2026'), findsOneWidget);
    expect(find.text('Hangi verileri topluyoruz'), findsOneWidget);
    expect(find.text('[gerçek metin buraya]'), findsNWidgets(3));
  });

  testWidgets('the terms page has its own title', (tester) async {
    await tester.pumpWidget(localizedApp(home: const LegalScreen(page: LegalPage.terms)));
    await tester.pumpAndSettle();
    expect(find.text('Kullanım koşulları'), findsOneWidget);
    expect(find.text('Hizmetin kapsamı'), findsOneWidget);
  });
}
