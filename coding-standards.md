# Kodlama Standartları (coding-standards.md)

> **Sürüm 3.0** — Bu dosya nedir? Günlük geliştirme sırasında uyulacak kodlama, test, commit ve kalite standartları. `skills.md` "ne yapılacağını", `architecture.md` "nasıl yapılandırılacağını", bu dosya "nasıl yazılacağını" tanımlar.

---

## 1. Dart / Flutter Kod Stili

### 1.1 Lint
`analysis_options.yaml` zorunlu:
```yaml
include: package:flutter_lints/flutter.yaml

linter:
  rules:
    - always_use_package_imports  # relative import YASAK (LLM tutarlılığı + refactor güvenliği)
    - always_declare_return_types
    - avoid_print  # debugPrint kullanılır
    - prefer_const_constructors
    - prefer_const_literals_to_create_immutables
    - prefer_final_locals
    - prefer_final_in_for_each
    - prefer_single_quotes
    - require_trailing_commas
    - sort_child_properties_last
    - unawaited_futures
    - use_super_parameters
    - avoid_dynamic_calls
    - cancel_subscriptions
    - close_sinks
    - prefer_typing_uninitialized_variables

analyzer:
  errors:
    invalid_annotation_target: ignore
    missing_required_param: error
    missing_return: error
  exclude:
    - lib/generated/**
    - "**/*.g.dart"
    - "**/*.freezed.dart"
```

`dart analyze` 0 hata vermeli. CI'da bu kuralı bozan PR merge edilmez.

### 1.2 Format
```bash
dart format --line-length 100 .
```
Her commit öncesi otomatik (pre-commit hook).

### 1.3 İsimlendirme

| Element | Stil | Örnek |
|---|---|---|
| Sınıf, enum, typedef | UpperCamelCase | `GameplayBloc`, `HintType` |
| Değişken, fonksiyon, parametre | lowerCamelCase | `currentLevelId`, `loadLevel()` |
| Sabit (const) | lowerCamelCase | `maxGridSize`, `defaultCoinReward` |
| Private | leading underscore | `_internalState`, `_handleTap()` |
| Dosya | snake_case | `gameplay_bloc.dart` |
| Klasör | snake_case | `features/gameplay/` |
| Asset | snake_case | `pack_animals.png` |
| Analytics event | snake_case | `level_completed` |
| Test dosyası | `_test.dart` suffix | `gameplay_bloc_test.dart` |

**Kısaltma yasakları:**
- ❌ `usr`, `lvl`, `btn`, `cfg`, `mgr` — açık yaz: `user`, `level`, `button`, `config`, `manager`
- ✅ Endüstri standardı kabul edilenler: `id`, `url`, `uri`, `db`, `iap`, `ad`, `ui`, `csv`, `json`

### 1.4 Dosya Başlığı
Her dosyanın ilk satırı yorum olarak dosya yolu:
```dart
// lib/features/gameplay/bloc/gameplay_bloc.dart
import 'package:bloc/bloc.dart';
// ...
```

### 1.5 Import Sıralama
```dart
// 1. Dart core
import 'dart:async';
import 'dart:math';

// 2. Flutter
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// 3. 3rd party (alfabetik)
import 'package:bloc/bloc.dart';
import 'package:hive/hive.dart';

// 4. Project (relative değil, package: prefix ile)
import 'package:kelime_oyunu/core/utils/turkish_locale.dart';
import 'package:kelime_oyunu/features/gameplay/models/level.dart';
```

VSCode için: "Dart: Sort Members" + import organize on save.

> **relative import KESİNLİKLE YASAK.** `import '../models/level.dart'` gibi satırlar `always_use_package_imports` lint kuralıyla hata verir. Her zaman `package:kelime_oyunu/...`. Sebep: klasör taşıdığında relative path kırılır; LLM bazen relative bazen package üretir, bu tutarsızlık projeyi bozar. Tek tip = güvenli refactor.

