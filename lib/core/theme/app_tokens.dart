// lib/core/theme/app_tokens.dart

import 'package:flutter/material.dart';

part 'package:kelime_oyunu/core/theme/app_tokens_dark.dart';
part 'package:kelime_oyunu/core/theme/app_tokens_light.dart';
part 'package:kelime_oyunu/core/theme/app_tokens_lerp.dart';

/// Kelime Zirvesi colour tokens — a 1:1 port of `THEMES.dark` / `THEMES.light`
/// in `docs/design/kz-tokens.js`, which stays the single source of truth.
///
/// Token names match the JS keys. CSS `linear-gradient(180deg …)` becomes a
/// top→bottom [LinearGradient], `135deg` top-left→bottom-right, `rgba()`
/// becomes [Color.fromRGBO] and `box-shadow` becomes a [BoxShadow]. Every
/// doc comment below is the matching `TOKEN_META` entry, verbatim.
///
/// Read them in widgets through `context.tokens` ([AppTokensContext]); this
/// is the ONLY place in `lib/` where raw colour literals are allowed.
class AppTokens extends ThemeExtension<AppTokens> {
  const AppTokens({
    required this.bgFlat,
    required this.bgHome,
    required this.bgGame,
    required this.bgMap,
    required this.bgWon,
    required this.bgLost,
    required this.bgDraw,
    required this.fog,
    required this.surface,
    required this.card,
    required this.border,
    required this.board,
    required this.boardBorder,
    required this.boardShadow,
    required this.cellLetter,
    required this.cellClue,
    required this.cellPending,
    required this.cellWrong,
    required this.clueText,
    required this.ink,
    required this.inkBot,
    required this.inkPending,
    required this.accent,
    required this.accentInk,
    required this.arrow,
    required this.tile,
    required this.tileInk,
    required this.tileShadow,
    required this.text,
    required this.muted,
    required this.faint,
    required this.success,
    required this.error,
    required this.bot,
    required this.botInk,
    required this.mtn1,
    required this.mtn2,
    required this.mtn3,
    required this.sheet,
    required this.sheetText,
    required this.sheetMuted,
    required this.sheetCard,
    required this.solid,
    required this.solidText,
    required this.toggleOff,
    required this.knob,
    required this.page,
    required this.pageText,
    required this.pageMuted,
    required this.pageLine,
    required this.logoMtn,
    required this.logoSun,
    required this.dim,
  });

  /// `THEMES.dark` — key `dark`, label "Koyu".
  static const AppTokens dark = _dark;

  /// `THEMES.light` — key `light`, label "Açık".
  static const AppTokens light = _light;

  /// `LOGO_BG`: `linear-gradient(160deg,#1c3358 0%,#0b1a33 100%)` — the app
  /// icon / splash tile background, identical in both themes. 160° maps to
  /// begin (−sin, cos) → end (sin, −cos) in CSS angle terms.
  static const LinearGradient logoBg = LinearGradient(
    begin: Alignment(-0.34, -0.94),
    end: Alignment(0.34, 0.94),
    colors: [Color(0xFF1C3358), Color(0xFF0B1A33)],
    stops: [0, 1],
  );

  /// Düz zemin (ayarlar, splash, harita üstü)
  final Color bgFlat;

  /// Ana ekran gökyüzü gradyanı
  final LinearGradient bgHome;

  /// Oyun ekranı gradyanı
  final LinearGradient bgGame;

  /// Harita gradyanı (yukarı gece → aşağı kamp)
  final LinearGradient bgMap;

  /// Kazandın gradyanı (şafak)
  final LinearGradient bgWon;

  /// Kaybettin gradyanı (gece)
  final LinearGradient bgLost;

  /// Berabere gradyanı (nötr)
  final LinearGradient bgDraw;

  /// Harita üst sis rengi
  final Color fog;

  /// Yuvarlak ikon buton zemini
  final Color surface;

  /// Yarı saydam kart (blur 8)
  final Color card;

  /// Kart / liste çerçevesi
  final Color border;

  /// Tahta zemini
  final Color board;

  /// Tahta çerçevesi (1 px)
  final Color boardBorder;

  /// Tahta gölgesi
  final BoxShadow boardShadow;

  /// Harf hücresi zemini
  final Color cellLetter;

  /// İpucu hücresi zemini
  final Color cellClue;

  /// Bekleyen harf hücresi zemini
  final Color cellPending;

  /// Yanlış harf hücresi (kısa flaş)
  final Color cellWrong;

  /// İpucu metni
  final Color clueText;

  /// Oyuncu harfi
  final Color ink;

  /// Bot (Rakip) harfi
  final Color inkBot;

  /// Bekleyen harf
  final Color inkPending;

  /// Kehribar vurgu (birincil buton, seçili taş)
  final Color accent;

  /// Vurgu üstü metin
  final Color accentInk;

  /// İpucu okları, köşe hücresi
  final Color arrow;

  /// Taş zemini (boşta)
  final Color tile;

  /// Taş harfi
  final Color tileInk;

  /// Taş alt gölgesi (4 px)
  final Color tileShadow;

  /// Birincil metin
  final Color text;

  /// İkincil metin
  final Color muted;

  /// Üçüncül metin / ayraç
  final Color faint;

  /// Başarı
  final Color success;

  /// Hata / yanlış harf kenarı
  final Color error;

  /// Rakip avatar zemini
  final Color bot;

  /// Rakip avatar silueti
  final Color botInk;

  /// Dağ katmanı 1 (uzak)
  final Color mtn1;

  /// Dağ katmanı 2
  final Color mtn2;

  /// Dağ katmanı 3 (yakın)
  final Color mtn3;

  /// Alt sayfa (sheet) zemini
  final Color sheet;

  /// Sheet metni
  final Color sheetText;

  /// Sheet ikincil metni
  final Color sheetMuted;

  /// Sheet içi kart
  final Color sheetCard;

  /// Koyu dolu buton (kazandın, kapat)
  final Color solid;

  /// Koyu buton metni
  final Color solidText;

  /// Anahtar kapalı
  final Color toggleOff;

  /// Anahtar topuzu (kapalı)
  final Color knob;

  /// Gizlilik / koşullar sayfa zemini
  final Color page;

  /// Sayfa metni
  final Color pageText;

  /// Sayfa ikincil metni
  final Color pageMuted;

  /// Sayfa ayraç / iskelet satır
  final Color pageLine;

  /// Logo dağ rengi
  final Color logoMtn;

  /// Logo güneş rengi
  final Color logoSun;

  /// Sheet arkası karartma
  final Color dim;

  /// The palettes are immutable constants (a theme is switched, never patched),
  /// so there is nothing to override field by field.
  @override
  AppTokens copyWith() => this;

  /// Endpoints return the palette constants themselves, so identity checks
  /// (`tokens != old.tokens` in painters) stay cheap once a switch settles.
  @override
  AppTokens lerp(covariant AppTokens? other, double t) {
    if (other == null || identical(other, this) || t <= 0) return this;
    if (t >= 1) return other;
    return _lerp(this, other, t);
  }
}

/// `context.tokens` — the active theme's [AppTokens]. Falls back on the
/// brightness-matched constant when a test pumps a bare [MaterialApp].
extension AppTokensContext on BuildContext {
  AppTokens get tokens =>
      Theme.of(this).extension<AppTokens>() ??
      (Theme.of(this).brightness == Brightness.dark ? AppTokens.dark : AppTokens.light);
}
