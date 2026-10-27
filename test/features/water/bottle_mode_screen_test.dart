/// Your bottle: set its size once, then "Finished" and "Half" log it in one tap.
library;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' as db;
import 'package:tablet_remainder/core/health/bottle_mode.dart';
import 'package:tablet_remainder/core/services/clean_storage_service.dart';
import 'package:tablet_remainder/core/theme/app_theme.dart';
import 'package:tablet_remainder/features/water/models/hydration_profile.dart';
import 'package:tablet_remainder/features/water/screens/aqua_water_dashboard.dart';
import 'package:tablet_remainder/features/water/services/water_bottle.dart';
import 'package:tablet_remainder/features/water/services/water_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  late db.AppDatabase database;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    database = db.AppDatabase.forTesting(NativeDatabase.memory());
    db.AppDatabase.setInstanceForTesting(database);
    CleanStorageService.resetForTesting();
    await CleanStorageService.init();
    WaterService.clearInMemory();
    await WaterService.resetForTesting();
    await WaterService.init();
  });

  tearDown(() async => database.close());

  Future<void> pumpFor(WidgetTester tester, [int n = 6]) async {
    for (var i = 0; i < n; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> open(WidgetTester tester, {double width = 390}) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = Size(width, 3000);
    addTearDown(tester.view.reset);
    final prev = FlutterError.onError;
    FlutterError.onError = (_) {};
    try {
      await tester.pumpWidget(MaterialApp(
          theme: AppTheme.lightTheme, home: const AquaWaterDashboard()));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 400));
    } finally {
      FlutterError.onError = prev;
    }
  }

  Future<void> reveal(WidgetTester tester, Finder f) => tester.scrollUntilVisible(
      f, 200, scrollable: find.byType(Scrollable).first);

  int totalMl() => WaterService.getTodayData().totalIntakeMl;

  group('the size', () {
    test('none until set', () {
      expect(WaterBottle.sizeMl, isNull);
    });

    test('kept, and forgotten', () async {
      await WaterBottle.setSize(750);
      expect(WaterBottle.sizeMl, 750);
      await WaterBottle.setSize(null);
      expect(WaterBottle.sizeMl, isNull);
    });

    test('a size the sheet could not make is not stored', () async {
      await WaterBottle.setSize(750);
      await WaterBottle.setSize(725);
      expect(CleanStorageService.getAppPreference('water_bottle_ml', 0), 750,
          reason: 'the earlier size is kept, and 725 never written');
      await WaterBottle.setSize(5000);
      expect(CleanStorageService.getAppPreference('water_bottle_ml', 0), 750);
    });

    test('and one that arrives some other way is not believed', () async {
      await CleanStorageService.setAppPreference('water_bottle_ml', 725);
      expect(WaterBottle.sizeMl, isNull);
      await CleanStorageService.setAppPreference('water_bottle_ml', 'big');
      expect(WaterBottle.sizeMl, isNull);
    });
  });

  testWidgets('before a size is set, an offer to set one', (tester) async {
    await open(tester);
    await reveal(tester, find.text('Set bottle'));
    expect(find.textContaining('Drink from a bottle?'), findsOneWidget);
    expect(find.text('Finished'), findsNothing);
  });

  testWidgets('setting the size turns the card on', (tester) async {
    await open(tester);
    await reveal(tester, find.text('Set bottle'));
    await tester.tap(find.text('Set bottle'));
    await pumpFor(tester);

    expect(find.text('Your bottle'), findsOneWidget);
    expect(find.text('500 ml'), findsOneWidget, reason: 'it starts at 500');
    await tester.tap(find.byTooltip('Larger bottle'));
    await tester.pump();
    await tester.tap(find.byTooltip('Larger bottle'));
    await tester.pump();
    expect(find.text('600 ml'), findsOneWidget);

    await tester.tap(find.text('Save'));
    await pumpFor(tester, 8);

    expect(WaterBottle.sizeMl, 600);
    expect(find.text('Your bottle · 600 ml'), findsOneWidget);
    expect(find.text('Finished'), findsOneWidget);
    expect(find.text('Half'), findsOneWidget);
  });

  testWidgets('"Finished" logs the whole bottle, with an Undo', (tester) async {
    await WaterBottle.setSize(750);
    await open(tester);
    await reveal(tester, find.text('Finished'));
    expect(totalMl(), 0);

    await tester.tap(find.text('Finished'));
    await pumpFor(tester, 10);
    expect(totalMl(), 750);
    expect(find.textContaining('+750ml'), findsOneWidget);

    await tester.tap(find.text('Undo'));
    await pumpFor(tester, 10);
    expect(totalMl(), 0);
  });

  testWidgets('"Half" logs half, to the nearest 10 ml', (tester) async {
    await WaterBottle.setSize(750);
    await open(tester);
    await reveal(tester, find.text('Half'));
    await tester.tap(find.text('Half'));
    await pumpFor(tester, 10);
    expect(totalMl(), 380);
  });

  testWidgets('says how many bottles are left of the goal', (tester) async {
    await WaterBottle.setSize(500);
    await open(tester);
    await reveal(tester, find.text('Finished'));
    final goal = WaterService.getDailyGoal();
    final n = (goal / 500).round();
    expect(find.text('About $n bottles to go'), findsOneWidget,
        reason: 'goal $goal ml in 500 ml bottles');

    await tester.tap(find.text('Finished'));
    await pumpFor(tester, 10);
    final after = BottleMode.toGo(remainingMl: goal - 500, bottleMl: 500)!;
    final before = BottleMode.toGo(remainingMl: goal, bottleMl: 500)!;
    expect(after, isNot(before), reason: 'the test needs a bottle to make a difference');
    expect(find.text(after), findsOneWidget);
  });

  testWidgets('the size can be changed or removed', (tester) async {
    await WaterBottle.setSize(750);
    await open(tester);
    await reveal(tester, find.byTooltip('Change bottle size'));
    await tester.tap(find.byTooltip('Change bottle size'));
    await pumpFor(tester);
    expect(find.text('750 ml'), findsOneWidget, reason: 'it opens on what is set');

    await tester.tap(find.text('Remove my bottle'));
    await pumpFor(tester, 8);
    expect(WaterBottle.sizeMl, isNull);
    await reveal(tester, find.text('Set bottle'));
    expect(find.text('Set bottle'), findsOneWidget);
  });

  testWidgets('under a fluid limit there is no countdown of bottles',
      (tester) async {
    await WaterBottle.setSize(500);
    await WaterService.saveProfile(HydrationProfile(
      id: 'profile',
      weightKg: 70,
      fluidCeilingMl: 1500,
      createdAt: DateTime.now(),
    ));
    expect(WaterService.isFluidRestricted, isTrue);
    await open(tester);
    await reveal(tester, find.text('Finished'));

    expect(find.text('Finished'), findsOneWidget,
        reason: 'logging a bottle is still fine');
    expect(find.textContaining('to go'), findsNothing,
        reason: 'a limit is a ceiling to stay under, not bottles to count down');
  });

  for (final scale in [1.0, 2.0]) {
    testWidgets('fits at 320pt and ${scale}x text', (tester) async {
      await WaterBottle.setSize(750);
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final reports = <String>[];
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(320, 3600);
      addTearDown(tester.view.reset);
      final prev = FlutterError.onError;
      FlutterError.onError = (d) => reports.add(d.toString());
      try {
        await tester.pumpWidget(MaterialApp(
            theme: AppTheme.lightTheme, home: const AquaWaterDashboard()));
        await tester.pump(const Duration(milliseconds: 50));
        await tester.pump(const Duration(milliseconds: 400));
      } finally {
        FlutterError.onError = prev;
      }
      await reveal(tester, find.text('Finished'));
      expect(find.text('Finished'), findsOneWidget);
      expect(reports.where((r) => r.contains('bottle_card.dart')), isEmpty);
    });
  }
}