### 1.6 Yorum Dili
- **Kod içi yorum: İngilizce** (uluslararası geliştirici uyumu).
- **TODO yasak.** Kullanırsan `// TODO(ad): açıklama #issue_no` formatında ve mutlaka GitHub issue.
- **Kullanıcıya görünür string: Türkçe**, sadece `.arb` dosyalarında.

```dart
// ✅ Doğru
/// Validates whether the given word matches any unfound word in the level.
/// Returns the matched word or null.
String? _validateSelection(List<GridCell> cells) { ... }

// ❌ Yanlış (Türkçe kod yorumu)
/// Seçili hücreleri kontrol eder
```

### 1.7 Async Kuralları
- `Future<void>` döndüren fonksiyon `await` edilmek zorunda → `unawaited_futures` lint.
- "Ateşle ve unut" senaryolarında açıkça `unawaited(...)`:
```dart
import 'package:flutter/foundation.dart';

unawaited(analytics.logEvent('level_started'));
```
- Stream'ler `StreamSubscription` ile takip edilir; `dispose()` / `close()` zorunlu.

### 1.8 Null Safety
- `!` (bang operator) kullanımı **istisna**. Gerekçesini yorumla yaz.
- `?? throw` yerine sealed `Result<T, E>` döndür.
- Late değişkenler sadece DI / init flow'da; mümkün oldukça `final T?` tercih et.

### 1.9 Const ve Immutable
- Tüm widget constructor'ları `const` olabiliyorsa `const`.
- Data class'lar `@immutable`, tüm fieldlar `final`.
- `copyWith` zorunlu (state için).

---

## 2. Widget Yazım Kuralları

### 2.1 Yapı
```dart
class HintPanel extends StatelessWidget {
  const HintPanel({
    required this.coinBalance,
    required this.onHintRequested,
    super.key,
  });
  
  final int coinBalance;
  final ValueChanged<HintType> onHintRequested;
  
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _HintButton(
          type: HintType.revealLetter,
          cost: 50,
          enabled: coinBalance >= 50,
          onTap: () => onHintRequested(HintType.revealLetter),
        ),
        // ...
      ],
    );
  }
}
```

### 2.2 Kural Seti
- **Constructor parametreleri:** required ve named — positional yasak (key hariç super).
- **Field'lar build üstünde**, hepsi `final`.
- **Helper widget'lar private class** (`_HintButton`), `_buildX()` fonksiyonu **yasak** (rebuild performansı).
- **BuildContext'i async fonksiyona geçirme**; `mounted` check'i unutma:
```dart
Future<void> _onPurchase() async {
  final result = await iapService.purchase('remove_ads');
  if (!mounted) return; // ✅ zorunlu
  ScaffoldMessenger.of(context).showSnackBar(...);
}
```
- **BlocListener** side effect (navigation, snackbar) için; **BlocBuilder** sadece UI rebuild için.
- **Tek widget tek dosya** kuralı: ana widget ve private helper widget'ları aynı dosyada, ama public widget'lar ayrı.

### 2.3 Tema Kullanımı
```dart
// ❌ Yasak
Container(color: Color(0xFF1565C0))
Container(color: Colors.blue)

// ✅ Doğru
Container(color: Theme.of(context).colorScheme.primary)
Container(color: AppColors.primary) // semantic ihtiyaçta
```

### 2.4 Responsive
- `MediaQuery.sizeOf(context)` (yeni API) — `MediaQuery.of(context).size` değil.
- Layout breakpointleri `AppDimensions` içinde sabit.
- Tablet boyutu: ≥ 600 dp short side. Bu durumda grid daha büyük ama mekanik aynı.

---

## 3. Bloc / Cubit Yazım Kuralları

### 3.0 Hangisi Ne Zaman?
- **Bloc:** Olay sırası önemli, event-driven akışlar → **yalnızca `gameplay`**.
- **Cubit:** Basit state değişimi (settings, wallet, monetization, menu, packs). Metot çağır → emit et.
- Karar testi: "Bu ekranda geçmişi/sırası önemli ardışık olaylar var mı?" Evet → Bloc, Hayır → Cubit.

