# HANDOFF — FAZ 4 teknik borç: 300 satır bölmesi + renk token'ları (2026-09-16)

Gece oturumu, gözetimsiz. Kural: **davranış değişmez, yalnız yapı.** Her
bölme sonrası `flutter analyze` 0 hata + `flutter test` tümü yeşil; her dosya
ayrı commit. Push yapılmadı.

Baseline (c8cb24d): analyze temiz, **187 test** yeşil. Görev metni ve
`HANDOFF_DEPS.md` 167 diyor; sayı o günden beri büyümüş (F6/F7 testleri).
Sonuç (a022d55 + bu docs commit'i): analyze temiz, 187/187 yeşil, `lib/`
altında 300 satırı aşan dosya **0** (en büyük: `rack_manager.dart` 254).

## Commit listesi (sırayla)

| # | Commit | Başlık |
|---|---|---|
| 1 | `373e269` | refactor(grid): split grid_painter.dart by layer responsibility |
| 2 | `a95008f` | refactor(screen): split game_screen.dart into body, interaction, dialogs, queries |
| 3 | `6419adc` | refactor(bloc): split GameBloc handlers into part-file extensions |
| 4 | `3907c94` | refactor(narration): split NarrationLayer builders into part files |
| 5 | `5857cf1` | refactor(models): split puzzle.dart into cell and word part files |
| 6 | `4cd137d` | refactor(narration): move WordFrame out of narration_tiles.dart |
| 7 | `a022d55` | refactor(theme): replace remaining opaque colour literals with AppColors tokens |
| 8 | (bu commit) | docs: HANDOFF_REFACTOR + CLAUDE.md |

## Dosya haritası (eski → yeni)

Satır sayıları bölme sonrası. Public API değişmedi: eski import yolları ya
aynı sembolleri taşıyor ya da yeni dosyayı `export` ediyor. Test dosyalarına
hiç dokunulmadı (import düzeltmesi bile gerekmedi).

### 1. `grid_painter.dart` (533) — ayrı kütüphaneler + export
| Yeni dosya | Satır | İçerik |
|---|---|---|
| `widgets/grid_painter.dart` | 244 | `GridPainter` widget + state (hit-test, drag hover/drop); iki painter'ı `export` eder |
| `widgets/grid_static_painter.dart` | 138 | `GridStaticPainter` (hücre zemini, harfler, ipucu metni, grid çizgileri) |
| `widgets/grid_dynamic_painter.dart` | 118 | `GridDynamicPainter` (joker spotlight, hover, pending taşlar, oklar) |
| `widgets/pending_letter_draggable.dart` | 64 | `PendingLetterDraggable` (eski `_PendingLetterDraggable`; tek dışa açılan yeni sembol, `super.key` eklendi — lint zorunluluğu) |

### 2. `game_screen.dart` (525) — alt widget + part mixin + fonksiyonlar
| Yeni dosya | Satır | İçerik |
|---|---|---|
| `view/game_screen.dart` | 133 | `GameScreen`, `_SessionFlushListener`, `_GameBody`, `_kBotProfile` |
| `view/game_active_body.dart` | 253 | `GameActiveBody` (eski `_GameActiveBody`, public; `botProfile` parametresi eklendi) — layout, narration/lifecycle, sonuç dialog'u |
| `view/game_active_interaction.dart` | 104 | `part of game_active_body.dart` — `_GameInteraction` mixin: `_revealMode`, tap/drop/recall yönlendirme, joker onayları |
| `view/game_dialogs.dart` | 109 | `showMatchResultDialog`, `showClueSheet`, `confirmRevealDialog`, `confirmSixthSlotDialog`, `showSwapSheet` — yalnız cevap toplar, bloc dispatch çağıranda |
| `view/game_active_queries.dart` | 35 | `GameActiveQueries` extension: `clueSpecAt`, `isPlaceable`, `isPendingAt`, `rackIndexForPending` (saf state sorguları) |

Dikkat: `_onCellTap` içinde ipucu hücresi araması eskiden iki kez yapılıyordu
(reveal modu ve normal mod dalları); şimdi bir kez `clueSpecAt` ile — aynı
sonuç, aynı dallanma sırası.

### 3. `game_bloc.dart` (454) — part dosyalarında private extension
| Yeni dosya | Satır | İçerik |
|---|---|---|
| `bloc/game_bloc.dart` | 216 | alanlar, event kaydı, load/resume/flush/save, `_onRackTileSelected`, `_finish` |
| `bloc/game_bloc_turn.dart` | 190 | `_TurnHandlers on GameBloc`: place/recall/confirm/pass/botMoveCompleted/`_runBotTurn` |
| `bloc/game_bloc_jokers.dart` | 69 | `_JokerHandlers on GameBloc`: swap/reveal/sixthSlot |

Tek metin farkı: `_stallLimit` extension içinden `GameBloc._stallLimit` olarak
nitelendi (static üye, extension kapsamında çıplak erişilemez).

### 4. `narration_layer.dart` (338) — part dosyalarında private extension
| Yeni dosya | Satır | İçerik |
|---|---|---|
| `widgets/narration_layer.dart` | 138 | widget, build, anchor matematiği, `_anchorCell/_label/_color` |
| `widgets/narration_layer_flights.dart` | 87 | `_LetterFlights`: `_flights`, `_returningLetters` |
| `widgets/narration_layer_cues.dart` | 134 | `_ScoreCues`: `_pulses`, `_frames`, `_badges` |

### 5. `puzzle.dart` (331) — part dosyaları
| Yeni dosya | Satır | İçerik |
|---|---|---|
| `data/models/puzzle.dart` | 147 | enum'lar, private JSON enum parser'ları, `PuzzleData` |
| `data/models/puzzle_cells.dart` | 97 | `ClueSpec`, `WordCell`, `CellSpec` |
| `data/models/puzzle_words.dart` | 99 | `WordSpec`, `GridSize`, `SafetyInfo` |

Bu üç dosya aynı commit'te 100 sütun formatına da getirildi (eskiden 80
sütun stilindeydi; yalnız whitespace).

