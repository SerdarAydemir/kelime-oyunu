# \# Kodlama Standartları (coding-standards.md)

# 

# > \*\*Sürüm 4.1\*\* — Bu dosya nedir? Günlük geliştirme sırasında uyulacak kodlama, test, commit ve kalite standartları. `skills.md` "ne yapılacağını", `architecture.md` "nasıl yapılandırılacağını", bu dosya "nasıl yazılacağını" tanımlar.

# >

# > v4.1 değişiklikleri: Oyun mekaniği word-search → Cross Up (rekabetçi çengel bulmaca). Bloc şablonu, widget örnekleri, .arb anahtarları, Python bölümü v4.1 mimarisine uyumlandı. Dart stili, lint, test, git, CI/CD kuralları değişmedi.

# 

# \---

# 

# \## 1. Dart / Flutter Kod Stili

# 

# \### 1.1 Lint

# `analysis\_options.yaml` zorunlu:

# ```yaml

# include: package:flutter\_lints/flutter.yaml

# 

# linter:

# &#x20; rules:

# &#x20;   - always\_use\_package\_imports  # relative import YASAK (LLM tutarlılığı + refactor güvenliği)

# &#x20;   - always\_declare\_return\_types

# &#x20;   - avoid\_print  # debugPrint kullanılır

# &#x20;   - prefer\_const\_constructors

# &#x20;   - prefer\_const\_literals\_to\_create\_immutables

# &#x20;   - prefer\_final\_locals

# &#x20;   - prefer\_final\_in\_for\_each

# &#x20;   - prefer\_single\_quotes

# &#x20;   - require\_trailing\_commas

# &#x20;   - sort\_child\_properties\_last

# &#x20;   - unawaited\_futures

# &#x20;   - use\_super\_parameters

# &#x20;   - avoid\_dynamic\_calls

# &#x20;   - cancel\_subscriptions

# &#x20;   - close\_sinks

# &#x20;   - prefer\_typing\_uninitialized\_variables

# 

# analyzer:

# &#x20; errors:

# &#x20;   invalid\_annotation\_target: ignore

# &#x20;   missing\_required\_param: error

# &#x20;   missing\_return: error

# &#x20; exclude:

# &#x20;   - lib/generated/\*\*

# &#x20;   - "\*\*/\*.g.dart"

# &#x20;   - "\*\*/\*.freezed.dart"

# ```

# 

# `dart analyze` 0 hata vermeli. CI'da bu kuralı bozan PR merge edilmez.

# 

# \### 1.2 Format

# ```bash

# dart format --line-length 100 .

# ```

# Her commit öncesi otomatik (pre-commit hook).

# 

# \### 1.3 İsimlendirme

# 

# | Element | Stil | Örnek |

# |---|---|---|

# | Sınıf, enum, typedef | UpperCamelCase | `GameplayBloc`, `HintType` |

# | Değişken, fonksiyon, parametre | lowerCamelCase | `playerScore`, `placeLetter()` |

# | Sabit (const) | lowerCamelCase | `maxGridSize`, `defaultCoinReward` |

# | Private | leading underscore | `\_internalState`, `\_handleTap()` |

# | Dosya | snake\_case | `gameplay\_bloc.dart` |

# | Klasör | snake\_case | `features/gameplay/` |

# | Asset | snake\_case | `pack\_animals.png` |

# | Analytics event | snake\_case | `level\_completed` |

# | Test dosyası | `\_test.dart` suffix | `gameplay\_bloc\_test.dart` |

# 

# \*\*Kısaltma yasakları:\*\*

# \- ❌ `usr`, `lvl`, `btn`, `cfg`, `mgr` — açık yaz: `user`, `level`, `button`, `config`, `manager`

# \- ✅ Endüstri standardı kabul edilenler: `id`, `url`, `uri`, `db`, `iap`, `ad`, `ui`, `csv`, `json`

# 

# \### 1.4 Dosya Başlığı

# Her dosyanın ilk satırı yorum olarak dosya yolu:

# ```dart

# // lib/features/gameplay/bloc/gameplay\_bloc.dart

# import 'package:bloc/bloc.dart';

# // ...

# ```

# 

# \### 1.5 Import Sıralama

# ```dart

# // 1. Dart core

# import 'dart:async';

# import 'dart:math';

# 

# // 2. Flutter

# import 'package:flutter/material.dart';

# import 'package:flutter/services.dart';

# 

# // 3. 3rd party (alfabetik)

# import 'package:bloc/bloc.dart';

# import 'package:hive/hive.dart';

# 

# // 4. Project (relative değil, package: prefix ile)

# import 'package:kelime\_oyunu/core/utils/turkish\_locale.dart';

# import 'package:kelime\_oyunu/features/gameplay/models/level.dart';

# ```

# 

# VSCode için: "Dart: Sort Members" + import organize on save.

# 

# > \*\*relative import KESİNLİKLE YASAK.\*\* `import '../models/level.dart'` gibi satırlar `always\_use\_package\_imports` lint kuralıyla hata verir. Her zaman `package:kelime\_oyunu/...`. Sebep: klasör taşıdığında relative path kırılır; LLM bazen relative bazen package üretir, bu tutarsızlık projeyi bozar. Tek tip = güvenli refactor.

# 

# \### 1.6 Yorum Dili

# \- \*\*Kod içi yorum: İngilizce\*\* (uluslararası geliştirici uyumu).

# \- \*\*TODO yasak.\*\* Kullanırsan `// TODO(ad): açıklama #issue\_no` formatında ve mutlaka GitHub issue.

# \- \*\*Kullanıcıya görünür string: Türkçe\*\*, sadece `.arb` dosyalarında.

# 

# ```dart

# // ✅ Doğru

# /// Validates whether the placed letter matches the expected solution

# /// in the given grid cell. Returns true if placement is correct.

# bool \_validatePlacement(GridCell cell, String letter) { ... }

# 

# // ❌ Yanlış (Türkçe kod yorumu)

# /// Seçili hücreleri kontrol eder

# ```

# 

# \### 1.7 Async Kuralları

# \- `Future<void>` döndüren fonksiyon `await` edilmek zorunda → `unawaited\_futures` lint.

# \- "Ateşle ve unut" senaryolarında açıkça `unawaited(...)`:

# ```dart

# import 'package:flutter/foundation.dart';

# 

# unawaited(analytics.logEvent('level\_started'));

# ```

# \- Stream'ler `StreamSubscription` ile takip edilir; `dispose()` / `close()` zorunlu.

# 

# \### 1.8 Null Safety

