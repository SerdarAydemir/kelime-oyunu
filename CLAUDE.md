# CLAUDE.md — Kelime Oyunu Projesi

## Rol
Flutter 3.x / Dart 3.x + Python 3.11+ ile Türkçe Kelime Bulmaca oyunu geliştiren kıdemli geliştirici.
Hedef pazar: Türkiye (TR-tr). Hedef kitle: 25–55 yaş casual oyunseverler.

---

## KOD YAZMADAN ÖNCE ONAY İSTE

Her yeni görev geldiğinde şu sırayı bozmadan uygula:

1. **PLANLA** — Hangi dosyalar değişecek, bağımlılıklar, riskler. **Listeyi sun, onay bekle.**
2. **MOCK** — Servis gerektiren işlerde önce sahte servis (`MockXService`).
3. **BLOC/CUBIT** — İş mantığı + unit test.
4. **UI** — Widget + BlocBuilder/Listener bağlantısı.
5. **ENTEGRE** — Gerçek SDK (AdMob, RevenueCat).

> "Devam et" demediğim sürece adım 1'den ileri geçme. (`skills.md §8`)

---

## Geliştirme Önceliği

1. **Önce Python puzzle generator** (`tools/puzzle_generator/`) — Flutter'a tek satır yazmadan önce 200 geçerli JSON puzzle üretilmeli.
2. **Sonra Flutter** — mock servislerle; akış onaylandıktan sonra gerçek SDK.

(`skills.md §1`)

---

## Teknoloji Kısıtları

**Yasak paketler:** `flame`, `provider`, `getx`, `sqflite`, `mockito`, `auto_route`, `in_app_purchase`

**Yeni paket eklemeden önce gerekçe sun, onay bekle.** (`skills.md §2`)

**Android build:** AGP 9 + built-in Kotlin (`android.builtInKotlin=true`);
`app/build.gradle.kts` `kotlin-android` uygulamaz.

**Durum yönetimi:** Gameplay → `Bloc` (event-driven). Diğer her şey → `Cubit`. (`skills.md §3`, `architecture.md §3`)

**Bağımlılık enjeksiyonu:** constructor injection (`AppRouter.build({required repos})`,
`GameBloc({repos?})`). `get_it` pubspec'te yok; gerçekten gerekirse gerekçeyle eklenir.

---

## Klasör ve Kod Kuralları

- **Feature-First yapı:** `lib/features/gameplay/`, `lib/features/wallet/` vb. (`architecture.md §1`)
- **Katman sırası:** View → Bloc/Cubit → Service → Repository → Data. Ters yön yasak. (`architecture.md §2`)
- **Tek dosya max 300 satır.** Aşıyorsa modülarize et. (`skills.md §9`)
- **Tek seferde max 3 dosya üret.** Fazlası için "devam edeyim mi?" sor. (`skills.md §9`)
- **Her dosyanın ilk satırı dosya yolu yorumu:** `// lib/features/gameplay/bloc/gameplay_bloc.dart` (`coding-standards.md §1.4`)
- **`package:` import zorunlu, relative import yasak.** (`coding-standards.md §1.5`)
- **`debugPrint` kullan, `print` yasak.** (`skills.md §11`)
- **Büyük sınıfı bölerken:** `part 'package:kelime_oyunu/...'` + aynı kütüphanede
  private extension/mixin (örn. `game_bloc_turn.dart`, `game_active_interaction.dart`);
  sembol dışa açılmaz, testler değişmez. Part dosyasında import olmaz, ilk satır
  yine dosya-yolu yorumu. Bağımsız widget/painter ise ayrı kütüphane + eski
  dosyadan `export` (`grid_painter.dart`, `narration_tiles.dart`). (`docs/HANDOFF_REFACTOR.md`)

---

## Dart Kod Stili

