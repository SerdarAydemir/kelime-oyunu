# F7 — İlerleme Kalıcılığı + Yarım Maç Resume + Level-Select

Durum: plan (bu doküman) → 4 fazda uygulanır. Referans: `architecture.md §11`, `CLAUDE.md`.

## 1. Teşhis — bugün ne oluyor?

| Sorun | Kaynak |
|---|---|
| Her açılışta `/gameplay/1` | `app_router.dart` → `_QuickStartScreen` post-frame `context.go('/gameplay/1')` |
| Kazanılan bölüm unutuluyor | Hiçbir yerde yazılmıyor. `result_dialog.onNext` → `router.go('/gameplay/${id+1}')`, ilerleme yalnız o anki navigasyonda yaşıyor |
| Yarım maç kayboluyor | `GameBloc` tamamen bellekte; `PuzzleLoadRequested` her zaman sıfır tahta + sıfır skor kuruyor |
| Hive hiç kurulmamış | `pubspec` içinde `hive`/`hive_flutter`/`flutter_secure_storage` var ama `main.dart` yalnız `runApp`. `lib/data/sources/` klasörü yok |

Elimizdeki sağlam zemin: `allowBackup="false"` zaten set; `kLastLevelId = 200` zaten var; sert ilerleme kuralı `ResultDialog._canAdvance` içinde (`status == won && !isLastLevel`) — F7 bunu **değiştirmez**, yalnız diske yazar.

## 2. Mimari kararlar (ve gerekçeleri)

### K1 — İlerleme modeli: tek `int highestCompletedLevel`
Tamamlananlar set'i **değil**. Gerekçe: ilerleme kuralı zaten katı-doğrusal (yalnız kazanan bir sonrakine geçer), dolayısıyla set her zaman `1..N` aralığının kendisi olurdu — set tutmak aynı bilgiyi 200 kat pahalıya saklamak olur. Kilit kuralı tek satır: `unlocked(id) ⇔ id <= highestCompletedLevel + 1`. Varsayılan `0` → yalnız Bölüm 1 açık.
Not: ileride yıldız/rozet gibi bölüm-başı veri gerekirse, box zaten map tabanlı olduğu için `level_meta` anahtarı eklenerek genişletilebilir; şema versiyonu bunun için var.

### K2 — Şifreleme anahtarı: `flutter_secure_storage`'da üretilen 256-bit AES anahtarı
`Hive.generateSecureKey()` ilk açılışta üretilir, base64 olarak `flutter_secure_storage`'a (`hive_aes_key`) yazılır, sonraki açılışlarda okunur. `SecureHive.cipher()` (`architecture.md §11.1`, v3 deseni). Anahtar cihazın Keystore/Keychain'inde durur, koda gömülmez.
**Kritik ayrıntı:** `allowBackup="false"` zorunlu, çünkü Android auto-backup Hive dosyasını geri yükleyip Keystore anahtarını yüklemez → reinstall'da çözülemeyen box → çökme. Manifest'te zaten set, doğrulandı.
**Fallback:** secure storage okunamazsa (nadir OEM hatası) → `SecureStorageException` yerine sessizce yeni anahtar üretmek eski veriyi *okunamaz* kılar. Karar: anahtar okunamaz/box açılamazsa box **silinip sıfırdan açılır** (`_openOrRecreate`). İlerleme kaybı kötü ama açılışta sonsuz çökme çok daha kötü; ilerleme kritik olmayan yerel veridir (para değil).

### K3 — Hive TypeAdapter YOK; JSON string saklanır
`build_runner` + adapter kaydı + şema göçü maliyetine karşılık kazanç sıfır. Box'lar `Box<String>`, değerler `jsonEncode(...)`. Serileştirme mantığı saf Dart codec dosyasında (`session_codec.dart`) → **Hive'sız round-trip testi** mümkün. Her kayıtta `schema_version` alanı; okurken uyuşmazsa kayıt atılır (null döner → temiz başlangıç).

### K4 — Puzzle resume kaydına GİRMEZ
`PuzzleData` ~30KB immutable asset. Kayda yalnız `puzzleId` yazılır; resume'da puzzle asset'ten yeniden yüklenir. Kayıt küçük, asset ile kayıt arasında tutarsızlık riski yok.

### K5 — Ne kaydedilir / ne kaydedilmez
Kaydedilen: `schemaVersion`, `puzzleId`, `board` (`[{row,col,letter}]`), `rack` (yalnız harfler), `playerScore`, `botScore`, `rackSize`, `revealedWordIds`, `swapQuotaRemaining`, `botPlacedCells`.
Kaydedilmeyen ve gerekçesi:
- `pendingPlacements` → onaylanmamış hamle; tur sınırında zaten boş.
- `narration` (F6) → **görev sınırı**: resume anlatı bittikten sonraki temiz state'ten devam eder. Yarım anlatı saklanmaz.
- `phase` / `botThinking` / `selectedRackIndex` → resume her zaman `playerTurn`, `botThinking: false`, `selectedRackIndex: -1`.
- `status` → yalnız `playing` iken kaydedilir; biten maçın kaydı silinir.
- `RackTile.isPlaced` / `isReturned` → geçici tur içi bayraklar.