### 3.1 Genel
- **Event isimleri geçmiş zaman + edilgen:** `GameplayCellTapped`, `LevelCompleted` (kullanıcı eylemi olmuş).
- **State'ler sealed class** (Dart 3+).
- Her event handler / cubit metodu max **40 satır**. Aşıyorsa private metoda çıkar.
- Bloc/Cubit içinde **direkt navigation yasak** — state emit et, BlocListener UI tarafında dinler.
- **Singleton Bloc/Cubit yasak** (gameplay bloc her seviyede yeni instance; wallet cubit app-scope tek instance olabilir ama get_it lazySingleton ile, global değişken değil).

### 3.2 Şablon
```dart
// lib/features/gameplay/bloc/gameplay_bloc.dart
class GameplayBloc extends Bloc<GameplayEvent, GameplayState> {
  GameplayBloc({
    required LevelLoaderService levelLoader,
    required AdService adService,
    required ProgressRepository progressRepo,
  })  : _levelLoader = levelLoader,
        _adService = adService,
        _progressRepo = progressRepo,
        super(const GameplayInitial()) {
    on<GameplayLevelLoaded>(_onLevelLoaded);
    on<GameplayCellTapped>(_onCellTapped);
    on<GameplayWordSubmitted>(_onWordSubmitted);
    on<GameplayHintRequested>(_onHintRequested);
  }
  
  final LevelLoaderService _levelLoader;
  final AdService _adService;
  final ProgressRepository _progressRepo;
  
  Future<void> _onLevelLoaded(
    GameplayLevelLoaded event,
    Emitter<GameplayState> emit,
  ) async {
    emit(const GameplayLoading());
    try {
      final level = await _levelLoader.loadLevel(event.levelId);
      emit(GameplayActive(
        level: level,
        grid: level.grid.toGridCells(),
        foundWords: const {},
        currentSelection: const [],
        coinsEarned: 0,
        elapsed: Duration.zero,
      ));
    } on LevelNotFoundException catch (e) {
      emit(GameplayError(e.message));
    }
  }
  
  // ...
}
```

### 3.2.1 Cubit Şablonu (basit ekranlar)
```dart
// lib/features/settings/cubit/settings_cubit.dart
class SettingsCubit extends Cubit<SettingsState> {
  SettingsCubit(this._repo) : super(const SettingsState.initial());
  final SettingsRepository _repo;

  Future<void> load() async {
    final s = await _repo.read();
    emit(SettingsState(
      soundOn: s.soundOn,
      musicOn: s.musicOn,
      hapticsOn: s.hapticsOn,
      themeMode: s.themeMode,
    ));
  }

  Future<void> toggleSound(bool value) async {
    await _repo.writeSound(value);
    emit(state.copyWith(soundOn: value));
  }
}
```
- Cubit'te event yok; doğrudan metot. `emit(state.copyWith(...))` ile güncelle.
- Yan etki (repo yazma) `emit`'ten **önce** tamamlanmalı (state ile disk tutarlı olsun).

### 3.3 Hata Yönetimi
- Exception'lar **sealed class** olarak `lib/core/errors/`:
```dart
sealed class AppException implements Exception {
  final String message;
  const AppException(this.message);
}

class LevelNotFoundException extends AppException {
  const LevelNotFoundException(super.message);
}

class NetworkException extends AppException {
  const NetworkException(super.message);
}
```
- Bloc her zaman `try/catch` ile yakalar, asla `unhandled`.
- Crashlytics log her exception'da: `FirebaseCrashlytics.instance.recordError(e, st)`.

---

## 4. Test Stratejisi

### 4.1 Coverage Hedefleri
| Layer | Min Coverage | Açıklama |
|---|---|---|
| Bloc | %85 | Tüm event → state geçişleri |
| Service | %80 | Mock + real |
| Widget | Smoke + critical | Sadece kritik akışlar |
| Integration | 1 happy path | Splash → bölüm bitir |
| Python generator | %70 | Şema doğrulama + edge case |

```bash
flutter test --coverage
genhtml coverage/lcov.info -o coverage/html
```

