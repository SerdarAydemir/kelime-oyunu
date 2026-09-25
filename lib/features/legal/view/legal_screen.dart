// lib/features/legal/view/legal_screen.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:kelime_oyunu/core/constants/app_dimensions.dart';
import 'package:kelime_oyunu/core/constants/app_typography.dart';
import 'package:kelime_oyunu/core/theme/app_tokens.dart';
import 'package:kelime_oyunu/core/widgets/circle_icon_button.dart';
import 'package:kelime_oyunu/features/legal/legal_document.dart';
import 'package:kelime_oyunu/l10n/generated/app_localizations.dart';

/// Which legal page to show; each maps to one asset file.
enum LegalPage {
  privacy('assets/legal/privacy_tr.md'),
  terms('assets/legal/terms_tr.md');

  const LegalPage(this.asset);

  final String asset;
}

/// Privacy / terms (README "Legal"): `page` background, Lora 20 title, the
/// muted "Son güncelleme" line, Lora 22 headings and body paragraphs, all
/// read from the page's markdown asset so the text ships without code.
class LegalScreen extends StatelessWidget {
  const LegalScreen({required this.page, super.key});

  final LegalPage page;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final l10n = AppLocalizations.of(context);
    final title = page == LegalPage.privacy ? l10n.privacy : l10n.terms;
    return Scaffold(
      backgroundColor: tokens.page,
      body: SafeArea(
        child: FutureBuilder<String>(
          future: DefaultAssetBundle.of(context).loadString(page.asset),
          builder: (context, snapshot) {
            final blocks = snapshot.hasData
                ? parseLegalDocument(snapshot.data!)
                : const <LegalBlock>[];
            return ListView(
              padding: const EdgeInsets.fromLTRB(
                AppDimensions.space16,
                AppDimensions.space8,
                AppDimensions.space24,
                AppDimensions.space32,
              ),
              children: [
                Row(
                  children: [
                    CircleIconButton(
                      icon: Icons.arrow_back,
                      onPressed: () => context.canPop() ? context.pop() : context.go('/'),
                      tooltip: l10n.settings,
                    ),
                    const SizedBox(width: AppDimensions.space12),
                    Expanded(
                      child: Text(
                        title,
                        style: AppTypography.screenTitle.copyWith(
                          fontSize: 20,
                          color: tokens.pageText,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppDimensions.space12),
                for (final block in blocks) _LegalBlockView(block: block),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _LegalBlockView extends StatelessWidget {
  const _LegalBlockView({required this.block});

  final LegalBlock block;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Padding(
      padding: EdgeInsets.only(
        left: AppDimensions.space8,
        top: block.kind == LegalBlockKind.heading ? AppDimensions.space20 : AppDimensions.space6,
        bottom: AppDimensions.space6,
      ),
      child: Text(
        block.text,
        style: switch (block.kind) {
          LegalBlockKind.meta => AppTypography.bodySmall.copyWith(color: tokens.pageMuted),
          LegalBlockKind.heading => AppTypography.screenTitle.copyWith(color: tokens.pageText),
          LegalBlockKind.paragraph => AppTypography.body.copyWith(color: tokens.pageText),
        },
      ),
    );
  }
}