### K6 — Flush noktası: **tur sınırı**, debounce YOK
`architecture.md §11.2` bu iki box için debounce'u açıkça yasaklıyor (save-scumming). Kural: `GameActive` yayınlandığında `phase == playerTurn && status == playing` ise **anında** yaz. Bu; bot hamlesi sonrası, reveal sonrası, +1 slot sonrası, reklamlı swap sonrası noktalarını kapsar — yani her zaman "oyuncunun sırası başlıyor" anlık görüntüsü diskte durur. Ayrıca `AppLifecycleListener` (pause/detach) ile garanti flush.
**Dürüst güvenlik notu:** bot düşünürken force-kill → kayıt oyuncunun hamlesinden öncesine sarar. Oyuncu kötü bir hamleyi böyle geri alabilir (save-scum). Karşı seçenek (bot sırasını da kaydedip resume'da botu yeniden oynatmak) çok daha karmaşık ve oyuncuya botun sırasını *atlatma* riski taşıyor — ki bu daha kötü bir istismar. `architecture.md §11.2`'nin kendi notu da (%100 engellenemez) bu tercihi destekliyor. Tur sınırı modeli seçildi.

### K7 — Bağımlılık enjeksiyonu: `GameBloc`'a opsiyonel repo'lar
`GameBloc({ProgressRepository? , SessionRepository?})` — varsayılan `InMemory*Repository()`. Gerekçe: 118 mevcut test tek satır değişmeden geçer ve her test kendi izole belleğini alır; gerçek uygulama `main()`'de Hive destekli impl'i geçer. `get_it` servis lokatörü F7 için gereksiz — yalnız iki singleton var ve `main()` → `app.dart` → router zinciri onları taşıyabilir.
Router artık statik `final` olamaz (repo'lara ihtiyacı var) → `AppRouter.build({required repos})` fabrikası.

### K8 — Level-select durumu: `Cubit`
`CLAUDE.md §Durum yönetimi`: gameplay dışı her şey Cubit. `LevelSelectCubit` → `highestCompletedLevel` + `ResumeSummary?` yükler.

### K9 — Metinler kodda Türkçe (hardcode) kalır
Projede hiç `.arb` yok; her ekran (`game_screen`, `result_dialog`) Türkçe string'i gömülü tutuyor. F7 yeni bir yerelleştirme altyapısı **kurmaz** — mevcut konvansiyona uyar. `.arb` göçü ayrı bir görev (tüm ekranları birden kapsamalı).

## 3. Dosya planı (faz başına ≤ 3 kaynak dosya)

**Faz 1 — Hive kurulumu + ilerleme kalıcılığı**
- `lib/data/sources/secure_hive.dart` (yeni) — anahtar üretimi/okuma, `cipher()`, `openEncryptedBox()`, hasarlı box kurtarma.
- `lib/data/repositories/progress_repository.dart` (yeni) — `ProgressRepository` arayüzü + `HiveProgressRepository` + `InMemoryProgressRepository`. `highestCompletedLevel`, `recordWin(levelId)` (`kLastLevelId` ile sınırlı, geriye gitmez), `isUnlocked(id)`.
- `lib/main.dart` (değişir) — `SecureHive.init()`, box'ları aç, repo'ları kur, `KelimeOyunuApp(...)`'e geçir.
- Yan dosyalar: `app.dart` + `app_router.dart` repo parametresi (fabrika), `game_bloc.dart` kazanınca `recordWin`.

**Faz 2 — Resume serileştirme + lifecycle flush**
- `lib/features/gameplay/bloc/session_codec.dart` (yeni) — saf `GameActive ⇄ Map<String,dynamic>` codec + `ResumeSummary`.
- `lib/data/repositories/session_repository.dart` (yeni) — `SessionRepository` arayüzü + Hive/InMemory impl (`save`, `load`, `clear`, `summary`).
- `game_bloc.dart` (değişir) — `SessionRestoreRequested` event'i, tur-sınırı flush, bitişte `clear`.
- `game_screen.dart` (değişir, +minik) — `AppLifecycleListener` flush.

**Faz 3 — Level-select ekranı + routing**
- `lib/features/levels/cubit/level_select_cubit.dart` + `level_select_state.dart` (yeni)
- `lib/features/levels/view/level_select_screen.dart` (yeni, <300 satır)
- `lib/features/levels/widgets/level_tile.dart` + `resume_banner.dart` (yeni) — `level_select_screen`'i 300'ün altında tutmak için ayrı.
- `app_router.dart` (değişir) — `initialLocation: '/levels'`, `_QuickStartScreen` silinir, `/` → `/levels` redirect.

**Faz 4 — Entegrasyon + cila**
- `result_dialog` → "Bölümler" çıkışı; `game_screen` geri tuşu → `/levels`.
- Testler, `flutter analyze`, dokunulan dosyalarda `dart format --line-length 100`.

## 4. Riskler

| Risk | Önlem |
|---|---|
| `game_screen.dart` (469) / `grid_painter.dart` (533) zaten 300+ | F7 bunlara yalnız birkaç satır ekler; yeni UI ayrı dosyalarda |
| Hive test ortamında path_provider ister | Testlerde `Hive.init(tempDir)` + şifresiz box; codec testi Hive'sız |
| 200 bölümlük grid'in performansı | `GridView.builder` (lazy), hücre başına widget maliyeti kabul (grid ekranı, oyun tahtası değil — ADR-0004 CustomPainter kuralı oyun tahtası içindir) |
| Emülatör bu ortamda boot etmiyor | Widget + unit testle doğrula (memory: emulator-wont-boot) |
| `dart format lib/` ilgisiz dosyaları reflow'lar | Yalnız dokunulan dosyalar formatlanır (memory: dart-format-scope) |

## 5. Kapsam dışı (bilerek)
Python/içerik hattı, puanlama/oynanış kuralları, F6 anlatı sistemi, görsel ipuçları, `.arb` göçü, `git push`.