# \- `!` (bang operator) kullanımı \*\*istisna\*\*. Gerekçesini yorumla yaz.

# \- `?? throw` yerine sealed `Result<T, E>` döndür.

# \- Late değişkenler sadece DI / init flow'da; mümkün oldukça `final T?` tercih et.

# 

# \### 1.9 Const ve Immutable

# \- Tüm widget constructor'ları `const` olabiliyorsa `const`.

# \- Data class'lar `@immutable`, tüm fieldlar `final`.

# \- `copyWith` zorunlu (state için).

# 

# \---

# 

# \## 2. Widget Yazım Kuralları

# 

# \### 2.1 Yapı

# ```dart

# class HintPanel extends StatelessWidget {

# &#x20; const HintPanel({

# &#x20;   required this.coinBalance,

# &#x20;   required this.onHintRequested,

# &#x20;   super.key,

# &#x20; });

# &#x20; 

# &#x20; final int coinBalance;

# &#x20; final ValueChanged<HintType> onHintRequested;

# &#x20; 

# &#x20; @override

# &#x20; Widget build(BuildContext context) {

# &#x20;   return Row(

# &#x20;     children: \[

# &#x20;       \_HintButton(

# &#x20;         type: HintType.revealLetter,

# &#x20;         cost: 50,

# &#x20;         enabled: coinBalance >= 50,

# &#x20;         onTap: () => onHintRequested(HintType.revealLetter),

# &#x20;       ),

# &#x20;       // ...

# &#x20;     ],

# &#x20;   );

# &#x20; }

# }

# ```

# 

# \### 2.2 Kural Seti

# \- \*\*Constructor parametreleri:\*\* required ve named — positional yasak (key hariç super).

# \- \*\*Field'lar build üstünde\*\*, hepsi `final`.

# \- \*\*Helper widget'lar private class\*\* (`\_HintButton`), `\_buildX()` fonksiyonu \*\*yasak\*\* (rebuild performansı).

# \- \*\*BuildContext'i async fonksiyona geçirme\*\*; `mounted` check'i unutma:

# ```dart

# Future<void> \_onPurchase() async {

# &#x20; final result = await iapService.purchase('remove\_ads');

# &#x20; if (!mounted) return; // ✅ zorunlu

# &#x20; ScaffoldMessenger.of(context).showSnackBar(...);

# }

# ```

# \- \*\*BlocListener\*\* side effect (navigation, snackbar) için; \*\*BlocBuilder\*\* sadece UI rebuild için.

# \- \*\*Tek widget tek dosya\*\* kuralı: ana widget ve private helper widget'ları aynı dosyada, ama public widget'lar ayrı.

# 

# \### 2.3 Tema Kullanımı

# ```dart

# // ❌ Yasak

# Container(color: Color(0xFF1565C0))

# Container(color: Colors.blue)

# 

# // ✅ Doğru

# Container(color: Theme.of(context).colorScheme.primary)

# Container(color: AppColors.primary) // semantic ihtiyaçta

# ```

# 

# \### 2.4 Responsive

# \- `MediaQuery.sizeOf(context)` (yeni API) — `MediaQuery.of(context).size` değil.

# \- Layout breakpointleri `AppDimensions` içinde sabit.

# \- Tablet boyutu: ≥ 600 dp short side. Bu durumda grid daha büyük ama mekanik aynı.

# 

# \---

# 

# \## 3. Bloc / Cubit Yazım Kuralları

# 

# \### 3.0 Hangisi Ne Zaman?

# \- \*\*Bloc:\*\* Olay sırası önemli, event-driven akışlar → \*\*yalnızca `gameplay`\*\*.

# \- \*\*Cubit:\*\* Basit state değişimi (settings, wallet, monetization, menu, packs). Metot çağır → emit et.

# \- Karar testi: "Bu ekranda geçmişi/sırası önemli ardışık olaylar var mı?" Evet → Bloc, Hayır → Cubit.

# 

# \### 3.1 Genel

# \- \*\*Event isimleri geçmiş zaman + edilgen:\*\* `LetterPlaced`, `MoveConfirmed`, `WordRevealed` (kullanıcı eylemi olmuş).

# \- \*\*State'ler sealed class\*\* (Dart 3+).

# \- Her event handler / cubit metodu max \*\*40 satır\*\*. Aşıyorsa private metoda çıkar.

# \- Bloc/Cubit içinde \*\*direkt navigation yasak\*\* — state emit et, BlocListener UI tarafında dinler.

# \- \*\*Singleton Bloc/Cubit yasak\*\* (gameplay bloc her seviyede yeni instance; wallet cubit app-scope tek instance olabilir ama get\_it lazySingleton ile, global değişken değil).

# 

# \### 3.2 Şablon

# ```dart

# // lib/features/gameplay/bloc/game\_bloc.dart

# class GameBloc extends Bloc<GameEvent, GameState> {

# &#x20; GameBloc({

# &#x20;   required PuzzleRepository puzzleRepo,

# &#x20;   required AdService adService,

# &#x20;   required ProgressRepository progressRepo,

# &#x20;   required ScoreEngine scoreEngine,

# &#x20;   required BotEngine botEngine,

# &#x20;   required RackManager rackManager,

# &#x20; })  : \_puzzleRepo = puzzleRepo,

# &#x20;       \_adService = adService,

# &#x20;       \_progressRepo = progressRepo,

# &#x20;       \_scoreEngine = scoreEngine,

# &#x20;       \_botEngine = botEngine,

# &#x20;       \_rackManager = rackManager,

# &#x20;       super(const GameInitial()) {

# &#x20;   on<LoadPuzzle>(\_onLoadPuzzle);

# &#x20;   on<SelectWord>(\_onSelectWord);

# &#x20;   on<PlaceLetter>(\_onPlaceLetter);

# &#x20;   on<RecallLetter>(\_onRecallLetter);

# &#x20;   on<ConfirmMove>(\_onConfirmMove);

# &#x20;   on<PassMove>(\_onPassMove);

# &#x20;   on<BotMoveCompleted>(\_onBotMoveCompleted);

# &#x20;   on<SwapLetters>(\_onSwapLetters);

# &#x20;   on<RevealWord>(\_onRevealWord);

# &#x20;   on<UnlockSixthSlot>(\_onUnlockSixthSlot);

# &#x20; }

# 

# &#x20; final PuzzleRepository \_puzzleRepo;

# &#x20; final AdService \_adService;

# &#x20; final ProgressRepository \_progressRepo;

# &#x20; final ScoreEngine \_scoreEngine;

