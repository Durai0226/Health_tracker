import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tablet_remainder/core/database/app_database.dart' as db;
import 'package:tablet_remainder/features/water/services/water_service.dart';

/// WaterService only warms a recent window of history into memory at start-up.
/// Everything older still exists in Drift, but used to be invisible to the
/// service — `getDataForDate` returned null, the history screen rendered the day
/// as empty, and saving an entry then wrote that blank day back over the stored
/// one: totals reset to a single drink and the day's real logs orphaned.
///
/// These tests pin the invariant: viewing or editing a day outside the warm
/// cache must read what is on disk and must never drop logs that exist there.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late db.AppDatabase database;

  /// A day comfortably outside [WaterService.warmCacheWindow].
  final oldDate = DateTime.now().subtract(const Duration(days: 200));
  final oldKey = '${oldDate.year}-${oldDate.month.toString().padLeft(2, '0')}'
      '-${oldDate.day.toString().padLeft(2, '0')}';

  /// Seeds the old day directly in Drift: 750ml raw / 700ml effective across a
  /// water and a coffee entry — history the service has never had in memory.
  Future<void> seedOldDay() async {
    await database.waterDao.saveDailyData(db.DailyWaterDataTableCompanion(
      id: Value(oldKey),
      date: Value(oldDate),
      dailyGoalMl: const Value(2500),
      totalIntakeMl: const Value(750),
      effectiveHydrationMl: const Value(700),
      totalCaffeineMg: const Value(95),
      alcoholicDrinksCount: const Value(0),
      goalReached: const Value(false),
    ));
    await database.waterDao.addWaterLog(db.EnhancedWaterLogsCompanion(
      id: const Value('old-log-water'),
      dailyDataId: Value(oldKey),
      time: Value(DateTime(oldDate.year, oldDate.month, oldDate.day, 8)),
      amountMl: const Value(500),
      effectiveHydrationMl: const Value(500),
      beverageId: const Value('water'),
      beverageName: const Value('Water'),
      beverageEmoji: const Value('💧'),
      hydrationPercent: const Value(100),
      caffeineAmount: const Value(0),
      isAlcoholic: const Value(false),
    ));
    await database.waterDao.addWaterLog(db.EnhancedWaterLogsCompanion(
      id: const Value('old-log-coffee'),
      dailyDataId: Value(oldKey),
      time: Value(DateTime(oldDate.year, oldDate.month, oldDate.day, 15)),
      amountMl: const Value(250),
      effectiveHydrationMl: const Value(200),
      beverageId: const Value('coffee'),
      beverageName: const Value('Coffee'),
      beverageEmoji: const Value('☕'),
      hydrationPercent: const Value(80),
      caffeineAmount: const Value(95),
      isAlcoholic: const Value(false),
    ));
  }

  setUp(() async {
    database = db.AppDatabase.forTesting(NativeDatabase.memory());
    db.AppDatabase.setInstanceForTesting(database);
    WaterService.clearInMemory();
    await WaterService.resetForTesting();
    await seedOldDay();
    await WaterService.init();
  });

  tearDown(() async => database.close());

  test('the old day is outside the warm start-up cache', () {
    // Guards the premise of every test below: if the window ever grows to cover
    // 200 days these tests would pass for the wrong reason.
    expect(WaterService.getDataForDate(oldDate), isNull);
  });

  test('viewing a day outside the cache reads its stored logs', () async {
    final loaded = await WaterService.loadDataForDate(oldDate);

    expect(loaded, isNotNull);
    expect(loaded!.logs.length, 2);
    expect(loaded.totalIntakeMl, 750);
    expect(loaded.effectiveHydrationMl, 700);
    expect(loaded.totalCaffeineMg, 95);
    // And it is now visible to the synchronous readers (calendar, stats).
    expect(WaterService.getDataForDate(oldDate)?.logs.length, 2);
  });

  test('adding an entry to a day outside the cache preserves its logs',
      () async {
    // Deliberately no preceding load: the write path itself must be safe.
    final water = WaterService.getBeverage('water')!;

    final updated = await WaterService.addWaterLogForDate(
      date: oldDate,
      amountMl: 250,
      beverage: water,
      time: DateTime(oldDate.year, oldDate.month, oldDate.day, 20),
    );

    expect(updated.logs.length, 3, reason: 'existing entries must survive');
    expect(updated.totalIntakeMl, 1000);
    expect(updated.effectiveHydrationMl, 950);
    expect(updated.totalCaffeineMg, 95);

    // The persisted day must match — this is what used to be destroyed.
    final storedLogs = await database.waterDao.getLogsForDay(oldKey);
    expect(storedLogs.map((l) => l.id),
        containsAll(<String>['old-log-water', 'old-log-coffee']));
    expect(storedLogs.length, 3);

    final storedDay = await database.waterDao.getDailyData(oldKey);
    expect(storedDay!.totalIntakeMl, 1000);
    expect(storedDay.effectiveHydrationMl, 950);
    expect(storedDay.totalCaffeineMg, 95);
  });

  test('editing one entry of an old day leaves the others intact', () async {
    final water = WaterService.getBeverage('water')!;

    final updated = await WaterService.updateWaterLogForDate(
      date: oldDate,
      logId: 'old-log-water',
      amountMl: 600,
      beverage: water,
      time: DateTime(oldDate.year, oldDate.month, oldDate.day, 8),
    );

    expect(updated.logs.length, 2);
    expect(updated.totalIntakeMl, 850);
    expect(updated.effectiveHydrationMl, 800);
    expect(updated.totalCaffeineMg, 95, reason: 'the coffee entry still counts');

    final storedLogs = await database.waterDao.getLogsForDay(oldKey);
    expect(storedLogs.length, 2);
    expect(
      storedLogs.firstWhere((l) => l.id == 'old-log-water').amountMl,
      600,
    );
    expect(
      storedLogs.firstWhere((l) => l.id == 'old-log-coffee').amountMl,
      250,
      reason: 'an untouched entry must not be rewritten',
    );

    final storedDay = await database.waterDao.getDailyData(oldKey);
    expect(storedDay!.totalIntakeMl, 850);
    expect(storedDay.effectiveHydrationMl, 800);
  });

  test('deleting an entry on an old day removes only that entry', () async {
    await WaterService.removeWaterLogForDate(oldDate, 'old-log-coffee');

    final storedLogs = await database.waterDao.getLogsForDay(oldKey);
    expect(storedLogs.length, 1);
    expect(storedLogs.single.id, 'old-log-water');

    final storedDay = await database.waterDao.getDailyData(oldKey);
    expect(storedDay!.totalIntakeMl, 500);
    expect(storedDay.effectiveHydrationMl, 500);
    expect(storedDay.totalCaffeineMg, 0);
  });

  test('ensureRangeLoaded exposes an old month to the range readers', () async {
    expect(WaterService.getDataForRange(oldDate, oldDate), isEmpty);

    await WaterService.ensureRangeLoaded(
      DateTime(oldDate.year, oldDate.month, 1),
      DateTime(oldDate.year, oldDate.month + 1, 0),
    );

    final range = WaterService.getDataForRange(oldDate, oldDate);
    expect(range.length, 1);
    expect(range.single.effectiveHydrationMl, 700);
    expect(range.single.logs.length, 2);
  });
}
