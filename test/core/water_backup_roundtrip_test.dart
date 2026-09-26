import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tablet_remainder/core/database/app_database.dart' as db;
import 'package:tablet_remainder/features/water/models/enhanced_water_log.dart';
import 'package:tablet_remainder/features/water/services/water_service.dart';

/// Water backup had two independent holes, both silent:
///
/// 1. **Export truncated to 90 days.** `exportAllData` snapshotted
///    `WaterService.listenToDailyData()?.value` — the in-memory warm cache — so
///    a backup contained only the last [WaterService.warmCacheWindow] days no
///    matter how long the person had been using the app.
/// 2. **Restore dropped every per-drink log.** The import wrote days through
///    `saveDailyData`, which persists the day row only. A restored day reported
///    "2,300 ml across 8 drinks" while its history screen showed nothing — and
///    the desync was permanent.
///
/// The backup *format* was never the problem: `DailyWaterData.toJson` has always
/// embedded logs. These tests pin both halves of the fix.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late db.AppDatabase database;

  DateTime dayAgo(int n) {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day - n);
  }

  String keyFor(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}'
      '-${d.day.toString().padLeft(2, '0')}';

  Future<void> seedDay(DateTime date, {required int logs}) async {
    final key = keyFor(date);
    await database.waterDao.saveDailyData(db.DailyWaterDataTableCompanion(
      id: Value(key),
      date: Value(date),
      dailyGoalMl: const Value(2500),
      totalIntakeMl: Value(250 * logs),
      effectiveHydrationMl: Value(250 * logs),
      goalReached: Value(250 * logs >= 2500),
    ));
    for (var i = 0; i < logs; i++) {
      await database.waterDao.addWaterLog(db.EnhancedWaterLogsCompanion(
        id: Value('$key-$i'),
        dailyDataId: Value(key),
        time: Value(DateTime(date.year, date.month, date.day, 8 + i)),
        amountMl: const Value(250),
        effectiveHydrationMl: const Value(250),
        beverageId: const Value('water'),
        beverageName: const Value('Water'),
        hydrationPercent: const Value(100),
      ));
    }
  }

  setUp(() async {
    database = db.AppDatabase.forTesting(NativeDatabase.memory());
    db.AppDatabase.setInstanceForTesting(database);
    WaterService.clearInMemory();
    await WaterService.resetForTesting();
  });

  tearDown(() async => database.close());

  test('export reaches past the warm cache', () async {
    await seedDay(dayAgo(300), logs: 2);
    await seedDay(dayAgo(200), logs: 3);
    await seedDay(dayAgo(1), logs: 4);
    await WaterService.init();

    // Premise guard: the two old days are outside the warmed window.
    expect(WaterService.getDataForDate(dayAgo(300)), isNull);
    expect(WaterService.getDataForDate(dayAgo(200)), isNull);

    final exported = await WaterService.exportAllDaysForBackup();

    expect(exported.length, 3,
        reason: 'a backup must carry every stored day, not just cached ones');
    expect(exported.map((d) => d.logs.length).toList(), [2, 3, 4],
        reason: 'oldest first, each with its own logs');
  });

  test('a full round trip through the backup format keeps the logs', () async {
    await seedDay(dayAgo(300), logs: 2);
    await seedDay(dayAgo(1), logs: 4);
    await WaterService.init();

    // Serialise exactly the way exportAllData does, then wipe and restore.
    final snapshot = (await WaterService.exportAllDaysForBackup())
        .map((d) => d.toJson())
        .toList();

    await database.waterDao.deleteLogsForDay(keyFor(dayAgo(300)));
    await database.waterDao.deleteLogsForDay(keyFor(dayAgo(1)));
    await database.delete(database.dailyWaterDataTable).go();
    WaterService.clearInMemory();

    for (final row in snapshot) {
      await WaterService.restoreDayWithLogs(
          DailyWaterData.fromJson(Map<String, dynamic>.from(row)));
    }

    final restored = await WaterService.exportAllDaysForBackup();
    expect(restored.length, 2);
    expect(restored.map((d) => d.logs.length).toList(), [2, 4],
        reason: 'restore must write per-drink logs, not just day totals');
    expect(restored.first.totalIntakeMl, 500);
    expect(restored.last.totalIntakeMl, 1000);
  });

  test('a restore that fails part-way leaves the day untouched', () async {
    await seedDay(dayAgo(1), logs: 2);
    await WaterService.init();
    final key = keyFor(dayAgo(1));

    // Make one row's insert fail at the database, the way a constraint
    // violation — or a kill mid-restore — interrupts the sequence. The restore
    // is delete-logs, write-day, re-insert-logs: correct only all together.
    await database.customStatement(
      "CREATE TRIGGER poison BEFORE INSERT ON enhanced_water_logs "
      "WHEN NEW.beverage_id = 'poison' "
      "BEGIN SELECT RAISE(ABORT, 'poisoned row'); END;",
    );

    EnhancedWaterLog incoming(String id, int hour, String beverage) =>
        EnhancedWaterLog(
          id: id,
          time: DateTime(dayAgo(1).year, dayAgo(1).month, dayAgo(1).day, hour),
          amountMl: 3333,
          effectiveHydrationMl: 3333,
          beverageId: beverage,
          beverageName: 'Water',
          beverageEmoji: '💧',
        );

    await expectLater(
      WaterService.restoreDayWithLogs(DailyWaterData(
        id: key,
        date: dayAgo(1),
        dailyGoalMl: 2500,
        totalIntakeMl: 9999,
        effectiveHydrationMl: 9999,
        // The good row before the bad one: without a transaction it is already
        // committed by the time the second throws.
        logs: [
          incoming('in-1', 10, 'water'),
          incoming('in-2', 11, 'poison'),
          incoming('in-3', 12, 'water'),
        ],
      )),
      throwsA(anything),
      reason: 'the caller has to learn the restore did not happen',
    );

    final logs = await database.waterDao.getLogsForDay(key);
    expect(logs.map((l) => l.id).toList(), ['$key-0', '$key-1'],
        reason: "the day's own drinks were deleted and never put back");
    final row = await database.waterDao.getDailyData(key);
    expect(row!.totalIntakeMl, 500,
        reason: 'totals from a restore that did not happen');
    expect(WaterService.getDataForDate(dayAgo(1))!.totalIntakeMl, 500,
        reason: 'and the in-memory view must not claim it did either');
  });

  test("a backup taken in a fresh session carries the day's tombstones",
      () async {
    await WaterService.init();
    final water = WaterService.getBeverage('water')!;
    await WaterService.addWaterLog(amountMl: 250, beverage: water);
    await WaterService.addWaterLog(amountMl: 300, beverage: water);
    final doomed =
        WaterService.getTodayData().logs.firstWhere((l) => l.amountMl == 250);
    await WaterService.removeWaterLog(doomed.id);

    // The export runs in a session that has not touched a tombstone yet —
    // launch the app, open Backup, tap export. `init()` deliberately does not
    // read the tombstone row, so unless the export asks for it the file goes
    // out claiming the drink was never deleted, and restoring it puts the
    // drink back.
    await WaterService.resetForTesting();
    await WaterService.init();

    final exported = await WaterService.exportAllDaysForBackup();

    expect(exported.single.deletedLogIds, contains(doomed.id));
    expect(exported.single.toJson()['deletedLogIds'], contains(doomed.id),
        reason: 'and it has to survive into the backup file itself');
  });

  test('restoring the same backup twice is not an error', () async {
    await seedDay(dayAgo(2), logs: 3);
    await WaterService.init();
    final snapshot = await WaterService.exportAllDaysForBackup();

    await WaterService.restoreDayWithLogs(snapshot.single);
    await WaterService.restoreDayWithLogs(snapshot.single);

    final after = await WaterService.exportAllDaysForBackup();
    expect(after.single.logs.length, 3,
        reason: 'a re-restore must replace the day, not duplicate its logs');
  });
}
