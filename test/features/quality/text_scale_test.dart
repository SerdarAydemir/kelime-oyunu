// test/features/quality/text_scale_test.dart
//
// Large-font pass (system text scale 1.3 and 1.6): every screen must lay out
// without overflow; the board and rack glyphs stay unscaled (fixed geometry).

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:kelime_oyunu/core/services/consent_service.dart';
import 'package:kelime_oyunu/core/services/purchase_service.dart';
import 'package:kelime_oyunu/data/models/puzzle.dart';
import 'package:kelime_oyunu/data/repositories/progress_repository.dart';
import 'package:kelime_oyunu/data/repositories/session_repository.dart';
import 'package:kelime_oyunu/data/repositories/settings_repository.dart';
import 'package:kelime_oyunu/features/gameplay/bloc/game_state.dart';
import 'package:kelime_oyunu/features/gameplay/engine/rack_manager.dart';
import 'package:kelime_oyunu/features/gameplay/widgets/action_bar.dart';
import 'package:kelime_oyunu/features/gameplay/widgets/clue_sheet.dart';
import 'package:kelime_oyunu/features/gameplay/widgets/level_top_bar.dart';
import 'package:kelime_oyunu/features/gameplay/widgets/rack_widget.dart';
import 'package:kelime_oyunu/features/gameplay/widgets/score_header.dart';
import 'package:kelime_oyunu/features/gameplay/widgets/swap_sheet.dart';
import 'package:kelime_oyunu/features/gameplay/widgets/turn_pill.dart';
import 'package:kelime_oyunu/features/home/view/home_screen.dart';
import 'package:kelime_oyunu/features/map/view/climb_map_screen.dart';
import 'package:kelime_oyunu/features/onboarding/view/onboarding_screen.dart';
import 'package:kelime_oyunu/features/result/view/result_screen.dart';
import 'package:kelime_oyunu/features/settings/cubit/settings_cubit.dart';
import 'package:kelime_oyunu/features/settings/view/settings_screen.dart';
import 'package:kelime_oyunu/features/shop/view/shop_screen.dart';

// Relative import — test helpers are not importable via package: path.
// ignore: always_use_package_imports
import '../../helpers/localized_app.dart';

// ignore_for_file: prefer_const_constructors

const _rack = [RackTile(letter: 'K'), RackTile(letter: 'O'), RackTile(letter: 'L')];

Widget _withCubit(Widget child) => BlocProvider(
  create: (_) => SettingsCubit(repository: InMemorySettingsRepository()),
  child: child,
);

/// The game screen's chrome around the board, as the real screen stacks it.
Widget _gameChrome() => Scaffold(
  body: SafeArea(
    child: Column(
      children: [
        LevelTopBar(levelId: 12, onExit: () {}),
        const ScoreHeader(playerScore: 123, botScore: 98, botName: 'Rakip', botThinking: true),
        TurnPill(spec: (text: 'Rakip düşünüyor', tint: TurnTint.bot, dots: true)),
        const Spacer(),
        RackWidget(
          rack: _rack,
          selectedIndex: 0,
          showPlusSlot: true,
          showAdLabel: true,
          onTileTap: (_) {},
          onTileRecall: (_) {},
        ),
        ActionBar(
          pendingPlacements: const [],
          onConfirm: () {},
          onPass: () {},
          onSwap: () {},
          onReveal: () {},
          showAdLabel: true,
        ),
      ],
    ),
  ),
);

const _clues = [
  (
    clue: ClueSpec(text: 'Farklı renklerde', arrow: ClueArrow.down, wordId: 'w1', source: 't'),
    length: 5,
  ),
  (
    clue: ClueSpec(text: 'Futbolda atlanamayan', arrow: ClueArrow.right, wordId: 'w2', source: 't'),
    length: 3,
  ),
];

void main() {
  // 390 × 844 dp reference phone.
  setUp(() {
    // ignore: deprecated_member_use
    TestWidgetsFlutterBinding.ensureInitialized().window.physicalSizeTestValue = const Size(
      1170,
      2532,
    );
    // ignore: deprecated_member_use
    TestWidgetsFlutterBinding.ensureInitialized().window.devicePixelRatioTestValue = 3;
  });

  for (final scale in [1.3, 1.6]) {
    group('text scale $scale', () {
      Future<void> pumpHome(WidgetTester tester, Widget home) async {
        await tester.pumpWidget(_withCubit(localizedApp(home: home, textScale: scale)));
        await tester.pump(const Duration(milliseconds: 400));
        expect(tester.takeException(), isNull);
      }

      testWidgets('home', (tester) async {
        await pumpHome(
          tester,
          HomeScreen(
            progressRepo: InMemoryProgressRepository(highestCompletedLevel: 58),
            sessionRepo: InMemorySessionRepository(),
          ),
        );
      });

      testWidgets('map', (tester) async {
        await pumpHome(
          tester,
          ClimbMapScreen(progressRepo: InMemoryProgressRepository(highestCompletedLevel: 7)),
        );
      });

      testWidgets('game chrome', (tester) async {
        await pumpHome(tester, _gameChrome());
        // Fixed-geometry glyphs ignore the system scale.
        final tile = tester.widget<Text>(find.text('K'));
        expect(tile.textScaler, TextScaler.noScaling);
      });

      testWidgets('clue sheet and swap sheet', (tester) async {
        await pumpHome(
          tester,
          Scaffold(
            body: ClueSheet(cell: const WordCell(row: 0, col: 2), entries: _clues),
          ),
        );
        await pumpHome(
          tester,
          Scaffold(body: SwapSheet(rack: _rack, quotaRemaining: 12, showAdLabel: true)),
        );
      });

      testWidgets('settings, shop, onboarding', (tester) async {
        await pumpHome(
          tester,
          SettingsScreen(
            progressRepo: InMemoryProgressRepository(),
            sessionRepo: InMemorySessionRepository(),
            consentService: const MockConsentService(),
          ),
        );
        await pumpHome(
          tester,
          ShopScreen(
            progressRepo: InMemoryProgressRepository(),
            purchases: const MockPurchaseService(),
          ),
        );
        await pumpHome(tester, const OnboardingScreen(firstRun: true));
      });

      testWidgets('result', (tester) async {
        final router = GoRouter(
          initialLocation: '/result/5',
          routes: [
            GoRoute(
              path: '/result/:levelId',
              builder: (_, _) => const ResultScreen(
                status: GameStatus.won,
                levelId: 5,
                playerScore: 12,
                botScore: 9,
                botName: 'Rakip',
              ),
            ),
          ],
        );
        await tester.pumpWidget(_withCubit(localizedRouterApp(router, textScale: scale)));
        await tester.pump(const Duration(milliseconds: 400));
        expect(tester.takeException(), isNull);
      });
    });
  }
}