# &#x20; final BotEngine \_botEngine;

# &#x20; final RackManager \_rackManager;

# 

# &#x20; Future<void> \_onLoadPuzzle(

# &#x20;   LoadPuzzle event,

# &#x20;   Emitter<GameState> emit,

# &#x20; ) async {

# &#x20;   emit(const GameLoading());

# &#x20;   try {

# &#x20;     final puzzle = await \_puzzleRepo.loadPuzzle(event.puzzleId);

# &#x20;     final rack = \_rackManager.initialRack(puzzle);

# &#x20;     emit(GameActive(

# &#x20;       puzzle: puzzle,

# &#x20;       board: const {},          // Map<Cell, PlacedLetter>

# &#x20;       rack: rack,               // List<RackTile> (5 veya 6 harf)

# &#x20;       pendingPlacements: const \[],

# &#x20;       playerScore: 0,

# &#x20;       botScore: 0,

# &#x20;       phase: TurnPhase.playerTurn,

# &#x20;       highlightedWordId: null,

# &#x20;       status: GameStatus.playing,

# &#x20;     ));

# &#x20;   } on PuzzleNotFoundException catch (e) {

# &#x20;     emit(GameError(e.message));

# &#x20;   }

# &#x20; }

# 

# &#x20; Future<void> \_onConfirmMove(

# &#x20;   ConfirmMove event,

# &#x20;   Emitter<GameState> emit,

# &#x20; ) async {

# &#x20;   final current = state as GameActive;

# &#x20;   // 1. ScoreEngine: doğrula + puanla (§8.2 architecture.md)

# &#x20;   final result = \_scoreEngine.resolveMove(

# &#x20;     placements: current.pendingPlacements,

# &#x20;     puzzle: current.puzzle,

# &#x20;     board: current.board,

# &#x20;     rackStartCount: current.rack.length,

# &#x20;   );

# &#x20;   // 2. Board güncelle, skor artır, pending temizle, sıra bota

# &#x20;   final updated = current.copyWith(

# &#x20;     board: result.updatedBoard,

# &#x20;     playerScore: current.playerScore + result.scoreDelta,

# &#x20;     pendingPlacements: const \[],

# &#x20;     rack: \_rackManager.refill(result.updatedRack, current.puzzle),

# &#x20;     phase: TurnPhase.botTurn,

# &#x20;     botThinking: true,

# &#x20;   );

# &#x20;   emit(updated);

# &#x20;   // 3. Bot hamlesini 2-5 sn gecikmeyle tetikle (§9.5 architecture.md)

# &#x20;   await Future<void>.delayed(

# &#x20;     Duration(seconds: 2 + \_random.nextInt(4)),

# &#x20;   );

# &#x20;   final botMove = \_botEngine.computeMove(

# &#x20;     puzzle: current.puzzle,

# &#x20;     board: result.updatedBoard,

# &#x20;     scoreDiff: updated.botScore - updated.playerScore,

# &#x20;     difficultyBand: current.puzzle.difficultyBand,

# &#x20;   );

# &#x20;   add(BotMoveCompleted(botMove));

# &#x20; }

# 

# &#x20; // ...

# }

# ```

# 

# 

# \### 3.2.1 Cubit Şablonu (basit ekranlar)

# ```dart

# // lib/features/settings/cubit/settings\_cubit.dart

# class SettingsCubit extends Cubit<SettingsState> {

# &#x20; SettingsCubit(this.\_repo) : super(const SettingsState.initial());

# &#x20; final SettingsRepository \_repo;

# 

# &#x20; Future<void> load() async {

# &#x20;   final s = await \_repo.read();

# &#x20;   emit(SettingsState(

# &#x20;     soundOn: s.soundOn,

# &#x20;     musicOn: s.musicOn,

# &#x20;     hapticsOn: s.hapticsOn,

# &#x20;     themeMode: s.themeMode,

# &#x20;   ));

# &#x20; }

# 

# &#x20; Future<void> toggleSound(bool value) async {

# &#x20;   await \_repo.writeSound(value);

# &#x20;   emit(state.copyWith(soundOn: value));

# &#x20; }

# }

# ```

# \- Cubit'te event yok; doğrudan metot. `emit(state.copyWith(...))` ile güncelle.

# \- Yan etki (repo yazma) `emit`'ten \*\*önce\*\* tamamlanmalı (state ile disk tutarlı olsun).

# 

# \### 3.3 Hata Yönetimi

# \- Exception'lar \*\*sealed class\*\* olarak `lib/core/errors/`:

# ```dart

# sealed class AppException implements Exception {

# &#x20; final String message;

# &#x20; const AppException(this.message);

# }

# 

# class PuzzleNotFoundException extends AppException {

# &#x20; const PuzzleNotFoundException(super.message);

# }

# 

# class NetworkException extends AppException {

# &#x20; const NetworkException(super.message);

# }

# ```

# \- Bloc her zaman `try/catch` ile yakalar, asla `unhandled`.

# \- Crashlytics log her exception'da: `FirebaseCrashlytics.instance.recordError(e, st)`.

# 

# \---

# 

# \## 4. Test Stratejisi

# 

# \### 4.1 Coverage Hedefleri

# | Layer | Min Coverage | Açıklama |

# |---|---|---|

# | Bloc | %85 | Tüm event → state geçişleri |

# | Service | %80 | Mock + real |

# | Widget | Smoke + critical | Sadece kritik akışlar |

# | Integration | 1 happy path | Splash → bölüm bitir |

# | Python generator | %70 | Şema doğrulama + edge case |

# 

# ```bash

# flutter test --coverage

# genhtml coverage/lcov.info -o coverage/html

# ```

# 

# \### 4.2 Bloc Test Şablonu

# ```dart

# // test/features/gameplay/game\_bloc\_test.dart

# void main() {

# &#x20; late MockPuzzleRepository puzzleRepo;

# &#x20; late MockAdService adService;

# &#x20; late MockProgressRepository progressRepo;

# &#x20; late MockScoreEngine scoreEngine;

# &#x20; late MockBotEngine botEngine;

# &#x20; late MockRackManager rackManager;

# 

# &#x20; setUp(() {

# &#x20;   puzzleRepo = MockPuzzleRepository();

# &#x20;   adService = MockAdService();

# &#x20;   progressRepo = MockProgressRepository();

# &#x20;   scoreEngine = MockScoreEngine();

# &#x20;   botEngine = MockBotEngine();

# &#x20;   rackManager = MockRackManager();

# &#x20; });

# 

