# HANDOFF — Tasarım Oturumu D: Kalan rotalar ve katmanlar (2026-09-25)

`docs/design/README.md` "Onboarding", "Consent", "ATT", "Settings", "Shop",
"Legal" bölümleri + oyun ⋯ menüsü. Altı adım, altı commit; her adımda
`flutter analyze` 0 sorun, `flutter test` yeşil (sonda 297). Arayüz ve yerel
durum; reklam / satın alma / consent gerçek SDK'ları FAZ 6'da aynı arayüzlere
bağlanır. Önceki oturumlar: `HANDOFF_DESIGN_A/B/C.md`.

| # | Commit | Özet |
|---|--------|------|
| 1 | `feat(settings): settings screen` | `/settings`, `ConsentService` mock, `ProgressRepository.reset`, package_info_plus |
| 2 | `feat(consent): consent and ATT pre-prompt` | `/consent`, `/consent/att` (yalnız iOS), `firstRoute`, kalıcı bayraklar |
| 3 | `feat(onboarding): three-card tutorial` | `/onboarding`, ilk açılış dalı, Ayarlar "Nasıl oynanır?" |
| 4 | `feat(shop): shop screen with mock purchases` | `/shop`, kamp parası / reklamsız / kamp ateşi, `PurchaseService` mock |
| 5 | `feat(legal): privacy and terms pages` | `/legal/*`, `assets/legal/*.md`, mini ayrıştırıcı |
| 6 | `feat(game): overflow menu` | ⋯ → Nasıl oynanır / Ayarlar / Haritaya dön (onaylı) |

---

## Yapılanlar

### 1. Ayarlar (`/settings`)
- `SettingsScreen(progressRepo, sessionRepo, consentService)`; `bgFlat`,
  ← + "Ayarlar" Lora 20; bölüm etiketleri 11/600 ls 3 %55; gruplar `surface`
  r18 1 px `border`, satır 14×18, ayraç `border`; etiket 700/15, alt 500/12 %60.
- OYUN: `SegmentedPill<ThemeMode>` (Açık / Koyu / Sistem, aktif amber, 700/12,
  6×12) → `SettingsCubit.setThemeMode` (anında; `MaterialApp.themeMode`);
  Ses / Titreşim / Gökyüzü `SettingsToggle` 48×28 (açık: amber ray + `accentInk`
  topuz; kapalı: `toggleOff` + `knob`); "Nasıl oynanır?" ›.
- HESAP: Reklamları kaldır → "Mağaza →" (`arrow`) `push('/shop')`; Reklam
  tercihleri → `ConsentService.showPrivacyOptions()` (mock) + snackbar;
  İlerlemeyi sıfırla → "Sil" (`error`) → onay diyaloğu →
  `ProgressRepository.reset()` + `sessionRepo.clear()`; Gizlilik › ; Koşullar ›.
- Alt bilgi "Kelime Zirvesi {sürüm}" — `package_info_plus` (yeni bağımlılık;
  gerekçe: sürüm metni elle yazılmaz, `pubspec` `version`'dan gelir; testte
  `PackageInfo.setMockInitialValues`). Arb `version` anahtarı artık
  kullanılmıyor (sabit "1.0.0" içeriyor).
- Yeni: `lib/core/services/consent_service.dart` (`requestConsent`,
  `showPrivacyOptions`, `requestTracking`; `MockConsentService`).