### 6. `narration_tiles.dart` (311) — ayrı kütüphane + export
| Yeni dosya | Satır | İçerik |
|---|---|---|
| `widgets/narration_tiles.dart` | 230 | `NarrationSpeedChip`, `CellPulse`, `FlyingTile`, `GhostLetterTile`, `NarrationBadge`; `word_frame.dart`'ı `export` eder |
| `widgets/word_frame.dart` | 91 | `WordFrame` + `_GoldenFramePainter` |

### 7. Renk token'ları
| Yer | Eski | Yeni |
|---|---|---|
| `action_bar.dart:69` | `Color(0xFFE3F2FD)` | `AppColors.circleButtonActiveBg` (yeni) |
| `action_bar.dart:140` | `Color(0xFFFFF8E1)` | `AppColors.revealActiveBg` (yeni) |
| `swap_sheet.dart:129` | `Color(0xFFF5E6C8)` | `AppColors.rackTileBg` (mevcut) |
| `word_frame.dart:80` | `Color(0xFFFFF3C4)` | `AppColors.shimmerHighlight` (yeni) |

Görev "üç literal" diyordu (TODO işaretli üçü); dördüncü opak literal
(`0xFFFFF3C4`, WordFrame shimmer) aynı kuralın kapsamında olduğu için o da
çevrildi. Üç TODO yorumu kaldırıldı.

## Kullanılan teknik: `part` + private extension/mixin

Sınıf metodlarını dosyalara dağıtmanın davranışı değiştirmeyen tek yolu
aynı kütüphanede kalmak: `part 'package:kelime_oyunu/...'` (package URI —
relative import yasağının ruhuna uygun) + `part of 'package:...'`. Böylece
private alanlar private kaldı, hiçbir sembol dışa açılmadı, testler
değişmedi. Part dosyalarında import olmaz; ilk satır dosya-yolu yorumu
korunur. Yeni handler eklerken ilgili part'a ekle; `on<>` kaydı ana dosyada.

## Geri alınan adımlar

Yok. Hiçbir bölme test kırmadı. Tek ara hata: `game_active_body.dart`'tan
`collection` import'u erken silindi (mixin `firstWhereOrNull` kullanıyor);
ilk denemede geri eklendi.

## Bulgular (görüldü, YAPILMADI)