# &#x20; GameBloc buildBloc() => GameBloc(

# &#x20;   puzzleRepo: puzzleRepo,

# &#x20;   adService: adService,

# &#x20;   progressRepo: progressRepo,

# &#x20;   scoreEngine: scoreEngine,

# &#x20;   botEngine: botEngine,

# &#x20;   rackManager: rackManager,

# &#x20; );

# 

# &#x20; group('GameBloc', () {

# &#x20;   blocTest<GameBloc, GameState>(

# &#x20;     'emits \[GameLoading, GameActive] when puzzle loads successfully',

# &#x20;     build: () {

# &#x20;       when(() => puzzleRepo.loadPuzzle(1))

# &#x20;           .thenAnswer((\_) async => fakePuzzle);

# &#x20;       when(() => rackManager.initialRack(fakePuzzle))

# &#x20;           .thenReturn(fakeRack);

# &#x20;       return buildBloc();

# &#x20;     },

# &#x20;     act: (bloc) => bloc.add(const LoadPuzzle(1)),

# &#x20;     expect: () => \[

# &#x20;       isA<GameLoading>(),

# &#x20;       isA<GameActive>(),

# &#x20;     ],

# &#x20;   );

# 

# &#x20;   blocTest<GameBloc, GameState>(

# &#x20;     'emits \[GameLoading, GameError] when puzzle not found',

# &#x20;     build: () {

# &#x20;       when(() => puzzleRepo.loadPuzzle(999))

# &#x20;           .thenThrow(const PuzzleNotFoundException('not found'));

# &#x20;       return buildBloc();

# &#x20;     },

# &#x20;     act: (bloc) => bloc.add(const LoadPuzzle(999)),

# &#x20;     expect: () => \[

# &#x20;       isA<GameLoading>(),

# &#x20;       isA<GameError>(),

# &#x20;     ],

# &#x20;   );

# 

# &#x20;   blocTest<GameBloc, GameState>(

# &#x20;     'PlaceLetter adds to pendingPlacements',

# &#x20;     build: () => buildBloc()..emit(fakeActiveState),

# &#x20;     act: (bloc) => bloc.add(PlaceLetter(rackIndex: 0, cell: fakeCell)),

# &#x20;     expect: () => \[

# &#x20;       isA<GameActive>().having(

# &#x20;         (s) => (s as GameActive).pendingPlacements.length,

# &#x20;         'pendingPlacements length',

# &#x20;         1,

# &#x20;       ),

# &#x20;     ],

# &#x20;   );

# 

# &#x20;   blocTest<GameBloc, GameState>(

# &#x20;     'ConfirmMove resolves score and transitions to botTurn',

# &#x20;     build: () {

# &#x20;       when(() => scoreEngine.resolveMove(

# &#x20;         placements: any(named: 'placements'),

# &#x20;         puzzle: any(named: 'puzzle'),

# &#x20;         board: any(named: 'board'),

# &#x20;         rackStartCount: any(named: 'rackStartCount'),

# &#x20;       )).thenReturn(fakeMoveResult);

# &#x20;       return buildBloc()..emit(fakeActiveWithPending);

# &#x20;     },

# &#x20;     act: (bloc) => bloc.add(const ConfirmMove()),

# &#x20;     expect: () => \[

# &#x20;       isA<GameActive>().having(

# &#x20;         (s) => (s as GameActive).phase,

# &#x20;         'phase',

# &#x20;         TurnPhase.botTurn,

# &#x20;       ),

# &#x20;     ],

# &#x20;   );

# &#x20; });

# }

# ```

# 

# 

# \### 4.2.1 Cubit Test Şablonu

# ```dart

# // test/features/wallet/wallet\_cubit\_test.dart

# void main() {

# &#x20; late MockWalletRepository repo;

# 

# &#x20; setUp(() => repo = MockWalletRepository());

# 

# &#x20; blocTest<WalletCubit, WalletState>(

# &#x20;   'spend fails and keeps balance when insufficient funds',

# &#x20;   build: () {

# &#x20;     when(() => repo.readBalance()).thenAnswer((\_) async => 20);

# &#x20;     return WalletCubit(repo)..load();

# &#x20;   },

# &#x20;   act: (cubit) => cubit.spend(50, reason: 'hint'),

# &#x20;   skip: 1, // load() sonrası ilk state'i atla

# &#x20;   expect: () => <WalletState>\[], // emit yok; bakiye değişmedi

# &#x20;   verify: (\_) => verifyNever(() => repo.writeBalance(any())),

# &#x20; );

# }

# ```

# 

# \### 4.3 Widget Test

# ```dart

# // test/features/gameplay/views/hint\_panel\_test.dart

# void main() {

# &#x20; testWidgets('HintPanel disables button when coins insufficient',

# &#x20;     (tester) async {

# &#x20;   await tester.pumpWidget(

# &#x20;     const MaterialApp(

# &#x20;       home: HintPanel(

# &#x20;         coinBalance: 10,

# &#x20;         onHintRequested: \_noop,

# &#x20;       ),

# &#x20;     ),

# &#x20;   );

# &#x20;   

# &#x20;   final button = tester.widget<ElevatedButton>(

# &#x20;     find.byKey(const Key('hint\_reveal\_letter')),

# &#x20;   );

# &#x20;   expect(button.onPressed, isNull);

# &#x20; });

# }

# 

# void \_noop(HintType \_) {}

# ```

# 

# \### 4.4 Test Fixture'lar

# \- Tüm test dataları `test/fixtures/` JSON'larında.

# \- Fixture loader helper:

# ```dart

# // test/helpers/fixture\_loader.dart

# Future<String> loadFixture(String name) async {

# &#x20; return File('test/fixtures/$name').readAsString();

# }

# ```

# \- \*\*Hardcoded test data yasak.\*\* Tek istisna: 1-2 alanlı basit objeler.

# 

# \### 4.5 Integration Test (Happy Path)

# ```dart

# // integration\_test/happy\_path\_test.dart

# void main() {

# &#x20; IntegrationTestWidgetsFlutterBinding.ensureInitialized();

# &#x20; 

# &#x20; testWidgets('User completes onboarding and first level', (tester) async {

# &#x20;   app.main();

# &#x20;   await tester.pumpAndSettle();

# &#x20;   

# &#x20;   // Consent

# &#x20;   await tester.tap(find.text('Kabul Et'));

# &#x20;   await tester.pumpAndSettle();

# &#x20;   

# &#x20;   // Onboarding

# &#x20;   await tester.tap(find.text('Atla'));

