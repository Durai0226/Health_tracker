/// SS-19 — re-importing an unchanged night must not rewrite it.
///
/// `syncFromHealth` upserted every bucketed night unconditionally, and
/// `SleepSession.toCompanion()` stamps a fresh `updatedAt` on every write. The
/// import window is eight days and `init()` kicks a sync off on every launch,
/// so up to eight untouched nights were rewritten with a new modification time
/// each time the app opened.
///
/// The cost is not only write churn. `updatedAt` is the last-write-wins key —
/// `lww_collection_sync` compares it against the cloud copy, and `_winsOver`
/// compares it locally. Re-stamping it on a row whose contents did not change
/// decouples the key from "when the data changed" and reduces it to "which
/// device opened the app most recently": a phone holding a stale or partial
/// copy of a night could overwrite a newer, more complete copy another device
/// had already uploaded, purely by being launched afterwards. That is a
/// data-loss path, not a performance nit, and the timestamp assertion below is
/// the one that guards it.
///
/// Driven through `importBucketsForTesting`, which is `syncFromHealth`'s own
/// loop: under `flutter test` there is no Health Connect / HealthKit channel,
/// so `syncFromHealth` returns 0 at its availability check before reaching any
/// of this.
///
/// Two nights on purpose. `computeScore` folds in `regularityIndex()`, which
/// returns a flat 0.75 placeholder below three sessions — so with two nights
/// the aggregate is bit-identical between syncs and "nothing changed" means
/// nothing changed. With three or more, the first-ever sync scores each bucket
/// against a map that is still filling, and the scores legitimately settle on
/// the second pass.
library;

import 'package:drift/drift.dart' show Insertable;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health/health.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' as db;
import 'package:tablet_remainder/features/sleep/models/sleep_session.dart';
import 'package:tablet_remainder/features/sleep/models/sleep_stage.dart';
import 'package:tablet_remainder/features/sleep/services/sleep_service.dart';

