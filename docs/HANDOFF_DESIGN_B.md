# HANDOFF — Tasarım Oturumu B: Oyun ekranı ve sheet'ler (2026-09-24)

`docs/design/README.md` "Game screen", "Clue sheet", "Swap sheet" bölümlerinin
Flutter'a taşınması. Bloc, motor ve anlatım zamanlaması değişmedi; yalnız
görünüm ve yerleşim. Altı adım, altı commit; her adımda `flutter analyze` 0
sorun, `flutter test` yeşil (sonda 239 test). Oturum A ve A2 için
`docs/HANDOFF_DESIGN_A.md`.

| # | Commit | Özet |
|---|--------|------|
| 1 | `feat(ui): game screen skeleton per design` | bgGame gradyanı, ← / BÖLÜM n / ⋯ üst bar, avatarlı skor başlığı, sıra pill'i |
| 2 | `feat(ui): board card, rounded cells over gridLine gaps, in-cell arrows` | `BoardFrame` (board zemini r16, padding 6, gölge), r6 hücreler, hücre içi oklar |
| 3 | `feat(ui): rack tiles, joker slot and bottom bar per design` | 52×56 taşlar, seçili/yerleşmiş/dönen görünümler, "+ HARF EKLE", alt bar, reklam etiketi kuralı |
| 4 | `feat(ui): narration visuals per design` | rakip harfi inkBot −14°, hedef hücre mavi kenar, yanlış hücre cellWrong, nabızlı altın çerçeve, anlatım pill metinleri |
| 5 | `feat(ui): clue and swap sheets per design` | `SheetShell`, ipucu kartları "SAĞA · 3 HARF", harf değiştir seçenek kartları |
| 6 | `feat(ads): AdService gate and offline toast` | `AdService` + `MockAdService`, üç reklam kapısı, "Bağlantı yok" toast'u, `DEV_ADS_OFFLINE` |

---

## Yapılanlar

### 1. İskelet
- `GameActiveBody`: `Positioned.fill(bgGame)` + `SafeArea` (üst/alt).
- `LevelTopBar`: `CircleIconButton` (40 dp `surface` daire; `lib/core/widgets/`)
  ← ve ⋯, ortada "BÖLÜM" (overline 11/600 ls 3, %70) + numara (Lora 22).
  Toplam bölüm sayısı artık hiçbir yerde gösterilmiyor. ⋯ butonu **işlevsiz**
  (menü/ayarlar ekranı henüz yok) — aşağıda "Açık kalanlar".
- `ScoreHeader`: `1fr auto 1fr`; 38 dp avatar (oyuncu `accent`/`accentInk`,
  rakip `bot`/`botInk`, `Icons.person` silueti), "Sen"/"Rakip" 11/600 %70,
  skor Lora 22; "VS" 11/600 ls 2 %55. Rakip düşünürken oyuncu tarafı %55,
  rakip avatarında 3 px nabızlı mavi halka (`AnimationController`, boşta
  durur). `avatarKey` / `playerScoreKey` anlatım çapaları aynen.
- `TurnPill` + `turnPillFor(state, l10n)`: Sıra sende / {n} harf bekliyor ·
  onayla / Boş bir hücreye dokun / Rakip düşünüyor (üç zıplayan nokta).
  Amber / mavi / kırmızı tint (%18 alfa).

### 2. Tahta
- `BoardFrame` (`lib/features/gameplay/widgets/board_frame.dart`): kısıtlardan
  sığan en büyük grid'i hesaplar (`cellSize` statik, testli), `board` zemin,
  r16, 6 dp padding, 1 px `boardBorder`, `boardShadow`; çocuğuna **tam grid
  boyutunda** kısıt verir. `GridPainter` ve `NarrationLayer` böylece aynı
  hücre boyutunu türetir (FAZ 4 "hücre hesabının ortaklaştırılması" kapandı).
- Hücreler: slot geometrisi aynı; `GridStaticPainter.cellShape(slot)` = slot
  1 px içeri, r6. Tüm kanvas önce `gridLine` ile dolar, aralık olarak görünür.
  Köşe logosu, harf, ipucu, bekleyen, hover, boş hücre aynı şekli kullanır.
