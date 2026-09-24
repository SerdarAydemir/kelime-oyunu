# HANDOFF — Tasarım Oturumu C: Ana ekran, harita, sonuç ekranları (2026-09-24)

`docs/design/README.md` "Home", "Climb map", "Result screens" bölümlerinin
Flutter'a taşınması + ilerleme modeli. Dört adım, dört commit; her adımda
`flutter analyze` 0 sorun, `flutter test` yeşil. Önceki oturumlar:
`docs/HANDOFF_DESIGN_A.md` (A/A2), `docs/HANDOFF_DESIGN_B.md` (B + R8 çökmesi).

| # | Commit | Özet |
|---|--------|------|
| 1 | `feat(progress): altitude, daily streak, words found` | `ProgressRepository` üç alan, Hive geriye uyumlu, `GameActive.playerWordsFound`, DoD'ye release kuralı |
| 2 | `feat(home): home screen` | `/` ana ekran, `HomeCubit`, gökyüzü gradyanı, dağ arka planı, kartlar/butonlar |
| 3 | `feat(map): climbing map replaces level select` | `/map` tırmanış haritası, `MapLayout` geometri, düğüm durumları, eski grid silindi |
| 4 | `feat(result): full-screen won/lost/draw` | `/result/:level` rotası, dialog kaldırıldı |

---

## Ön kontroller

