# Mimari Dökümanı (architecture.md)

> **Sürüm 3.0** — Bu dosya nedir? Projenin teknik mimarisi, klasör yapısı, veri modelleri ve sözleşmeleri (contract) tanımlar. `skills.md` "ne yapılacağını", bu dosya "nasıl yapılacağını" belirler.

---

## 1. Klasör Yapısı (Feature-First)

```
kelime_oyunu/
├── android/
├── ios/
├── assets/
│   ├── fonts/
│   │   ├── Inter-Regular.ttf
│   │   ├── Inter-Bold.ttf
│   │   └── Nunito-Bold.ttf
│   ├── images/
│   │   ├── icons/
│   │   ├── illustrations/
│   │   └── backgrounds/
│   ├── audio/
│   │   ├── sfx/                  # tap, success, error, level_complete
│   │   └── music/                # menu_loop, gameplay_loop (opsiyonel)
│   ├── levels/
│   │   ├── pack_001_baslangic.json
│   │   ├── pack_002_kolay.json
│   │   └── manifest.json         # tüm packlerin listesi
│   └── data/
│       └── word_frequency_tr.json  # dolgu harfler + difficulty_score için
├── lib/
│   ├── main.dart
│   ├── app.dart                  # MaterialApp + Bloc/Cubit Providers
│   ├── core/
│   │   ├── constants/
│   │   │   ├── app_colors.dart
│   │   │   ├── app_typography.dart
│   │   │   ├── app_dimensions.dart
│   │   │   ├── ad_unit_ids.dart       # --dart-define + test-ID assert
│   │   │   ├── legal_urls.dart
│   │   │   └── turkish_alphabet.dart  # collation + frekans
│   │   ├── theme/
│   │   │   ├── app_theme.dart
│   │   │   ├── light_theme.dart
│   │   │   └── dark_theme.dart
│   │   ├── storage/
│   │   │   └── secure_hive.dart       # AES key + şifreli box açma
│   │   ├── utils/
│   │   │   ├── turkish_locale.dart    # toUpperCase(tr), compare
│   │   │   ├── result.dart            # Result<T, E> sealed class
│   │   │   └── logger.dart            # debugPrint wrapper
│   │   ├── errors/
│   │   │   └── app_exception.dart     # sealed exception hierarchy
│   │   ├── router/
│   │   │   └── app_router.dart        # go_router
│   │   └── di/
│   │       └── service_locator.dart   # get_it
│   ├── features/
│   │   ├── splash/
│   │   ├── consent/                   # KVKK + UMP + ATT
│   │   ├── menu/                      # cubit
│   │   ├── gameplay/                  # bloc (tutorial overlay buraya gömülü)
│   │   │   ├── bloc/
│   │   │   │   ├── gameplay_bloc.dart
│   │   │   │   ├── gameplay_event.dart
│   │   │   │   └── gameplay_state.dart
│   │   │   ├── models/
│   │   │   │   ├── level.dart
│   │   │   │   ├── grid_cell.dart
│   │   │   │   ├── word_placement.dart
│   │   │   │   ├── active_level_state.dart   # resume için
│   │   │   │   └── hint_type.dart
│   │   │   ├── services/
│   │   │   │   ├── level_loader_service.dart
│   │   │   │   ├── word_validator_service.dart
│   │   │   │   └── hint_service.dart
│   │   │   ├── views/
│   │   │   │   ├── gameplay_screen.dart
│   │   │   │   ├── grid_painter.dart        # CustomPainter
│   │   │   │   ├── tutorial_overlay.dart    # in-context tutorial
│   │   │   │   ├── word_list_widget.dart
│   │   │   │   └── hint_panel_widget.dart
│   │   │   └── widgets/
│   │   ├── progress/                  # cubit
│   │   │   ├── cubit/
│   │   │   ├── models/
│   │   │   │   └── user_progress.dart
│   │   │   ├── services/
│   │   │   │   └── progress_repository.dart  # Hive
│   │   │   └── views/
│   │   ├── wallet/                    # cubit
│   │   │   ├── cubit/
│   │   │   ├── models/
│   │   │   │   └── coin_wallet.dart
│   │   │   └── services/
│   │   ├── monetization/              # cubit
│   │   │   ├── cubit/
│   │   │   ├── services/
│   │   │   │   ├── ad_service.dart           # interface (ağ-bağımsız)
│   │   │   │   ├── mock_ad_service.dart
│   │   │   │   ├── admob_ad_service.dart     # MVP impl (AppLovin v1.1+)
│   │   │   │   ├── iap_service.dart          # interface
│   │   │   │   ├── mock_iap_service.dart
│   │   │   │   └── revenuecat_iap_service.dart
│   │   │   └── views/
│   │   │       └── shop_screen.dart
│   │   ├── settings/                  # cubit
│   │   └── daily/                     # v1.1 günlük puzzle
│   ├── l10n/
│   │   ├── app_tr.arb
│   │   ├── app_en.arb
│   │   └── l10n.yaml
│   └── generated/                     # .gitignore'da
├── test/
│   ├── fixtures/
│   │   ├── sample_level_easy.json
│   │   └── sample_level_hard.json
│   ├── features/
│   │   ├── gameplay/
│   │   │   ├── gameplay_bloc_test.dart
│   │   │   └── word_validator_service_test.dart
│   │   └── monetization/
│   └── helpers/
│       └── pump_app.dart
├── integration_test/
│   └── happy_path_test.dart
├── tools/
│   └── level_generator/                      # Python projesi (ÖNCE BU)
│       ├── pyproject.toml
│       ├── README.md
│       ├── src/
│       │   └── kelime_gen/
│       │       ├── __init__.py
│       │       ├── __main__.py               # typer CLI
│       │       ├── schema.py                 # pydantic models
│       │       ├── word_pool.py              # TDK temizleme + frekans
│       │       ├── difficulty.py             # difficulty_score hesabı
│       │       ├── word_search_generator.py  # backtracking
│       │       ├── csp_solver.py             # crossword (opsiyonel/ileri)
│       │       ├── hint_writer.py            # özgün ipucu üretimi
│       │       └── validators/
│       │           ├── schema_validator.py
│       │           └── post_fill_safety.py   # KÜFÜR TARAMA (kritik)
│       ├── data/
│       │   ├── raw/
│       │   │   ├── tdk_words.txt             # CanNuhlar repo
│       │   │   └── profanity_blacklist.txt   # ooguz repo
│       │   └── processed/
│       │       └── word_pool_cleaned.json
│       └── tests/
├── docs/
│   └── adr/
│       ├── 0001-flutter-over-react-native.md
│       ├── 0002-bloc-cubit-hybrid.md
│       ├── 0003-hive-over-sqflite.md
│       └── 0004-no-flame-custompainter.md
├── pubspec.yaml
├── analysis_options.yaml
├── .gitignore
├── README.md
├── CHANGELOG.md
├── skills.md
├── architecture.md
└── coding-standards.md
```