- Oklar: hücre **içinde**, kenara 1 px mesafede, 5 px derinlik / 6 px taban
  `arrow` renginde üçgen; en üst pass'te çizilmeye devam eder.
- Çift-ipucu ayırıcı: `clueText` %60. İpucu metni: `clueText`, Nunito 600,
  mevcut otomatik sığdırma algoritması (9–14 px, hece-tire) **korundu**;
  README'nin "≤8 → 12 px, ≤14 → 10 px, üstü 9 px" tablosu uygulanmadı
  (mevcut algoritma test edilmiş ve daha ince taneli).

### 3. Rack ve alt bar
- `RackWidget`: `selectedIndex` (state.selectedRackIndex) ve `showAdLabel`
  aldı. Taş 52×56 r10, aralık 6; boşta `tile` + `0 4 0 tileShadow`; seçili
  `accent`, −8 dp, `0 12 24 accent@.4`; yerleşmiş → kesikli `faint` **boş**
  yuva (harf gizli; uzun basış hâlâ geri çağırır); dönen taş 2 px `error`.
  Sürükleme geri bildirimi (`DragFeedbackTile`) seçili taş görünümünde.
- `DashedBorderPainter` (`lib/core/widgets/dashed_border.dart`).
- "+ HARF EKLE": 1.5 px kesikli `accent`, + ikonu 16, etiket 800/7.5.
- `AdLabel` (`▶ reklam`, 7 px, %65) + `showAdLabelsFor(level) => level > 3`.
  Rack, alt bar ve swap sheet bu kuralı kullanır.
- `ActionBar`: ⇄ 52 dp daire 1.5 px `faint` halka; Onayla/Pas `accent`
  stadyum pill 52 (`buttonPrimary` 18/800); lamba 52 dp daire `accent` %15 +
  1.5 px halka, ikon 17, "İPUCU AL" 800/7, reklam alt etiketi. Rakip
  sırasında (`_botTurn`): rack %45, bar %40, pill `surface` "Sıra rakipte".
  Etkinleştirme mantığı (onSwap/onReveal null koşulları) aynen.

### 4. Anlatım görselleri
- `FlyingTile`: `ink` ve `rotationDeg`; rakip harfi `inkBot`, −14°. Uçuş
  sırasında hedef hücrede 2 px `inkBot` kenar (yalnız rakip; oyuncunun
  harfleri zaten bekleyen taş olarak hücrede).
- `GhostLetterTile` (yanlış harf): `cellWrong` zemin + 2 px `error` halka;
  sonra rack'e uçar (zamanlama aynı).
- `WordFrame`: 3 px `accent` halka, nabızlı parıltı (12 px stroke, 15 px
  blur, `accent`@.55 × nabız), mevcut `cellLetter` ışıltı süpürmesi durur.
- `narrationPillFor(controller, puzzle, l10n)`: "{KELİME} · +{n} puan"
  (kelime bonusu tutarken; rakip için mavi tint) ve "Bu harf buraya
  uymuyor" (yanlış harf hücrede dururken, kırmızı). Yalnız saati **okur**.
- Yapılmayan: rakip avatarından hücreye kesikli mavi yay ve kırmızı geri
  dönüş yayı; "+12 ↑" rozetindeki ok glifi.

### 5. Sheet'ler
- `SheetShell`: 44×5 tutamak, Lora 24 `sheetText` başlık, sağda `trailing`;
  `sheet` zemini ve r28 tema'dan. `SheetSolidButton` (52, `solid`).
- `ClueSheet(cell, entries)`: "n. satır · m. sütun[ — bu hücre iki kelimeye
  açılıyor]" (1 tabanlı), her ipucu için `sheetCard` r16 p16 kart: 36 dp r10
  `arrow` kare + yön ikonu, "SAĞA · 3 HARF" (overline ls 1, `sheetMuted`),
  ipucu Lora 600 18 `sheetText`; "Kapat". Kelime uzunlukları
  `showClueSheet(context, spec, puzzle)` içinde puzzle'dan.
