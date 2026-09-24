# HANDOFF — Tasarım Oturumu A: Altyapı (2026-09-24)

Yeni görsel kimlik ("Kelime Zirvesi") tesliminin altyapı katmanı. Tasarım
kaynağı `docs/design/` altındadır; **`docs/design/kz-tokens.js` tek
kaynaktır** (renk, tipografi, yarıçap, boşluk, buton yüksekliği, metin, logo).
Bu oturumda davranış değişmedi; ekran yeniden tasarımları (harita, sonuç
ekranları, sheet'ler, ayarlar UI'ı) **Oturum B**'ye kaldı.

Beş adım, beş commit; her adımda `flutter analyze` 0 sorun, `flutter test`
yeşil (219 test).

| # | Commit | Özet |
|---|--------|------|
| 1 | `feat(ui): bundle Lora and Nunito Sans` | Fontlar `assets/fonts/` altında, OFL.txt yanlarında, pubspec'te tanımlı |
| 2 | `feat(ui): Kelime Zirvesi design tokens, both themes` | `AppTokens` ThemeExtension (53 token × 2 tema), `AppTypography`, `AppDimensions`, `AppTheme`; `AppColors` kaldırıldı |
| 3 | `feat(settings): persisted theme mode and toggles` | `SettingsCubit` + `SettingsRepository` (shared_preferences), `MaterialApp.themeMode` |
| 4 | `feat(l10n): arb strings from design bundle` | `lib/l10n/app_tr.arb` + `app_en.arb`, gen_l10n, tüm hardcoded metinler arb'a, "Rakip" |
| 5 | `feat(ui): logo, launcher icons, splash` | `AppLogo` painter, köşe hücresi, launcher ikonları, native + Flutter splash, uygulama adı |

---

## 1. Fontlar

- github.com/google/fonts (OFL) reposunda Lora ve Nunito Sans yalnızca
  **değişken (variable) TTF** olarak var (`Lora[wght].ttf`,
  `NunitoSans[YTLC,opsz,wdth,wght].ttf`). İstenen sabit ağırlıklar
  fontTools `varLib.instancer` ile kesildi (Nunito Sans için
  `wdth=100, opsz=12, YTLC=500` sabitlendi). Dosyalar:
  `assets/fonts/lora/Lora-{Medium,SemiBold,Bold}.ttf`,
  `assets/fonts/nunito_sans/NunitoSans-{Regular,Medium,SemiBold,Bold,ExtraBold}.ttf`.
- Yeniden üretmek için (kaynak güncellenirse):
  ```bash
  python3 -m venv venv && venv/bin/pip install fonttools
  venv/bin/python -c "from fontTools.ttLib import TTFont; from fontTools.varLib import instancer; \
    instancer.instantiateVariableFont(TTFont('Lora[wght].ttf'), {'wght': 700}, updateFontNames=True).save('Lora-Bold.ttf')"
  ```
- `google_fonts` paketi **yok** (çevrimdışı oyun). `ThemeData.fontFamily =
  'Nunito Sans'`; Lora yalnızca `AppTypography` stilleriyle gelir.
- `flutter test` gerçek fontları yüklemez; `test/tooling/clue_fit_report_test.dart`
  ölçümleri test fontuyla yapılır. Nunito Sans 600 metrikleriyle ipucu taşması
  cihazda tekrar kontrol edilmeli (Oturum B).

## 2. Token'lar

- `lib/core/theme/app_tokens.dart` — `AppTokens extends ThemeExtension<AppTokens>`;
  alan adları JS anahtarlarıyla birebir (`bgFlat`, `cellClue`, `tileShadow` …),
  doc-comment'ler `TOKEN_META` metinleri (bilinçli olarak Türkçe — CLAUDE.md'nin
  "yorumlar İngilizce" kuralının tek istisnası).
  - `app_tokens_dark.dart` / `app_tokens_light.dart` (part): `THEMES.dark` /
    `THEMES.light` sabit örnekleri, Python ile kz-tokens.js'ten makine
    transkripsiyonu (elle yazılmadı).
  - `app_tokens_lerp.dart` (part): alan-alan `lerp`. Uç noktalarda (t=0/1)
    sabit örneklerin kendisi döner; painter'lardaki `tokens != old.tokens`
    kimlik karşılaştırması bu sayede ucuz.
  - `copyWith()` parametresiz (paletler sabit; tema değişir, yamalanmaz).
  - `AppTokens.logoBg` — `LOGO_BG` (160°); iki temada aynı.
- Dönüşüm kuralları: `#rrggbb` → `Color(0xFF…)`, `rgba()` → `Color.fromRGBO`,
  `transparent` → alfa 0, `linear-gradient(180deg…)` → `topCenter→bottomCenter`,
  `135deg` → `topLeft→bottomRight`, `160deg` → `Alignment(∓0.34, ∓0.94)`,
  `box-shadow` → `BoxShadow(offset, blurRadius, color)`.