---

## 2. Katman Mimarisi

```
┌─────────────────────────────────────────────┐
│  Views (Widget)                             │
│  - Sadece UI, BlocBuilder/Listener          │
└─────────────┬───────────────────────────────┘
              │ Event ↓     ↑ State
┌─────────────▼───────────────────────────────┐
│  Bloc (gameplay) / Cubit (diğer)            │
│  - İş mantığı, Service çağrıları             │
└─────────────┬───────────────────────────────┘
┌─────────────▼───────────────────────────────┐
│  Services (interface)                       │
│  - İş kuralları, Mock + Real implementasyon  │
└─────────────┬───────────────────────────────┘
┌─────────────▼───────────────────────────────┐
│  Repositories                               │
│  - Hive (AES), SharedPreferences, asset      │
└─────────────┬───────────────────────────────┘
┌─────────────▼───────────────────────────────┐
│  Data Sources                               │
│  - JSON files, Firebase, AdMob SDK          │
└─────────────────────────────────────────────┘
```

**Kural:** Alt katman üstünü tanımaz. UI → Bloc/Cubit → Service → Repo → Data. Ters yön yasak.

**DI:** `get_it` ile service locator. Bloc/Cubit'ler `BlocProvider` ile sağlanır; servisler `getIt<AdService>()` ile alınır.

---

## 3. Bloc / Cubit Tasarım Şablonu

### 3.1 Gameplay = Bloc (event-driven)
```dart
// lib/features/gameplay/bloc/gameplay_event.dart
sealed class GameplayEvent {}

class GameplayLevelLoaded extends GameplayEvent {
  final int levelId;
  GameplayLevelLoaded(this.levelId);
}

class GameplayCellTapped extends GameplayEvent {
  final int row;
  final int col;
  GameplayCellTapped(this.row, this.col);
}

class GameplayWordSubmitted extends GameplayEvent {}

class GameplayHintRequested extends GameplayEvent {
  final HintType type;
  GameplayHintRequested(this.type);
}

// Resume: uygulama arka plandan dönünce kaydedilmiş oturum yüklenir
class GameplaySessionRestored extends GameplayEvent {
  final ActiveLevelState saved;
  GameplaySessionRestored(this.saved);
}
```

```dart
// lib/features/gameplay/bloc/gameplay_state.dart
sealed class GameplayState {
  const GameplayState();
}

class GameplayInitial extends GameplayState {
  const GameplayInitial();
}

class GameplayLoading extends GameplayState {
  const GameplayLoading();
}

class GameplayActive extends GameplayState {
  final Level level;
  final List<List<GridCell>> grid;
  final Set<String> foundWords;
  final List<GridCell> currentSelection;
  final int coinsEarned;
  final int hintsUsed;
  final Duration elapsed;
  final bool isTutorial;
  final int tutorialStep;

  const GameplayActive({
    required this.level,
    required this.grid,
    required this.foundWords,
    required this.currentSelection,
    required this.coinsEarned,
    required this.hintsUsed,
    required this.elapsed,
    this.isTutorial = false,
    this.tutorialStep = 0,
  });

  GameplayActive copyWith({/* ... */});
}

class GameplayCompleted extends GameplayState {
  final int totalCoins;
  final int stars;
  final Duration totalTime;
  const GameplayCompleted({
    required this.totalCoins,
    required this.stars,
    required this.totalTime,
  });
}

class GameplayError extends GameplayState {
  final String message;
  const GameplayError(this.message);
}
```

