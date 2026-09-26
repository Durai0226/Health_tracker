/// Three defects that all corrupted a NIGHT of sleep data.
///
/// 1. A daytime nap was folded into the night before it. Every sleep segment in
///    the 18:00→18:00 bucket went into one session, so an afternoon nap both
///    inflated time-in-bed and MOVED the recorded wake time to the end of the
///    nap. The sleep score, the sleep debt and the bedtime guidance all shifted
///    off a night the user never slept.
///
/// 2. Logging a second manual night for a date that already had one minted a
///    fresh uuid, leaving TWO rows with the same `dateKey`. The reader showed
///    one; the other was invisible in the UI, so it could never be corrected or
///    deleted — and it stayed in the database and in cloud sync forever.
///
/// 3. `init()` awaited the Health Connect / HealthKit import, and `main.dart`
///    awaits `SleepService.init()` before `runApp`. So the first frame waited on
///    a whole platform round trip (configure → SDK status → permissions → eight
///    days of segments) and the app opened on a blank screen.
library;

import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health/health.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' as db;
import 'package:tablet_remainder/features/sleep/models/sleep_stage.dart';
import 'package:tablet_remainder/features/sleep/services/sleep_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late db.AppDatabase database;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    database = db.AppDatabase.forTesting(NativeDatabase.memory());
    db.AppDatabase.setInstanceForTesting(database);
    await SleepService.resetForTesting();
  });

  tearDown(() async => database.close());

  // ---- the health import: a nap is not part of the night -------------------

  HealthDataPoint sleep(
    HealthDataType type,
    DateTime from,
    Duration span,
  ) =>
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

  group('a fragmented night is still ONE night', () {
    // The first version of the nap split picked the LONGEST-SPANNING episode as
    // the night. That is the wrong discriminator twice over, and the second way
    // is worse than the bug it replaced:
    //
    //  * a 4-hour afternoon nap beats a 3-hour night, so the nap BECOMES the
    //    night; and
    //  * a genuinely fragmented night — asleep 22:00, awake 3½ hours, asleep
    //    again until 08:00 — was truncated to its longest fragment, discarding
    //    two hours of real sleep and moving the wake time six hours early.
    //
    // A nap is defined by WHEN it happens, not by how short it is.

    test('positive: a mid-night gap longer than the episode threshold does not '
        'truncate the night', () {
      final night = SleepService.aggregateForTesting(
        '2026-03-12',
        [
          // 22:00 → 02:00, then up for 3h30, then 05:30 → 08:00.
          sleep(HealthDataType.SLEEP_LIGHT, DateTime(2026, 3, 11, 22),
              const Duration(hours: 4)),
          sleep(HealthDataType.SLEEP_LIGHT, DateTime(2026, 3, 12, 5, 30),
              const Duration(hours: 2, minutes: 30)),
        ],
        SleepSource.healthConnect,
      );

      expect(night, isNotNull);
      expect(night!.wakeTime.hour, 8,
          reason: 'the wake time must be the end of the LAST night segment, '
              'not the end of the longest one');
      expect(night.bedtime.hour, 22);
      expect(night.asleepMinutes, 390,
          reason: '4h + 2h30 of recorded sleep — none of it is a nap');
      expect(night.note ?? '', isNot(contains('daytime')),
          reason: 'calling half of someone\'s night "daytime sleep" is worse '
              'than the original defect');
    });

    test('negative: a LONGER afternoon nap still does not become the night',
        () {
      final night = SleepService.aggregateForTesting(
        '2026-03-12',
        [
          // A short 3-hour night...
          sleep(HealthDataType.SLEEP_SESSION, DateTime(2026, 3, 12, 1),
              const Duration(hours: 3)),
          // ...and a LONGER 4-hour nap at 13:00.
          sleep(HealthDataType.SLEEP_SESSION, DateTime(2026, 3, 12, 13),
              const Duration(hours: 4)),
        ],
        SleepSource.healthConnect,
      );

      expect(night, isNotNull);
      expect(night!.bedtime.hour, 1,
          reason: 'the 01:00 night is the night even though the nap is longer');
      expect(night.wakeTime.hour, 4);
      expect(night.asleepMinutes, 180);
      expect(night.note ?? '', contains('daytime'),
          reason: 'the nap is recorded, not silently dropped');
    });

    test('negative: an evening bedtime is never mistaken for a nap', () {
      // 18:30 is inside no daytime window that matters — an episode that starts
      // in the evening and runs into the night IS the night beginning.
      final night = SleepService.aggregateForTesting(
        '2026-03-12',
        [
          sleep(HealthDataType.SLEEP_SESSION, DateTime(2026, 3, 11, 18, 30),
              const Duration(hours: 9)),
        ],
        SleepSource.healthConnect,
      );
      expect(night, isNotNull);
      expect(night!.bedtime.hour, 18);
      expect(night.asleepMinutes, 540);
      expect(night.note ?? '', isNot(contains('daytime')));
    });

    test('negative: a bucket containing ONLY a nap still reports the nap', () {
      // Losing the day entirely would be a third kind of wrong.
      final night = SleepService.aggregateForTesting(
        '2026-03-12',
        [
          sleep(HealthDataType.SLEEP_SESSION, DateTime(2026, 3, 12, 14),
              const Duration(minutes: 45)),
        ],
        SleepSource.healthConnect,
      );
      expect(night, isNotNull,
          reason: 'a day whose only sleep was a nap is still a record');
      expect(night!.asleepMinutes, 45);
    });
  });

  group('health import, night vs nap', () {
    // 23:00 → 07:00 the next morning, reported as one session record.
    final nightStart = DateTime(2026, 3, 11, 23);
    // A 45-minute nap at 15:00 on the wake day — same 18:00→18:00 bucket.
    final napStart = DateTime(2026, 3, 12, 15);

    test('the night keeps its own wake time and duration', () {
      final s = SleepService.aggregateForTesting(
        '2026-03-12',
        [
          sleep(HealthDataType.SLEEP_SESSION, nightStart,
              const Duration(hours: 8)),
          sleep(HealthDataType.SLEEP_SESSION, napStart,
              const Duration(minutes: 45)),
        ],
        SleepSource.healthConnect,
      )!;

      expect(s.bedtime, nightStart);
      // The wake time is the night's, NOT 15:45 at the end of the nap.
      expect(s.wakeTime, DateTime(2026, 3, 12, 7));
      expect(s.inBedMinutes, 8 * 60);
      expect(s.asleepMinutes, 8 * 60);
    });

    test('the nap is not folded into the night, and is not lost either', () {
      final s = SleepService.aggregateForTesting(
        '2026-03-12',
        [
          sleep(HealthDataType.SLEEP_SESSION, nightStart,
              const Duration(hours: 8)),
          sleep(HealthDataType.SLEEP_SESSION, napStart,
              const Duration(minutes: 45)),
        ],
        SleepSource.healthConnect,
      )!;

      // The broken behaviour: bedtime 23:00 → wake 15:45 = 16h45 in bed.
      expect(s.inBedMinutes, isNot(16 * 60 + 45));
      expect(s.wakeTime, isNot(DateTime(2026, 3, 12, 15, 45)));
      expect(s.note, 'Excludes 45 min of daytime sleep');
    });

    test('a mid-night wake still belongs to the same night', () {
      // Awake 03:00–03:20 between two asleep stretches: a 20-minute gap must
      // NOT split the night in two, or every restless night would be halved.
      final s = SleepService.aggregateForTesting(
        '2026-03-12',
        [
          sleep(HealthDataType.SLEEP_LIGHT, nightStart,
              const Duration(hours: 4)),
          sleep(HealthDataType.SLEEP_DEEP, DateTime(2026, 3, 12, 3, 20),
              const Duration(hours: 3, minutes: 40)),
        ],
        SleepSource.healthConnect,
      )!;

      expect(s.bedtime, nightStart);
      expect(s.wakeTime, DateTime(2026, 3, 12, 7));
      expect(s.asleepMinutes, 4 * 60 + 220);
      expect(s.note, isNull); // nothing was excluded
    });
  });

  // ---- manual logging: one row per night ----------------------------------

  group('a second manual night for the same date', () {
    final bed = DateTime(2026, 3, 11, 23);
    final wake = DateTime(2026, 3, 12, 7);

    test('edits the first instead of hiding it behind a new row', () async {
      final first = await SleepService.logManualSession(
        bedtime: bed,
        wakeTime: wake,
        quality: 3,
        note: 'first guess',
      );
      final second = await SleepService.logManualSession(
        bedtime: bed,
        wakeTime: DateTime(2026, 3, 12, 8),
        quality: 5,
        note: 'checked my watch',
      );

      expect(second.id, first.id, reason: 'the second log is an edit');
      expect(second.createdAt, first.createdAt);

      // Exactly one row survives in Drift, and it is the corrected one.
      final rows = await database.sleepDao
          .getForRange(DateTime(2026, 3, 1), DateTime(2026, 3, 20));
      final forNight = rows.where((r) => r.dateKey == '2026-03-12').toList();
      expect(forNight, hasLength(1));
      expect(forNight.single.note, 'checked my watch');
      expect(forNight.single.inBedMinutes, 9 * 60);
    });

    test('no unreachable row is left behind', () async {
      final first = await SleepService.logManualSession(
        bedtime: bed,
        wakeTime: wake,
      );
      await SleepService.logManualSession(
        bedtime: bed,
        wakeTime: DateTime(2026, 3, 12, 8),
      );

      // The broken behaviour: two ids for one night, one of them invisible.
      final rows = await database.sleepDao
          .getForRange(DateTime(2026, 3, 1), DateTime(2026, 3, 20));
      final ids = rows
          .where((r) => r.dateKey == '2026-03-12')
          .map((r) => r.id)
          .toSet();
      expect(ids, {first.id});

      // Deleting what the UI shows really removes the night.
      await SleepService.deleteSession(first.id);
      expect(SleepService.getForDate(wake), isNull);
      final after = await database.sleepDao
          .getForRange(DateTime(2026, 3, 1), DateTime(2026, 3, 20));
      expect(after.where((r) => r.dateKey == '2026-03-12'), isEmpty);
    });

    test('different nights still get their own rows', () async {
      final a = await SleepService.logManualSession(
        bedtime: bed,
        wakeTime: wake,
      );
      final b = await SleepService.logManualSession(
        bedtime: DateTime(2026, 3, 12, 23),
        wakeTime: DateTime(2026, 3, 13, 7),
      );
      expect(b.id, isNot(a.id));
      expect(SleepService.getAllSessions(), hasLength(2));
    });
  });

  // ---- init must not block the first frame --------------------------------

  group('init', () {
    // `HealthDataService.availability()` starts with `Health().configure()`,
    // which reads the device id over the device_info_plus channel. Stalling
    // that channel stalls the whole health round trip — exactly what a slow
    // Health Connect does on a real phone.
    const deviceInfo =
        MethodChannel('dev.fluttercommunity.plus/device_info');

    setUp(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
              deviceInfo, (_) => Completer<Object?>().future);
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(deviceInfo, null);
    });

    test('completes without waiting on the health round trip', () async {
      final outcome = await SleepService.init()
          .then((_) => 'completed')
          .timeout(const Duration(seconds: 2), onTimeout: () => 'stalled');
      expect(outcome, 'completed');
    });

    test('still loads the nights it is responsible for', () async {
      // Inside init's own ~35-night load window, which is anchored to the wall
      // clock — so the night has to be a recent one.
      final today = DateTime.now();
      final wakeMorning = DateTime(today.year, today.month, today.day, 7);
      final logged = await SleepService.logManualSession(
        bedtime: wakeMorning.subtract(const Duration(hours: 8)),
        wakeTime: wakeMorning,
      );
      await SleepService.resetForTesting();
      expect(SleepService.getAllSessions(), isEmpty);

      await SleepService.init()
          .timeout(const Duration(seconds: 2), onTimeout: () {});
      expect(SleepService.getAllSessions().map((s) => s.id), contains(logged.id));
    });
  });
}