### 4.2 Bloc Test Şablonu
```dart
// test/features/gameplay/gameplay_bloc_test.dart
void main() {
  late MockLevelLoaderService levelLoader;
  late MockAdService adService;
  late MockProgressRepository progressRepo;
  
  setUp(() {
    levelLoader = MockLevelLoaderService();
    adService = MockAdService();
    progressRepo = MockProgressRepository();
  });
  
  GameplayBloc buildBloc() => GameplayBloc(
    levelLoader: levelLoader,
    adService: adService,
    progressRepo: progressRepo,
  );
  
  group('GameplayBloc', () {
    blocTest<GameplayBloc, GameplayState>(
      'emits [Loading, Active] when level loads successfully',
      build: () {
        when(() => levelLoader.loadLevel(1))
            .thenAnswer((_) async => fakeLevel);
        return buildBloc();
      },
      act: (bloc) => bloc.add(GameplayLevelLoaded(1)),
      expect: () => [
        isA<GameplayLoading>(),
        isA<GameplayActive>(),
      ],
    );
    
    blocTest<GameplayBloc, GameplayState>(
      'emits [Loading, Error] when level not found',
      build: () {
        when(() => levelLoader.loadLevel(999))
            .thenThrow(const LevelNotFoundException('not found'));
        return buildBloc();
      },
      act: (bloc) => bloc.add(GameplayLevelLoaded(999)),
      expect: () => [
        isA<GameplayLoading>(),
        isA<GameplayError>(),
      ],
    );
  });
}
```

### 4.2.1 Cubit Test Şablonu
```dart
// test/features/wallet/wallet_cubit_test.dart
void main() {
  late MockWalletRepository repo;

  setUp(() => repo = MockWalletRepository());

  blocTest<WalletCubit, WalletState>(
    'spend fails and keeps balance when insufficient funds',
    build: () {
      when(() => repo.readBalance()).thenAnswer((_) async => 20);
      return WalletCubit(repo)..load();
    },
    act: (cubit) => cubit.spend(50, reason: 'hint'),
    skip: 1, // load() sonrası ilk state'i atla
    expect: () => <WalletState>[], // emit yok; bakiye değişmedi
    verify: (_) => verifyNever(() => repo.writeBalance(any())),
  );
}
```

### 4.3 Widget Test
```dart
// test/features/gameplay/views/hint_panel_test.dart
void main() {
  testWidgets('HintPanel disables button when coins insufficient',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: HintPanel(
          coinBalance: 10,
          onHintRequested: _noop,
        ),
      ),
    );
    
    final button = tester.widget<ElevatedButton>(
      find.byKey(const Key('hint_reveal_letter')),
    );
    expect(button.onPressed, isNull);
  });
}

void _noop(HintType _) {}
```

### 4.4 Test Fixture'lar
- Tüm test dataları `test/fixtures/` JSON'larında.
- Fixture loader helper:
```dart
// test/helpers/fixture_loader.dart
Future<String> loadFixture(String name) async {
  return File('test/fixtures/$name').readAsString();
}
```
- **Hardcoded test data yasak.** Tek istisna: 1-2 alanlı basit objeler.

### 4.5 Integration Test (Happy Path)
```dart
// integration_test/happy_path_test.dart
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  
  testWidgets('User completes onboarding and first level', (tester) async {
    app.main();
    await tester.pumpAndSettle();
    
    // Consent
    await tester.tap(find.text('Kabul Et'));
    await tester.pumpAndSettle();
    
    // Onboarding
    await tester.tap(find.text('Atla'));
    await tester.pumpAndSettle();
    
    // Bölüm 1
    await tester.tap(find.byKey(const Key('level_1')));
    await tester.pumpAndSettle();
    
    // ... grid etkileşimi
  });
}
```

### 4.6 Mock Yazım
**mocktail** kullanılır, mockito YERİNE:
```dart
class MockAdService extends Mock implements AdService {}

void main() {
  setUpAll(() {
    registerFallbackValue(HintType.revealLetter);
  });
  
  // ...
}
```

---

## 5. Performans Standartları