import '../../support/counting_executor.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late CountingExecutor counter;
  late db.AppDatabase database;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    counter = CountingExecutor(NativeDatabase.memory());
    database = db.AppDatabase.forTesting(counter);
    db.AppDatabase.setInstanceForTesting(database);
    await SleepService.resetForTesting();
  });

  tearDown(() async => database.close());

  HealthDataPoint sleep(HealthDataType type, DateTime from, Duration span) =>
      HealthDataPoint(
        uuid: '$type-${from.millisecondsSinceEpoch}',
        value: NumericHealthValue(numericValue: span.inMinutes),
        type: type,
        unit: HealthDataUnit.MINUTE,
        dateFrom: from,
        dateTo: from.add(span),
        sourcePlatform: HealthPlatformType.googleHealthConnect,
        sourceDeviceId: 'unknown',
        sourceId: 'com.watch',
        sourceName: 'Galaxy Watch5',
        recordingMethod: RecordingMethod.automatic,
      );

  /// Two nights the device reports identically on every sync.
  Map<String, List<HealthDataPoint>> twoNights({int extraDeepMinutes = 0}) => {
        '2026-03-12': [
          sleep(HealthDataType.SLEEP_LIGHT, DateTime(2026, 3, 11, 23),
              const Duration(hours: 5)),
          sleep(HealthDataType.SLEEP_DEEP, DateTime(2026, 3, 12, 4),
              Duration(minutes: 90 + extraDeepMinutes)),
        ],
        '2026-03-13': [
          sleep(HealthDataType.SLEEP_LIGHT, DateTime(2026, 3, 12, 23, 15),
              const Duration(hours: 6)),
          sleep(HealthDataType.SLEEP_DEEP, DateTime(2026, 3, 13, 5, 15),
              const Duration(minutes: 60)),
        ],
      };

  Future<int> import({int extraDeepMinutes = 0}) =>
      SleepService.importBucketsForTesting(
        twoNights(extraDeepMinutes: extraDeepMinutes),
        SleepSource.healthConnect,
      );

  int sessionWrites() => counter.writeTally['sleep_sessions'] ?? 0;

  /// Long enough for a rewrite to land on a DIFFERENT stored timestamp.
  ///
  /// Drift's default `DateTimeColumn` mapping is a unix timestamp in SECONDS,
  /// and `toCompanion()` stamps `DateTime.now()` — not `clock.now()`, so no
  /// fake clock can shorten this. With a 20 ms gap both timestamp tests below
  /// passed with the fix reverted: the second re-upsert really did happen and
  /// landed on the same stored second. A real second of wall clock is what
  /// makes them able to fail.
  const aStoredTick = Duration(milliseconds: 1100);

  test('the FIRST import writes both nights', () async {
    // The control. Without it, every assertion below would also pass on an
    // import path that had stopped writing altogether.
    counter.reset();
    final imported = await import();

    expect(imported, 2);
    expect(sessionWrites(), 2, reason: 'writes seen: ${counter.writeTally}');
  });

  test('a re-import of the SAME nights writes nothing', () async {
    await import();

    counter.reset();
    final imported = await import();

    expect(sessionWrites(), 0,
        reason: 'an unchanged night was rewritten — ${counter.writeTally}');
    expect(imported, 0,
        reason: 'nothing was imported, so the count reported to the caller '
            'must be 0 rather than "two nights re-stamped"');
  });

  test('and leaves updatedAt exactly where it was — the LWW key', () async {
    await import();
    final before = (await database.sleepDao.getForDateKey('2026-03-12'))!
        .updatedAt;

    await Future<void>.delayed(aStoredTick);
    await import();

    final after =
        (await database.sleepDao.getForDateKey('2026-03-12'))!.updatedAt;
    expect(after, before,
        reason: 'updatedAt moved on a night whose contents did not change. '
            'That is the key last-write-wins compares, so this row now looks '
            'newer than an actually-newer cloud copy and would overwrite it: '
            '$before → $after');
  });

  test('a night that really did change is still written', () async {
    // The other half of the guard: "never write" is not the fix, "write only
    // when it changed" is. Thirty more minutes of deep sleep on night one.
    await import();

    counter.reset();
    final imported = await import(extraDeepMinutes: 30);

    expect(imported, 1, reason: 'only the changed night should re-import');
    expect(sessionWrites(), 1, reason: 'writes: ${counter.writeTally}');
    final row = await database.sleepDao.getForDateKey('2026-03-12');
    expect(row!.deepMinutes, 120,
        reason: 'the updated night did not reach the database');
  });

  test('a re-import keeps the row’s original createdAt', () async {
    await import();
    final created =
        (await database.sleepDao.getForDateKey('2026-03-12'))!.createdAt;

    await Future<void>.delayed(aStoredTick);
    await import(extraDeepMinutes: 30); // a real change, so it does write

    final after =
        (await database.sleepDao.getForDateKey('2026-03-12'))!.createdAt;
    expect(after, created,
        reason: 'editing a night is not creating one; createdAt moved from '
            '$created to $after');
  });

  test('_sameNight covers every column the row actually stores', () {
    // The "enumerated nine and missed the tenth" failure mode: `_sameNight`
    // lists its fields by hand, so a column added to SleepSessions later would
    // be invisible to it and a real change to that column would be dropped as
    // "unchanged". Pin the column set here; adding one fails this test and
    // forces the author to decide whether _sameNight should compare it.
    final s = SleepSession(
      id: 'hk_2026-03-12',
      dateKey: '2026-03-12',
      bedtime: DateTime(2026, 3, 11, 23),
      wakeTime: DateTime(2026, 3, 12, 7),
      inBedMinutes: 480,
      asleepMinutes: 420,
      createdAt: DateTime(2026, 3, 12, 8),
      updatedAt: DateTime(2026, 3, 12, 8),
    );
    final written =
        (s.toCompanion() as Insertable).toColumns(false).keys.toSet();

    // Compared by _sameNight.
    const compared = {
      'id',
      'date_key',
      'bedtime',
      'wake_time',
      'in_bed_minutes',
      'asleep_minutes',
      'awake_minutes',
      'light_minutes',
      'deep_minutes',
      'rem_minutes',
      'sleep_score',
      'efficiency',
      'quality_index',
      'source_index',
      'note',
    };
    // Deliberately excluded: the two timestamps (createdAt is equalised by the
    // caller, updatedAt is the thing being protected) and the sync flag, which
    // toCompanion always clears.
    const excluded = {'created_at', 'updated_at', 'synced'};

    expect(written, compared.union(excluded),
        reason: 'the columns SleepSession writes have changed. Update '
            '_sameNight (and this list) — a column it does not compare is a '
            'change it will silently discard.');
  });
}