Mantık / davranış:
- **Aynı harften iki pending taş:** `_onTileRecall` pending yerleşimi harfe
  göre ilk eşleşen ile buluyor; `rackIndexForPending` de ilk `isPlaced` aynı
  harfli taşı seçiyor. Rack'te iki "A" ikisi de tahtadayken, dokunulan taşın
  değil ilk eşleşenin yerleşimi geri çağrılabilir. Görsel olarak fark edilmez
  (harf aynı) ama hücre farklı olabilir. Önceden de böyleydi.
- **`_onLetterPlaced` / `isPlaceable` çift kontrol:** bloc ve view aynı
  "harf hücresi mi + dolu mu" kontrolünü ayrı ayrı yapıyor. Yorum bunu
  "defence in depth" diye kasıtlı işaretliyor; bırakıldı.

Yinelenen kod:
- **Hücre boyutu hesabı** (`math.min(maxWidth/cols, maxHeight/rows)` +
  48.0 fallback) `grid_painter.dart` (`_fallbackCell` const) ve
  `narration_layer.dart` (çıplak `48.0`) içinde kopya. Ortak bir helper
  (`gridCellSize(constraints, grid)`) iki katmanın hizasını tek yerden
  garanti eder.
- `GridStaticPainter` ve `GridDynamicPainter` ayrı ayrı
  `static const ClueRenderer _clueRenderer` tutuyor.
- Ortalanmış harf çizimi: `GridStaticPainter._paintCenteredLetter` ile
  `GridDynamicPainter` içindeki pending-taş `TextPainter` bloğu aynı işi
  yapıyor.
- `game_dialogs.dart`'taki iki onay dialog'u (reveal / sixth slot) aynı
  Hayır/Evet iskeletini paylaşıyor; ortak `_confirmDialog(title, content)`
  olabilir.

Ölü kod:
- `AppColors.gridCellSelected` ve `AppColors.star` hiçbir yerde
  kullanılmıyor.

Standart ihlalleri (önceden var, kapsam dışı):
- Kalan raw renkler opak değil, alpha-only: gölge renkleri
  `Color(0x40000000)` (narration_tiles ×2), `Color(0x4D000000)` ve
  `Color(0x26000000)` (rack_widget), `Color(0x00FFFFFF)` gradient durakları
  (word_frame ×3). Token (`AppColors.shadow*`) veya
  `Colors.black.withValues(alpha:)` adayı. Dokunulmadı: görev opak
  literal'leri hedefliyordu.
- Kullanıcıya görünür Türkçe string'ler kodda: `game_dialogs.dart` (reveal
  ve +1 harf dialog metinleri, "Hayır"/"Evet"), `game_screen.dart`
  `_kBotProfile.description`. `.arb` kuralı (coding-standards §7).
- `TODO` formatı `TODO(ad): ... #issue` değil: `main.dart:9`,
  `game_active_interaction.dart:88,101`.
- `dart format --line-length 100` şu dosyaları değiştirmek istiyor (bu
  oturumda dokunulmadı): `lib/data/repositories/puzzle_repository.dart`,
  `test/data/puzzle_parse_test.dart`, `test/helpers/engine_test_fixtures.dart`.
  Pre-commit hook yok.

Test kapsamı:
- Hiçbir test `GameScreen` ya da `GameActiveBody`'yi pump etmiyor;
  `game_screen_test.dart` state→UI eşlemesini kendi private
  `_GameStateRenderer`'ıyla taklit ediyor. Ekran bölmesi bu yüzden yalnız
  analyze + dolaylı testlerle doğrulandı; emülatörde bir tur oynayıp
  reveal/swap/+1 dialog'larını ve sonuç dialog'unu görmek iyi olur.

## Sonraki adım için kontrol listesi

1. Emülatörde bir bölüm: tap yerleştirme, drag, pending taşı sürükleme,
   reveal dialog'u, swap sheet, +1 harf, sonuç dialog'u (Tekrar / Sonraki /
   Bölümler).
2. Bulgulardaki "ölü kod" ve "yinelenen kod" maddeleri küçük ve güvenli;
   ayrı bir cilalama commit'i olabilir.
3. `.arb` taşıması ve gölge token'ları için ayrı görev.