- `SwapSheet(rack, quotaRemaining, showAdLabel)`: "Kalan hak · n harf",
  56×60 taşlar (`sheetCard`, 4 dp `tileShadow`; seçili `accent` + 3 px
  `arrow` halka, −6 dp), "n harf seçildi / Henüz harf seçilmedi", iki
  seçenek kartı (primary 56 "Şimdi değiştir ▶ reklam · sıra sende kalır",
  outlined 52 "Değiştir ve pas · ücretsiz, sıra rakibe"), seçim yokken %40 ve
  devre dışı. Kota sınırı ve `SwapChoice` aynı.
- Yeni arb anahtarları: `levelTag`, `clueCellPosition`,
  `clueCellPositionDouble`, `swapSelected`, `swapNone` (tr + en).

### 6. Reklam kapısı ve toast
- `lib/core/services/ad_service.dart`: `AdService.showRewarded()` →
  `RewardedAdResult { rewarded, dismissed, unavailable }`.
  `mock_ad_service.dart`: `const MockAdService()` anında ödüllendirir;
  `MockAdService(result: unavailable)` çevrimdışıyı taklit eder.
- `GameScreen.adService` (constructor injection, varsayılan mock) →
  `GameActiveBody` → `_GameInteraction._adGate`. Üç reklam-ödemeli aksiyon
  kapıdan geçer: 6. yuva, "Şimdi değiştir", **ipucu (reveal)**. Reveal daha
  önce reklamsızdı; mock her zaman ödüllendirdiği için gözlenen davranış
  aynı, gerçek SDK gelince kapı hazır.
- `showOfflineToast(context, onRetry)`: floating SnackBar, `solid` zemin r14,
  kırmızı wifi-off, "Bağlantı yok · reklam yüklenemedi" 600/12, "Tekrar dene"
  800/12 `accent` → aynı aksiyonu baştan çalıştırır (dialog yeniden gelir).
  Rack + alt barın üstünde durur. Oyun akışı etkilenmez.
- QA: `flutter run --dart-define=DEV_ADS_OFFLINE=true` (kDebugMode ile AND;
  `lib/core/config/dev_flags.dart`) → router `unavailable` mock'u enjekte eder.

## Doğrulama durumu

- `flutter analyze` 0 sorun; `flutter test` 239/239; `lib/` altında 300 satır
  üstü dosya yok.
- **Emülatörde bakılmadı.** Aşağıdaki liste bunun için.
- `flutter build apk` çalıştırılmadı.

## Emülatörde bakılacaklar (her biri koyu + açık temada)