### 2. Onay ve ATT (`/consent`, `/consent/att`)
- Bayraklar `AppSettings.consentDone / attAsked / onboardingDone`
  (shared_preferences `flags.*`, tek yönlü `markX()` setter'ları). CLAUDE.md
  `ad_state` şifreli box'ı UMP SDK ile FAZ 6'da gelir; şimdilik bayrak yeter
  (bilinçli).
- `lib/core/router/first_run.dart` `firstRoute(settings, isIOS)`: consent →
  (iOS && !attAsked) `/consent/att` → (!onboardingDone) `/onboarding?first=1`
  → `/`. Splash `next`'i bunu `settingsRepo.read()` ile hesaplar
  (`AppRouter.build` artık `settingsRepo` alır).
- Consent: `bgGame` + iki sırt (%65), "HOŞ GELDİN", Lora 40 başlık, alt kart
  `sheet` r20 (başlık Lora 18, gövde 14/1.55 `sheetMuted`, "Gizlilik ·
  Koşullar" `arrow`), "Kabul et ve başla" 56 (→ `requestConsent`),
  "Seçenekleri yönet" 48 (→ `showPrivacyOptions`). İkisi de `consentDone`
  işaretler.
- ATT: `bgFlat`, 64 dp `surface` daire + kalkan ikonu, "BİR ADIM KALDI",
  Lora 36, gövde 15/1.6, çerçeveli r18 iki madde (yeşil nokta; metinler
  `attBullet1/2` — README'de madde metni yoktu, attBody'den türetildi),
  "Devam" → `requestTracking()` (mock; gerçek sistem diyaloğu FAZ 6),
  "Şimdi değil" metin 48. Platform: `defaultTargetPlatform == iOS`
  (`ConsentScreen.isIOS` testlerde enjekte). Android'de rota hiç girilmez.

### 3. Onboarding (`/onboarding`)
- `OnboardingScreen(firstRun)`: "Atla" sağ üst; `OnboardingStrip(stage)` —
  tahta şeridi (ipucu → bekleyen amber İ → vurgulu boş → boş) ve 1. kartta
  −8° eğik, 2.4 sn salınan amber "L" taşı; 2–3. kartlarda yerleşmiş/rakip
  harfi hâlleri; "n / 3" overline; Lora 28 başlık; gövde 15/1.55 %72; dört
  adım çipi (aktif amber; 2. kartta "Harf koy" + "Onayla"); üç nokta (aktif
  22×6 amber); "Devam" 56.
- Bitiş/Atla → `markOnboardingDone`; `first=1` ise `go('/')`, değilse `pop`.
  Ayarlar "Nasıl oynanır?" ve oyun ⋯ menüsü `push('/onboarding')`.
- Yeni arb: `onb2/onb2Sub/onb3/onb3Sub` (README: "chip metni, tek cümle"),
  `onbProgress`, `howToPlay`.

### 4. Mağaza (`/shop`)
- `ProgressRepository`: `coins`, `adFree`, `campfireClaimedToday`,
  `addCoins`, `setAdFree`, `claimDailyCampfire()` (günde bir, +20 =
  `kCampfireCoins`; seri **dokunulmaz** — test var). Kayıt şema 1, yeni
  anahtarlar `coins / ad_free / last_campfire_day` eski kayıtta 0/false/null.
  Şifreli `progress` box'ında (CLAUDE.md `coin_wallet`/`iap_state` ayrı
  box'ları yerine tek kayıt — bilinçli, AES aynı).
- `lib/core/services/purchase_service.dart`: `ProductIds` (`kz_ad_free`,
  `kz_coins_150`, `kz_coins_500`), `ShopProduct`, `PurchaseResult`,
  `PurchaseService.buy/restore/products`, `MockPurchaseService` (her satın
  alma başarılı; `restore` verilen listeyi döner). `in_app_purchase` FAZ 6.
- `ShopCubit`/`ShopState` (coins, adFree, campfireClaimed); `buy`,
  `claimCampfire`, `restore`.
- UI: ← + "Kamp dükkânı" + `CoinPill` (amber %18, `arrow`, 800/13); hero
  `AdFreeCard` (135° `accent`→`arrow`, r20, "TEK SEFERLİK", Lora 26, gövde
  500/13, fiyat çipi `solid` — alındıysa "Aktif"); "KAMP PARASI" iki kart
  (150 ≈ 15 harf açma ₺29,99 çerçeveli; 500 ≈ 50 ₺79,99 amber + "EN ÇOK
  ALINAN" + amber kenar); "ÜCRETSİZ" satırı Günlük kamp ateşi "Al" → "Alındı";
  "Satın alımları geri yükle". Fiyatlar arb `price1..3` placeholder.

### 5. Gizlilik / Koşullar (`/legal/privacy`, `/legal/terms`)
- `assets/legal/privacy_tr.md`, `terms_tr.md`; `parseLegalDocument`:
  `_meta_` / `## başlık` / paragraf. `LegalScreen(page)`: `page` zemin,
  `pageText`, Lora 20 başlık (arb), meta `pageMuted` 500/12, Lora 22 başlıklar,
  gövde. Başlıklar README'den (gizlilik: legal1–3; koşullar: üç placeholder
  başlık), gövdeler "[gerçek metin buraya]". Metin kodsuz güncellenir.

### 6. Oyun ⋯ menüsü
- `showGameMenu` → `GameMenuSheet` (`SheetShell`): Nasıl oynanır, Ayarlar,
  Haritaya dön (onay: "Yarım kalan oyun kaydedilir…" → `go('/map')`).
  `LevelTopBar.onMore` bağlandı.

## Doğrulama durumu
- `flutter analyze` 0; `flutter test` 297/297; `lib/` altında 300 satır üstü
  dosya yok (l10n/generated hariç).
- **Release doğrulama (oturum sonu):** `flutter build apk --release` (57.3 MB)
  → `adb install -r` → `pm clear` (temiz ilk açılış) → monkey → `adb logcat -d`:
  FATAL 0, `Displayed com.kelimeoyunu.kelime_oyunu/.MainActivity +456ms`,
  süreç ayakta; ekran görüntüleri (açık tema): onay ekranı README'ye uygun,
  "Kabul et ve başla" sonrası onboarding kart 1 (şerit, salınan L, çipler,
  noktalar, Devam). Not: emülatör uykudaysa `screencap` siyah döner —
  `input keyevent KEYCODE_WAKEUP` + `wm dismiss-keyguard` önce.
- Ekranlar iki temada gözle kontrol edilmedi; liste aşağıda.

## Emülatörde bakılacaklar (koyu + açık)
Hazırlık: `adb shell pm clear com.kelimeoyunu.kelime_oyunu` (ilk açılış
akışı için) ve `flutter run --dart-define=DEV_UNLOCK_ALL=true`.

| # | Ekran | Nasıl | Bakılacak |
|---|-------|-------|-----------|
| 1 | Onay | Temiz kurulum | `bgGame` + iki soluk sırt; "HOŞ GELDİN"; Lora 40 başlık iki satıra sığıyor; alt kart r20, gövde okunaklı, linkler `arrow` renkli ve legal sayfayı açıyor; Kabul et 56 amber gölgeli; Seçenekleri yönet 48 |
| 2 | ATT | Yalnız iOS simülatör | Android'de görünmemeli; iOS'ta kalkan dairesi, iki madde, Devam / Şimdi değil |
| 3 | Onboarding | Onaydan sonra | Şerit + salınan L taşı; "1 / 3"; çipler; Devam ile 2–3. kart (yerleşmiş harf, mavi rakip harfi); son Devam → ana ekran; Atla aynı; Ayarlar'dan açınca geri dönüyor |
| 4 | Ayarlar | Ana → Ayarlar | Segmented pill anında tema değiştiriyor; anahtarlar; Nasıl oynanır; HESAP satırları; sürüm satırı gerçek sürümü gösteriyor; "Sil" kırmızı, diyalog; sıfırlama sonrası ana ekran 0 |
| 5 | Mağaza | Ayarlar → Reklamları kaldır | Coin pill; hero gradyanı; 150/500 kartları yan yana sığıyor (360 dp'de taşma?); Al → Alındı, bakiye +20; ikinci gün tekrar Al; Reklamsız → Aktif |
| 6 | Legal | Ayarlar / Onay linkleri | Krem `page` zemin iki temada; başlıklar Lora 22; placeholder metin |
| 7 | ⋯ menüsü | Oyun ekranı | Sheet; Nasıl oynanır push; Ayarlar push; Haritaya dön onay → harita; ana ekranda "Yarım kalan oyun" kartı |
| 8 | Reklam tercihleri | Ayarlar | Snackbar "Reklam tercihleri güncellendi" (mock) |

## Tasarım eksikleri turu — README ekranı ↔ uygulama (bilinçli sapmalar hariç)

> Oturum E (2026-09-26) kapanışları işlendi; kalan satırlar bilinçli sapma ya da uygulama dışı iş.

| README ekranı | Uygulama | Fark / eksik |
|---|---|---|
| Splash | `/splash` | Tam. |
| Onboarding | `/onboarding` | Kart 1'deki şerit README'ye yakın; 2–3. kart illüstrasyonları README'de tarif edilmediği için türetildi. Nokta/çip/CTA tam. |
| Consent | `/consent` | Tam (E: sırtlar `mtn1` %70 / `mtn2` %60). |
| ATT | `/consent/att` | Madde metinleri README'de yok, türetildi. Gerçek sistem diyaloğu FAZ 6. |
| Home | `/` | Tam (E: pill blur 6, kayıt kartı blur 8 — `GlassSurface`). |
| Climb map | `/map` | Done kartı mini grid'de "letter with level number" var; patika 3 px dash 5/9; sis; tam. Done düğümleri widget (performans ölçülmedi). |
| Game | `/gameplay/:id` | Tam (E: mavi/kırmızı kesikli uçuş yayları, "+N ↑"). **Bilinçli:** ipucu font tablosu yerine test edilmiş otomatik sığdırma (9–14 px, hece-tire). |
| Clue sheet / Swap sheet | sheet'ler | Tam. |
| Result | `/result/:id` | Güneş/skor renkleri token'a eşlendi (sapma kaydı); "+40 m → X m" kamp irtifası. |
| Settings | `/settings` | Tam + ek "Nasıl oynanır?" satırı (README'de yok). |
| Shop | `/shop` | Tam; fiyatlar placeholder. |
| Legal | `/legal/*` | Tam; gövde placeholder. |
| App icon / store frames | ikon var | Store ekran görüntüsü çerçeveleri (5 kare + slogan bandı) yapılmadı. |
| Interactions: ses/titreşim | Ayarlar anahtarları | Davranış yok (FAZ 5). |
| Ad labels level>3 | `showAdLabelsFor` | Tam. |

## D2 düzeltmeleri (2026-09-25, kullanıcı GIF'i üzerine)

| Commit | Ne |
|---|---|
| `4402f8e fix(narration): word bonus badge no longer wraps` | Kelime bonusu rozeti hücre genişliğinde bir kutuda konumlanıyordu; "+12" satır kırıp yalnız "+" görünüyordu. Kutu üç hücre genişliğinde, hücreye ortalı. |
| `c52e639 fix(splash): Android 12 splash icon drawn for the circle mask` | Android 12+ sistem splash'i 480 px kare tile'ı 240 dp daireye büyütüp kırpıyordu (koyu, bulanık, kesik merkez). Artık `assets/icon/splash_icon_android12.png` (1152 px, yalnız dağ işareti, güvenli daire içinde) + `icon_background_color` navy daire; `tools/make_icons.sh` üretir. Emülatörde doğrulandı: krem zemin, navy daire, keskin işaret. Android 12 API yuvarlak kare tile çizemez; README'nin 120 dp kutusu Flutter splash rotasında aynen duruyor. |

Not: sistem splash'i tema tercihini bilemez — Ayarlar'da "Koyu" seçiliyken
cihaz açık modda olsa da native splash açık (krem), ardından gelen Flutter
splash koyu olur. Kaçınılmaz; `ThemeMode.system` kullanan oyuncuda tutarlıdır.

## Açık kalanlar
- FAZ 5: ses/titreşim davranışı; FAZ 6: AdMob (`AdService`), UMP + ATT
  (`ConsentService`), in_app_purchase (`PurchaseService`), fiyatların mağazadan
  gelmesi, `ad_state`/`iap_state` ayrı şifreli box'lar gerekiyorsa taşıma.
- Kamp parası harcama yolu yok (jokerler hâlâ reklam kapısında; README:
  reklamsızda jokerler para kullanır) — FAZ 6.
- Store ekran görüntüsü çerçeveleri; onboarding 2–3 illüstrasyon spec'i.
- Haritada done düğümü sayısı 200'e çıkınca kaydırma performansı.
- `/menu`, `/packs` placeholder rotaları kullanılmıyor; silinebilir.
