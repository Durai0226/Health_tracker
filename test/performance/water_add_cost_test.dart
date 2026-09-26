/// PERF-06 — logging a drink must not scan the whole water history.
///
/// Every "+" used to await, in series: the day row write, the log write, a
/// Health Connect round trip, `usageCounts()` (a grouped COUNT over every log
/// row ever written) and `lifetimeDayAggregates()` (a full scan of
/// `daily_water_data` with two correlated subqueries per row) — and only then
/// could the Undo toast appear. Both scans grow with how long the person has
/// used the app, so the hottest write path in the feature got slower every day.
///
/// Measured as SELECTs through `CountingExecutor` rather than elapsed time: the
/// count is the same number on every machine, and the failure this guards
/// against is specifically "work moved, not removed" — a recompute deferred to
/// the next frame would feel faster and count the same.
///
/// The table names are asserted against real `tally` output, not guessed: the
/// Drift tables are `daily_water_data` and `enhanced_water_logs`.
library;

import 'dart:async';

import 'package:clock/clock.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' as db;
import 'package:tablet_remainder/features/water/models/beverage_type.dart';
import 'package:tablet_remainder/features/water/services/water_service.dart';

import '../support/counting_executor.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late CountingExecutor counter;
  late db.AppDatabase database;

  /// Fixed so the seeded history sits at a known offset from "today".
  final now = DateTime(2026, 6, 15, 10, 30);

  String keyFor(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}'
      '-${d.day.toString().padLeft(2, '0')}';

  Future<void> seedDay(DateTime date,
      {required int intakeMl, required bool goalReached}) async {
    final key = keyFor(date);
    await database.waterDao.saveDailyData(db.DailyWaterDataTableCompanion(
      id: Value(key),
      date: Value(date),
      dailyGoalMl: const Value(2500),
      totalIntakeMl: Value(intakeMl),
      effectiveHydrationMl: Value(intakeMl),
      goalReached: Value(goalReached),
    ));
    await database.waterDao.addWaterLog(db.EnhancedWaterLogsCompanion(
      id: Value('$key-seed'),
      dailyDataId: Value(key),
      time: Value(DateTime(date.year, date.month, date.day, 9)),
      amountMl: Value(intakeMl),
      effectiveHydrationMl: Value(intakeMl),
      beverageId: const Value('water'),
      beverageName: const Value('Water'),
      hydrationPercent: const Value(100),
      caffeineAmount: const Value(0),
      isAlcoholic: const Value(false),
    ));
  }

  /// 40 days of history plus today, so the whole-table scans have something to
  /// scan and today's row is already in the warm cache when "+" is tapped.
  Future<void> seedHistoryAndInit() async {
    for (var i = 40; i >= 0; i--) {
      final d = DateTime(now.year, now.month, now.day - i);
      await seedDay(d, intakeMl: 2600, goalReached: true);
    }
    await withClock(Clock.fixed(now), () => WaterService.init());
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    counter = CountingExecutor(NativeDatabase.memory());
    database = db.AppDatabase.forTesting(counter);
    db.AppDatabase.setInstanceForTesting(database);
    WaterService.clearInMemory();
    await WaterService.resetForTesting();
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('flutter_health'), null);
    await database.close();
  });

  group('PERF-06 the add path does not scan history', () {
    test('one "+" runs no SELECT over the water tables', () async {
      await seedHistoryAndInit();

      counter.reset();
      await withClock(
        Clock.fixed(now),
        () => WaterService.addWaterLog(
          amountMl: 250,
          beverage: BeverageType.defaultBeverages.first,
        ),
      );

      // Premise guard: the measurement window has to have caught the write, or
      // a zero read count proves nothing.
      expect(counter.writeTally['daily_water_data'], isNotNull,
          reason: 'the day row must still be persisted inside the window');
      expect(counter.writeTally['enhanced_water_logs'], isNotNull,
          reason: 'the drink must still be persisted inside the window');

      // Before this fix: 2 SELECTs — `usageCounts()` over enhanced_water_logs
      // and `lifetimeDayAggregates()` over daily_water_data. Both are matched
      // on the raw statement text rather than through `CountingExecutor.tally`,
      // because tally's `FROM "table"` regex wants Drift's quoting and these
      // two are hand-written `customSelect`s with the table name bare — so a
      // tally lookup for either reads null whether the scan ran or not.
      expect(
          counter.statements.where((s) => s.contains('FROM daily_water_data')),
          isEmpty,
          reason: 'the lifetime aggregate scan must not run per drink: '
              '${counter.statements}');
      expect(
          counter.statements
              .where((s) => s.contains('FROM enhanced_water_logs')),
          isEmpty,
          reason: 'the usage recount must not run per drink: '
              '${counter.statements}');
      expect(counter.selects, 0,
          reason: 'no read at all belongs on the "+" path: '
              '${counter.statements}');
    });

    test('the scans do not come back as the history grows', () async {
      await seedHistoryAndInit();

      // Ten drinks in a row — the cost of the tenth must equal the cost of the
      // first. A cache that was only ever populated once and then invalidated
      // by its own writes would pass the single-add test and fail here.
      final perAdd = <int>[];
      for (var i = 0; i < 10; i++) {
        counter.reset();
        await withClock(
          Clock.fixed(now),
          () => WaterService.addWaterLog(
            amountMl: 250,
            beverage: BeverageType.defaultBeverages.first,
          ),
        );
        perAdd.add(counter.selects);
      }

      expect(perAdd, everyElement(0), reason: 'selects per add: $perAdd');
    });
  });

  group('PERF-06 the patched state still agrees with the table', () {
    test('achievements after ten patched adds match a cold re-read', () async {
      await seedHistoryAndInit();

      for (var i = 0; i < 10; i++) {
        await withClock(
          Clock.fixed(now),
          () => WaterService.addWaterLog(
            amountMl: 300,
            beverage: BeverageType.defaultBeverages[i % 3],
          ),
        );
      }
      final patched = WaterService.getAchievements();
      final patchedStreak =
          withClock(Clock.fixed(now), WaterService.getStreakResult);
      final patchedFavourites =
          WaterService.getFavoriteBeverages().map((b) => b.id).toList();

      // Same database, service state thrown away: everything is now read back
      // out of Drift instead of patched in memory.
      await WaterService.resetForTesting();
      await withClock(Clock.fixed(now), () => WaterService.init());
      final cold = WaterService.getAchievements();
      final coldStreak =
          withClock(Clock.fixed(now), WaterService.getStreakResult);

      expect(patched.totalMl, cold.totalMl);
      expect(patched.totalDrinks, cold.totalDrinks);
      expect(patched.daysGoalMet, cold.daysGoalMet);
      expect(patched.currentStreak, cold.currentStreak);
      expect(patched.longestStreak, cold.longestStreak);
      expect(patchedStreak.gracesRemaining, coldStreak.gracesRemaining);
      expect(patchedFavourites,
          WaterService.getFavoriteBeverages().map((b) => b.id).toList(),
          reason: 'the incrementally patched usage counts must rank the '
              'favourites the same way a full recount does');
    });

    test('an undone drink is taken back out of the usage counts', () async {
      await seedHistoryAndInit();

      final tea = BeverageType.defaultBeverages
          .firstWhere((b) => b.id != 'water', orElse: () => BeverageType.defaultBeverages[1]);
      final before = WaterService.beverageUseCount(tea.id);

      final day = await withClock(
        Clock.fixed(now),
        () => WaterService.addWaterLog(amountMl: 200, beverage: tea),
      );
      expect(WaterService.beverageUseCount(tea.id), before + 1);

      await withClock(Clock.fixed(now),
          () => WaterService.removeWaterLog(day.logs.last.id));

      expect(WaterService.beverageUseCount(tea.id), before,
          reason: 'the counts are patched per drink now, so an Undo that did '
              'not decrement would leave the drink voting in the favourites '
              'ranking for ever');
    });
  });

  group('PERF-06 Undo still works and the drink still reaches the health store',
      () {
    /// The health plugin has no platform implementation under `flutter test`,
    /// and `HealthDataService.configure()` blocks on device_info, so both
    /// channels are stubbed. Returns the method names seen.
    ///
    /// [gate], when given, holds the permission probe open — which is how a
    /// slow health store is simulated, and the only way to tell an awaited
    /// write from a detached one.
    List<String> mockHealthChannels({Future<void>? gate}) {
      final calls = <String>[];
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(
          const MethodChannel('dev.fluttercommunity.plus/device_info'),
          (call) async => <String, dynamic>{});
      messenger.setMockMethodCallHandler(const MethodChannel('flutter_health'),
          (call) async {
        if (gate != null && call.method == 'hasPermissions') await gate;
        calls.add(call.method);
        return true;
      });
      return calls;
    }

    test('"+" returns without waiting for the health store', () async {
      SharedPreferences.setMockInitialValues(
          {'health_connect_hydration_sync_enabled': true});
      final gate = Completer<void>();
      final calls = mockHealthChannels(gate: gate.future);
      await seedHistoryAndInit();

      // The health store is wedged. The drink must still be recorded and the
      // call must still return, because nothing on this path awaits it.
      await withClock(
        Clock.fixed(now),
        () => WaterService.addWaterLog(
          amountMl: 250,
          beverage: BeverageType.defaultBeverages.first,
        ),
      ).timeout(
        const Duration(seconds: 2),
        onTimeout: () => fail('addWaterLog blocked on the health write'),
      );

      expect(calls, isNot(contains('writeData')),
          reason: 'premise guard: the health write must genuinely still be '
              'in flight, or this proves nothing');

      gate.complete();
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(calls, contains('writeData'),
          reason: 'and it must land once the store answers');
    });

    test('the fire-and-forget health write still happens', () async {
      SharedPreferences.setMockInitialValues(
          {'health_connect_hydration_sync_enabled': true});
      final calls = mockHealthChannels();
      await seedHistoryAndInit();

      await withClock(
        Clock.fixed(now),
        () => WaterService.addWaterLog(
          amountMl: 250,
          beverage: BeverageType.defaultBeverages.first,
        ),
      );
      // The write is deliberately not awaited by the caller, so let the
      // detached future run before asserting on it.
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(calls, contains('writeData'),
          reason: 'making the health write fire-and-forget must not mean it '
              'stops happening: $calls');

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getStringList('hydration_hc_recent_syncs'), isNotEmpty,
          reason: 'a successful write must still be recorded so it is not '
              'repeated');
    });

    test('Undo removes the drink from the day and from Drift', () async {
      await seedHistoryAndInit();
      final key = keyFor(now);
      final baseline =
          (await database.waterDao.getDailyData(key))!.totalIntakeMl;

      final day = await withClock(
        Clock.fixed(now),
        () => WaterService.addWaterLog(
          amountMl: 250,
          beverage: BeverageType.defaultBeverages.first,
        ),
      );
      final addedId = day.logs.last.id;

      await withClock(
          Clock.fixed(now), () => WaterService.removeWaterLog(addedId));

      final stored = (await database.waterDao.getDailyData(key))!;
      expect(stored.totalIntakeMl, baseline,
          reason: 'the day total must be back where it started');
      final logs = await database.waterDao.getLogsForDay(key);
      expect(logs.where((l) => l.id == addedId), isEmpty,
          reason: 'the row must be gone, not just the in-memory copy');
      expect(WaterService.getDataForDate(now)!.totalIntakeMl, baseline,
          reason: 'and the cached day must agree with it');
    });
  });
}