### 3.2 Diğer Ekranlar = Cubit (basit state)
```dart
// lib/features/wallet/cubit/wallet_cubit.dart
class WalletCubit extends Cubit<WalletState> {
  WalletCubit(this._repo) : super(const WalletState(balance: 0));
  final WalletRepository _repo;

  Future<void> load() async {
    final balance = await _repo.readBalance();
    emit(WalletState(balance: balance));
  }

  Future<bool> spend(int amount, {required String reason}) async {
    if (state.balance < amount) return false;
    final newBalance = state.balance - amount;
    await _repo.writeBalance(newBalance);
    emit(WalletState(balance: newBalance));
    return true;
  }

  Future<void> earn(int amount, {required String source}) async {
    final newBalance = state.balance + amount;
    await _repo.writeBalance(newBalance);
    emit(WalletState(balance: newBalance));
  }
}
```

**Kural:** State'ler sealed class (Dart 3+). `freezed` opsiyonel (paket eklemeden önce sor).

---

## 4. Level JSON Şeması

Python tarafının üreteceği ve Flutter tarafının tüketeceği **kontrat**.

### 4.1 Şema
```json
{
  "$schema": "https://kelime-oyunu.app/schemas/level/v1.json",
  "schema_version": 1,
  "level_id": 42,
  "pack_id": "pack_002_hayvanlar",
  "difficulty": "easy",
  "difficulty_score": 34,
  "category": "hayvanlar",
  "category_display_tr": "Hayvanlar",
  "grid_size": { "rows": 8, "cols": 8 },
  "grid": [
    ["K", "E", "D", "İ", "A", "R", "N", "L"],
    ["B", "T", "K", "U", "Ş", "M", "E", "İ"]
  ],
  "words": [
    {
      "word": "KEDİ",
      "start": { "row": 0, "col": 0 },
      "direction": "horizontal",
      "length": 4,
      "frequency_score": 88,
      "hint_tr": "Miyavlayan ev hayvanı"
    },
    {
      "word": "KUŞ",
      "start": { "row": 1, "col": 2 },
      "direction": "horizontal",
      "length": 3,
      "frequency_score": 75,
      "hint_tr": "Uçan canlı"
    }
  ],
  "bonus_words": ["EK", "EL"],
  "rewards": {
    "coins_base": 50,
    "coins_perfect": 100,
    "stars_threshold_seconds": [60, 120, 180]
  },
  "safety": {
    "post_fill_scanned": true,
    "scanner_version": "1.0.0"
  },
  "generated_at": "2026-05-15T10:30:00Z",
  "generator_version": "1.2.0"
}
```

### 4.2 Alan Açıklamaları
| Alan | Tip | Zorunlu | Açıklama |
|---|---|---|---|
| `schema_version` | int | ✅ | Şu an `1`. Major değişiklik → migration kodu. |
| `level_id` | int | ✅ | Global benzersiz, 1'den başlar. |
| `pack_id` | string | ✅ | snake_case. |
| `difficulty` | enum | ✅ | tutorial/easy/medium/hard/expert |
| `difficulty_score` | int (0-100) | ✅ | Hesaplanmış zorluk (bkz. § 7.4). Level sıralama + A/B test. |
| `grid` | string[][] | ✅ | Her hücre tek Türkçe harf. **Dolgu dahil tüm grid küfür taramasından geçmiş olmalı.** |
| `words[].frequency_score` | int (0-100) | ✅ | Kelime sıklığı; yüksek = yaygın = kolay. |
| `words[].hint_tr` | string ≤60 | ✅ | TDK tanımı **doğrudan kullanılmaz**; özgün/yeniden yazılmış. |
| `bonus_words` | string[] | ⚪ | Grid'de oluşmuş ek geçerli Türkçe kelimeler. |
| `safety.post_fill_scanned` | bool | ✅ | `true` değilse Flutter level'i **yüklemeyi reddeder** (assert). |

### 4.3 Manifest.json
```json
{
  "version": "1.0.0",
  "total_levels": 200,
  "packs": [
    {
      "id": "pack_001_baslangic",
      "title_tr": "Başlangıç",
      "level_ids": [1,2,3,4,5,6,7,8,9,10],
      "unlock_requirement": null,
      "icon": "icons/pack_starter.png"
    },
    {
      "id": "pack_002_hayvanlar",
      "title_tr": "Hayvanlar",
      "level_ids": [11,12,13],
      "unlock_requirement": {
        "type": "previous_pack_completed",
        "pack_id": "pack_001_baslangic"
      },
      "icon": "icons/pack_animals.png"
    }
  ]
}
```

---

## 5. Hive Veri Modelleri

