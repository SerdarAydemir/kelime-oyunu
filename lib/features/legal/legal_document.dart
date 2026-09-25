// lib/features/legal/legal_document.dart

/// One block of a legal page.
enum LegalBlockKind { meta, heading, paragraph }

class LegalBlock {
  const LegalBlock(this.kind, this.text);

  final LegalBlockKind kind;
  final String text;
}

/// The tiny markdown dialect of `assets/legal/*.md`, so the copy can change
/// without a code change:
/// - `_…_` on its own line → meta line ("Son güncelleme · …");
/// - `## …` → section heading;
/// - anything else, separated by blank lines → paragraph (lines joined).
List<LegalBlock> parseLegalDocument(String source) {
  final blocks = <LegalBlock>[];
  final paragraph = <String>[];
  void flush() {
    if (paragraph.isEmpty) return;
    blocks.add(LegalBlock(LegalBlockKind.paragraph, paragraph.join(' ')));
    paragraph.clear();
  }

  for (final raw in source.split('\n')) {
    final line = raw.trim();
    if (line.isEmpty) {
      flush();
    } else if (line.startsWith('## ')) {
      flush();
      blocks.add(LegalBlock(LegalBlockKind.heading, line.substring(3).trim()));
    } else if (line.length > 2 && line.startsWith('_') && line.endsWith('_')) {
      flush();
      blocks.add(LegalBlock(LegalBlockKind.meta, line.substring(1, line.length - 1)));
    } else {
      paragraph.add(line);
    }
  }
  flush();
  return blocks;
}