# &#x20;   await tester.pumpAndSettle();

# &#x20;   

# &#x20;   // Bölüm 1

# &#x20;   await tester.tap(find.byKey(const Key('level\_1')));

# &#x20;   await tester.pumpAndSettle();

# &#x20;   

# &#x20;   // ... grid etkileşimi

# &#x20; });

# }

# ```

# 

# \### 4.6 Mock Yazım

# \*\*mocktail\*\* kullanılır, mockito YERİNE:

# ```dart

# class MockAdService extends Mock implements AdService {}

# 

# void main() {

# &#x20; setUpAll(() {

# &#x20;   registerFallbackValue(HintType.revealLetter);

# &#x20; });

# &#x20; 

# &#x20; // ...

# }

# ```

# 

# \---

# 

# \## 5. Performans Standartları

# 

# \### 5.1 Grid Çizim Optimizasyonu (Flame YOK — Manuel Sorumluluk)

# > Flame motoru projeden çıkarıldığı için (ADR-0004) repaint optimizasyonunu \*\*motor değil biz\*\* yaparız. Yanlış yapılırsa eski cihazlar ısınır, batarya akar. Aşağıdaki kurallar bağlayıcıdır.

# 

# \- Grid `CustomPainter` ile çizilir, tek `RepaintBoundary` içinde.

# \- \*\*İki katmanlı painter:\*\* Statik katman (grid çizgileri, harfler, kilitlenmiş kelimeler) ile animasyonlu katman (aktif seçim, parıltı, titreme) \*\*ayrı\*\* painter'lardır. Statik katman nadiren repaint olur; sadece animasyonlu katman her frame yeniden çizilir. Bu, her frame'de tüm grid'i yeniden çizmeyi önler.

# \- `shouldRepaint` her zaman doğru implement edilir; gereksiz `true` dönmek = ısınma:

# ```dart

# @override

# bool shouldRepaint(covariant GridPainter oldDelegate) {

# &#x20; // Statik katman: hücre durumu veya kalıcı board değişince

# &#x20; // Dinamik katman: pending placements, highlight, puan rozetleri değişince

# &#x20; return oldDelegate.board != board ||

# &#x20;     oldDelegate.pendingPlacements != pendingPlacements ||

# &#x20;     oldDelegate.highlightedWordId != highlightedWordId ||

# &#x20;     oldDelegate.scoreEvents != scoreEvents;

# }

# ```

# \- Animasyon değerleri için `Listenable` (AnimationController) painter constructor'ına `repaint:` parametresiyle geçer; `setState` ile rebuild \*\*yasak\*\* (painter `super(repaint: controller)`).

# \- Sürekli çalışan animasyon \*\*yok\*\*; her animasyon `AnimationController` ile başlar, biter, `dispose` edilir. Idle durumda 0 repaint hedeflenir (statik ekran = 0 fps redraw).

# \- Ölçüm: DevTools "Track Repaints" ile idle ekranda yeşil flash olmamalı.

# 

# \### 5.2 Liste Performansı

# \- `ListView` yerine `ListView.builder` (lazy).

# \- `const` widget'lar mümkün her yerde.

# \- Büyük listeler için `AutomaticKeepAliveClientMixin` yerine state'i parent'a taşı.

# 

# \### 5.3 Asset Optimizasyon

# \- PNG yerine WebP (ikonlar hariç).

# \- SVG → `flutter\_svg` paketinin \*\*cached\*\* versiyonu (raster cache).

# \- Görsel boyutu: 1x asset için tasarlanan boyutta; 2x/3x asset coğrafyaya göre.

# \- `precacheImage` ile splash'ta önemli görseller bellek'e alınır.

# 

# \### 5.4 Build Performansı

# \- Şube içi `print` yasak — `debugPrint` (kAssertion mode'da çalışır).

# \- Production build:

# ```bash

# flutter build apk --release --obfuscate --split-debug-info=build/symbols

# ```

# \- Tree shaking için `tree-shake-icons` aktif (default Flutter).

# \- ProGuard kuralları `android/app/proguard-rules.pro`.

# 

# \### 5.5 Memory

# \- Image cache:

# ```dart

# PaintingBinding.instance.imageCache.maximumSizeBytes = 100 << 20; // 100 MB

# ```

# \- Hive box'ları lazy open (sadece feature açıldığında).

# 

# \---

# 

# \## 6. Git ve Commit Disiplini

# 

# \### 6.1 Branch İsimlendirme

# ```

# main                        # production-ready

# develop                     # entegrasyon

# feature/gameplay-grid       # özellik

# fix/coin-display-overflow   # bug

# chore/upgrade-flutter-3.16  # bakım

# docs/update-architecture    # döküman

# ```

# 

# \### 6.2 Commit Mesajı (Conventional Commits)

# ```

# <type>(<scope>): <subject>

# 

# <body>

# 

# <footer>

# ```

# 

# \*\*Type:\*\*

# \- `feat` — yeni özellik

# \- `fix` — bug

# \- `refactor` — davranış değiştirmeden iyileştirme

# \- `perf` — performans

# \- `test` — sadece test

# \- `docs` — döküman

# \- `style` — format/linter (kod değil)

# \- `chore` — bağımlılık, build, config

# \- `ci` — pipeline

# 

# \*\*Örnek:\*\*

# ```

# feat(gameplay): add diagonal word selection support

# 

# \- Update GridPainter to render diagonal paths

# \- Add direction validation in WordValidatorService

# \- Cover with bloc + widget tests

# 

# Closes #42

# ```

# 

# \### 6.3 PR Kuralları

# \- Max \*\*400 satır\*\* değişiklik (test/auto-generated hariç).

# \- En az 1 reviewer (solo dev için: 24 saat soğuma süresi, sonra self-merge).

# \- PR template:

# ```markdown

# \## Ne yapıldı

# \## Nasıl test edildi

# \## Ekran görüntüsü (UI değişikliği varsa)

# \## Kontrol listesi

# \- \[ ] dart analyze 0 hata

# \- \[ ] Testler ekli/güncel

# \- \[ ] Türkçe karakter testi yapıldı

# \- \[ ] arb güncellemesi yapıldı (string ekledi/değiştirdiyse)

# \- \[ ] Performance bütçesi aşılmadı

# \- \[ ] CHANGELOG güncellendi (kullanıcıya yansıyan değişiklik varsa)

# ```

# 

# \### 6.4 Pre-commit Hook

# `.git/hooks/pre-commit`:

# ```bash

# \#!/bin/sh

# dart format --set-exit-if-changed --line-length 100 .

