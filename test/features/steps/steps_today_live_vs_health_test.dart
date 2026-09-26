/// Today's step count used to flip-flop between the pedometer and the health
/// store.
///
/// `syncFromHealth` wrote the Health Connect / HealthKit figure for TODAY
/// verbatim. That figure lags — the platform stores aggregate on a delay — so
/// the number on screen jumped BACKWARDS after every sync and then climbed
/// again, which reads as steps being lost. Worse, the live pedometer baseline
/// was left anchored to the pre-sync total, so the following sensor ticks added
/// their delta to a stale start count and quietly under-counted the rest of
/// the day.
///
/// Today's total must never go down while live tracking is running, and after a
/// sync a sensor tick must add only the steps taken SINCE that sync.
library;

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
    await StepService.startLiveTracking();
  });

  tearDown(() async {
    await StepService.resetForTesting();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockStreamHandler(stepCount, null);
    await database.close();
  });

  /// Let the stream event reach the listener.
  Future<void> settle() => Future<void>.delayed(Duration.zero);

  Future<void> walk(int cumulative) async {
    tick(cumulative);
    await settle();
  }

  test('live tracking is actually running (harness sanity)', () async {
    await walk(1000); // first event: anchors the baseline
    await walk(1500);
    expect(StepService.getTodayData().effectiveSteps, 500);
    expect(StepService.liveBaselineAnchoredForTesting, isTrue);
  });

  test("a lagging Health total never lowers today's count", () async {
    await walk(1000);
    await walk(1500);
    expect(StepService.getTodayData().effectiveSteps, 500);

    // Health Connect has only caught up to 300 of those steps.
    final merged =
        StepService.storeHealthDayForTesting(DateTime.now(), 300, isToday: true);

    expect(merged.effectiveSteps, 500, reason: 'the pedometer total stands');
    // The broken behaviour: the ring visibly dropped to 300.
    expect(merged.effectiveSteps, isNot(300));
    expect(StepService.getTodayData().effectiveSteps, 500);
  });

  test('a higher Health total is adopted, and NOT ONE STEP after it is lost',
      () async {
    await walk(1000);
    await walk(1500); // pedometer says 500

    // A paired watch has already reported 800 to the health store.
    final merged =
        StepService.storeHealthDayForTesting(DateTime.now(), 800, isToday: true);
    expect(merged.effectiveSteps, 800);

    // The sensor's since-boot origin has NOT changed, so the baseline must
    // stay anchored. Dropping it makes `_onStepCount` treat the next event as
    // a first event: it re-baselines and returns WITHOUT applying that event's
    // delta, so every sync while the dashboard is open silently discards the
    // steps taken since the last sensor event.
    expect(StepService.liveBaselineAnchoredForTesting, isTrue,
        reason: 'a null baseline costs the user the next tick entirely');
    expect(StepService.liveStartStepsForTesting, 800,
        reason: 'only the DAY START moves — to the total we just kept');

    await walk(1900); // 400 steps on the sensor since the 1500 reading

    // 800 at the sync + the 400 walked after it. Every step counted once.
    expect(StepService.getTodayData().effectiveSteps, 1200);
    // The stale-baseline bug: 1900 - 1000 = 900, swallowing what Health knew.
    expect(StepService.getTodayData().effectiveSteps, isNot(900));
  });

  test('negative: a sync does not lose the steps taken since the last tick',
      () async {
    await walk(1000);
    await walk(1200); // 200 steps

    // Sync adopts a LOWER health figure, so the live total is kept.
    StepService.storeHealthDayForTesting(DateTime.now(), 50, isToday: true);
    expect(StepService.getTodayData().effectiveSteps, 200,
        reason: 'the live total wins when it is higher');

    // One more tick. Under the dropped-baseline behaviour this event was
    // consumed as a pure re-baseline and its 100 steps vanished.
    await walk(1300);
    expect(StepService.getTodayData().effectiveSteps, 300);
  });

  test('past days still take the Health figure verbatim', () async {
    await walk(1000);
    await walk(1500);

    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    final merged =
        StepService.storeHealthDayForTesting(yesterday, 300, isToday: false);
    expect(merged.effectiveSteps, 300);
    // …and today is untouched by a past-day sync.
    expect(StepService.getTodayData().effectiveSteps, 500);
    expect(StepService.liveBaselineAnchoredForTesting, isTrue);
  });

  test('with live tracking stopped, Health is authoritative for today too',
      () async {
    await walk(1000);
    await walk(1500);
    await StepService.stopLiveTracking();

    final merged =
        StepService.storeHealthDayForTesting(DateTime.now(), 300, isToday: true);
    // Nothing is watching the sensor any more, so there is no fresher number to
    // defend — the guard must not over-fire and pin a stale total forever.
    expect(merged.effectiveSteps, 300);
  });
}
