/// SS-16 — a pedometer tick must not be a database write.
///
/// `_onStepCount` ended in `unawaited(_persistDay(day))`, and the sensor fires
/// once per step. `_persistDay` is a `saveDay` upsert plus `_bumpBestDay`,
/// which reads the best-day preference and rewrites two keys whenever the day
/// is a record — so a walk that beats yesterday cost up to three write
/// transactions per footfall, each its own WAL fsync, for the whole walk.
///
/// Measured as WRITES through `CountingExecutor`, not elapsed time: a write
/// count is the same number on every machine, and the failure mode being
/// guarded against is specifically "work moved, not removed" — a throttle that
/// still wrote once per tick from a timer would look faster and count the same.
///
/// The ticks are delivered through the REAL `step_count` EventChannel, the
/// same harness `steps_midnight_rollover_test` uses, so this exercises
/// `startLiveTracking` → `_onStepCount` → the throttle as shipped rather than
/// a test-only seam.
library;

import 'package:clock/clock.dart';
import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' as db;
import 'package:tablet_remainder/core/services/clean_storage_service.dart';
import 'package:tablet_remainder/features/steps/services/step_service.dart';

import '../support/counting_executor.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const stepCount = EventChannel('step_count');

  late CountingExecutor counter;
  late db.AppDatabase database;
  late void Function(int cumulativeSinceBoot) tick;

  /// Fake wall clock, mutable so a test can cross a day boundary.
  late DateTime now;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    counter = CountingExecutor(NativeDatabase.memory());
    database = db.AppDatabase.forTesting(counter);
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
    now = DateTime(2026, 5, 12, 9);
  });

  tearDown(() async {
    await StepService.resetForTesting();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockStreamHandler(stepCount, null);
    await database.close();
  });

  /// Runs [body] with live tracking started INSIDE the fake-clock zone — a
  /// stream listener runs in the zone that called `listen`, not the one that
  /// fired the event.
  Future<void> live(Future<void> Function() body) =>
      withClock(Clock(() => now), () async {
        await StepService.startLiveTracking();
        await body();
      });

  /// Deliver one sensor reading and let it reach the listener.
  Future<void> walk(int cumulativeSinceBoot) async {
    tick(cumulativeSinceBoot);
    await Future<void>.delayed(Duration.zero);
  }

  /// One tick per step, the way the sensor actually reports: 200 events from
  /// a two-minute stroll.
  Future<void> walkSteps(int from, int count) async {
    for (var i = 1; i <= count; i++) {
      await walk(from + i);
    }
  }

  test('a burst of 200 ticks does not write 200 times', () async {
    await live(() async {
      await walk(100000); // first event anchors the baseline; writes nothing
      counter.reset();
      await walkSteps(100000, 200);

      expect(counter.writes, 0,
          reason: 'the throttle window is still open, so nothing should have '
              'reached the disk yet — writes seen: ${counter.writeTally}');
      expect(StepService.getTodayData().effectiveSteps, 200,
          reason: 'deferring the WRITE must not defer the COUNT: the number '
              'on screen has to move on every tick, as it did before');
    });
  });

  test('the queued value is written exactly once when the window closes',
      () async {
    await live(() async {
      await walk(100000);
      await walkSteps(100000, 200);
      counter.reset();

      await StepService.flushPendingLiveDay();

      expect(counter.writeTally['step_daily_data'], 1,
          reason: 'one row write for the whole burst, not 200 — '
              '${counter.writeTally}');
      final stored = await database.stepsDao.getDay('2026-05-12');
      expect(stored?.sensorSteps, 200,
          reason: 'the LAST value queued has to be the one that lands; a '
              'throttle that wrote the first tick and dropped the rest would '
              'lose the whole walk');
    });
  });

  test('a second flush with nothing queued writes nothing', () async {
    await live(() async {
      await walk(100000);
      await walkSteps(100000, 50);
      await StepService.flushPendingLiveDay();

      counter.reset();
      await StepService.flushPendingLiveDay();
      expect(counter.writes, 0,
          reason: 'an idle flush must be free — the lifecycle handler calls '
              'it on every background/inactive transition');
    });
  });

  test('stopping live tracking flushes rather than discarding', () async {
    // The kill path: the user leaves the screen (dispose → stopLiveTracking)
    // before the throttle window elapses. Those steps must survive.
    await live(() async {
      await walk(100000);
      await walkSteps(100000, 37);
      counter.reset();
      await StepService.stopLiveTracking();
    });

    expect(counter.writeTally['step_daily_data'], 1,
        reason: 'stopping mid-window dropped the pending day — '
            '${counter.writeTally}');
    final stored = await database.stepsDao.getDay('2026-05-12');
    expect(stored?.sensorSteps, 37);
  });

  test('a data wipe does NOT flush the pending day back in', () async {
    // `clearInMemory` runs while the Drift rows are being deleted; writing the
    // queued day there would resurrect exactly the count the wipe removed.
    await live(() async {
      await walk(100000);
      await walkSteps(100000, 12);

      counter.reset();
      StepService.clearInMemory();
      await Future<void>.delayed(Duration.zero);
    });

    expect(counter.writes, 0,
        reason: 'the wipe path wrote: ${counter.writeTally}');
    expect(await database.stepsDao.getDay('2026-05-12'), isNull);
  });

  test('the window closes on its own, with no explicit flush', () async {
    // Without this, "0 writes during the burst" would also be satisfied by a
    // throttle that never wrote at all unless something called flush.
    //
    // A REAL timer on a shortened window rather than FakeAsync: the write it
    // has to perform is Drift I/O, and `testWidgets` runs its body inside
    // FakeAsync where that never completes — the first version of this test
    // hung for the full ten-minute timeout. The window is the only thing
    // shortened; the code path is the shipped one.
    StepService.livePersistWindowForTesting = const Duration(milliseconds: 50);
    await live(() async {
      await walk(100000);
      await walkSteps(100000, 20);
      counter.reset();

      await Future<void>.delayed(const Duration(milliseconds: 250));
    });

    expect(counter.writeTally['step_daily_data'], 1,
        reason: 'the throttle timer never fired, or fired per tick — '
            '${counter.writeTally}');
    expect((await database.stepsDao.getDay('2026-05-12'))?.sensorSteps, 20);
  });
}