- `dart analyze` 0 hata, `dart format --line-length 100` uygulanmış olmalı. (`coding-standards.md §1.1`)
- Null safety: `!` bang operator istisnai; tercih `Result<T,E>` sealed class. (`coding-standards.md §1.8`)
- Widget constructor'ları `const`; field'lar `final`. (`coding-standards.md §1.9`)
- `_buildX()` helper fonksiyonu yasak; private class (`_WidgetName`) yaz. (`coding-standards.md §2.2`)
- Renk: `AppColors.primary` veya `Theme.of(context).colorScheme.x` — raw `Color(0xFF...)` literal yasak. (`architecture.md §9`)
- Kullanıcıya görünür string: `.arb` dosyasında, hardcode yasak. (`coding-standards.md §7`)
- Kod yorumu: **İngilizce**. (`coding-standards.md §1.6`)

---

## Grid Performans Kuralları (Flame yok — ADR-0004)

- Grid: `CustomPainter` + tek `GestureDetector`. Hücre başına widget yok.
- **İki katmanlı painter:** Statik (grid/harfler) + animasyonlu (seçim/parıltı) ayrı.
- `shouldRepaint` doğru implement edilmeli; gereksiz `true` dönme. (`coding-standards.md §5.1`)
- Animasyon: `AnimationController` + `TweenSequence`. Idle durumda 0 repaint hedefi.

---

## Güvenlik ve Veri