Hazırlık: `flutter run --dart-define=DEV_UNLOCK_ALL=true --dart-define=DEV_ADS_OFFLINE=true`
(4+ bölüme girip reklam etiketlerini, 1–3'te etiketsiz hâli görmek için).
Tema: Ayarlar ekranı henüz yok; sistem temasını değiştir (ThemeMode.system
varsayılan) ya da geçici olarak `SettingsCubit.setThemeMode` çağır.

| # | Durum | Nasıl tetiklenir | Bakılacak |
|---|-------|------------------|-----------|
| 1 | **Sıra sende** | Bölümü aç | bgGame gradyanı; ← / BÖLÜM n / ⋯; avatarlar, skorlar Lora 22, "VS"; amber "Sıra sende" pill; tahta kartı (r16, gölge, açık temada 1 px kenar); r6 hücreler + gridLine aralığı; köşe logosu; ipucu metni okunurluğu (9–14 px, Nunito 600); oklar hücre içinde kenarda; rack taşları 52×56 + 4 dp taban gölgesi; "+ HARF EKLE" kesikli; alt bar üçlüsü; **ipucu taşması** (Nunito metrikleri — `test/tooling` raporu test fontuyla) |
| 2 | Taş seçili / bekleyen harf | Taşa dokun; hücreye dokun | Seçili taş amber, 8 dp yukarı, parıltı; pill "Boş bir hücreye dokun"; yerleşince pill "1 harf bekliyor · onayla", rack'te kesikli boş yuva, hücrede `cellPending` + `inkPending`; uzun basışla geri çağırma; sürükleme geri bildirimi taşı |
| 3 | **Rakip düşünüyor** | Onayla / Pas | Oyuncu tarafı %55, rack %45, bar %40, pill `surface` "Sıra rakipte", mavi pill + zıplayan noktalar, rakip avatarında nabızlı halka; **boşta repaint yok** (DevTools "Repaint Rainbow": halka yalnız düşünürken) |
| 4 | **Harf uçuşu** (rakip) | Rakip hamlesi | Taş `inkBot` −14° avatardan hücreye; hedef hücrede 2 px mavi kenar; iniş anında harf belirir (çift görüntü yok) |
| 5 | **Kelime tamamlandı** | Kelimeyi bitir | 3 px amber halka + nabızlı parıltı + ışıltı; "+N" amber rozet skora uçar; pill "{KELİME} · +{n} puan"; sayaç adım adım artar; rakip tamamlarsa pill mavi |
| 6 | **Yanlış harf** | Yanlış harf koy, onayla | Hücre `cellWrong` + 2 px kırmızı halka; taş rack'e uçar; rack'te 2 px kırmızı halka; pill kırmızı "Bu harf buraya uymuyor"; −1 rozeti |
| 7 | **İpucu sheet** | İpucu hücresine dokun (tek ve çift) | `sheet` zemin r28, tutamak, başlık İpucu/İpuçları, "n. satır · m. sütun" (çiftte ek not), kartlar (arrow kare, "SAĞA · 3 HARF", Lora 18 metin), Kapat 52 `solid`; arka karartma `dim` |
| 8 | **Harf değiştir sheet** | ⇄ | "Kalan hak · n harf", 56×60 taşlar, seçimde amber + kahverengi halka + 6 dp kalkış, "n harf seçildi", seçimsizken kartlar %40 ve pasif; "Şimdi değiştir ▶ reklam" alt satırı "sıra sende kalır"; 4+ bölümde reklam etiketi, 1–3'te yok |
| 9 | **Bağlantı yok toast** | `DEV_ADS_OFFLINE=true` ile: + HARF EKLE → Evet; ⇄ → Şimdi değiştir; lamba → ipucu hücresi → Evet | Toast rack'in üstünde, `solid` r14, kırmızı wifi-off, metin, amber "Tekrar dene"; Tekrar dene aynı dialogu yeniden açar; oyun akışı bozulmaz (sıra geçmez, yuva açılmaz) |
| 10 | Reveal modu | Lamba | Lamba dolu amber; ipucu olmayan hücreye dokununca mod kapanır; hücre karartması `dim` |
| 11 | Sonuç dialogu | Bölümü bitir | Token renkleri (henüz README "Result screens" tasarımı değil — Oturum C) |
| 12 | Tablet / küçük telefon | 600 dp+ ve 360 dp | Tahta `BoardFrame` ile ortalanır, hücre 49–56 dp beklenir; küçük ekranda rack + bar sığmalı |

## Açık kalanlar

- ⋯ butonu işlevsiz; ayarlar/duraklat menüsü Oturum C (settings ekranı ile).
- Sonuç ekranları (won/lost/draw), harita, ana ekran, ayarlar, onboarding,
  consent, ATT, shop, legal: README'de var, uygulanmadı (Oturum C).
- Kesikli uçuş yayları ve "+12 ↑" ok glifi yapılmadı.
- İpucu font boyutu tablosu yerine mevcut otomatik sığdırma kullanıldı.
- Rakip düşünürken rack %45 — README bunu "player side 55 %, rack 45 %, bar
  40 %" diye verir; sürükleme/dokunma zaten kapalı, yalnız görünüm.
- Toast konumu sabit bir marj (rack + bar yüksekliği + 40 dp) ile hesaplanıyor;
  farklı ekranlarda rack'e göre hizası gözle doğrulanmalı.
- Gerçek AdMob: `AdService` implementasyonu + `GameScreen.adService`
  enjeksiyonu; consent (UMP) SDK init'ten önce (CLAUDE.md).
- `narration_layer_test` ve `grid_painter_test` çıplak `MaterialApp` ile
  çalışır (l10n gerekmez); l10n'li widget'lar `test/helpers/localized_app.dart`.
