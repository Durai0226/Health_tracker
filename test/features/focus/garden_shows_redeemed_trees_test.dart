/// A tree added with coins is in the garden.
///
/// Redeeming spent the coins and wrote the tree down, and the Garden screen drew
/// only what sessions had grown — so the garden a person had paid into had none
/// of it in it, and "My Garden" with nothing but a redeemed tree was the empty
/// state.
library;

import 'package:clock/clock.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' show AppDatabase;
import 'package:tablet_remainder/core/services/audio_service.dart';
import 'package:tablet_remainder/core/services/clean_storage_service.dart';
import 'package:tablet_remainder/features/focus/models/focus_coins.dart';
import 'package:tablet_remainder/features/focus/models/focus_plant.dart';
import 'package:tablet_remainder/features/focus/screens/focus_garden_screen.dart';
import 'package:tablet_remainder/features/focus/services/coins_service.dart';
import 'package:tablet_remainder/features/focus/services/focus_service.dart';
import 'package:tablet_remainder/features/focus/services/tag_service.dart';

import '../../support/fake_audio_engine.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  late AppDatabase db;
  final now = DateTime(2026, 9, 30, 11, 0);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    AppDatabase.setInstanceForTesting(db);
    CleanStorageService.resetForTesting();
    await CleanStorageService.loadAppPreferences();
    AudioService().engineForTesting = FakeAudioEngine();
    FocusService().resetForTesting();
    CoinsService().resetForTesting();
    TagService().resetForTesting();
  });

  tearDown(() async {
    FocusService().resetForTesting();
    CoinsService().resetForTesting();
    await db.close();
  });

  RealTreePlanting tree(String id, RealTreeType type, DateTime at) =>
      RealTreePlanting(id: id, treeType: type, plantedAt: at, coinsCost: type.coinCost);

  Future<void> seed({
    List<RealTreePlanting> trees = const [],
    List<FocusPlant> plants = const [],
    int coins = 0,
  }) async {
    if (plants.isNotEmpty) {
      await CleanStorageService.setAppPreference(
          'focusGarden', [for (final p in plants) p.toJson()]);
    }
    await CleanStorageService.setAppPreference(
        'focusCoins',
        FocusCoins(
          totalCoins: coins,
          lifetimeCoins: coins,
          plantedTrees: trees,
        ).toJson());
    await FocusService().init();
    await CoinsService().init();
  }

  Future<void> open(WidgetTester tester, {double width = 411, double scale = 1}) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = Size(width, 1400);
    tester.platformDispatcher.textScaleFactorTestValue = scale;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    addTearDown(tester.view.reset);
    final prev = FlutterError.onError;
    FlutterError.onError = (d) {
      if (!'${d.exception}'.contains('overflowed')) prev?.call(d);
    };
    addTearDown(() => FlutterError.onError = prev);
    await tester.pumpWidget(const MaterialApp(home: FocusGardenScreen()));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 350));
  }

  FocusPlant plant(String id, DateTime at, {int minutes = 25}) => FocusPlant(
        id: id,
        type: PlantType.values.first,
        plantedAt: at,
        durationMinutes: minutes,
        isAlive: true,
        growthProgress: 1,
      );

  testWidgets('a garden with only a redeemed tree is not the empty garden',
      (tester) async {
    await withClock(Clock.fixed(now), () async {
      await seed(trees: [tree('t1', RealTreeType.oak, DateTime(2026, 9, 29, 18, 30))]);
      await open(tester);

      expect(find.text('Your garden grows as you focus'), findsNothing);
      expect(find.text('Added with coins'), findsOneWidget);
      expect(find.text('Oak Tree'), findsOneWidget);
      expect(find.text('500 coins'), findsOneWidget);
      expect(find.text('Sep 29 · 6:30 PM'), findsOneWidget);
      expect(find.text('1 tree'), findsOneWidget);
      expect(find.text('0 alive • 0 withered • 1 added'), findsOneWidget);
    });
  });

  testWidgets('several are listed newest first, and counted in the plural',
      (tester) async {
    await withClock(Clock.fixed(now), () async {
      await seed(trees: [
        tree('old', RealTreeType.bamboo, DateTime(2026, 9, 1, 9)),
        tree('new', RealTreeType.maple, DateTime(2026, 9, 29, 9)),
        tree('mid', RealTreeType.pine, DateTime(2026, 9, 15, 9)),
      ]);
      await open(tester);

      expect(find.text('3 trees'), findsOneWidget);
      final order = [
        for (final name in ['Maple Tree', 'Pine Tree', 'Bamboo Grove'])
          tester.getTopLeft(find.text(name)).dy
      ];
      expect(order, [...order]..sort(),
          reason: 'newest at the top: maple, then pine, then bamboo');
    });
  });

  testWidgets('they sit above the days the sessions grew, and both are there',
      (tester) async {
    await withClock(Clock.fixed(now), () async {
      await seed(
        trees: [tree('t1', RealTreeType.cherry, DateTime(2026, 9, 28, 20))],
        plants: [plant('p1', DateTime(2026, 9, 28, 10, 15), minutes: 35)],
      );
      await open(tester);

      expect(find.text('35m'), findsOneWidget, reason: 'the session is still there');
      expect(find.text('Cherry Tree'), findsOneWidget);
      expect(tester.getTopLeft(find.text('Added with coins')).dy,
          lessThan(tester.getTopLeft(find.text('35m')).dy));
      expect(find.text('1 alive • 0 withered • 1 added'), findsOneWidget);
    });
  });

  testWidgets('with none redeemed, nothing about them is shown', (tester) async {
    await withClock(Clock.fixed(now), () async {
      await seed(plants: [plant('p1', DateTime(2026, 9, 28, 10, 15))]);
      await open(tester);

      expect(find.text('Added with coins'), findsNothing);
      expect(find.text('1 alive • 0 withered'), findsOneWidget,
          reason: 'and the line under the title does not mention them');
    });
  });

  testWidgets('a tree redeemed while the garden is open appears in it',
      (tester) async {
    await withClock(Clock.fixed(now), () async {
      await seed(
          plants: [plant('p1', DateTime(2026, 9, 28, 10, 15))], coins: 300);
      await open(tester);
      expect(find.text('Added with coins'), findsNothing);

      await tester.runAsync(
          () => CoinsService().redeemGardenTree(RealTreeType.bamboo));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Added with coins'), findsOneWidget);
      expect(find.text('Bamboo Grove'), findsOneWidget);
      expect(find.text('200 coins'), findsOneWidget);
    });
  });

  for (final (width, scale) in [(320.0, 1.0), (320.0, 2.0)]) {
    testWidgets('fits $width wide at ${scale}x text', (tester) async {
      await withClock(Clock.fixed(now), () async {
        // Trees alone: with sessions the header also carries a row of species
        // counts, whose own 2px fit at 320 is not what is being measured here.
        await seed(trees: [
          tree('a', RealTreeType.rainforest, DateTime(2026, 9, 29, 9)),
          tree('b', RealTreeType.mangrove, DateTime(2026, 9, 1, 9)),
        ]);
        final errors = <FlutterErrorDetails>[];
        final prev = FlutterError.onError;
        tester.view.devicePixelRatio = 1.0;
        tester.view.physicalSize = Size(width, 1400);
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        addTearDown(tester.view.reset);
        FlutterError.onError = errors.add;
        try {
          await tester.pumpWidget(const MaterialApp(home: FocusGardenScreen()));
          await tester.pump(const Duration(milliseconds: 50));
          await tester.pump(const Duration(milliseconds: 350));
        } finally {
          FlutterError.onError = prev;
        }
        expect(errors.where((e) => '${e.exception}'.contains('overflowed')), isEmpty);

        // No overflow error is not the same as fitting: a cost that does not
        // shrink is clipped off the edge of the row instead of reported.
        final cost = tester.getRect(find.text('550 coins'));
        final name = tester.getRect(find.text('Rainforest Tree'));
        expect(cost.right, lessThanOrEqualTo(width),
            reason: 'the cost runs off the right edge of the screen');
        expect(cost.left, greaterThanOrEqualTo(name.right - 0.5),
            reason: 'the cost sits over the name');
        expect(
            tester
                .widget<FittedBox>(find
                    .ancestor(
                        of: find.text('550 coins'), matching: find.byType(FittedBox))
                    .first)
                .fit,
            BoxFit.scaleDown,
            reason: 'a cost that is merely clipped reads "550 co" at large text, and '
                'no overflow is reported for it: it has to shrink instead');
      });
    });
  }
}