### 5.1 Box Listesi
| Box adı | Tip | Şifreli? | İçerik |
|---|---|---|---|
| `user_progress` | `UserProgress` (typeId: 0) | ⚪ Hayır | Bitirilen leveller, yıldızlar |
| `active_session` | `ActiveLevelState` (typeId: 6) | ⚪ Hayır | **Yarım kalan oturum (resume)** |
| `coin_wallet` | `CoinWallet` (typeId: 1) | ✅ **AES** | Coin bakiyesi |
| `app_settings` | `AppSettings` (typeId: 2) | ⚪ Hayır | Ses, müzik, dil, tema |
| `ad_state` | `AdState` (typeId: 3) | ✅ **AES** | Son interstitial timestamp, frekans cap |
| `iap_state` | `IapState` (typeId: 4) | ✅ **AES** | Reklamsız satın alındı mı |
| `daily_state` | `DailyState` (typeId: 5) | ⚪ Hayır | Streak, son giriş |

### 5.2 ActiveLevelState (Resume — KRİTİK)
```dart
// lib/features/gameplay/models/active_level_state.dart
@HiveType(typeId: 6)
class ActiveLevelState {
  @HiveField(0)
  final int levelId;

  @HiveField(1)
  final List<String> foundWords;   // şu ana dek bulunan kelimeler

  @HiveField(2)
  final int elapsedSeconds;

  @HiveField(3)
  final int hintsUsed;

  @HiveField(4)
  final DateTime lastInteractionAt;

  const ActiveLevelState({
    required this.levelId,
    required this.foundWords,
    required this.elapsedSeconds,
    required this.hintsUsed,
    required this.lastInteractionAt,
  });
}
```
- Her kelime bulunduğunda / her 10 saniyede bir `active_session` box'a yazılır (debounce).
- Bölüm tamamlanınca box temizlenir.
- Açılışta `active_session` doluysa → "Devam Et" kartı ana menüde gösterilir; oyuncu kaldığı yerden başlar (`GameplaySessionRestored`).

### 5.3 UserProgress
```dart
// lib/features/progress/models/user_progress.dart
@HiveType(typeId: 0)
class UserProgress extends HiveObject {
  @HiveField(0)
  final Map<int, LevelResult> completedLevels;

  @HiveField(1)
  int currentLevelId;

  @HiveField(2)
  DateTime? lastPlayedAt;

  UserProgress({
    required this.completedLevels,
    required this.currentLevelId,
    this.lastPlayedAt,
  });
}

@HiveType(typeId: 10)
class LevelResult {
  @HiveField(0) final int levelId;
  @HiveField(1) final int stars;          // 1-3
  @HiveField(2) final int durationSeconds;
  @HiveField(3) final int hintsUsed;
  @HiveField(4) final DateTime completedAt;

  LevelResult({
    required this.levelId,
    required this.stars,
    required this.durationSeconds,
    required this.hintsUsed,
    required this.completedAt,
  });
}
```

### 5.4 Şifreli Box Açma (AES)
```dart
// lib/core/storage/secure_hive.dart
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_flutter/hive_flutter.dart';

class SecureHive {
  static const _keyName = 'hive_aes_key';
  static const _storage = FlutterSecureStorage();

  /// Returns a stable AES cipher, generating+persisting a key on first run.
  static Future<HiveAesCipher> cipher() async {
    var encoded = await _storage.read(key: _keyName);
    if (encoded == null) {
      final key = Hive.generateSecureKey(); // 256-bit
      encoded = base64UrlEncode(key);
      await _storage.write(key: _keyName, value: encoded);
    }
    return HiveAesCipher(base64Url.decode(encoded));
  }
}
```
```dart
// kullanım (main.dart):
final cipher = await SecureHive.cipher();
await Hive.openBox<CoinWallet>('coin_wallet', encryptionCipher: cipher);
await Hive.openBox<AdState>('ad_state', encryptionCipher: cipher);
await Hive.openBox<IapState>('iap_state', encryptionCipher: cipher);
// şifresizler:
await Hive.openBox<UserProgress>('user_progress');
await Hive.openBox<ActiveLevelState>('active_session');
```
> Bu, dosya yöneticisiyle yapılan amatör coin/cap hilelerini ~%99 eler. Tam koruma (server-side) v2.0.

### 5.5 ActiveLevelState — Lifecycle Flush (Veri Kaybı Önleme)

Debounce + "kelime bulununca yaz" yetmez; kullanıcı uygulamayı ortada öldürebilir. İki katmanlı savunma:

**Katman 1 — AppLifecycleListener (birincil, Flutter 3.13+):**
```dart
// lib/features/gameplay/bloc/gameplay_bloc.dart
// GameplayBloc constructor'ında:
_lifecycleListener = AppLifecycleListener(
  onPause: _flushSessionIfDirty,    // Android: arka plana geç
  onInactive: _flushSessionIfDirty, // iOS: kontrol merkezi vb.
);

Future<void> _flushSessionIfDirty() async {
  final s = state;
  if (s is! GameplayActive || !s.isDirty) return;
  await _progressRepo.saveActiveSession(ActiveLevelState(
    levelId: s.level.levelId,
    foundWords: s.foundWords.toList(),
    elapsedSeconds: s.elapsed.inSeconds,
    hintsUsed: s.hintsUsed,
    lastInteractionAt: DateTime.now(),
  ));
}
```
- `isDirty` flag: son flush'tan sonra state değiştiyse `true`. Gereksiz Hive yazımını engeller (`inactive` iOS'ta sık tetiklenir).
- `AppLifecycleListener` Bloc'un `close()` içinde `dispose()` edilir.

