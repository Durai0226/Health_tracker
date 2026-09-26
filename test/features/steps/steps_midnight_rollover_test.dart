/// TQ-17 — the step counter had no midnight-rollover test.
///
/// The pedometer reports steps CUMULATIVE SINCE BOOT, so a phone that has been
/// up for a week arrives at midnight reading a six-figure number. Today's count
/// is that reading minus a baseline snapshotted when tracking started, which
/// means the rollover is not a no-op: at 00:00 `_onStepCount` has to re-anchor
/// the baseline to the current raw reading and start the new day at zero.
///
/// Get it wrong in either direction and the damage is silent:
///
///  * baseline NOT re-anchored → the new day opens with the whole of
///    yesterday's total already on it;
///  * yesterday's row re-keyed or overwritten → the day the user actually
///    walked is gone from history, the streak breaks and the weekly chart
///    loses a bar.
///
/// `_onStepCount` reads `clock.now()`, so the rollover is driven here by moving
/// a fake clock across midnight rather than by waiting for one. `withClock`
/// wraps `startLiveTracking()` as well as the ticks, because a stream listener
/// runs in the zone that called `listen`, not the zone that fired the event.
library;

import 'package:clock/clock.dart';
import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' as db;
import 'package:tablet_remainder/core/services/clean_storage_service.dart';
import 'package:tablet_remainder/features/steps/services/step_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // `Pedometer.stepCountStream` is this EventChannel. Driving it by hand is the
  // only way to have live tracking genuinely running under `flutter test`.
  const stepCount = EventChannel('step_count');

  late db.AppDatabase database;
  late void Function(int cumulativeSinceBoot) tick;

  /// The fake wall clock. Mutated by the tests to cross midnight.
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
  /// tracking started INSIDE that zone so `_onStepCount` sees the fake clock.
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

  test('the new day starts at zero, not at yesterday’s total', () async {
    now = DateTime(2026, 5, 12, 23, 50);
    await live(() async {
      await walk(120000); // first event of the evening: anchors the baseline
      await walk(124000); // 4000 steps before midnight
      expect(StepService.getTodayData().effectiveSteps, 4000);

      now = DateTime(2026, 5, 13, 0, 5);
      await walk(124300); // the first reading of the new day re-anchors
      expect(StepService.getTodayData().effectiveSteps, 0,
          reason: 'the rollover tick is a re-baseline, it carries nothing over');

      await walk(124800); // 500 steps after midnight
      expect(StepService.getTodayData().effectiveSteps, 500,
          reason: 'the new day counts only steps taken after midnight');
    });
  });

  test('yesterday keeps the steps it was walked', () async {
    now = DateTime(2026, 5, 12, 23, 50);
    await live(() async {
      await walk(120000);
      await walk(124000);

      now = DateTime(2026, 5, 13, 0, 5);
      await walk(124300);
      await walk(124800);

      final yesterday = StepService.getDataForDate(DateTime(2026, 5, 12));
      expect(yesterday, isNotNull, reason: 'the walked day vanished from history');
      expect(yesterday!.effectiveSteps, 4000);
      // Two separate rows, not one row moved forward.
      expect(StepService.getDataForDate(DateTime(2026, 5, 13))?.effectiveSteps,
          500);
    });
  });

  test('the rollover survives a month boundary', () async {
    now = DateTime(2026, 4, 30, 23, 59);
    await live(() async {
      await walk(9000);
      await walk(9700); // 700 steps on Apr 30

      now = DateTime(2026, 5, 1, 0, 1);
      await walk(9700); // re-baseline on the new day
      await walk(9900);

      expect(
          StepService.getDataForDate(DateTime(2026, 4, 30))?.effectiveSteps, 700);
      expect(
          StepService.getDataForDate(DateTime(2026, 5, 1))?.effectiveSteps, 200);
    });
  });

  test('a reboot at midnight still opens the new day at zero', () async {
    // The cumulative-since-boot counter restarts after a reboot, so the first
    // reading of the new day can be a tiny number. The rollover must re-anchor
    // to it; treating it as a delta against the old baseline yields a large
    // negative and the new day never gets written at all.
    now = DateTime(2026, 5, 12, 23, 50);
    await live(() async {
      await walk(120000);
      await walk(124000); // 4000 steps on May 12

      now = DateTime(2026, 5, 13, 0, 5);
      await walk(40); // rebooted overnight: the sensor restarted near zero
      await walk(340); // 300 steps on May 13

      expect(StepService.getDataForDate(DateTime(2026, 5, 13))?.effectiveSteps,
          300, reason: 'the new day was never opened');
      expect(StepService.getDataForDate(DateTime(2026, 5, 12))?.effectiveSteps,
          4000, reason: 'yesterday must not be disturbed by the reboot');
    });
  });
}
