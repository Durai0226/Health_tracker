/// "Step counting: pedometer only counts while the Steps screen is open."
///
/// Android's sensor counts cumulative since boot whether or not the app runs, so
/// the steps taken while it was closed are the difference between the reading at
/// the last count and the first reading of the next session. These pin that sum
/// and, as much, the cases where it must NOT be claimed: another day, a restart
/// of the phone, a wipe, an allowance given afresh.
library;

import 'package:clock/clock.dart';
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' as db;
import 'package:tablet_remainder/core/services/clean_storage_service.dart';
import 'package:tablet_remainder/features/steps/models/step_daily_data.dart';
import 'package:tablet_remainder/features/steps/services/live_step_mark.dart';
import 'package:tablet_remainder/features/steps/services/step_sensor_access.dart';
import 'package:tablet_remainder/features/steps/services/step_service.dart';

class _Access implements StepSensorAccess {
  _Access(this.granted);
  final bool granted;
  @override
  Future<bool> isGranted() async => granted;
  @override
  Future<bool> request() async => granted;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const stepCount = EventChannel('step_count');

  late db.AppDatabase database;
  late void Function(int cumulativeSinceBoot) tick;
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
    debugDefaultTargetPlatformOverride = null;
    await StepService.resetForTesting();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockStreamHandler(stepCount, null);
    await database.close();
  });

  Future<void> walk(int reading) async {
    tick(reading);
    await Future<void>.delayed(Duration.zero);
  }

  StepDailyData? dayNow() =>
      StepService.getDataForDate(DateTime(now.year, now.month, now.day));

  int steps() => dayNow()?.effectiveSteps ?? 0;

  Future<void> inClock(Future<void> Function() body) =>
      withClock(Clock(() => now), body);

  /// Start counting the way the app shell does, then stop the way the phone ending
  /// the process does: nothing more is written, and a fresh session starts.
  Future<void> session(
    List<int> readings, {
    bool allowed = true,
  }) =>
      inClock(() async {
        await StepService.keepCountingWhileOpen(access: _Access(allowed));
        for (final r in readings) {
          await walk(r);
        }
        await StepService.flushPendingLiveDay();
        await StepService.stopLiveTracking();
      });

  group('LiveStepMark', () {
    test('what is written is read back', () {
      final back = LiveStepMark.decode(
          const LiveStepMark(dayKey: '2026-05-12', raw: 98765).encode());
      expect(back?.dayKey, '2026-05-12');
      expect(back?.raw, 98765);
    });

    test('anything else counts nothing', () {
      for (final bad in <Object?>[null, '', 'x', '|5', '2026-05-12|', '2026-05-12|-3', '2026-05-12|1.5', 5]) {
        expect(LiveStepMark.decode(bad), isNull, reason: '$bad');
      }
    });

    test('the same day counts the gap; another day and a reboot count none', () {
      const mark = LiveStepMark(dayKey: '2026-05-12', raw: 5000);
      expect(mark.stepsSince('2026-05-12', 5400), 400);
      expect(mark.stepsSince('2026-05-12', 5000), 0);
      expect(mark.stepsSince('2026-05-13', 5400), 0,
          reason: 'a gap over midnight cannot be split between two days');
      expect(mark.stepsSince('2026-05-12', 120), 0,
          reason: 'the counter began again after a restart of the phone');
    });
  });

  group('keepCountingWhileOpen', () {
    test('starts the sensor on Android when it is allowed', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      now = DateTime(2026, 5, 12, 9);
      await inClock(() async {
        await StepService.keepCountingWhileOpen(access: _Access(true));
        expect(StepService.liveTrackingStartedForTesting, isTrue);
      });
    });

    test('does nothing when the sensor was not allowed', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      await StepService.keepCountingWhileOpen(access: _Access(false));
      expect(StepService.liveTrackingStartedForTesting, isFalse,
          reason: 'launch must never ask, and must not subscribe without a yes');
    });

    test('does nothing on an iPhone, where reading it raises a prompt', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      await StepService.keepCountingWhileOpen(access: _Access(true));
      expect(StepService.liveTrackingStartedForTesting, isFalse);
    });

    test('is harmless when already counting', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      now = DateTime(2026, 5, 12, 9);
      await inClock(() async {
        await StepService.keepCountingWhileOpen(access: _Access(true));
        await StepService.keepCountingWhileOpen(access: _Access(true));
        expect(StepService.liveTrackingStartedForTesting, isTrue);
      });
    });
  });

  group('steps taken while the app was closed', () {
    setUp(() => debugDefaultTargetPlatformOverride = TargetPlatform.android);

    test('are added to the same day at the next open', () async {
      now = DateTime(2026, 5, 12, 9);
      await session([50000, 50400]); // 400 counted live
      expect(steps(), 400);

      now = DateTime(2026, 5, 12, 18); // the app was closed; 1,100 steps walked
      await session([51500]);
      expect(steps(), 1500,
          reason: '400 counted live + the 1,100 the phone counted meanwhile');
    });

    test('are not given an hour of their own', () async {
      now = DateTime(2026, 5, 12, 9);
      await session([50000, 50400]);
      now = DateTime(2026, 5, 12, 18);
      await session([51500]);
      final hourly = dayNow()!.hourly;
      expect(hourly[9], 400);
      expect(hourly[18], 0,
          reason: 'they were taken at some time since 9, not at 6 pm');
    });

    test('are not counted across midnight', () async {
      now = DateTime(2026, 5, 12, 22);
      await session([50000, 50400]);
      now = DateTime(2026, 5, 13, 8);
      await session([60000]);
      expect(StepService.getDataForDate(DateTime(2026, 5, 13))?.effectiveSteps ?? 0, 0,
          reason: 'ten thousand steps cannot be told apart from the two days');
      expect(StepService.getDataForDate(DateTime(2026, 5, 12))?.effectiveSteps, 400);
    });

    test('are not counted after the phone restarted', () async {
      now = DateTime(2026, 5, 12, 9);
      await session([50000, 50400]);
      now = DateTime(2026, 5, 12, 18);
      await session([300]); // the counter began again at the restart
      expect(steps(), 400);
    });

    test('are never more than the phone counted after a restart', () async {
      now = DateTime(2026, 5, 12, 9);
      await session([50000, 50400]);
      now = DateTime(2026, 5, 12, 18);
      await session([52000]); // restarted, then 2,000 since: claims 1,600, not 2,000
      expect(steps(), 400 + 1600);
    });

    test('an allowance given afresh does not count what came before it', () async {
      now = DateTime(2026, 5, 12, 9);
      await session([50000, 50400]);
      await StepService.forgetLiveMark();
      now = DateTime(2026, 5, 12, 18);
      await session([51500]);
      expect(steps(), 400);
    });

    test('a wipe does not bring back the steps since', () async {
      now = DateTime(2026, 5, 12, 9);
      await session([50000, 50400]);
      await CleanStorageService.clearAllPersistentData();
      now = DateTime(2026, 5, 12, 18);
      await session([51500]);
      expect(steps(), 0);
    });

    test('a count the throttle still held is written when the app is left', () async {
      now = DateTime(2026, 5, 12, 9);
      await inClock(() async {
        await StepService.keepCountingWhileOpen(access: _Access(true));
        await walk(50000);
        await walk(50400);
        // No flush yet: the 30-second throttle is still holding the day.
        await StepService.flushPendingLiveDay(); // what the shell does on pause
        await StepService.stopLiveTracking(flush: false);
      });
      now = DateTime(2026, 5, 12, 18);
      await session([51500]);
      expect(steps(), 1500);
    });
  });
}