# dart analyze --fatal-infos

# flutter test

# ```

# 

# \---

# 

# \## 7. Lokalizasyon (.arb) Kuralları

# 

# \### 7.1 Anahtar İsimlendirme

# \- `screen\_action\_object` formatı: `menuButtonStart`, `gameplayActionRevealWord`

# \- Kısa keyler yasak: `ok`, `cancel` yerine `commonOk`, `commonCancel`

# 

# \### 7.2 Örnek arb

# ```json

# {

# &#x20; "@@locale": "tr",

# &#x20; "appTitle": "Kelime Hazinem",

# &#x20; "@appTitle": {

# &#x20;   "description": "Uygulama adı (splash + about ekranlarında)"

# &#x20; },

# 

# &#x20; "menuButtonStart": "Oyna",

# &#x20; "menuButtonShop": "Mağaza",

# 

# &#x20; "gameplayButtonConfirm": "Onayla",

# &#x20; "gameplayButtonPass": "Pas",

# &#x20; "gameplayButtonSwap": "Değiştir",

# &#x20; "gameplayButtonRevealWord": "Kelime",

# 

# &#x20; "gameplayToastPerfectFive": "Harikasın 🚀 Muhteşem 5'li",

# &#x20; "gameplayToastPerfectSix": "Etkileyici 🎉 Süper 6'lı",

# &#x20; "gameplayToastBonusPoints": "+{count} puan",

# &#x20; "@gameplayToastBonusPoints": {

# &#x20;   "placeholders": {

# &#x20;     "count": {"type": "int"}

# &#x20;   }

# &#x20; },

# 

# &#x20; "gameplayRevealWordDialogTitle": "Kelimeyi Göster",

# &#x20; "gameplayRevealWordDialogBody": "Bu ipucunu kullanmak istiyor musun?",

# &#x20; "gameplayRevealWordDialogAction": "Kelimeyi Aç",

# 

# &#x20; "gameplaySwapSheetTitle": "Harfleri Değiştir",

# &#x20; "gameplaySwapSheetBody": "Değiştirmek istediğin en fazla 5 harfi seç.",

# &#x20; "gameplaySwapSheetAction": "Değiştir",

# 

# &#x20; "gameplayBotThinking": "{botName} düşünüyor...",

# &#x20; "@gameplayBotThinking": {

# &#x20;   "placeholders": {

# &#x20;     "botName": {"type": "String"}

# &#x20;   }

# &#x20; },

# 

# &#x20; "gameResultWin": "Kazandın!",

# &#x20; "gameResultLose": "Kaybettin!",

# &#x20; "gameResultSubtitle": "Rakibini geçtin. Yarın yeni bir karşılaşma seni bekliyor.",

# &#x20; "gameResultPointDiff": "+{diff} puan fark",

# &#x20; "@gameResultPointDiff": {

# &#x20;   "placeholders": {

# &#x20;     "diff": {"type": "int"}

# &#x20;   }

# &#x20; },

# 

# &#x20; "matchmakingTitle": "Bugün Rakibin",

# &#x20; "matchmakingPlayButton": "Oyuna Başla"

# }

# ```

# 

# 

# \### 7.3 Kullanım

# ```dart

# final l10n = AppLocalizations.of(context);

# Text(l10n.gameplayButtonConfirm),

# Text(l10n.gameplayBotThinking(botProfile.name)),

# Text(l10n.gameplayToastBonusPoints(5)),

# ```

# 

# 

# `Text('Oyna')` formunda hardcoded \*\*yasak\*\*. CI'da regex ile kontrol edilebilir.

# 

# \---

# 

# \## 8. Python (Puzzle Generator) Standartları

# 

# \### 8.1 Stil

# \- Python 3.11+

# \- Type hint \*\*zorunlu\*\* her public fonksiyonda

# \- `ruff` linter + `black` formatter

# \- `mypy --strict` 0 hata

# 

# \### 8.2 Klasör

# ```

# tools/puzzle\_generator/          # (eski: level\_generator)

# ├── pyproject.toml

# ├── src/

# │   └── kelime\_gen/

# │       ├── \_\_init\_\_.py

# │       ├── schema.py            # Pydantic v2 — puzzle JSON şema v2

# │       ├── word\_pool.py         # TDK kelime havuzu + küfür filtresi (KORUNDU)

# │       ├── mask\_template.py     # Mask şablonu yükle + transform

# │       ├── csp\_filler.py        # AC-3 + backtracking CSP fill

# │       ├── clue\_writer.py       # TDK/LLM/placeholder ipucu

# │       ├── post\_fill\_safety.py  # Küfür tarama — yatay+dikey (KORUNDU)

# │       ├── difficulty.py        # Zorluk skoru

# │       ├── generator.py         # Orkestratör: mask → fill → ipucu → doğrula

# │       └── \_\_main\_\_.py          # Typer CLI

# ├── templates/                   # Elle tasarlanmış mask şablonları

# │   ├── small\_\*.json  (6×5)

# │   ├── medium\_\*.json (8×6)

# │   └── large\_\*.json  (10×7)

# ├── data/

# │   ├── raw/          # tdk\_words.txt, profanity\_blacklist.txt (KORUNDU)

# │   └── processed/    # word\_pool\_cleaned.json

# └── tests/

# ```

# 

# \### 8.3 pyproject.toml

# ```toml

# \[project]

# name = "kelime-gen"

# version = "2.0.0"

# requires-python = ">=3.11"

# dependencies = \[

# &#x20;   "pydantic>=2.5",

# &#x20;   "typer>=0.9",

# &#x20;   "rich>=13.7",

# ]

# 

# \[project.optional-dependencies]

# dev = \["pytest>=7", "ruff>=0.1", "black>=23", "mypy>=1.7"]

# 

# \[tool.pytest.ini\_options]

# pythonpath = \["src"]

# 

# \[tool.ruff]

# line-length = 100

# target-version = "py311"

# 

# \[tool.black]

# line-length = 100

# 

# \[tool.mypy]

# strict = true

# ```

# 

# \### 8.4 CLI (typer)

# ```python

# \# src/kelime\_gen/\_\_main\_\_.py

# import typer

# from pathlib import Path

# from typing import Annotated

# 

# app = typer.Typer()

# 

# @app.callback()

# def \_callback() -> None:

# &#x20;   """Türkçe Kelime Bulmaca puzzle generator."""

# 

# @app.command()

# def generate(

# &#x20;   count: Annotated\[int, typer.Option(help="Üretilecek bölüm sayısı")] = 200,