- **Şifreli Hive box'lar:** `coin_wallet`, `iap_state`, `ad_state` → AES. (`architecture.md §5.1`)
- AES anahtarı: `flutter_secure_storage` → `SecureHive.cipher()`. (`architecture.md §5.4`)
- **`allowBackup="false"`** AndroidManifest'te zorunlu — aksi hâlde reinstall çökmesi. Flutter projesi oluşturulduğunda ilk iş AndroidManifest'i ayarla. (`architecture.md §5.6`, `coding-standards.md §9.1`)
- API key: `--dart-define` ile; kod içinde hardcode yasak. (`architecture.md §11.1`)
- **Yayın sonrası `flutter_secure_storage` major atlaması yapılmaz;** her major
  sırayla, migrasyon sürümü üzerinden geçilir (9→11 doğrudan atlandığında v9
  verisi taşınmaz, AES anahtarı kaybolur, `openEncryptedBox` box'ı sıfırlar).
  Yayın öncesi 9→11 atlaması bilinçli kabul edildi (2026-09-13).
- Test AdMob ID production build'e sızmaması için `AdUnitIds.assertNoTestIdsInRelease()`. (`architecture.md §11.4`)

---

## Resume (Yarım Kalan Oturum)

- `ActiveLevelState` Hive `active_session` box'a yazılır.
- Her kelime bulunduğunda + 3 saniyelik debounce + `AppLifecycleListener` (onPause/onInactive) flush.
- Bölüm tamamlanınca box temizlenir. (`architecture.md §5.2`, `architecture.md §5.5`)

---

## Monetizasyon Kuralları (Kesin)

- Oyun esnasında interstitial yasak; sadece bölüm sonunda, min 90 sn cap. (`skills.md §6.1`)
- İlk 3 bölüm: hiç reklam yok. ATT prompt: 2. bölüm sonunda. (`skills.md §6.2`)
- Consent (UMP) → reklam SDK başlatılmadan önce. SDK'yı consent öncesi init etme. (`skills.md §11`)
- `AdService` interface ağ-bağımsız tasarlanır; MVP impl: `admob_ad_service.dart`. (`architecture.md §6.1`)

---

## Hata Ayıklama

- Konsol hatası paylaşırsan **tüm kodu baştan yazma.**
- Hatanın nedenini açıkla; sadece değişecek bloğu öncesi/sonrası olarak ver.
- Tek seferde max 3 dosya değiştir.
- **QA kilit açma:** `flutter run --dart-define=DEV_UNLOCK_ALL=true` → level select'te tüm
  bölümler oynanabilir, başlıkta "DEV" rozeti; ilerlemeye yazmaz, kDebugMode ile AND'li
  (`lib/core/config/dev_flags.dart`), release'de etkisiz.

(`skills.md §8 Adım 6`)

---

## Python Puzzle Generator Kuralları

- **Geometri: 9×7 tam-çerçeve (Cross Up standardı).** Satır 0 + sütun 0 ipucu hücresi,
  (0,0) tek BLANK; iç alan tamamen harf + k∈[5,7] iç ipucu. İç alanda blank yok.
- **Mask kütüphanesi:** `mask_synth_frame.py` tüm geçerli mask'leri kapsamlı sayar
  (~416k), `data/cache/frame_masks_9x7.json`'a deterministik cache'ler.
  Mask seçimi seed=puzzle_id; fill başarısızlığında kütüphane sırasında bir
  sonraki mask'e fallback (seed restart yok). Pack içinde mask tekrarı yasak.
- Pipeline adımları (sırasıyla): mask (kütüphaneden) → CSP fill (attempt başına
  node bütçesi) → post-fill güvenlik taraması → clue_writer → pydantic validate → JSON.
- **Cevap-düzeyi dışlama:** `data/raw/sensitive_answers.txt` (elle bakım) +
  `data/processed/rejected_words.json` (audit etiketi) havuza hiç girmez;
  `approved_words.json` audit onay listesi. Bu listeleri onaysız genişletme.
- **P0 placeholder gate (üç katman):** master clue'su olmayan kelime (1) havuza
  alınmaz, (2) generator runtime'da fill'e girse bile atlanır, (3) `pack_report.py`
  `source="placeholder"` tespit ederse pack BAŞARISIZ sayılır. Placeholder clue
  ("N harfli kelime") oynanamaz — asla dosyaya yazılmaz.
- **Üretim sonrası doğrulama:** `pack_report.py` her pack'i diskten bağımsız
  yeniden okur (adet, köşe-blank, mask tekrarsızlığı, placeholder=0, kaynak/k
  dağılımları) ve `reports/generation_report_*.json` yazar.
- **Havuz kaynağı:** `word_pool_cleaned.json` git'te yok; `scripts/rebuild_pool_from_master.py`
  ile `master_clues.json` anahtarlarından türetilir (ham TDK listesi artık gerekmez,
  blacklist uygulanmaz — dışlamalar üretim anında `load_excluded_answers` ile).
- **Havuz kalite kapısı (2026-09-13):** havuz flash-lite (`model="gemini-2.5-flash-lite"`)
  kelime içermez; `rebuild_pool_from_master.py` bunları varsayılan olarak dışlar
  (~8.8k kelime; kuru koşu 200/200, ort. fallback 1.62, maks 48). Flash-lite bir
  kelime ancak Claude re-clue'dan geçince (`source="claude_reclue"`, model alanı
  değişir) havuza girer. `--include-model` yalnız deney içindir.
