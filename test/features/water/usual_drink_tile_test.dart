import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' as db;
import 'package:tablet_remainder/core/services/clean_storage_service.dart';
import 'package:tablet_remainder/core/theme/app_theme.dart';
import 'package:tablet_remainder/features/water/models/beverage_type.dart';
import 'package:tablet_remainder/features/water/screens/aqua_water_dashboard.dart';
import 'package:tablet_remainder/features/water/services/water_service.dart';

/// "Your usual, one tap": a tile on the water screen that logs the drink the
/// person habitually has around this time. The rule is pinned in
/// `usual_drink_test`; this checks it reaches the screen and logs.
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

  BeverageType beverage(String id) =>
      BeverageType.defaultBeverages.firstWhere((b) => b.id == id);

  /// [days] mornings-ago, at the current time of day so the window always
  /// matches whenever the test runs. The dashboard reads the wall clock.
  Future<void> seedHabit(String id, int ml, Iterable<int> days) async {
    final now = DateTime.now();
    for (final d in days) {
      final at = DateTime(now.year, now.month, now.day - d, now.hour, now.minute);
      await WaterService.addWaterLogForDate(
          date: at, amountMl: ml, beverage: beverage(id), time: at);
    }
  }

  Future<void> pump(WidgetTester tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(390, 1800);
    addTearDown(tester.view.reset);
    final prev = FlutterError.onError;
    FlutterError.onError = (_) {}; // layout is the responsive suite's job
    try {
      await tester.pumpWidget(MaterialApp(
          theme: AppTheme.lightTheme, home: const AquaWaterDashboard()));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 400));
    } finally {
      FlutterError.onError = prev;
    }
  }

  testWidgets('no habit, no tile', (tester) async {
    await pump(tester);
    expect(find.text('Your usual'), findsNothing);
  });

  testWidgets('a habit shows its drink and size', (tester) async {
    await seedHabit('coffee', 200, [1, 2, 3, 4]);
    await pump(tester);
    expect(find.text('Your usual'), findsOneWidget);
    expect(find.text('Coffee · 200 ml'), findsOneWidget);
  });

  testWidgets('one tap logs it', (tester) async {
    await seedHabit('coffee', 200, [1, 2, 3, 4]);
    await pump(tester);
    expect(WaterService.getTodayData().logs, isEmpty);

    await tester.tap(find.text('Coffee · 200 ml'));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 400));

    final logs = WaterService.getTodayData().logs;
    expect(logs, hasLength(1));
    expect(logs.single.beverageId, 'coffee');
    expect(logs.single.amountMl, 200);
    await tester.pump(const Duration(seconds: 8));
  });
}
