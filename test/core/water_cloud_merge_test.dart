import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tablet_remainder/core/database/app_database.dart' as db;
import 'package:tablet_remainder/features/water/models/enhanced_water_log.dart';
import 'package:tablet_remainder/features/water/services/water_service.dart';

/// `CloudSyncService._syncWaterIntake` was cloud-wins-unconditionally: whenever
/// the remote document existed, the local day was replaced by it with no
/// comparison at all. Four glasses logged on the phone against a cloud copy
/// holding one meant three silently vanished. It also wrote through
/// `saveDailyData` (day row only, no logs), and addressed the document with an
/// unpadded `'${y}-${m}-${d}'` key that disagreed with every local reader in
/// single-digit months.
///
/// The merge itself lives in `WaterService.mergeCloudDay` precisely so it is
/// testable without Firestore. These tests pin it.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late db.AppDatabase database;

  final today = DateTime.now();
  final todayKey = WaterService.dateKeyFor(today);

  EnhancedWaterLog log(String id, int hour, int ml) => EnhancedWaterLog(
        id: id,
        time: DateTime(today.year, today.month, today.day, hour),
        amountMl: ml,
        effectiveHydrationMl: ml,
        beverageId: 'water',
        beverageName: 'Water',
        beverageEmoji: '💧',
      );

  setUp(() async {
    database = db.AppDatabase.forTesting(NativeDatabase.memory());
    db.AppDatabase.setInstanceForTesting(database);
    WaterService.clearInMemory();
    await WaterService.resetForTesting();
    await WaterService.init();
  });

  tearDown(() async => database.close());

  test('the date key is zero-padded', () {
    expect(WaterService.dateKeyFor(DateTime(2026, 8, 1)), '2026-08-01');
    expect(WaterService.dateKeyFor(DateTime(2026, 12, 25)), '2026-12-25');
  });

  test('local drinks survive a cloud day that does not know about them',
      () async {
    final water = WaterService.getBeverage('water')!;
    for (var i = 0; i < 4; i++) {
      await WaterService.addWaterLog(amountMl: 250, beverage: water);
    }
    expect(WaterService.getTodayData().logs.length, 4);

    // A stale cloud copy holding a single, different drink.
    final merged = await WaterService.mergeCloudDay(DailyWaterData(
      id: todayKey,
      date: today,
      dailyGoalMl: 2500,
      totalIntakeMl: 500,
      effectiveHydrationMl: 500,
      logs: [log('cloud-1', 7, 500)],
    ));

    expect(merged.logs.length, 5,
        reason: 'union of both sides — nothing may be discarded');
    expect(merged.totalIntakeMl, 1500,
        reason: 'totals are recomputed from the merged logs, not copied');
  });

  test('the merge is idempotent', () async {
    final cloud = DailyWaterData(
      id: todayKey,
      date: today,
      dailyGoalMl: 2500,
      logs: [log('c1', 8, 250), log('c2', 9, 250)],
    );

    await WaterService.mergeCloudDay(cloud);
    final second = await WaterService.mergeCloudDay(cloud);

    expect(second.logs.length, 2, reason: 'no duplication on re-sync');
    expect(second.totalIntakeMl, 500);
  });

  test('merged logs are persisted, not just totalled', () async {
    await WaterService.mergeCloudDay(DailyWaterData(
      id: todayKey,
      date: today,
      dailyGoalMl: 2500,
      logs: [log('c1', 8, 250), log('c2', 9, 300)],
    ));

    // Read straight from Drift: the old path left this table empty.
    final stored = await database.waterDao.getLogsForDay(todayKey);
    expect(stored.length, 2,
        reason: 'a cloud merge must write the per-drink rows');
    expect(stored.map((l) => l.amountMl).toList(), [250, 300]);
  });

  test('a deleted drink is not resurrected by the cloud copy', () async {
    final water = WaterService.getBeverage('water')!;
    await WaterService.addWaterLog(amountMl: 250, beverage: water);
    await WaterService.addWaterLog(amountMl: 300, beverage: water);

    // The cloud copy was uploaded BEFORE the delete, so it still holds the
    // drink. This is the single-device case: no second phone is needed.
    final cloudCopy =
        DailyWaterData.fromJson(WaterService.getTodayData().toJson());
    final doomed =
        WaterService.getTodayData().logs.firstWhere((l) => l.amountMl == 250);

    await WaterService.removeWaterLog(doomed.id);
    expect(WaterService.getTodayData().logs.length, 1);

    final merged = await WaterService.mergeCloudDay(cloudCopy);

    expect(merged.logs.map((l) => l.id), isNot(contains(doomed.id)),
        reason: 'a union by log id put the deleted drink straight back');
    expect(merged.totalIntakeMl, 300,
        reason: 'and the totals counted it again with it');
    expect((await database.waterDao.getLogsForDay(todayKey)).length, 1,
        reason: 'the resurrection must not reach Drift either');
  });

  test('the deletion still holds after a restart', () async {
    final water = WaterService.getBeverage('water')!;
    await WaterService.addWaterLog(amountMl: 250, beverage: water);
    await WaterService.addWaterLog(amountMl: 300, beverage: water);
    final cloudCopy =
        DailyWaterData.fromJson(WaterService.getTodayData().toJson());
    final doomed =
        WaterService.getTodayData().logs.firstWhere((l) => l.amountMl == 250);
    await WaterService.removeWaterLog(doomed.id);

    // The next launch: every scrap of in-memory state gone, same database.
    // This is the form the bug actually took — the tombstone has to be
    // persisted, not just remembered for the session that did the deleting.
    await WaterService.resetForTesting();
    await WaterService.init();

    final merged = await WaterService.mergeCloudDay(cloudCopy);

    expect(merged.logs.map((l) => l.id), isNot(contains(doomed.id)));
    expect(merged.totalIntakeMl, 300);
  });

  test("a deletion made on the other device is applied here", () async {
    final water = WaterService.getBeverage('water')!;
    await WaterService.addWaterLog(amountMl: 250, beverage: water);
    await WaterService.addWaterLog(amountMl: 300, beverage: water);
    final local = WaterService.getTodayData();
    final deletedThere = local.logs.firstWhere((l) => l.amountMl == 250);

    // What the other device pushes after deleting that drink: its own copy of
    // the day, minus the drink, plus the tombstone saying why.
    final merged = await WaterService.mergeCloudDay(DailyWaterData(
      id: todayKey,
      date: today,
      dailyGoalMl: 2500,
      logs: local.logs.where((l) => l.id != deletedThere.id).toList(),
      deletedLogIds: {deletedThere.id},
    ));

    expect(merged.logs.map((l) => l.id), isNot(contains(deletedThere.id)),
        reason: 'the tombstone has to remove the local copy too');
    expect(await database.waterDao.getLogsForDay(todayKey),
        hasLength(1));
  });

  test('the tombstone travels in the day JSON', () async {
    final water = WaterService.getBeverage('water')!;
    await WaterService.addWaterLog(amountMl: 250, beverage: water);
    final doomed = WaterService.getTodayData().logs.single.id;
    await WaterService.removeWaterLog(doomed);

    // `toJson` is what the uploader writes to `users/{uid}/water_intake/{day}`.
    final uploaded = WaterService.getTodayData().toJson();
    expect(uploaded['deletedLogIds'], [doomed]);
    expect(DailyWaterData.fromJson(uploaded).deletedLogIds, {doomed},
        reason: 'and the other device has to be able to read it back');
  });

  test('the upload payload still carries the tombstone after a restart',
      () async {
    final water = WaterService.getBeverage('water')!;
    await WaterService.addWaterLog(amountMl: 250, beverage: water);
    await WaterService.addWaterLog(amountMl: 300, beverage: water);
    final doomed =
        WaterService.getTodayData().logs.firstWhere((l) => l.amountMl == 250);
    await WaterService.removeWaterLog(doomed.id);

    // The next launch. `init()` deliberately does not read the tombstone row —
    // it runs before the first frame — so the day that the synchronous
    // `getTodayData()` hands back carries none of them yet.
    await WaterService.resetForTesting();
    await WaterService.init();
    expect(WaterService.getTodayData().deletedLogIds, isEmpty,
        reason: 'premise: nothing has asked for them yet this session');

    // Which is why the uploader goes through `todayDataForSync`. Sending the
    // day without its tombstones is what lets the very next download — the
    // copy uploaded before the delete — hand the drink straight back.
    final payload = await WaterService.todayDataForSync();
    expect(payload.deletedLogIds, {doomed.id});
    expect(payload.toJson()['deletedLogIds'], [doomed.id],
        reason: 'and it has to survive into the document Firestore stores');
  });

  test('the merged day carries the tombstone back to the cloud', () async {
    final water = WaterService.getBeverage('water')!;
    await WaterService.addWaterLog(amountMl: 250, beverage: water);
    await WaterService.addWaterLog(amountMl: 300, beverage: water);
    final cloudCopy =
        DailyWaterData.fromJson(WaterService.getTodayData().toJson());
    final doomed =
        WaterService.getTodayData().logs.firstWhere((l) => l.amountMl == 250);
    await WaterService.removeWaterLog(doomed.id);

    final merged = await WaterService.mergeCloudDay(cloudCopy);

    // Dropping the drink locally is only half of it. `_syncWaterIntake` writes
    // `merged.toJson()` back to the document, and decides whether to write at
    // all by comparing `deletedLogIds.length` against the cloud copy's — so a
    // merge that returns no tombstone strands the deletion on this device: the
    // cloud keeps the drink and the other phone never hears it was deleted.
    expect(merged.deletedLogIds, contains(doomed.id));
    expect(merged.toJson()['deletedLogIds'], contains(doomed.id),
        reason: 'the pushed-back document is what the other device reads');
    expect(merged.deletedLogIds.length,
        greaterThan(cloudCopy.deletedLogIds.length),
        reason: 'and that length is what decides whether it is pushed at all');
  });

  test('a deletion learnt from the cloud survives the next restart', () async {
    final water = WaterService.getBeverage('water')!;
    await WaterService.addWaterLog(amountMl: 250, beverage: water);
    await WaterService.addWaterLog(amountMl: 300, beverage: water);
    final local = WaterService.getTodayData();
    final deletedThere = local.logs.firstWhere((l) => l.amountMl == 250);
    // The copy an earlier upload left in the cloud, taken before the other
    // device deleted anything: it still holds the drink.
    final stale = DailyWaterData.fromJson(local.toJson());

    await WaterService.mergeCloudDay(DailyWaterData(
      id: todayKey,
      date: today,
      dailyGoalMl: 2500,
      logs: local.logs.where((l) => l.id != deletedThere.id).toList(),
      deletedLogIds: {deletedThere.id},
    ));

    // Next launch. This tombstone was never made here, so it is on disk only
    // if the merge adopted it — and `downloadDataFromCloud` merges thirty days
    // without writing anything back, so nothing else can carry it forward.
    await WaterService.resetForTesting();
    await WaterService.init();

    final merged = await WaterService.mergeCloudDay(stale);

    expect(merged.logs.map((l) => l.id), isNot(contains(deletedThere.id)),
        reason: 'a tombstone adopted from the cloud has to be persisted too');
  });

  test("the local profile's goal wins over the cloud copy's", () async {
    final water = WaterService.getBeverage('water')!;
    await WaterService.addWaterLog(amountMl: 250, beverage: water);
    final localGoal = WaterService.getTodayData().dailyGoalMl;

    final merged = await WaterService.mergeCloudDay(DailyWaterData(
      id: todayKey,
      date: today,
      dailyGoalMl: localGoal + 1234,
      logs: [log('c1', 8, 250)],
    ));

    expect(merged.dailyGoalMl, localGoal,
        reason: 'the goal follows this device profile');
  });
}