# &#x20;   output\_dir: Annotated\[Path, typer.Option(help="Çıktı klasörü")] = Path("assets/puzzles"),

# &#x20;   size: Annotated\[str, typer.Option(help="small | medium | large | all")] = "all",

# ) -> None:

# &#x20;   """Bulmaca bölümlerini üretir ve JSON olarak yazar."""

# &#x20;   ...

# 

# if \_\_name\_\_ == "\_\_main\_\_":

# &#x20;   \_main()

# 

# def \_main() -> None:

# &#x20;   import sys, io

# &#x20;   if hasattr(sys.stdout, "buffer"):

# &#x20;       sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8")

# &#x20;   if hasattr(sys.stderr, "buffer"):

# &#x20;       sys.stderr = io.TextIOWrapper(sys.stderr.buffer, encoding="utf-8")

# &#x20;   app()

# ```

# 

# Kullanım:

# ```bash

# cd tools/puzzle\_generator

# python -m kelime\_gen generate --count 200 --size medium

# ```

# 

# \### 8.5 Türkçe İşleme (Python)

# ```python

# TR\_UPPER\_MAP = str.maketrans("iı", "İI")

# TR\_LOWER\_MAP = str.maketrans("İI", "iı")

# 

# def tr\_upper(text: str) -> str:

# &#x20;   return text.translate(TR\_UPPER\_MAP).upper()

# 

# def tr\_lower(text: str) -> str:

# &#x20;   return text.translate(TR\_LOWER\_MAP).lower()

# ```

# `str.upper()` / `str.lower()` \*\*doğrudan yasak\*\* — her zaman `tr\_upper`/`tr\_lower` kullan.

# 

# \### 8.6 Çıktı Doğrulama

# \- Her üretilen bölüm pydantic v2 ile parse edilir (schema v2).

# \- `safety.post\_fill\_scanned = true` zorunlu — model\_validator ile guarantee.

# \- CI: tüm `assets/puzzles/\*.json` dosyaları Flutter parse testinden geçer.

# 

# \### 8.7 Hata ve Exit Code Kuralları (Sessiz Başarı Yasak)

# \- Bölüm üretimi başarısız → `PuzzleGenerationError` fırlat, `stderr`'e yaz, dosyaya yazma.

# \- Üretim bittikten sonra herhangi başarısız bölüm varsa `sys.exit(1)` — CI kırmızı.

# \- `sys.exit(0)` yalnızca \*\*tüm\*\* istenen bölümler üretildiğinde.

# \- `safety.post\_fill\_scanned = False` olan bölüm JSON'a \*\*asla\*\* yazılamaz:

# 

# ```python

# \# schema.py içinde PuzzleData modeline ekle

# from pydantic import model\_validator

# 

# @model\_validator(mode="after")

# def require\_safety\_scan(self) -> "PuzzleData":

# &#x20;   if not self.safety.post\_fill\_scanned:

# &#x20;       raise ValueError("Puzzle cannot be saved without post-fill safety scan")

# &#x20;   return self

# ```

# 

# \- Küfür tarama: yatay + dikey diziler (çapraz opsiyonel). Küfür bulunursa CSP

# &#x20; yeniden denenir (farklı kelime seti); 3×5=15 denemede de başarısızsa `PuzzleGenerationError`.

# 

# \### 8.8 UTF-8 Konsol (Windows)

# `\_force\_utf8\_stdout()` yalnızca CLI giriş noktasında (`\_main()` içinde), \*\*modül tepesinde değil\*\*

# (pytest capture'ını bozar):

# ```python

# def \_force\_utf8\_stdout() -> None:

# &#x20;   import sys, io

# &#x20;   if hasattr(sys.stdout, "buffer"):

# &#x20;       sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8")

# &#x20;   if hasattr(sys.stderr, "buffer"):

# &#x20;       sys.stderr = io.TextIOWrapper(sys.stderr.buffer, encoding="utf-8")

# ```

# 

# \## 9. Android Native Yapılandırma Notları

# 

# \### 9.1 allowBackup — Şifreli Hive Çökmesini Önleme (ZORUNLU)

# 

# `Auto-Backup` açıkken uygulama silinip tekrar kurulursa Google Drive eski şifreli `.hive` dosyalarını geri yükler; Keystore AES anahtarı gitmiştir → `HiveError` → \*\*açılışta çökme.\*\*

# 

# `AndroidManifest.xml`'de proje oluşturulur oluşturulmaz ayarla:

# ```xml

# <!-- android/app/src/main/AndroidManifest.xml -->

# <application

# &#x20;   android:allowBackup="false"

# &#x20;   android:fullBackupContent="false"

# &#x20;   ...>

# ```

# \- Unutulursa Flutter projesi oluşturulduğunda \*\*ilk iş\*\* bu. v1.1 hesap sistemi gelince yeniden değerlendirilir.

# 

# \### 9.2 ProGuard / R8

# ```

# \# android/app/proguard-rules.pro

# \-keep class com.hive.\*\* { \*; }

# \-keep class io.hive.\*\* { \*; }

# ```

# AdMob / AppLovin MAX kütüphanelerinin `consumerProguardFiles` ile kendi kurallarını dahil ettiğini kontrol et.

# 

# \---

# 

# \## 10. Erişilebilirlik Standartları

# 

# \- Minimum dokunma alanı: \*\*48×48 dp\*\*.

# \- Font ölçeklendirme: kullanıcının sistem ayarlarına uyum (`MediaQuery.textScalerOf(context)`).

# \- Renk kontrastı: WCAG AA (4.5:1 metin, 3:1 large text).

# \- `Semantics` widget'ı butonlarda anlamlı label ile:

# ```dart

# Semantics(

# &#x20; label: 'Harf aç ipucu, 50 coin',

# &#x20; button: true,

# &#x20; child: HintButton(...),

# )

# ```

# \- Renk + ikon zorunlu (sadece renkle ayrım yasak).

# \- Dark mode tam destek.

# 

# \---

# 

# \## 11. Güvenlik

# 

# \### 11.1 Secret Yönetimi

# \- API key / SDK key \*\*kod içinde yok\*\* — `--dart-define` ile inject.

# \- `.env` dosyaları `.gitignore`'da.

# \- Production secret'lar CI/CD secret manager'da (GitHub Actions secrets, Codemagic env).

# 

# \### 11.2 IAP Doğrulama

# \- MVP'de local validation (`purchases\_flutter` SDK'sı zaten platform'a sorar).

# \- Receipt cache Hive'da, ama tampering riski kabul ediliyor (hesap sistemi yok).

