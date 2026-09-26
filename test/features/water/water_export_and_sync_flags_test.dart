import 'package:clock/clock.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' as db;
import 'package:tablet_remainder/features/water/models/beverage_type.dart';
import 'package:tablet_remainder/features/water/models/enhanced_water_log.dart';
import 'package:tablet_remainder/features/water/services/hydration_health_sync.dart';
import 'package:tablet_remainder/features/water/services/water_service.dart';

/// Three defects that all share one cause: something in the water feature only
/// ever looked at the recent past.
///
///  * W11 — both CSV exports defaulted to the last 30 days of the in-memory
///    warm cache while the export sheet offered "Daily totals" and "All drink
///    logs" and shared a file named `water-summary.csv`. A two-year history
///    exported as one month with nothing said about it.
///  * W5 — deleting a drink never refreshed the home-screen widget, so the
///    widget kept showing an intake the app had already removed until an
///    unrelated steps or sleep write happened to push a new snapshot.
///  * W-13 — one permanent `hydration_hc_synced_<uuid>` preference key per
///    drink, never pruned, in a store that is loaded whole at start-up.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late db.AppDatabase database;

  /// Pinned: the export window is defined relative to "now", and the seeded
  /// days below are placed relative to the same instant.
  final now = DateTime(2026, 9, 26, 14, 0);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    HydrationHealthSync.resetForTesting();
    database = db.AppDatabase.forTesting(NativeDatabase.memory());
    db.AppDatabase.setInstanceForTesting(database);
    WaterService.clearInMemory();
    await WaterService.resetForTesting();
  });

  tearDown(() async => database.close());

  String keyFor(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}'
      '-${d.day.toString().padLeft(2, '0')}';

  /// Writes one day straight to Drift, bypassing the service — history the
  /// warm cache has never seen.
  Future<void> seedStoredDay(DateTime date,
      {required String logId, required int amountMl, int hour = 9}) async {
    final key = keyFor(date);
    await database.waterDao.saveDailyData(db.DailyWaterDataTableCompanion(
      id: Value(key),
      date: Value(date),
      dailyGoalMl: const Value(2500),
      totalIntakeMl: Value(amountMl),
      effectiveHydrationMl: Value(amountMl),
      totalCaffeineMg: const Value(0),
      alcoholicDrinksCount: const Value(0),
      goalReached: const Value(false),
    ));
    await database.waterDao.addWaterLog(db.EnhancedWaterLogsCompanion(
      id: Value(logId),
      dailyDataId: Value(key),
      time: Value(DateTime(date.year, date.month, date.day, hour)),
      amountMl: Value(amountMl),
      effectiveHydrationMl: Value(amountMl),
      beverageId: const Value('water'),
      beverageName: const Value('Water'),
      beverageEmoji: const Value('💧'),
      hydrationPercent: const Value(100),
      caffeineAmount: const Value(0),
      isAlcoholic: const Value(false),
    ));
  }

  group('W11 — CSV export covers the whole history, not the warm cache', () {
    test('summary CSV includes a day 400 days back', () async {
      final ancient = DateTime(2025, 8, 22);
      expect(now.difference(ancient).inDays,
          greaterThan(WaterService.warmCacheWindow.inDays),
          reason: 'the seeded day must be outside the warm cache for this '
              'test to mean anything');

      await withClock(Clock.fixed(now), () async {
        await seedStoredDay(ancient, logId: 'ancient-log', amountMl: 1800);
        await WaterService.init();

        final csv = await WaterService.exportToCsv();
        expect(csv, contains(keyFor(ancient)),
            reason: 'the export sheet calls this "Daily totals" with no date '
                'range — a stored day must not be silently dropped');
        expect(csv, contains('1800'));
      });
    });

    test('detailed CSV includes a drink from outside the 30-day default',
        () async {
      final ancient = DateTime(2025, 8, 22);
      await withClock(Clock.fixed(now), () async {
        await seedStoredDay(ancient, logId: 'ancient-log', amountMl: 1800);
        await WaterService.init();

        final csv = await WaterService.exportDetailedCsv();
        expect(csv, contains(keyFor(ancient)),
            reason: '"All drink logs" has to mean all of them');
      });
    });

    test('an explicit window still narrows the export', () async {
      final ancient = DateTime(2025, 8, 22);
      final recent = DateTime(2026, 9, 20);
      await withClock(Clock.fixed(now), () async {
        await seedStoredDay(ancient, logId: 'ancient-log', amountMl: 1800);
        await seedStoredDay(recent, logId: 'recent-log', amountMl: 900);
        await WaterService.init();

        final csv = await WaterService.exportToCsv(
            startDate: DateTime(2026, 9, 1), endDate: now);
        expect(csv, contains(keyFor(recent)));
        expect(csv, isNot(contains(keyFor(ancient))),
            reason: 'widening the default must not remove the ability to ask '
                'for a range');
      });
    });
  });

  group('W5 — deleting a drink refreshes the home-screen widget', () {
    /// Everything `home_widget` is asked to save, in order.
    late List<String> savedKeys;

    setUp(() {
      savedKeys = [];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(const MethodChannel('home_widget'),
              (call) async {
        if (call.method == 'saveWidgetData') {
          savedKeys.add((call.arguments as Map)['id'] as String);
        }
        return true;
      });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
              const MethodChannel('home_widget'), null);
    });

    /// The add/update pushes are deliberately not awaited (the "+" is the
    /// hottest write path in the app), so give the channel calls a turn.
    Future<void> settlePush() =>
        Future<void>.delayed(const Duration(milliseconds: 50));

    test('adding a drink from ANY caller pushes a fresh snapshot', () async {
      await withClock(Clock.fixed(now), () async {
        await WaterService.init();
        final water = BeverageType.defaultBeverages
            .firstWhere((b) => b.id == 'water');

        savedKeys.clear();
        // Straight through the service, the way the home "Log something" sheet
        // and the history editor reach it. The push used to live in the water
        // dashboard's own "+" handler, so those callers left the widget on its
        // last number — and then the Undo, which does push, refreshed it to a
        // total the widget had never shown.
        await WaterService.addWaterLog(amountMl: 250, beverage: water);
        await settlePush();

        expect(savedKeys, contains('waterMl'),
            reason: 'a drink added anywhere has to reach the widget, not only '
                'one added from the water dashboard');
      });
    });

    test('editing a drink pushes a fresh snapshot', () async {
      await withClock(Clock.fixed(now), () async {
        await WaterService.init();
        final water = BeverageType.defaultBeverages
            .firstWhere((b) => b.id == 'water');
        final day = await WaterService.addWaterLog(
          amountMl: 250,
          beverage: water,
        );
        await settlePush();

        savedKeys.clear();
        await WaterService.updateWaterLogForDate(
          date: now,
          logId: day.logs.last.id,
          amountMl: 900,
          beverage: water,
        );
        await settlePush();

        expect(savedKeys, contains('waterMl'),
            reason: 'an edit moves the day total exactly as much as an add or '
                'a delete does');
      });
    });

    test('removing a log pushes a fresh snapshot', () async {
      await withClock(Clock.fixed(now), () async {
        await WaterService.init();
        final water = BeverageType.defaultBeverages
            .firstWhere((b) => b.id == 'water');
        final day = await WaterService.addWaterLog(
          amountMl: 500,
          beverage: water,
        );
        final logId = day.logs.last.id;

        savedKeys.clear();
        await WaterService.removeWaterLog(logId);

        expect(savedKeys, contains('waterMl'),
            reason: 'the widget shows today\'s intake and only a push updates '
                'it — an Undo that skips the push leaves a deleted drink on '
                'the home screen');
      });
    });
  });

  group('W-13 — the per-drink sync flags are bounded', () {
    test('the recent-id list never grows past its cap', () {
      var ids = <String>[];
      for (var i = 0; i < 1000; i++) {
        ids = HydrationHealthSync.appendCapped(ids, 'log-$i');
      }
      expect(ids.length, lessThanOrEqualTo(200),
          reason: 'one entry per drink forever is the defect being fixed');
      expect(ids.last, 'log-999', reason: 'newest is kept');
      expect(ids, isNot(contains('log-0')), reason: 'oldest is dropped');
    });

    test('re-appending an id moves it rather than duplicating it', () {
      final ids = HydrationHealthSync.appendCapped(
          HydrationHealthSync.appendCapped(const ['a'], 'b'), 'a');
      expect(ids, ['b', 'a']);
    });

    test('the first write deletes the legacy per-drink keys', () async {
      SharedPreferences.setMockInitialValues({
        'health_connect_hydration_sync_enabled': true,
        for (var i = 0; i < 300; i++) 'hydration_hc_synced_log-$i': true,
        'unrelated_pref': 7,
      });
      HydrationHealthSync.resetForTesting();

      await HydrationHealthSync.onLogAdded(
        // The health write itself cannot succeed headless — which is exactly
        // why the sweep has to run before the permission check, not after it.
        EnhancedWaterLog(
          id: 'fresh-log',
          time: now,
          amountMl: 250,
          effectiveHydrationMl: 250,
          beverageId: 'water',
          beverageName: 'Water',
          beverageEmoji: '💧',
        ),
      );

      final prefs = await SharedPreferences.getInstance();
      final leftover =
          prefs.getKeys().where((k) => k.startsWith('hydration_hc_synced_'));
      expect(leftover, isEmpty,
          reason: 'these accumulated one per drink for the life of the '
              'install and were loaded on every launch');
      expect(prefs.get('unrelated_pref'), 7,
          reason: 'the sweep must only touch its own prefix');
    });
  });
}
