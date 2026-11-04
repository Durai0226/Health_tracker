/// The hourly chart used to fill only from a health app: a phone with none showed
/// an empty one however far its own sensor had counted. The steps each live tick
/// adds now go into the hour they were taken in.
library;

import 'package:clock/clock.dart';
import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' as db;
import 'package:tablet_remainder/core/health/active_hours.dart';
import 'package:tablet_remainder/core/services/clean_storage_service.dart';
import 'package:tablet_remainder/features/steps/services/step_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // `Pedometer.stepCountStream` is this EventChannel.
  const stepCount = EventChannel('step_count');

  late db.AppDatabase database;
  late void Function(int cumulativeSinceBoot) tick;

  /// The fake wall clock, moved by the tests from hour to hour.
  late DateTime now;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    database = db.AppDatabase.forTesting(NativeDatabase.memory());
    db.AppDatabase.setInstanceForTesting(database);
    CleanStorageService.resetForTesting();
    await CleanStorageService.init();
    await StepService.resetForTesting();

    MockStreamHandlerEventSink? sink;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockStreamHandler(
      stepCount,
      MockStreamHandler.inline(
        onListen: (_, events) => sink = events,
        onCancel: (_) => sink = null,
      ),
    );
    tick = (int steps) => sink!.success(steps);
  });

  tearDown(() async {
    await StepService.resetForTesting();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockStreamHandler(stepCount, null);
    await database.close();
  });

  /// Runs [body] with `clock.now()` reading the mutable [now], and with live
  /// tracking started INSIDE that zone: a stream listener runs in the zone that
  /// called `listen`, not the zone that fired the event.
  Future<void> live(DateTime start, Future<void> Function() body) {
    now = start;
    return withClock(Clock(() => now), () async {
      await StepService.startLiveTracking();
      await body();
    });
  }

  Future<void> walk(int cumulative) async {
    tick(cumulative);
    await Future<void>.delayed(Duration.zero);
  }

  List<int> hourlyOf(DateTime day) => StepService.getDataForDate(day)!.hourly;

  group('adding steps to an hour', () {
    test('an empty record starts as 24 empty hours', () {
      final h = StepService.hourlyWith(const [], 10, 300);

      expect(h, hasLength(24));
      expect(h[10], 300);
      expect(h.where((x) => x != 0), hasLength(1));
    });

    test('steps add to what the hour already holds, leaving the rest', () {
      final start = [for (var i = 0; i < 24; i++) i];
      final h = StepService.hourlyWith(start, 5, 100);

      expect(h[5], 105);
      expect(h[4], 4);
      expect(h[6], 6);
    });

    test('the record it was given is not changed', () {
      final start = List<int>.filled(24, 0);
      StepService.hourlyWith(start, 5, 100);

      expect(start[5], 0);
    });

    test('a record that is not 24 hours is replaced, not extended', () {
      final h = StepService.hourlyWith([1, 2, 3], 2, 50);

      expect(h, hasLength(24));
      expect(h[2], 50);
      expect(h[0], 0);
    });

    test('no steps, or an hour that is not one, changes nothing', () {
      final start = List<int>.filled(24, 7);

      expect(StepService.hourlyWith(start, 5, 0), same(start));
      expect(StepService.hourlyWith(start, 5, -3), same(start));
      expect(StepService.hourlyWith(start, -1, 10), same(start));
      expect(StepService.hourlyWith(start, 24, 10), same(start));
    });
  });

  group('live ticks', () {
    final today = DateTime(2026, 3, 12);

    test('the steps a tick adds land in the hour they were taken', () async {
      await live(DateTime(2026, 3, 12, 10, 15), () async {
        await walk(1000); // anchors the baseline
        await walk(1500);
      });

      final h = hourlyOf(today);
      expect(h[10], 500);
      expect(h.where((x) => x != 0), hasLength(1));
    });

    test('the next hour gets its own', () async {
      await live(DateTime(2026, 3, 12, 10, 15), () async {
        await walk(1000);
        await walk(1500);
        now = DateTime(2026, 3, 12, 11, 5);
        await walk(1800);
      });

      final h = hourlyOf(today);
      expect(h[10], 500);
      expect(h[11], 300);
    });

    test('the hours add up to the day\'s steps, so nothing downstream doubts them',
        () async {
      await live(DateTime(2026, 3, 12, 8, 0), () async {
        await walk(10);
        await walk(310);
        await walk(710);
        now = DateTime(2026, 3, 12, 9, 30);
        await walk(1410);
      });

      final day = StepService.getDataForDate(today)!;
      expect(day.hourly.fold<int>(0, (a, b) => a + b), day.sensorSteps);
      expect(day.sensorSteps, 1400);
    });

    test('so Active hours can say something for a phone with no health app',
        () async {
      await live(DateTime(2026, 3, 12, 8, 0), () async {
        await walk(10);
        await walk(410); // hour 8: 400
        now = DateTime(2026, 3, 12, 9, 0);
        await walk(710); // hour 9: 300
        now = DateTime(2026, 3, 12, 10, 0);
        await walk(810); // hour 10: 100
      });

      final day = StepService.getDataForDate(today)!;
      final r = ActiveHoursCalc.compute(
          hourly: day.hourly, sensorTotal: day.sensorSteps)!;
      expect([for (var h = 0; h < 24; h++) if (r.hours[h]) h], [8, 9],
          reason: '100 steps in hour 10 is under the threshold');
    });

    test('a tick that adds nothing changes nothing', () async {
      await live(DateTime(2026, 3, 12, 10, 15), () async {
        await walk(1000);
        await walk(1500);
        await walk(1500); // the same reading again
        await walk(1400); // a reading lower than the last
      });

      expect(hourlyOf(today)[10], 500);
    });

    test('a health sync that knew more does not take the sensor\'s hour away',
        () async {
      await live(DateTime(2026, 3, 12, 10, 15), () async {
        await walk(1000);
        await walk(1500); // 500 in hour 10
        StepService.storeHealthDayForTesting(now, 800, isToday: true);
        await walk(1900); // 400 more after the sync
      });

      expect(hourlyOf(today)[10], 900,
          reason: 'the 500 before the sync and the 400 after it');
    });

    test('they survive a restart', () async {
      await live(DateTime(2026, 3, 12, 10, 15), () async {
        await walk(1000);
        await walk(1500);
        await StepService.flushPendingLiveDay();
        StepService.clearInMemory();
        await StepService.reloadFromDb();
      });

      expect(hourlyOf(today)[10], 500);
    });

    test('across midnight the new day starts its own hours', () async {
      await live(DateTime(2026, 3, 12, 23, 50), () async {
        await walk(1000);
        await walk(1200); // 200 in hour 23
        now = DateTime(2026, 3, 13, 0, 10);
        await walk(1300); // first event of the new day: re-anchors only
        await walk(1450); // 150 in hour 0
      });

      expect(hourlyOf(today)[23], 200);
      expect(hourlyOf(DateTime(2026, 3, 13))[0], 150);
      expect(hourlyOf(DateTime(2026, 3, 13))[23], 0,
          reason: 'yesterday\'s hour is not carried over');
    });
  });
}