# \- v2.0: kendi backend ile server-side validation.

# 

# \### 11.3 Bağımlılık Güvenliği

# \- `flutter pub outdated` haftalık çalıştırılır.

# \- Major version bump'ları PR ile, değişim notu CHANGELOG'da.

# \- `dart pub deps --style=compact` ile transitive dep audit.

# 

# \---

# 

# \## 12. Dokümantasyon Standartları

# 

# \### 11.1 Kod Yorumu (dartdoc)

# Public API'ler için zorunlu:

# ```dart

# /// Loads a level by its global ID from local assets.

# ///

# /// Throws \[PuzzleNotFoundException] if the puzzle ID is not in the manifest.

# ///

# /// Example:

# /// ```dart

# /// final puzzle = await repo.loadPuzzle(42);

# /// ```

# Future<PuzzleData> loadPuzzle(int puzzleId);

# ```

# 

# \### 11.2 README'ler

# Her `feature/` klasöründe \*\*opsiyonel\*\* kısa README. Özellik karmaşıksa zorunlu.

# 

# \### 11.3 ADR (Architecture Decision Records)

# Mimari kararlar `docs/adr/` altında numaralı markdown dosyalarında:

# \- `0001-flutter-over-react-native.md`

# \- `0002-bloc-over-provider.md`

# \- `0003-hive-over-sqflite.md`

# 

# Şablon:

# ```markdown

# \# 0001: Flutter over React Native

# 

# Status: Accepted

# Date: 2026-05-15

# 

# \## Context

# ...

# 

# \## Decision

# ...

# 

# \## Consequences

# ...

# ```

# 

# \---

# 

# \## 13. CI/CD (Önerilen)

# 

# GitHub Actions iş akışı (`.github/workflows/ci.yml`):

# 

# ```yaml

# name: CI

# 

# on:

# &#x20; pull\_request:

# &#x20; push:

# &#x20;   branches: \[main, develop]

# 

# jobs:

# &#x20; flutter:

# &#x20;   runs-on: ubuntu-latest

# &#x20;   steps:

# &#x20;     - uses: actions/checkout@v4

# &#x20;     - uses: subosito/flutter-action@v2

# &#x20;       with:

# &#x20;         flutter-version: '3.x'

# &#x20;         channel: stable

# &#x20;     - run: flutter pub get

# &#x20;     - run: dart format --set-exit-if-changed --line-length 100 .

# &#x20;     - run: flutter analyze --fatal-infos

# &#x20;     - run: flutter test --coverage

# &#x20;     - uses: codecov/codecov-action@v3

# &#x20; 

# &#x20; python:

# &#x20;   runs-on: ubuntu-latest

# &#x20;   steps:

# &#x20;     - uses: actions/checkout@v4

# &#x20;     - uses: actions/setup-python@v5

# &#x20;       with:

# &#x20;         python-version: '3.11'

# &#x20;     - working-directory: tools/puzzle\_generator

# &#x20;       run: |

# &#x20;         pip install -e ".\[dev]"

# &#x20;         ruff check .

# &#x20;         black --check .

# &#x20;         mypy src/

# &#x20;         pytest

# ```

# 

# \---

# 

# \## 14. Release Süreci

# 

# \### 13.1 Versiyonlama

# SemVer: `MAJOR.MINOR.PATCH+BUILD`

# \- `1.0.0+1` → ilk lansman

# \- `1.0.1+2` → bug fix

# \- `1.1.0+5` → yeni özellik (günlük puzzle vb.)

# 

# `pubspec.yaml`'daki version tek kaynak; `flutter build` build number'ı otomatik geçirir.

# 

# \### 13.2 CHANGELOG

# \[Keep a Changelog](https://keepachangelog.com/) formatı:

# ```markdown

# \## \[1.1.0] - 2026-08-15

# 

# \### Added

# \- Günlük puzzle özelliği

# \- 50 yeni hayvan kategorisi bölümü

# 

# \### Changed

# \- İpucu fiyatları dengelendi (Harf Aç 60 → 50 coin)

# 

# \### Fixed

# \- Bazı cihazlarda grid çizimi taşması (#123)

# ```

# 

# \### 13.3 Release Notes (Mağaza için)

# `fastlane/metadata/tr/release\_notes.txt`:

# ```

# \- 50 yeni bölüm: Hayvanlar kategorisi

# \- Günlük puzzle: her gün yeni bir bulmaca

# \- Çeşitli hatalar giderildi

# ```

# 

# \---

# 

# \## 15. Hızlı Referans (Cheatsheet)

# 

# ```dart

# // Türkçe lokal

# 'KELİME'.toLowerCase(Locale('tr')); // ✅

# 'KELİME'.toLowerCase(); // ❌

# 

# // Async-safe context

# if (!mounted) return;

# 

# // Hive box açma

# final box = await Hive.openBox<UserProgress>('user\_progress');

# 

# // Bloc test

# blocTest<MyBloc, MyState>(...)

# 

# // String externalization

# Text(AppLocalizations.of(context).menuButtonStart)

# 

# // Color

# AppColors.primary

# 

# // Logging

# debugPrint('\[GameplayBloc] level loaded: ${event.levelId}');

# 

# // Env

# const apiKey = String.fromEnvironment('REVENUECAT\_KEY', defaultValue: '');

# ```

# 

# \---

# 

# \## 16. Versiyon Geçmişi

# 

# | Sürüm | Tarih | Değişiklik |

# |---|---|---|

# | 1.0 | 2026-05 | İlk taslak; lint, naming, test, git, lokalizasyon, CI/CD |

# | 3.0 | 2026-05 | `always\_use\_package\_imports` lint; Bloc/Cubit ayrımı + Cubit şablonu; CustomPainter iki-katman optimizasyonu (Flame çıktığı için manuel sorumluluk) |

# | 4.1 | 2026-05 | Oyun mekaniği word-search → Cross Up. GameBloc şablonu (GameplayBloc→GameBloc, word-search event'leri→PlaceLetter/ConfirmMove/BotMoveCompleted); §4.2 test şablonu v4.1 event'leriyle; §7.2 .arb anahtarları Cross Up UI'ye göre (Kelime Aç/Değiştir/BotThinking); §8 Python tamamen yeniden (level\_generator→puzzle\_generator, backtracking→CSP/AC-3+mask, eski şema→v2); §5.1 shouldRepaint board/pendingPlacements/highlightedWordId'ye güncellendi; LevelNotFoundException→PuzzleNotFoundException; save-scumming önlemi notları eklendi |

