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

**Durum yönetimi:** Gameplay → `Bloc` (event-driven). Diğer her şey → `Cubit`. (`skills.md §3`, `architecture.md §3`)

---

## Klasör ve Kod Kuralları

- **Feature-First yapı:** `lib/features/gameplay/`, `lib/features/wallet/` vb. (`architecture.md §1`)
- **Katman sırası:** View → Bloc/Cubit → Service → Repository → Data. Ters yön yasak. (`architecture.md §2`)
- **Tek dosya max 300 satır.** Aşıyorsa modülarize et. (`skills.md §9`)
- **Tek seferde max 3 dosya üret.** Fazlası için "devam edeyim mi?" sor. (`skills.md §9`)
- **Her dosyanın ilk satırı dosya yolu yorumu:** `// lib/features/gameplay/bloc/gameplay_bloc.dart` (`coding-standards.md §1.4`)
- **`package:` import zorunlu, relative import yasak.** (`coding-standards.md §1.5`)
- **`debugPrint` kullan, `print` yasak.** (`skills.md §11`)

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
- Post-fill küfür taraması zorunlu (`post_fill_safety.py`). `safety.post_fill_scanned = true` olmayan puzzle dosyaya yazılmaz. (`architecture.md §7.3`)
- Hatalı puzzle: `SafetyGenerationError` fırlat, `sys.exit(1)` ile çık. Sessiz başarı yasak. (`coding-standards.md §8.7`)
- Türkçe büyük/küçük harf: `tr_upper()` / `tr_lower()` helper'larını kullan, `str.upper()` değil. (`architecture.md §7.6`)
- Her puzzle `pydantic` ile validate edilir + Flutter parse testi (CI). (`coding-standards.md §8.6`)
- Windows konsolunda Türkçe karakter için: `_force_utf8_stdout()` fonksiyonuna koy,
  yalnızca `main()` / CLI giriş noktasından çağır.
  Import edilebilen modüllerin tepesine asla koyma — pytest capture'ını bozar.

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

**Flutter:**
- F1: Data layer (PuzzleData, repository) ✅
- F2: Engines (ScoreEngine, RackManager, BotEngine) ✅
- F3: GameBloc ✅
- F4: GridPainter + GameScreen ✅ — fit-to-screen grid, ipucu render
  (tam metin auto-fit, kenar okları, çift-ipucu okunabilirliği, dokun-oku)
- Oyun sonu ekranı + sert ilerleme (kaybedince tekrar) ✅
- Joker akışı ✅ — harf açma (reveal), harf değiştirme (kota + çift ödeme),
  +1 harf slotu (mock reklam kapısı)
- Talep-bilinçli rack ✅ — hedef hücresi olmayan taş verilmez, ölü taş
  yenileme, oyun sonu rack küçülmesi
- F7: kalıcılık + resume + level-select ✅ — şifreli Hive (`progress`,
  `active_session`), tur-sınırı flush + lifecycle flush, `/levels` giriş
  ekranı. Kararlar ve save-scum ödünleşimi: `docs/F7_PLAN.md`.