- **Blacklist zorunlu:** `data/raw/profanity_blacklist.txt` (`scripts/build_blacklist.py` üretir,
  git'te izlenir) yoksa `generate` açıklayıcı hata ile `Exit(1)` — boş set ile sessiz tarama yasak.
- **İpucu uzunluk bütçesi:** çift-ipucu hücresi 49 dp hücrede (360 dp telefon) 9 px fontla
  2 satır × ~10 karakter alır. İpucu bütçesi **20 karakter üst sınır, 16 hedef**; tek kelime
  10 karakteri geçmesin. symbols/two_letter ≤16 test ile zorlanır
  (`test_curated_clue_budget.py`); Flutter tarafı `test/tooling/clue_fit_report_test.dart`
  ile ölçülür (49 dp'de overflow 0 hedefi). UI kelime içinde kırmaz, hece+tire ile böler;
  sığmayanı generator kısaltır, UI zorlamaz.
- Post-fill küfür taraması zorunlu (`post_fill_safety.py`). `safety.post_fill_scanned = true` olmayan puzzle dosyaya yazılmaz. (`architecture.md §7.3`)
- Hatalı puzzle: `SafetyGenerationError` fırlat, `sys.exit(1)` ile çık. Sessiz başarı yasak. (`coding-standards.md §8.7`)
- Türkçe büyük/küçük harf: `tr_upper()` / `tr_lower()` helper'larını kullan, `str.upper()` değil. (`architecture.md §7.6`)
- Her puzzle `pydantic` ile validate edilir + Flutter parse testi (CI). (`coding-standards.md §8.6`)
- `_force_utf8_stdout()`: yalnızca Windows konsolunda gerekliydi; Linux'ta stdout
  zaten UTF-8 olduğundan fiilen no-op. Kalsın ama yalnızca `main()` / CLI giriş
  noktasından çağır. Import edilebilen modüllerin tepesine asla koyma — pytest
  capture'ını bozar.

---

## Tamamlandı Tanımı (DoD)

- [ ] `dart analyze` 0 hata, `dart format` uygulandı
- [ ] Unit test (Bloc/Cubit + service) + widget test eklendi
- [ ] Türkçe karakterler ekranda doğru (ğ, ş, ı, İ)
- [ ] Dark + light mode, telefon + tablet test edildi
- [ ] Performans bütçesi aşılmadı (cold start < 2.5 sn, ≥ 60 fps)
- [ ] `.arb`'a string eklendi, `package:` import kullanıldı
- [ ] Commit mesajı Conventional Commits formatında ve **İngilizce** (başlık + gövde; UI stringleri Türkçe kalır)

(`skills.md §12`, `coding-standards.md §6.2`)

---

## Referans Dosyalar

| Konu | Dosya ve Bölüm |
|---|---|
| Rol, tech stack, geliştirme akışı, monetizasyon | `skills.md` |
| Klasör yapısı, mimari katmanlar, Hive modelleri, JSON şeması | `architecture.md` |
| Dart stili, lint, test şablonları, git/commit, Python standartları | `coding-standards.md` |
| Flame neden çıkarıldı | `docs/adr/0004-no-flame-custompainter.md` |


## Tamamlanan Adımlar

**Python generator:**
- P1-P9: v1 pipeline ✅ (8×6 arşivi `assets/puzzles_v1/`, gitignored)
- 9×7 tam-çerçeve üretim hattı ✅ — `mask_synth_frame` kütüphanesi, mask-sıralı
  fallback, CSP node bütçesi, `pack_report` doğrulaması
- P2a: cevap-düzeyi dışlama ✅ (sensitive + rejected/approved audit dosyaları)
- P0: placeholder gate ✅ (havuz önleme + runtime skip + rapor tespiti)
- Efektif havuz: ~30k master-clue'lu kelime ∖ sensitive ∖ rejected

**İlerleme modeli (ÖNEMLİ — skills.md/architecture.md'deki "günlük" bayat):**
Oyun **günlük eşleşme değil, 200 sıralı bölüm** (Bölüm X / 200). Sert ilerleme:
yalnız kazanınca sonraki bölüm açılır. Bot zorluğu bölüm numarasından türer
(matchmaking feature'ı yok). Grid tek boyut: **9×7 tam-çerçeve** (3-boyut
tasarımı uygulanmadı).

**Flutter:**
- F1: Data layer (PuzzleData, repository) ✅
- F2: Engines (ScoreEngine, RackManager, BotEngine) ✅
- F3: GameBloc ✅
- F4: GridPainter + GameScreen ✅ — fit-to-screen grid, ipucu render
  (tam metin auto-fit, kenar okları, çift-ipucu okunabilirliği, dokun-oku sheet)
- Oyun sonu ekranı + sert ilerleme (kaybedince tekrar) ✅
- Joker akışı ✅ — harf açma (reveal), harf değiştirme (kota + çift ödeme),
  +1 harf slotu (mock reklam kapısı)
- Talep-bilinçli rack ✅ — hedef hücresi olmayan taş verilmez, ölü taş
  yenileme, oyun sonu rack küçülmesi
- F5: Drag & drop ✅ — WYSIWYG yerleştirme (uçan tile görsel merkezine hizalı,
  `feedbackOffset` ile alt-satır ölü bölgesi yok), pending harfi tek hamlede
  başka hücreye taşıma, geçersiz→yerinde kal / grid dışı→rack'e dön. Tap akışı
  korunur; bot turu/reveal/bitiş'te kapalı. `_GameActiveBody` içinde.
- F6: Puan anlatısı + harf uçuşu ✅ — bloc çözülen hamleye `MoveNarration`
  iliştirir (id'li), zamanlama tamamen UI-tarafı `NarrationController`'da
  (bloc'un tur akışı gate'lenmez, mevcut testler korunur). Oyuncu harfleri
  yerinde değerlendirilir (uçmaz), bot harfleri avatardan uçar; skora uçan
  rozetler + sayarak artan sayaç; kelime tamamlama altın çerçeve/ışıltı + tek
  "+N"; yanlış harf hücreden rack'e uçarak döner; refill bot cevabına ertelenir;
  ekrana dokun = 2× (iptal değil). `narration_*.dart` dosyaları.
- F7: kalıcılık + resume + level-select ✅ — şifreli Hive (`progress`,
  `active_session`), tur-sınırı flush + lifecycle flush, `/levels` giriş
  ekranı. Emülatörde soğuk-başlat (süreç öldür → box sağ çıkıyor) doğrulandı.
  Kararlar ve save-scum ödünleşimi: `docs/F7_PLAN.md`.
- Bağımlılık yükseltmesi (2026-09-13) ✅ — secure_storage 11, go_router 18,
  firebase core-4 hattı, google_mobile_ads 9, built-in Kotlin, Impeller opt-out
  kaldırıldı; Java 8 uyarısı kapandı, KGP uyarısı Flutter tarafında yanlış
  pozitif (`docs/HANDOFF_DEPS.md`).
- Bot rezervasyon kotası ✅ — `computeMove` harf-başına rezerv kotası + stalemate
  guard: oyuncunun elindeki harflerin multiset sayımı kadar hücre bot'a kapalı,
  böylece oyuncunun oynayabileceği taş bot tarafından kapılmaz; hiçbir hamle
  kalmazsa guard kilitlenmeyi önler. (d2e6cf0, 818ded6, a42ba5f)
- FAZ 4 teknik borç (2026-09-16) ✅ — 300 satırı aşan 6 dosya sorumluluğa göre
  bölündü (grid painter'lar, game screen gövde/etkileşim/dialog, bloc handler
  part'ları, narration layer/tiles, puzzle modelleri); opak raw renk literal'leri
  token'landı. Davranış değişmedi, 187 test yeşil, `lib/` altında 300 üstü dosya 0.
  Dosya haritası + yapılmayan bulgular: `docs/HANDOFF_REFACTOR.md`.

**Sıradaki (planlı, yapılmadı):**
- FAZ 4 artıkları (`docs/HANDOFF_REFACTOR.md` "Bulgular"): alpha-only gölge
  renkleri token'a, dialog/bot-profil string'leri `.arb`'a, kullanılmayan
  `AppColors.gridCellSelected`/`star`, hücre-boyutu hesabının ortaklaştırılması,
  `GameScreen`/`GameActiveBody` için gerçek widget testi.
- **P1 re-clue** — ~2k kelimenin flash-lite clue'ları elden geçmeli; teşhiste
  %15+ hatalı/zorlama (İDAME="ölüme mahkum", KERİME, MET, KAK gibi aktif
  yanlışlar). ≤20kr bütçe + aile-uygunluk kriteri. Detay memory'de.
- Ses/haptik cilası; gerçek SDK (AdMob/RevenueCat) entegrasyonu.
- Impeller altında GridPainter'ın emülatörde gözle doğrulanması
  (`docs/HANDOFF_DEPS.md` kontrol listesi) — opt-out kaldırıldı, henüz
  emülatörde görülmedi.