### 5.1 Grid Çizim Optimizasyonu (Flame YOK — Manuel Sorumluluk)
> Flame motoru projeden çıkarıldığı için (ADR-0004) repaint optimizasyonunu **motor değil biz** yaparız. Yanlış yapılırsa eski cihazlar ısınır, batarya akar. Aşağıdaki kurallar bağlayıcıdır.

- Grid `CustomPainter` ile çizilir, tek `RepaintBoundary` içinde.
- **İki katmanlı painter:** Statik katman (grid çizgileri, harfler, kilitlenmiş kelimeler) ile animasyonlu katman (aktif seçim, parıltı, titreme) **ayrı** painter'lardır. Statik katman nadiren repaint olur; sadece animasyonlu katman her frame yeniden çizilir. Bu, her frame'de tüm grid'i yeniden çizmeyi önler.
- `shouldRepaint` her zaman doğru implement edilir; gereksiz `true` dönmek = ısınma:
```dart
@override
bool shouldRepaint(covariant GridPainter oldDelegate) {
  return oldDelegate.cells != cells ||
      oldDelegate.selection != selection ||
      oldDelegate.foundPaths != foundPaths;
}
```
- Animasyon değerleri için `Listenable` (AnimationController) painter constructor'ına `repaint:` parametresiyle geçer; `setState` ile rebuild **yasak** (painter `super(repaint: controller)`).
- Sürekli çalışan animasyon **yok**; her animasyon `AnimationController` ile başlar, biter, `dispose` edilir. Idle durumda 0 repaint hedeflenir (statik ekran = 0 fps redraw).
- Ölçüm: DevTools "Track Repaints" ile idle ekranda yeşil flash olmamalı.

### 5.2 Liste Performansı
- `ListView` yerine `ListView.builder` (lazy).
- `const` widget'lar mümkün her yerde.
- Büyük listeler için `AutomaticKeepAliveClientMixin` yerine state'i parent'a taşı.

### 5.3 Asset Optimizasyon
- PNG yerine WebP (ikonlar hariç).
- SVG → `flutter_svg` paketinin **cached** versiyonu (raster cache).
- Görsel boyutu: 1x asset için tasarlanan boyutta; 2x/3x asset coğrafyaya göre.
- `precacheImage` ile splash'ta önemli görseller bellek'e alınır.