### (a) "Test sayısı 260'tan 239'a düştü" iddiası
`git log --stat --diff-filter=D -- test/` (A başlangıcı `d73b7cc`'den B sonuna):
**silinen test dosyası yok**. Statik `test(`/`testWidgets(`/`blocTest(`
bildirimi sayısı: `d73b7cc` 148 → A sonu 166 → A2 168 → B sonu 186. Çalışan
test sayısı da tek yönlü arttı: 198 (A öncesi) → 219 (A) → 221 (A2) → 239 (B).
**260 hiçbir noktada olmadı**; düşüş yok, geri getirilecek test yok. Tek
"azaltma" bu oturumda: `result_dialog_test.dart` (11 test) sonuç ekranı
testlerine (8 test, aynı senaryolar + rota testleri) taşındı ve
`level_select_screen_test.dart` (13) `climb_map_screen_test.dart` +
`map_state_test.dart` (16) olarak yeniden yazıldı. Oturum sonu: **262 test**.

### (b) CLAUDE.md kuralı
DoD'ye eklendi: her oturum sonunda `flutter build apk --release` + `adb
install -r` + monkey ile açılış + `adb logcat -d`'de FATAL yok / `Displayed
.../.MainActivity`. Test kadar zorunlu (R8 yalnız release'de çalışır).

## Yapılanlar

### 1. İlerleme modeli
- `ProgressRepository`: `altitudeMeters` (kazanılan bölüm × `kMetersPerLevel`
  = 40, türetilir, saklanmaz), `dailyStreak`, `wordsFound`,
  `recordMatchFinished({wordsFound})`. Streak kuralı: art arda yerel takvim
  günlerinde +1; aynı gün ikinci maç değiştirmez; bugün ya da dün oynanmışsa
  seri canlı, bir gün atlanınca `dailyStreak` 0 okur ve sonraki maç 1'den
  başlar. Gün sınırı cihaz yerel saati (`yyyy-mm-dd` anahtarı); saat
  `now` enjekte edilebilir (testler `TestClock`).
- Hive JSON kaydı şema 1'de kaldı; yeni anahtarlar (`last_played_day`,
  `streak`, `words_found`) eski kayıtta yoksa 0/null okunur (test:
  "schema-1 record written before the stats existed opens with zeros").
- `GameActive.playerWordsFound`: her onaylanan hamlede
  `result.completedWordIds.length` kadar artar; `SavedSession`'a
  `player_words_found` (yoksa 0) yazılır; maç bitince (kazan/kaybet/berabere)
  `recordMatchFinished` çağrılır, kazançta ayrıca `recordWin`.
- `InMemoryProgressRepository(initialStats:, now:)` testler için.

### 2. Ana ekran (`/`)
- Rota: `/splash` → `/` (`SplashScreen(next: '/')`), `initialLocation` `/splash`.
- `HomeCubit`/`HomeState` (`nextLevel`, `altitudeMeters`, `dailyStreak`,
  `wordsFound`, `resume`); `climbProgress` gökyüzü için.
- `lib/core/theme/sky.dart`: `homeSky` / `mapSky` — Gökyüzü ayarı açıkken
  gece (tema gradyanı) → şafak (`bgWon`, ilerleme 0.5) → gündüz (açık paletin
  gradyanı); kapalıyken tema gradyanı. Uç noktalar birebir nesne (test).
  `SettingsCubit` yoksa (testler) açık kabul edilir.
- `MountainBackdrop`: üç sırt (`mtn1` %85, `mtn2`, `mtn3`) + kesikli amber
  patika ve nokta; sonuç ekranlarında `trail: false`.
- Metinler: tag, "Kelime\nZirvesi" Lora 62, `NowPill` ("Şu an · Bölüm n ·
  X m"), `StatsRow`, `SaveCard` (kayıt yoksa "Kaydedilmiş oyun yok" + alt
  metin), `PrimaryButton` 56 (amber gölge; `solid:` varyantı sonuç ekranı),
  `SecondaryButton` 48. CTA: kayıt varsa "Tırmanışa devam et" →
  `/gameplay/n?resume=true`, yoksa "Bölüm n ile başla" → `/gameplay/n`.
  "Harita" → `/map`, "Ayarlar" → `/settings` (placeholder, Oturum D).
- Yeni arb: `meters` ('{m} m').

### 3. Tırmanış haritası (`/map`)
- `MapLayout` (saf): `N = max(level+40, 80)`, `H = N·96 + 240`,
  `center(n) = (w/2 + 0.3·w·sin(0.85n), H − 140 − (n−1)·96)`,
  `initialOffset(viewport)` = buradasın %60'ta. 390 dp'de x = 195 ± 118.
- `MapState.kindOf`: done / current / upcoming (sonraki iki) / far;
  `isPlayable` = done | current | unlockAll.
- Çizim: `TrailPainter` kesikli amber polyline (3 px, 5/9, %60) + uzak
  düğümlerin 14 dp `faint` noktaları (widget değil, boya); done kartı 48 dp
  (board, 2 px amber, 2×2 mini grid, numara Lora 11), buradasın 68 dp amber
  daire (Lora 24 + "BURADASIN" 800/8, 2 s nabız halkası, 40 px parıltı),
  sıradaki iki 44 dp kesikli daire + kilit.
- Üst 200 dp sis (`fog` → saydam) **dokunuşu geçirir**; ← butonu ayrıca
  üstte. Başlık "TIRMANIŞ / Bölüm n · m m", "yukarısı sisin içinde…", altta
  "Kamp · başlangıç". Toplam bölüm sayısı hiçbir yerde yok.
- DEV_UNLOCK_ALL: uzak düğümler 32 dp `surface` daire içinde numaralı ve
  tıklanabilir, sıradaki iki numaralı, başlıkta DEV rozeti.
- Kaldırılan: `lib/features/levels/` (screen, cubit, state, tile, banner)
  ve testi; `/levels` → `/map` yönlendirmesi kaldı. Oyun ekranındaki ←
  ve sonuç "Harita" hedefleri `/map`.

### 4. Sonuç ekranları (`/result/:level?status=&p=&b=`)
- `ResultScreen.location(...)` rota üretir; `GameActiveBody` anlatım
  bitince `context.go` ile geçer (bloc dialog callback'leri kalktı;
  `showMatchResultDialog`, `ResultDialog` silindi).
- Kazandın: `bgWon`, güneş diski, "Bir adım daha / zirveye", "+40 m → X m"
  pill'i (X = bölüm × 40 — o kampın irtifası; tekrar oynanan eski bölümde
  gerçek irtifadan düşük görünür, bilinçli), skor kartı (Lora 40, oyuncu
  `accent`, rakip `bot`, "fark d"), `solid` "Bölüm n+1 · tırmanmaya devam"
  (son bölümde gizli, "Tüm bölümleri bitirdin! 🎉" görünür), "Tekrar oyna"
  / "Harita" `solid` renkli çerçeveli.
- Kaybettin: `bgLost`, kamp ateşi, "Kampta / bir gece daha", alt metin,
  "Tekrar dene" amber 56, "Haritaya dön" 48. Berabere: `bgDraw`, kendi
  metni, aynı aksiyonlar. Sert ilerleme aynen; geri hareketi kapalı.
- Tekrar oyna → `/gameplay/n` (yeni GameScreen, temiz yükleme).
- Renk sapmaları README "Flutter sapmaları"na yazıldı (güneş, skor renkleri).

## Doğrulama durumu

- `flutter analyze` 0; `flutter test` 262/262; `lib/` altında 300 satır üstü
  dosya yok (l10n/generated hariç).
- **Release doğrulama (oturum sonu):** `flutter build apk --release` (56.9 MB)
  → `adb install -r` → `adb shell monkey -p com.kelimeoyunu.kelime_oyunu 1` →
  `adb logcat -d`: FATAL 0, `ActivityTaskManager: Displayed
  com.kelimeoyunu.kelime_oyunu/.MainActivity +597ms`, süreç 10 sn sonra ayakta;
  ekran görüntüsü alındı (splash → ana ekran).
- Ekranlar gözle **kontrol edilmedi**; liste aşağıda.

## Emülatörde bakılacaklar (koyu + açık tema)

Hazırlık: `flutter run --dart-define=DEV_UNLOCK_ALL=true --dart-define=DEV_ADS_OFFLINE=true`.
Tema: sistem temasını değiştir (Ayarlar ekranı Oturum D).

| # | Ekran / durum | Nasıl | Bakılacak |
|---|---------------|-------|-----------|
| 1 | Splash → Ana | Uygulamayı aç | 1.4 sn sonra `/`; native splash ile Flutter splash arası atlama yok |
| 2 | Ana, yeni oyuncu | Temiz kurulum | `bgHome` gece gradyanı, üç dağ + kesikli patika; tag ls 3; "Kelime / Zirvesi" iki satır Lora 62 taşmıyor; pill "Şu an · Bölüm 1 · 0 m"; "Bugünün serisi · 0 gün / Bulunan kelime · 0"; "Kaydedilmiş oyun yok" kartı; "Bölüm 1 ile başla" amber gölgeli 56; Harita / Ayarlar 48 |
| 3 | Ana, ilerlemiş | Birkaç bölüm kazan, bir maçı yarıda bırak | Pill irtifa (n−1)×40; seri ve kelime sayaçları artıyor; "Yarım kalan oyun" + "Bölüm n · Sen p – Rakip b" Lora 18; CTA "Tırmanışa devam et" kaldığı yerden açıyor |
| 4 | Ana, gökyüzü | DEV ile 100. bölümü kazan; Gökyüzü kapalıyken (D'de anahtar) | Gradyan şafağa/gündüze kayıyor; kapalıyken tema gradyanı |
| 5 | Harita, açılış | Ana → Harita | Buradasın %60 yükseklikte; sis üstte, başlık "TIRMANIŞ / Bölüm n · m m", "yukarısı sisin içinde…"; altta "Kamp · başlangıç" |
| 6 | Harita, düğümler | Kaydır | Done kartı 2×2 grid + numara; buradasın nabız + parıltı; sıradaki iki kesikli kilit; uzak 14 dp noktalar numarasız; patika düğüm merkezlerinden geçiyor; 200 hiçbir yerde görünmüyor |
| 7 | Harita, dokunma | Done'a, buradasın'a, kilitliye dokun | Done tekrar açılır (resume yok), buradasın açılır, kilitli inert; **sis altındaki düğüme dokunuş geçiyor**, ← çalışıyor |
| 8 | Harita, DEV | `DEV_UNLOCK_ALL` | Uzak düğümler numaralı daireler, tıklanınca açılır; DEV rozeti; ilerlemeye yazmıyor |
| 9 | Kazandın | Bir bölümü kazan | Anlatım bitince tam ekran; `bgWon` şafak + güneş diski; "BÖLÜM n · KAZANDIN" ls 4; başlık Lora 44 iki satır; "+40 m → X m"; skor kartı Lora 40 amber/mavi, "fark d"; `solid` CTA; Tekrar oyna / Harita; geri hareketi kapalı |
| 10 | Kaybettin / Berabere | Kaybet; berabere kal | `bgLost` gece + kamp ateşi / `bgDraw`; metinler; Tekrar dene aynı bölümü temiz açar; Haritaya dön |
| 11 | Son bölüm | DEV ile 200'ü kazan | CTA yok, "Tüm bölümleri bitirdin! 🎉"; harita buradasın 200'de kalır |
| 12 | Küçük / büyük ekran | 360 dp ve tablet | Ana ekranda `Spacer` sıkışması, taşma yok; haritada x salınımı kenarlara çarpmıyor; sonuç ekranı kartları sığıyor |

## Açık kalanlar

- Ayarlar ekranı placeholder (Oturum D): tema/ses/titreşim/gökyüzü UI'ı;
  gökyüzü anahtarı şimdilik yalnız kalıcı değer + gradyan.
- Oyun ekranı ⋯ butonu hâlâ işlevsiz.
- Haritada done kartlarının tamamı widget (200'e kadar); kaydırma
  performansı emülatörde ölçülmedi. Gerekirse `CustomScrollView`/sliver.
- Sonuç "+40 m → X m" tekrar oynanan bölümde kampın irtifasını gösterir,
  toplam irtifayı değil.
- Sonuç ekranındaki üç literal renk token'a eşlendi (README sapma kaydı).
- Onboarding/consent/ATT/shop/legal (README) yapılmadı.