- 55 JS anahtarından 53'ü görsel token; `key` ve `label` meta (label →
  arb `appDark`/`appLight`).
- Erişim: `context.tokens` (`AppTokensContext`); tema uzantısı yoksa
  parlaklığa göre sabit palete düşer (çıplak `MaterialApp` pump eden testler).
  Painter'lar (`GridStaticPainter`, `GridDynamicPainter`, `ClueRenderer`,
  `_GoldenFramePainter`) paleti parametre olarak alır.
- `lib/` altında `Color(0x…)` / `Colors.*` literal'i yalnız
  `app_tokens_*.dart` ve `app_logo.dart`'ta (SVG'nin kendi marka renkleri);
  `Colors.transparent` (hit-test/Material zemini) serbest.

### Eski `AppColors` → yeni token eşlemesi

| Eski `AppColors.` | Yeni |
|---|---|
| `primary` | `bot` (bot avatarı), `accent` (sıradaki bölüm karosu), `text` (bar ikonları) |
| `primaryDark` | `ink` |
| `accent` (FFA000) | `accent` (#f2c27a) — üstündeki metin `accentInk` |
| `brandCorner` | `appLogoGround` (= `AppTokens.dark.bgFlat`, iki temada sabit) + logo |
| `success` / `error` | `success` / `error` |
| `warning` | `accent` (berabere başlığı) |
| `gridCellNormal` | `cellLetter` |
| `gridCellSelected` | kaldırıldı (kullanılmıyordu) |
| `gridCellFound` | `board` (tamamlanan bölüm karosu) |
| `gridCellLocked` | `surface` (boş hücre, kilitli karo); devre dışı butonlar %40 opaklık |
| `clueCellBg` | `cellClue` |
| `gridLine` | `board` (hücre aralığı tahta renginde) |
| `ghost` | `ink` @ %30 alfa |
| `botLetter` | `inkBot` |
| `rackTileBg` | `tile` (rack/uçan taş), `cellPending` (tahtadaki bekleyen harf), `sheetCard` (swap sheet) |
| `circleButtonActiveBg` | `surface` |
| `revealActiveBg` | `accent` @ %15 |
| `shimmerHighlight` | `cellLetter` |
| `coinGold` | `accent` |
| `star` | kaldırıldı |
| `Colors.white` (buton/rozet metni) | `accentInk` (amber üstü), `solidText` (yeşil/kırmızı/koyu üstü) |
| `Colors.black` / `black87` | `ink` (tahta), `tileInk` (taş), `clueText` (ipucu) |
| `Colors.grey`, `black45`, `black.withValues(.55)` | `sheetMuted`, `dim`, `dim` |
| `Colors.red.shade300` | `error` |
| `Color(0x40000000)` vb. gölgeler | `dim` (uçan taş), `tileShadow` (rack taşı: `0 4 0`) |

### `AppTypography` / `AppDimensions`

| Eski | Yeni |
|---|---|
| `headline1` | `display` (Lora 62/700) |
| `headline2` | `resultTitle` (Lora 40/700) |
| `title`, `hudCounter` | `screenTitle` (Lora 22/700) |
| `bodyLarge`, `bodyMedium` | `body` (Nunito 15/400, 1.55) |
| `bodySmall` | `bodySmall` (Nunito 12/500) |
| `caption` | `pill` (13/600) — büyük harf etiket için `overline` (11/600, ls 3) |
| `button` | `buttonPrimary` (18/800) / `buttonSecondary` (15/700) |
| `gridLetter` | `cellLetter` (Lora 22) — rack taşı `tileLetter` (Lora 26); ipucu `clue` (Nunito 600, boyut otomatik) |
| — | `nodeNumber` (Lora 15/600), `label` (12/600) |
| `spacingXxs/Xs/S/M/L/Xl` | `space2/4/8/16/24/32` (+ `space6/10/12/18/20/40`) |
| `radiusS/M/L/Xl/Full` | `radiusCell 6 / radiusTile 10 / radiusBoard 16 / radiusListCard 18 / radiusScoreCard 20 / radiusSheet 28 / radiusPill 999` |
| `bottomSheetRadius`, `appBarHeight`, `cardElevation` | kaldırıldı |
| `gridCellMin/Max` 32/48 | 49/56 (LAYOUT) — grid fit-to-screen hesabı bunları **kullanmıyor**, yalnız değer güncellendi |
| — | `buttonPrimary 56 / buttonGame 52 / buttonSecondary 48`, `boardPadding`, `tileWidth/Height`, `iconButton`, `avatar` |

`AppTheme.dark()/light()`: `ColorScheme` (primary=accent, secondary=bot,
surface=bgFlat, error=error…), `TextTheme` rol eşlemesi, dialog/sheet/buton
temaları token'lardan; `extensions: [AppTokens]`.

## 3. Ayarlar

- `AppSettings` (`lib/data/models/`): `themeMode` (varsayılan `system`),
  `soundEnabled`, `hapticsEnabled`, `skyEnabled` (varsayılan `true`).
- `SettingsRepository` → `SharedPrefsSettingsRepository` (anahtarlar
  `settings.theme_mode|sound|haptics|sky`; enum adıyla saklanır, bilinmeyen
  değer varsayılana düşer) ve `InMemorySettingsRepository` (test).
- `SettingsCubit extends Cubit<AppSettings>`; `main()` `SharedPreferences`'ı
  ilk frame'den önce alır; `KelimeOyunuApp` `BlocProvider` + `BlocBuilder`
  ile `MaterialApp.themeMode`'u besler.
- Ses / titreşim / gökyüzü yalnızca kalıcı değer; davranış yok. Ayarlar
  ekranı hâlâ placeholder (`/settings`).

## 4. Metinler

- `l10n.yaml`: şablon `app_tr.arb`, çıktı `lib/l10n/generated/`
  (analysis_options'ta hariç; dosyalar git'te). `pubspec` `generate: true`.
- `STRINGS.tr/en` birebir (124 anahtar; diziler `slogans1..5`, `onbSteps1..4`;
  `get` → `getReward`). Placeholder tipleri: `n,total,done,d,p,b` int, `w` String.
- Eklenen uygulama anahtarları (tasarımda karşılığı olmayan mevcut metinler):
  `clue, levels, levelOfTotal, levelsProgress, levelsAllDone, allLevelsDone,
  scoreGap, resumeScore, swapLeftCount, revealConfirmTitle, yes, no,
  sixthSlotTitle, sixthSlotBody, levelDone/Current/Locked, botDescription`.
- Tasarım metni olan yerlerde tasarım metni benimsendi: "Devam Et" → "Yarım
  kalan oyun", "Kazandın! 🎉" → "KAZANDIN", "Sonraki Bölüm" → "Bölüm {n} ·
  tırmanmaya devam", "Fark: N" → "fark N", "Ad" rozeti → "reklam".
- Locale: `supportedLocales: [tr, en]`, ancak **A2 ile kilitlendi**:
  `localeResolutionCallback` her zaman `tr` döner (bulmaca paketi yalnız
  Türkçe). EN paketi gelince `app.dart`'taki callback silinir;
  `test/app_locale_test.dart` cihaz en iken tr'yi doğrular.
- "Sokrates" hiçbir yerde yok; bot profili adı `l10n.bot` ("Rakip"),
  id `rakip`, avatar `assets/images/rakip.png` (dosya henüz yok, eskisi de yoktu).
- Testler `test/helpers/localized_app.dart` (`localizedApp` /
  `localizedRouterApp`, locale tr) ile pump eder.

## 5. Logo, ikon, splash

- `lib/core/widgets/app_logo.dart`: `paintAppLogo(canvas, rect)` LOGO_SVG'nin
  birebir transkripsiyonu (viewBox 40, hücre 4.6, adım 5.4); `AppLogo`,
  `AppLogoTile` (120 dp, r28, `AppTokens.logoBg`). **flutter_svg eklenmedi**:
  22 dikdörtgen + 1 daire için SVG runtime gereksiz; painter tahtanın köşe
  hücresinde de aynı çizimi kullanır (`appLogoGround` = #0b1a33, iki temada).
- `docs/design/app-icon-1a*.svg`: C2PA `<metadata>` bloğu ve `xmlns:c2pa`
  temizlendi (9.6 KB → 1.9 KB).
- Raster'lar ImageMagick (rsvg delegate) ile `assets/icon/`'a:
  - `app_icon.png` 1024 (tam ikon, iOS düz), `app_icon_foreground.png` 1024
    (A2: çizim trim'lenip ortalanır, en uzak köşe merkezden 31.4 dp — 108 dp
    kanvasta 66 dp güvenli bölge içinde; `adaptive_icon_foreground_inset: 0`),
    `app_icon_background.png` (LOGO_BG 160° gradyan), `splash_logo.png` 480
    (= 120 dp @4x, r28 tile; flutter_native_splash kaynağı xxxhdpi sayar,
    1024 px verilse 256 dp görünürdü).
  - **Tek komut: `tools/make_icons.sh`** — dört PNG'yi SVG'lerden üretir,
    güvenli-bölge kontrolü yapar, `flutter_launcher_icons` ve
    `flutter_native_splash:create`'i çalıştırır. Çıktılar deterministik
    (ikinci koşuda diff yok).
- Splash: `flutter_native_splash` (native: `bgFlat` açık/koyu + logo tile,
  Android 12 + iOS storyboard) **ve** `/` rotasında `SplashScreen` (tam
  tasarım: tile, "Kelime Zirvesi" Lora 40, tag overline, 120×3 ilerleme
  çubuğu; 1.4 sn sonra `/levels`). Router `initialLocation` `/` oldu.
- Uygulama adı: AndroidManifest `android:label="Kelime Zirvesi"`, iOS
  `CFBundleDisplayName`; `applicationId` / bundle id değişmedi.
  `MaterialApp.title` "Kelime Zirvesi".

### Yeni paket gerekçeleri (dev_dependencies)

| Paket | Neden |
|---|---|
| `flutter_launcher_icons ^0.14.4` | Android adaptive (foreground + gradyan background PNG) ve iOS 1024 setini tek komutla üretir; elle mipmap/appiconset yönetimi hataya açık. Yalnız build-time. |
| `flutter_native_splash ^2.4.8` | Flutter ayağa kalkana kadarki beyaz flaşı bgFlat'e çevirir (açık/koyu), Android 12 SplashScreen API'sini ve iOS LaunchScreen'i düzenler. Yalnız build-time. |
| `flutter_svg` | **Eklenmedi** — logo CustomPainter; runtime SVG bağımlılığı gereksiz. |

## Doğrulama durumu

- `flutter analyze` 0 sorun, `flutter test` 219/219, `lib/` altında 300 satır
  üstü dosya yok.
- **Cihaz/emülatörde bakılmadı**: launcher ikonu (A2 sonrası dairesel/kare/
  damla maskelerde geometrik olarak tam sığar, gözle doğrulanmadı), native
  splash → Flutter splash geçişi, Lora/Nunito render'ı, ipucu taşması.
  Oturum B'nin ilk işi.
- `flutter build apk` bu oturumda çalıştırılmadı (Android kaynakları
  flutter_native_splash/flutter_launcher_icons tarafından yazıldı; Gradle
  doğrulaması yok).

## A2 düzeltmeleri (2026-09-24, aynı gün)

| Commit | Ne |
|---|---|
| `fix(l10n): pin the app locale to Turkish…` | `localeResolutionCallback` → tr; `test/app_locale_test.dart` |
| `fix(ui): gridLine token and a distinct light letter cell` | `AppTokens.gridLine` (dark `cellClue`, light `boardBorder`), `light.cellLetter` #fffdf7; sapma kaydı `docs/design/README.md` "Flutter sapmaları" |
| `fix(icons): keep the adaptive foreground inside the 66 dp safe zone` | foreground trim + 440 px, inset 0 |
| `build(icons): tools/make_icons.sh` | SVG → PNG → platform kaynakları tek script |

## Açık kalanlar / Oturum B'ye notlar

- Ekranlar yalnız **renk/tipografi olarak** token'lara taşındı; yerleşim,
  boyutlar (48 dp yuvarlak butonlar, 12/8 padding'ler, 4 dp rack aralığı) ve
  bileşen anatomisi README'deki spec'e göre yeniden yapılacak (harita, sonuç
  ekranları, clue/swap sheet r28, ayarlar, onboarding, consent, ATT, shop, legal).
- Reklam rozeti: "reklam" 9 px rozet; tasarım "▶ reklam" 7 px alt yazı, ilk 3
  bölümde gizli (`showAdLabels && level > 3`) — mantık yok.
- "Bölüm X / 200" hâlâ gösteriliyor (`levelOfTotal`); tasarım toplam sayıyı
  hiç göstermez. `kLastLevelId` ile ilerleme mantığı değişmedi.
- Level select 200'lük grid; tasarımın dikey harita/sis modeli yapılmadı.
- Gökyüzü/ses/titreşim ayarları davranışsız; ayarlar ekranı placeholder.
- `AppTokens.copyWith()` no-op; alan bazlı override gerekirse parametreler eklenir.
- `dart format --line-length 100` bu SDK'da `lib/data/repositories/puzzle_repository.dart`,
  `test/data/puzzle_parse_test.dart`, `test/helpers/engine_test_fixtures.dart`'ı
  yeniden biçimlendiriyor (önceki SDK'dan kalma sapma) — dokunulmadı; ayrı
  bir `style:` commit'i ile düzeltilebilir.
- Info.plist: flutter_native_splash `UIStatusBarHidden=false` ekledi.
- `.idea/caches/deviceStreaming.xml` IDE tarafından değiştirilmiş, commit'lenmedi.
- Arb'daki `price1..3`, shop/legal/consent/ATT/onboarding metinleri henüz
  hiçbir widget'ta kullanılmıyor (Oturum B ekranları için hazır).