### 5.4 Build Performansı
- Şube içi `print` yasak — `debugPrint` (kAssertion mode'da çalışır).
- Production build:
```bash
flutter build apk --release --obfuscate --split-debug-info=build/symbols
```
- Tree shaking için `tree-shake-icons` aktif (default Flutter).
- ProGuard kuralları `android/app/proguard-rules.pro`.

### 5.5 Memory
- Image cache:
```dart
PaintingBinding.instance.imageCache.maximumSizeBytes = 100 << 20; // 100 MB
```
- Hive box'ları lazy open (sadece feature açıldığında).

---

## 6. Git ve Commit Disiplini

### 6.1 Branch İsimlendirme
```
main                        # production-ready
develop                     # entegrasyon
feature/gameplay-grid       # özellik
fix/coin-display-overflow   # bug
chore/upgrade-flutter-3.16  # bakım
docs/update-architecture    # döküman
```

### 6.2 Commit Mesajı (Conventional Commits)
```
<type>(<scope>): <subject>

<body>

<footer>
```

**Type:**
- `feat` — yeni özellik
- `fix` — bug
- `refactor` — davranış değiştirmeden iyileştirme
- `perf` — performans
- `test` — sadece test
- `docs` — döküman
- `style` — format/linter (kod değil)
- `chore` — bağımlılık, build, config
- `ci` — pipeline

**Örnek:**
```
feat(gameplay): add diagonal word selection support

- Update GridPainter to render diagonal paths
- Add direction validation in WordValidatorService
- Cover with bloc + widget tests

Closes #42
```

### 6.3 PR Kuralları
- Max **400 satır** değişiklik (test/auto-generated hariç).
- En az 1 reviewer (solo dev için: 24 saat soğuma süresi, sonra self-merge).
- PR template:
```markdown
## Ne yapıldı
## Nasıl test edildi
## Ekran görüntüsü (UI değişikliği varsa)
## Kontrol listesi
- [ ] dart analyze 0 hata
- [ ] Testler ekli/güncel
- [ ] Türkçe karakter testi yapıldı
- [ ] arb güncellemesi yapıldı (string ekledi/değiştirdiyse)
- [ ] Performance bütçesi aşılmadı
- [ ] CHANGELOG güncellendi (kullanıcıya yansıyan değişiklik varsa)
```

### 6.4 Pre-commit Hook
`.git/hooks/pre-commit`:
```bash
#!/bin/sh
dart format --set-exit-if-changed --line-length 100 .
dart analyze --fatal-infos
flutter test
```

---

## 7. Lokalizasyon (.arb) Kuralları

### 7.1 Anahtar İsimlendirme
- `screen_action_object` formatı: `menuButtonStart`, `gameplayHintRevealLetter`
- Kısa keyler yasak: `ok`, `cancel` yerine `commonOk`, `commonCancel`

### 7.2 Örnek arb
```json
{
  "@@locale": "tr",
  "appTitle": "Kelime Hazinem",
  "@appTitle": {
    "description": "Uygulama adı (splash + about ekranlarında)"
  },
  
  "menuButtonStart": "Oyna",
  "menuButtonShop": "Mağaza",
  
  "gameplayHintRevealLetter": "Harf Aç",
  "gameplayHintCost": "{cost} 🪙",
  "@gameplayHintCost": {
    "placeholders": {
      "cost": {"type": "int"}
    }
  },
  
  "gameplayLevelCompleted": "Tebrikler! {count, plural, =1{1 yıldız} other{{count} yıldız}} kazandın",
  "@gameplayLevelCompleted": {
    "placeholders": {
      "count": {"type": "int"}
    }
  }
}
```

### 7.3 Kullanım
```dart
final l10n = AppLocalizations.of(context);
Text(l10n.menuButtonStart),
Text(l10n.gameplayHintCost(50)),
```

`Text('Oyna')` formunda hardcoded **yasak**. CI'da regex ile kontrol edilebilir.

---

## 8. Python (Level Generator) Standartları

### 8.1 Stil
- Python 3.11+
- Type hint **zorunlu** her public fonksiyonda
- `ruff` linter + `black` formatter
- `mypy --strict` 0 hata

### 8.2 Klasör
```
tools/level_generator/
├── pyproject.toml
├── src/
│   └── kelime_gen/        # package adı
│       ├── __init__.py
│       ├── schema.py
│       ├── word_pool.py
│       ├── generator.py
│       └── ...
└── tests/
    ├── test_schema.py
    └── test_generator.py
```

### 8.3 pyproject.toml
```toml
[project]
name = "kelime-gen"
version = "0.1.0"
requires-python = ">=3.11"
dependencies = [
    "pydantic>=2.5",
    "typer>=0.9",
    "rich>=13.7",
]

[project.optional-dependencies]
dev = ["pytest>=7", "ruff>=0.1", "black>=23", "mypy>=1.7"]

[tool.ruff]
line-length = 100
target-version = "py311"

[tool.black]
line-length = 100

[tool.mypy]
strict = true
```

### 8.4 CLI (typer)
```python
# src/kelime_gen/__main__.py
import typer
from pathlib import Path

app = typer.Typer()

@app.command()
def generate(
    count: int = typer.Option(200, help="Üretilecek bölüm sayısı"),
    output_dir: Path = typer.Option("../../assets/levels"),
    difficulty: str = typer.Option("mixed"),
) -> None:
    """Bulmaca bölümlerini üretir ve JSON olarak yazar."""
    ...

if __name__ == "__main__":
    app()
```

Kullanım:
```bash
cd tools/level_generator
python -m kelime_gen generate --count 200
```

### 8.5 Türkçe İşleme (Python)
```python
import locale

locale.setlocale(locale.LC_ALL, 'tr_TR.UTF-8')

# casefold Türkçe-uyumlu değil; manual mapping:
TR_UPPER_MAP = str.maketrans('iı', 'İI')
TR_LOWER_MAP = str.maketrans('İI', 'iı')

def tr_upper(text: str) -> str:
    return text.translate(TR_UPPER_MAP).upper()

def tr_lower(text: str) -> str:
    return text.translate(TR_LOWER_MAP).lower()
```

### 8.6 Çıktı Doğrulama
- Her üretilen level pydantic ile parse edilir.
- Ekstra: Flutter tarafından da parse edilebildiği test edilir (CI step).

### 8.7 Hata ve Exit Code Kuralları (Sessiz Başarı Yasak)
- **`SafetyGenerationError`** fırlatan her level atlanır; `stderr`'e yazılır, **dosyaya yazılmaz**.
- Üretim bittikten sonra atlanmış level varsa `sys.exit(1)` ile çık — CI kırmızı olur.
- `sys.exit(0)` yalnızca **tüm** istenen level'lar başarıyla üretildiğinde.
- Timeout (`TIMEOUT_SECONDS = 30` per level) aşılması da `SafetyGenerationError` sayılır.
- `safety.post_fill_scanned = False` olan hiçbir level JSON'a yazılamaz — pydantic validator'da `model_validator(mode='after')` ile `assert` edilir:

```python
# schema.py içinde Level modeline ekle
from pydantic import model_validator

@model_validator(mode='after')
def require_safety_scan(self) -> 'Level':
    if not self.safety.post_fill_scanned:
        raise ValueError('Level cannot be saved without post-fill safety scan')
    return self
```

- Test seti: `tests/test_post_fill_safety.py` içinde bilinen küfürlü grid fixture'ları ile tarayıcı test edilir; `SafetyGenerationError` beklenen senaryolar da kapsanır.

---

## 9. Android Native Yapılandırma Notları

### 9.1 allowBackup — Şifreli Hive Çökmesini Önleme (ZORUNLU)

`Auto-Backup` açıkken uygulama silinip tekrar kurulursa Google Drive eski şifreli `.hive` dosyalarını geri yükler; Keystore AES anahtarı gitmiştir → `HiveError` → **açılışta çökme.**

`AndroidManifest.xml`'de proje oluşturulur oluşturulmaz ayarla:
```xml
<!-- android/app/src/main/AndroidManifest.xml -->
<application
    android:allowBackup="false"
    android:fullBackupContent="false"
    ...>
```
- Unutulursa Flutter projesi oluşturulduğunda **ilk iş** bu. v1.1 hesap sistemi gelince yeniden değerlendirilir.

### 9.2 ProGuard / R8
```
# android/app/proguard-rules.pro
-keep class com.hive.** { *; }
-keep class io.hive.** { *; }
```
AdMob / AppLovin MAX kütüphanelerinin `consumerProguardFiles` ile kendi kurallarını dahil ettiğini kontrol et.

---

## 10. Erişilebilirlik Standartları

- Minimum dokunma alanı: **48×48 dp**.
- Font ölçeklendirme: kullanıcının sistem ayarlarına uyum (`MediaQuery.textScalerOf(context)`).
- Renk kontrastı: WCAG AA (4.5:1 metin, 3:1 large text).
- `Semantics` widget'ı butonlarda anlamlı label ile:
```dart
Semantics(
  label: 'Harf aç ipucu, 50 coin',
  button: true,
  child: HintButton(...),
)
```
- Renk + ikon zorunlu (sadece renkle ayrım yasak).
- Dark mode tam destek.

---

## 11. Güvenlik

### 11.1 Secret Yönetimi
- API key / SDK key **kod içinde yok** — `--dart-define` ile inject.
- `.env` dosyaları `.gitignore`'da.
- Production secret'lar CI/CD secret manager'da (GitHub Actions secrets, Codemagic env).

### 11.2 IAP Doğrulama
- MVP'de local validation (`purchases_flutter` SDK'sı zaten platform'a sorar).
- Receipt cache Hive'da, ama tampering riski kabul ediliyor (hesap sistemi yok).
- v2.0: kendi backend ile server-side validation.

### 11.3 Bağımlılık Güvenliği
- `flutter pub outdated` haftalık çalıştırılır.
- Major version bump'ları PR ile, değişim notu CHANGELOG'da.
- `dart pub deps --style=compact` ile transitive dep audit.

---

## 12. Dokümantasyon Standartları

### 11.1 Kod Yorumu (dartdoc)
Public API'ler için zorunlu:
```dart
/// Loads a level by its global ID from local assets.
///
/// Throws [LevelNotFoundException] if the level ID is not in the manifest.
///
/// Example:
/// ```dart
/// final level = await loader.loadLevel(42);
/// ```
Future<Level> loadLevel(int levelId);
```

### 11.2 README'ler
Her `feature/` klasöründe **opsiyonel** kısa README. Özellik karmaşıksa zorunlu.

### 11.3 ADR (Architecture Decision Records)
Mimari kararlar `docs/adr/` altında numaralı markdown dosyalarında:
- `0001-flutter-over-react-native.md`
- `0002-bloc-over-provider.md`
- `0003-hive-over-sqflite.md`

Şablon:
```markdown
# 0001: Flutter over React Native

Status: Accepted
Date: 2026-05-15

## Context
...

## Decision
...

## Consequences
...
```

---

## 13. CI/CD (Önerilen)

GitHub Actions iş akışı (`.github/workflows/ci.yml`):

```yaml
name: CI

on:
  pull_request:
  push:
    branches: [main, develop]

jobs:
  flutter:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.x'
          channel: stable
      - run: flutter pub get
      - run: dart format --set-exit-if-changed --line-length 100 .
      - run: flutter analyze --fatal-infos
      - run: flutter test --coverage
      - uses: codecov/codecov-action@v3
  
  python:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with:
          python-version: '3.11'
      - working-directory: tools/level_generator
        run: |
          pip install -e ".[dev]"
          ruff check .
          black --check .
          mypy src/
          pytest
```

---

## 14. Release Süreci

### 13.1 Versiyonlama
SemVer: `MAJOR.MINOR.PATCH+BUILD`
- `1.0.0+1` → ilk lansman
- `1.0.1+2` → bug fix
- `1.1.0+5` → yeni özellik (günlük puzzle vb.)

`pubspec.yaml`'daki version tek kaynak; `flutter build` build number'ı otomatik geçirir.

### 13.2 CHANGELOG
[Keep a Changelog](https://keepachangelog.com/) formatı:
```markdown
## [1.1.0] - 2026-08-15

### Added
- Günlük puzzle özelliği
- 50 yeni hayvan kategorisi bölümü

### Changed
- İpucu fiyatları dengelendi (Harf Aç 60 → 50 coin)

### Fixed
- Bazı cihazlarda grid çizimi taşması (#123)
```

### 13.3 Release Notes (Mağaza için)
`fastlane/metadata/tr/release_notes.txt`:
```
- 50 yeni bölüm: Hayvanlar kategorisi
- Günlük puzzle: her gün yeni bir bulmaca
- Çeşitli hatalar giderildi
```

---

## 15. Hızlı Referans (Cheatsheet)

```dart
// Türkçe lokal
'KELİME'.toLowerCase(Locale('tr')); // ✅
'KELİME'.toLowerCase(); // ❌

// Async-safe context
if (!mounted) return;

// Hive box açma
final box = await Hive.openBox<UserProgress>('user_progress');

// Bloc test
blocTest<MyBloc, MyState>(...)

// String externalization
Text(AppLocalizations.of(context).menuButtonStart)

// Color
AppColors.primary

// Logging
debugPrint('[GameplayBloc] level loaded: ${event.levelId}');

// Env
const apiKey = String.fromEnvironment('REVENUECAT_KEY', defaultValue: '');
```

---

## 16. Versiyon Geçmişi

| Sürüm | Tarih | Değişiklik |
|---|---|---|
| 1.0 | 2026-05 | İlk taslak; lint, naming, test, git, lokalizasyon, CI/CD |
| 3.0 | 2026-05 | `always_use_package_imports` lint (relative yasak vurgusu); Bloc/Cubit ayrımı + Cubit şablonu + Cubit test örneği; CustomPainter iki-katman optimizasyonu ve cihaz ısınma kuralları (Flame çıktığı için manuel sorumluluk) |