**Katman 2 — Debounce penceresi 3 sn (ikincil, lifecycle yakalanamasa diye):**
- Her kelime bulunduğunda + her ipucu kullanımında anında yaz.
- Ek olarak 3 saniyelik timer debounce (10 sn değil).

### 5.6 Android Auto-Backup Çökme Riski ve Çözümü (ÖNEMLİ)

**Risk:** Android'de `Auto-Backup` varsayılan açık. Uygulama silinip tekrar kurulunca Google Drive'dan eski şifreli `.hive` dosyaları geri yüklenir. Ama uygulama silinince Keystore'daki AES anahtarı da gider. Sonuç: eski şifreli veri + yok anahtar = `HiveError` → **açılışta çökme.**

**Çözüm A (MVP — uygulandı):** `allowBackup` tamamen kapat.
```xml
<!-- android/app/src/main/AndroidManifest.xml -->
<application
    android:allowBackup="false"
    android:fullBackupContent="false"
    ...>
```
- Basit, sıfır risk. Trade-off: uygulama silinince ilerleme gider (MVP'de hesap yok zaten; kabul edilebilir).
- v1.1'de hesap sistemi veya selective backup (B seçeneği) değerlendirilebilir.

**Savunma kodu (çift güvenlik):** Yine de box açılışını `try/catch` içine al; decrypt hatası gelirse **çökme yerine** box temizle + sıfırla:
```dart
// lib/core/storage/secure_hive.dart
static Future<Box<T>> openBoxSafe<T>(
  String name, {
  HiveCipher? cipher,
}) async {
  try {
    return await Hive.openBox<T>(name, encryptionCipher: cipher);
  } catch (e, st) {
    FirebaseCrashlytics.instance.recordError(e, st,
        reason: 'Hive decrypt failed — clearing box: $name');
    await Hive.deleteBoxFromDisk(name);
    return Hive.openBox<T>(name, encryptionCipher: cipher);
  }
}
```
Kullanıcı coin'ini kaybeder ama uygulama açılır. Kayıp < çökme.

---

## 6. Service Interface'leri (Mock-First)

### 6.1 AdService (ağ-bağımsız)
```dart
// lib/features/monetization/services/ad_service.dart
abstract class AdService {
  Future<void> initialize();
  Future<void> requestConsent();              // UMP
  Future<bool> showInterstitial({required String placement});
  Future<bool> showRewarded({required String placement});
  Stream<BannerHandle?> bannerStream({required String placement});
  bool get isInterstitialReady;
  bool get isRewardedReady;
  void setRemoveAdsPurchased(bool value);
}
```
- MVP implementasyonu: `admob_ad_service.dart`.
- v1.1+ AppLovin MAX'e geçişte: `applovin_ad_service.dart` yazılır, AdService **interface'i değişmez**, Bloc/UI dokunulmaz.

### 6.2 IapService
```dart
abstract class IapService {
  Future<void> initialize();
  Future<List<IapProduct>> fetchProducts();
  Future<PurchaseOutcome> purchase(String productId);
  Future<bool> restorePurchases();
  Stream<EntitlementStatus> entitlementStream();
  Future<bool> hasRemoveAdsPurchase();
}
```

### 6.3 LevelLoaderService
```dart
abstract class LevelLoaderService {
  Future<Level> loadLevel(int levelId);
  Future<Manifest> loadManifest();
  Future<List<Pack>> loadPacks();
}
```
- `loadLevel` parse ederken `safety.post_fill_scanned == true` doğrular; değilse `LevelNotScannedException` fırlatır.

### 6.4 Mock Kuralları
- `debugPrint('[MockXService] action: $details')` her çağrıda
- Random delay (200–800 ms)
- Configurable failure (`MockAdService(failureRate: 0.1)`) — test için
- Singleton (hot-reload state korunur)

---

## 7. Python Level Generator (tools/level_generator) — ÖNCE BU YAZILIR

### 7.1 Pipeline
```
[raw TDK list (76K)  — CanNuhlar repo]
       ↓
[1. profanity filter (ooguz blacklist)]
       ↓
[2. length filter (3–12 harf), yabancı harf (Q/W/X) ele]
       ↓
[3. kategori sınıflandırma (manual + LLM assist)]
       ↓
[4. frekans skorlama (Türkçe corpus) → frequency_score]
       ↓
[word_pool_cleaned.json]
       ↓
[generator: word_search (backtracking) / crossword (CSP)]
       ↓
[grid DOLGU harfleri (Türkçe frekansa göre)]
       ↓
[★ POST-FILL SAFETY: her satır/sütun/diyagonal n-gram küfür taraması ★]
       ↓   (eşleşme → dolguyu re-randomize; 100 denemede çözülmezse grid reset)
[hint_writer: özgün ipucu üretimi (LLM + insan QA)]
       ↓
[difficulty.py: difficulty_score hesabı]
       ↓
[schema_validator (pydantic) + Flutter parse testi]
       ↓
[assets/levels/*.json]
```

### 7.2 Pydantic Şeması
```python
# tools/level_generator/src/kelime_gen/schema.py
from enum import Enum
from pydantic import BaseModel, Field

class Difficulty(str, Enum):
    TUTORIAL = "tutorial"; EASY = "easy"; MEDIUM = "medium"
    HARD = "hard"; EXPERT = "expert"

class Direction(str, Enum):
    HORIZONTAL = "horizontal"; VERTICAL = "vertical"
    DIAGONAL_DOWN = "diagonal_down"; DIAGONAL_UP = "diagonal_up"

class Position(BaseModel):
    row: int = Field(ge=0); col: int = Field(ge=0)

class WordPlacement(BaseModel):
    word: str = Field(min_length=2, max_length=15)
    start: Position
    direction: Direction
    length: int = Field(ge=2, le=15)
    frequency_score: int = Field(ge=0, le=100)
    hint_tr: str = Field(max_length=60)

class GridSize(BaseModel):
    rows: int = Field(ge=5, le=18); cols: int = Field(ge=5, le=18)

class Rewards(BaseModel):
    coins_base: int = Field(ge=10, le=500)
    coins_perfect: int = Field(ge=20, le=1000)
    stars_threshold_seconds: list[int] = Field(min_length=3, max_length=3)

class Safety(BaseModel):
    post_fill_scanned: bool
    scanner_version: str

class Level(BaseModel):
    schema_version: int = 1
    level_id: int = Field(ge=1)
    pack_id: str
    difficulty: Difficulty
    difficulty_score: int = Field(ge=0, le=100)
    category: str
    category_display_tr: str
    grid_size: GridSize
    grid: list[list[str]]
    words: list[WordPlacement] = Field(min_length=3, max_length=25)
    bonus_words: list[str] = []
    rewards: Rewards
    safety: Safety
    generated_at: str
    generator_version: str
```

### 7.3 Post-Fill Küfür Taraması (KRİTİK — "Scrabble Efekti" Önleme)
Dolgu harfleri rastgele konunca grid içinde istemeden küfür oluşabilir. Bu yüzden dolgudan **sonra**:
```python
# tools/level_generator/src/kelime_gen/validators/post_fill_safety.py
def scan_grid(grid: list[list[str]], blacklist: set[str],
              min_n: int = 3, max_n: int = 6) -> list[str]:
    """Tüm yatay, dikey ve iki çapraz hatları (ve ters okunuşlarını)
    n-gram pencereleriyle tarar; karalisteyle eşleşen alt dizgileri döndürür."""
    hits: list[str] = []
    lines = _all_lines(grid)  # satır + sütun + 2 diyagonal yön
    for line in lines:
        s = "".join(line)
        for variant in (s, s[::-1]):  # ters okunuş da kontrol
            for n in range(min_n, max_n + 1):
                for i in range(len(variant) - n + 1):
                    sub = variant[i:i + n]
                    if sub in blacklist:
                        hits.append(sub)
    return hits
```
- `scan_grid` boş liste dönene kadar dolgu yeniden randomize edilir; katmanlı retry:

```python
# tools/level_generator/src/kelime_gen/validators/post_fill_safety.py

class SafetyGenerationError(Exception):
    """Raised when a clean grid cannot be produced within attempt budgets."""

MAX_FILL_ATTEMPTS   = 100   # dolgu re-randomize
MAX_GRID_RESETS     = 10    # aynı kelimelerle grid baştan
MAX_WORD_RESAMPLES  = 3     # farklı kelime seti dene
TIMEOUT_SECONDS     = 30    # mutlak zaman sınırı

def safe_fill(
    grid: list[list[str]],
    word_cells: set[tuple[int, int]],
    blacklist: set[str],
    word_pool: list[str],
) -> list[list[str]]:
    import time
    deadline = time.monotonic() + TIMEOUT_SECONDS

    for word_attempt in range(MAX_WORD_RESAMPLES):
        for grid_attempt in range(MAX_GRID_RESETS):
            for fill_attempt in range(MAX_FILL_ATTEMPTS):
                if time.monotonic() > deadline:
                    raise SafetyGenerationError(
                        f"Timeout after {TIMEOUT_SECONDS}s — "
                        f"word_attempt={word_attempt}, grid_attempt={grid_attempt}"
                    )
                candidate = _randomize_fill(grid, word_cells)
                if not scan_grid(candidate, blacklist):
                    return candidate  # ✅ temiz grid bulundu
            # 100 dolgu denemesi başarısız → grid sıfırla (farklı yerleşim)
            grid = _reset_grid_layout(grid, word_cells)

        # 10 grid reset başarısız → farklı kelime seti
        grid, word_cells = _resample_words(word_pool)

    # Her şey başarısız
    raise SafetyGenerationError(
        "Cannot produce profanity-free grid after all retries"
    )
```

**Generator üst katmanında:**
```python
# tools/level_generator/src/kelime_gen/generator.py
import sys

def generate_level(level_id: int, ...) -> Level | None:
    try:
        filled_grid = safe_fill(grid, word_cells, blacklist, word_pool)
        level = _build_level(filled_grid, ...)
        # pydantic doğrulama — safety.post_fill_scanned False ise hata fırlatır
        Level.model_validate(level.model_dump())
        return level
    except SafetyGenerationError as e:
        print(f"[WARN] Level {level_id} skipped: {e}", file=sys.stderr)
        return None  # build raporu "üretilemedi" listesine ekler

# CLI exit code — CI bu kodu yakalar
if failed_levels:
    print(f"[ERROR] {len(failed_levels)} level(s) failed: {failed_levels}",
          file=sys.stderr)
    sys.exit(1)  # sessizce başarı döndürme; hatalı dosya asla yazılmaz
```

- `safety.post_fill_scanned = False` olan level pydantic validate'de hata verir → dosyaya yazılmaz.
- `sys.exit(1)` ile CI pipeline görünür kırmızı olur; sessiz başarı **asla**.
- Flutter `LevelLoaderService` hâlâ ikinci kontrol noktası: flag `False` ise `LevelNotScannedException`.

### 7.4 difficulty_score
```python
# tools/level_generator/src/kelime_gen/difficulty.py
def difficulty_score(level) -> int:
    """0 (en kolay) – 100 (en zor). Ağırlıklar deneysel; Remote Config ile ayarlanabilir."""
    grid_factor = (level.grid_size.rows * level.grid_size.cols) / (18 * 18)
    word_count_factor = len(level.words) / 25
    avg_len = sum(w.length for w in level.words) / len(level.words)
    len_factor = (avg_len - 2) / 13
    avg_freq = sum(w.frequency_score for w in level.words) / len(level.words)
    rarity_factor = 1 - (avg_freq / 100)            # az frekans = zor
    diag = sum(1 for w in level.words
               if w.direction.value.startswith("diagonal")) / len(level.words)
    raw = (0.20 * grid_factor + 0.20 * word_count_factor +
           0.20 * len_factor + 0.30 * rarity_factor + 0.10 * diag)
    return round(min(100, max(0, raw * 100)))
```

### 7.5 Türkçe Harf Frekansları (dolgu için)
```python
TR_LETTER_FREQUENCY = {
    "A": 11.92, "E": 8.91, "İ": 8.60, "N": 7.49, "R": 6.95,
    "L": 5.92, "I": 5.20, "K": 4.71, "D": 4.68, "M": 3.75,
    "U": 3.43, "Y": 3.34, "T": 3.14, "S": 3.01, "O": 2.61,
    # ... kalan harfler
}
```

### 7.6 Türkçe İşleme (Python)
```python
TR_UPPER_MAP = str.maketrans("iı", "İI")
TR_LOWER_MAP = str.maketrans("İI", "iı")
def tr_upper(t: str) -> str: return t.translate(TR_UPPER_MAP).upper()
def tr_lower(t: str) -> str: return t.translate(TR_LOWER_MAP).lower()
```

---

## 8. Routing (go_router)
```dart
// lib/core/router/app_router.dart
'/'                    → SplashScreen
'/consent'             → ConsentScreen
'/menu'                → MenuScreen        // "Devam Et" kartı resume için burada
'/packs'               → PacksScreen
'/gameplay/:levelId'   → GameplayScreen    // tutorial overlay bölüm 1-4'te aktif
'/shop'                → ShopScreen
'/settings'            → SettingsScreen
'/legal/privacy'       → PrivacyPolicyScreen (WebView)
'/legal/terms'         → TermsScreen
```
Deep-link şeması v1.1.

---

## 9. Tema ve Tasarım Token'ları
```dart
// lib/core/constants/app_colors.dart
class AppColors {
  static const primary = Color(0xFF1565C0);
  static const primaryDark = Color(0xFF0D47A1);
  static const accent = Color(0xFFFFA000);
  static const success = Color(0xFF2E7D32);
  static const error = Color(0xFFC62828);
  static const warning = Color(0xFFF9A825);
  static const gridCellNormal = Color(0xFFFAFAFA);
  static const gridCellSelected = Color(0xFFFFE082);
  static const gridCellFound = Color(0xFFA5D6A7);
  static const gridCellLocked = Color(0xFFB0BEC5);
  static const coinGold = Color(0xFFFFC107);
  static const star = Color(0xFFFFB300);
}
```
Ham `Color(0xFF...)` literal yasak; sadece `AppColors.x` veya `Theme.of(context)`.

---

## 10. Analytics Event Şeması (Firebase)
snake_case, ≤40 karakter.

| Event | Parametreler | Ne zaman |
|---|---|---|
| `app_open` | `is_first_open` | Açılış |
| `consent_given` / `consent_denied` | `consent_type` (kvkk/ump/att) | Rıza |
| `tutorial_step_done` | `step_index` | In-context tutorial adımı |
| `tutorial_completed` | `total_steps` | Tutorial bitti |
| `level_started` | `level_id`, `difficulty`, `difficulty_score`, `category` | Bölüme girildi |
| `level_completed` | `level_id`, `duration_seconds`, `stars`, `hints_used`, `coins_earned` | Bitti |
| `level_resumed` | `level_id`, `found_words_count` | Yarım oturum devam |
| `level_abandoned` | `level_id`, `found_words_count` | Bölümden çıkıldı |
| `hint_used` | `level_id`, `hint_type`, `source` (coin/ad) | İpucu |
| `ad_shown` | `ad_type`, `placement`, `network` | Reklam |
| `ad_rewarded_completed` | `placement`, `reward_type`, `reward_amount` | Ödüllü tamam |
| `iap_initiated` / `iap_completed` / `iap_failed` | `product_id`, `price_local`/`error_code` | IAP |
| `coins_spent` / `coins_earned` | `amount`, `reason`/`source` | Ekonomi |

**User properties:** `total_levels_completed`, `is_paying_user`, `consent_status`, `total_play_minutes`.

---

## 11. Environment ve Build

### 11.1 --dart-define Anahtarları
```bash
flutter build apk --release \
  --dart-define=ADMOB_APP_ID_ANDROID=ca-app-pub-xxx~yyy \
  --dart-define=ADMOB_INTERSTITIAL_ID_ANDROID=ca-app-pub-xxx/zzz \
  --dart-define=ADMOB_REWARDED_ID_ANDROID=ca-app-pub-xxx/www \
  --dart-define=ADMOB_BANNER_ID_ANDROID=ca-app-pub-xxx/vvv \
  --dart-define=REVENUECAT_PUBLIC_KEY_ANDROID=goog_xxx \
  --dart-define=ENV=production
```

### 11.2 Build Flavors
`dev` (test reklamı, dev Firebase) / `staging` / `production`.

### 11.3 Secret Sınırı
- `--dart-define` ile geçirilen değerler APK içinden okunabilir; ama AdMob unit ID + RevenueCat **public** key zaten public sayılır → **MVP için kabul edilen risk**.
- **Gerçek sırlar (RevenueCat secret key, imza anahtarı, ileride backend JWT secret) ASLA client'ta değil.** Yalnızca sunucu tarafında.

### 11.4 Test-ID Production Koruması (ZORUNLU)
Test AdMob ID'si canlıda kalırsa Google hesabı askıya alır. `ad_unit_ids.dart`:
```dart
// lib/core/constants/ad_unit_ids.dart
import 'package:flutter/foundation.dart';

class AdUnitIds {
  static const _testInterstitial = 'ca-app-pub-3940256099942544/1033173712';

  static const interstitialAndroid = String.fromEnvironment(
    'ADMOB_INTERSTITIAL_ID_ANDROID',
    defaultValue: _testInterstitial,
  );

  /// Call once at startup. Crashes early in release if a test ID leaked.
  static void assertNoTestIdsInRelease() {
    if (kReleaseMode) {
      assert(
        !interstitialAndroid.contains('3940256099942544'),
        'TEST AdMob ID detected in RELEASE build — aborting.',
      );
      // assert release'de çalışmaz; ek olarak hard guard:
      if (interstitialAndroid.contains('3940256099942544')) {
        throw StateError('Test AdMob ID in release build');
      }
    }
  }
}
```

### 11.5 .gitignore Önemli Maddeler
```
/lib/generated/
/build/
.dart_tool/
.env
.env.*
*.keystore
google-services.json
GoogleService-Info.plist
ios/Runner/Configs/Secrets.xcconfig
```
> Firebase config dev/staging için repo'da olabilir; production CI secret'tan inject.

---

## 12. Test Stratejisi (özet — detay coding-standards.md)
| Tip | Coverage | Konum |
|---|---|---|
| Unit (service + bloc/cubit) | %85+ | `test/features/*/` |
| Widget | smoke + kritik | `test/features/*/views/` |
| Integration | happy path | `integration_test/` |
| Python generator | %70+ | `tools/level_generator/tests/` |

Python tarafında **post-fill küfür taraması** için ayrı test seti zorunlu (bilinen kötü gridler fixture olarak).

---

## 13. ADR (Mimari Karar Kayıtları)
`docs/adr/` altında:
- `0001-flutter-over-react-native.md`
- `0002-bloc-cubit-hybrid.md`
- `0003-hive-over-sqflite.md`
- `0004-no-flame-custompainter.md` ← Flame'i neden çıkardığımız

---

## 14. Versiyon Geçmişi
| Sürüm | Tarih | Değişiklik |
|---|---|---|
| 1.0 | 2026-05 | İlk taslak |
| 3.0 | 2026-05 | Flame çıkarıldı (klasör/model güncellendi); ActiveLevelState (resume); AES şifreli box'lar + SecureHive; AdMob-only servis (admob_ad_service); difficulty_score + difficulty.py; post-fill küfür taraması (post_fill_safety.py + safety alanı); test-ID assert; tutorial overlay gameplay'e gömüldü; Bloc/Cubit ayrımı klasöre yansıtıldı |
