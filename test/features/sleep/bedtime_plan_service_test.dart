/// Tonight's bedtime from the real nights, and the wind-down reminder that can
/// follow it.
library;

import 'package:clock/clock.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' as db;
import 'package:tablet_remainder/core/health/bedtime_plan.dart';
import 'package:tablet_remainder/core/health/sleep_debt.dart';
import 'package:tablet_remainder/core/services/active_profile_service.dart';
import 'package:tablet_remainder/core/services/clean_storage_service.dart';
import 'package:tablet_remainder/core/services/notification_service.dart';
import 'package:tablet_remainder/features/sleep/models/sleep_schedule.dart';
import 'package:tablet_remainder/features/sleep/models/sleep_stage.dart';
import 'package:tablet_remainder/features/sleep/services/sleep_service.dart';
import 'package:tablet_remainder/features/sleep/services/wind_down_service.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../../support/recording_notification_scheduler.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late db.AppDatabase database;
  late RecordingNotificationScheduler scheduler;
  final now = DateTime(2026, 6, 20, 12);

  setUpAll(() {
    tz_data.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('UTC'));
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    database = db.AppDatabase.forTesting(NativeDatabase.memory());
    db.AppDatabase.setInstanceForTesting(database);
    ActiveProfileService().resetForTesting();
    CleanStorageService.resetForTesting();
    await CleanStorageService.init();
    await SleepService.resetForTesting();
    scheduler = RecordingNotificationScheduler();
    NotificationService().schedulerForTesting = scheduler;
  });

  tearDown(() async => database.close());

  String key(int daysAgo) {
    final d = DateTime(now.year, now.month, now.day - daysAgo);
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  /// The night that ended [daysAgo] mornings ago, with [asleep] of [inBed]
  /// minutes asleep, from a device or by hand.
  Future<void> night(int daysAgo, int asleep,
      {int inBed = 480, SleepSource source = SleepSource.healthConnect}) async {
    final wake = DateTime(now.year, now.month, now.day - daysAgo, 7);
    await database.sleepDao.upsert(db.SleepSessionsCompanion(
      id: Value('n$daysAgo-${source.name}'),
      dateKey: Value(key(daysAgo)),
      bedtime: Value(wake.subtract(Duration(minutes: inBed))),
      wakeTime: Value(wake),
      inBedMinutes: Value(inBed),
      asleepMinutes: Value(asleep),
      sourceIndex: Value(source.index),
      createdAt: Value(wake),
      updatedAt: Value(wake),
    ));
  }

  Future<void> load({SleepSchedule? schedule}) async {
    if (schedule != null) await SleepService.saveSchedule(schedule);
    await SleepService.reloadFromDb();
  }

  Future<R> run<R>(Future<R> Function() body) => withClock(Clock.fixed(now), body);

  const goal = SleepSchedule(targetMinutes: 465, wakeHour: 7, wakeMinute: 0);

  group('tonight\'s plan', () {
    test('with no nights logged: wake less the target and the usual allowance',
        () async {
      await run(() async {
        await load(schedule: goal);
        final p = SleepService.bedtimePlan();
        expect(p.bedMinuteOfDay, 23 * 60, reason: '7:00 - (7h45m + 15m)');
        expect(p.catchUpMinutes, 0);
        expect(p.awakeIsYours, isFalse);
      });
    });

    test('follows the wake time on the schedule', () async {
      await run(() async {
        await load(schedule: goal.copyWith(wakeHour: 6, wakeMinute: 30));
        expect(SleepService.bedtimePlan().bedMinuteOfDay, 22 * 60 + 30);
      });
    });

    test('behind on sleep, it asks for the debt\'s own catch-up', () async {
      await run(() async {
        for (var i = 1; i <= 8; i++) {
          await night(i, 400);
        }
        await load(schedule: goal);
        final debt = SleepService.sleepDebt();
        expect(debt.catchUp, isNotNull, reason: 'the premise');
        final p = SleepService.bedtimePlan();
        expect(p.catchUpMinutes, debt.catchUp!.minutesPerNight);
        expect(p.bedMinuteOfDay,
            (7 * 60 - (465 + p.catchUpMinutes + p.awakeMinutes)) % 1440);
      });
    });

    test('fewer than four logged nights are not enough to quote a debt', () async {
      await run(() async {
        for (var i = 1; i <= SleepDebt.minNights - 1; i++) {
          await night(i, 300);
        }
        await load(schedule: goal);
        expect(SleepService.bedtimePlan().catchUpMinutes, 0,
            reason: 'three bad nights are a few bad nights, not a debt');
      });
    });

    test('four are', () async {
      await run(() async {
        for (var i = 1; i <= SleepDebt.minNights; i++) {
          await night(i, 300);
        }
        await load(schedule: goal);
        expect(SleepService.bedtimePlan().catchUpMinutes, greaterThan(0));
      });
    });

    test('rested, it asks for nothing extra', () async {
      await run(() async {
        for (var i = 1; i <= 8; i++) {
          await night(i, 470);
        }
        await load(schedule: goal);
        expect(SleepService.bedtimePlan().catchUpMinutes, 0);
      });
    });

    test('seven measured nights give the person\'s own time awake', () async {
      await run(() async {
        for (var i = 1; i <= 7; i++) {
          await night(i, 450, inBed: 480); // 30 m awake in bed
        }
        await load(schedule: goal);
        final p = SleepService.bedtimePlan();
        expect(p.awakeMinutes, 30);
        expect(p.awakeIsYours, isTrue);
      });
    });

    test('hand-logged nights do not: their "awake" is an estimate from a rating',
        () async {
      await run(() async {
        for (var i = 1; i <= 8; i++) {
          await night(i, 440, source: SleepSource.manual);
        }
        await load(schedule: goal);
        final p = SleepService.bedtimePlan();
        expect(p.awakeMinutes, BedtimePlans.defaultAwakeMinutes);
        expect(p.awakeIsYours, isFalse);
      });
    });

    test('only the last two weeks of nights count', () async {
      await run(() async {
        for (var i = 15; i <= 22; i++) {
          await night(i, 450, inBed: 480);
        }
        await load(schedule: goal);
        expect(SleepService.bedtimePlan().awakeIsYours, isFalse);
      });
    });

    test('a night with more asleep than in bed is not a negative allowance',
        () async {
      await run(() async {
        for (var i = 1; i <= 7; i++) {
          await night(i, 500, inBed: 480);
        }
        await load(schedule: goal);
        final p = SleepService.bedtimePlan();
        expect(p.awakeIsYours, isFalse,
            reason: 'impossible nights are left out rather than averaged in');
      });
    });
  });

  group('the schedule keeps the choice', () {
    test('off by default, and kept across a restart', () async {
      await run(() async {
        await load(schedule: goal);
        expect(SleepService.getSchedule().followPlan, isFalse);
        await SleepService.saveSchedule(goal.copyWith(followPlan: true));
        await SleepService.reloadFromDb();
        expect(SleepService.getSchedule().followPlan, isTrue);
        await SleepService.saveSchedule(goal.copyWith(followPlan: false));
        await SleepService.reloadFromDb();
        expect(SleepService.getSchedule().followPlan, isFalse);
      });
    });

    test('and leaves the other settings as they were', () async {
      await run(() async {
        await load(
            schedule: goal.copyWith(
                reminderEnabled: true, alarmEnabled: true, windDownMinutes: 45));
        await SleepService.saveSchedule(
            SleepService.getSchedule().copyWith(followPlan: true));
        await SleepService.reloadFromDb();
        final s = SleepService.getSchedule();
        expect(s.reminderEnabled, isTrue);
        expect(s.alarmEnabled, isTrue);
        expect(s.windDownMinutes, 45);
        expect(s.targetMinutes, 465);
      });
    });
  });

  group('the wind-down reminder', () {
    const withReminder = SleepSchedule(
      targetMinutes: 465,
      wakeHour: 7,
      wakeMinute: 0,
      bedtimeHour: 22,
      bedtimeMinute: 30,
      windDownMinutes: 30,
      reminderEnabled: true,
    );

    test('at the usual time: the schedule\'s bedtime less the lead', () async {
      await run(() async {
        await load(schedule: withReminder);
        expect(WindDownService.minuteOfDay(), 22 * 60,
            reason: '10:30 PM bedtime, 30 minutes before');
      });
    });

    test('following the plan: the plan\'s bedtime less the lead', () async {
      await run(() async {
        await load(schedule: withReminder.copyWith(followPlan: true));
        // No debt, so the plan is 11:00 PM and the reminder 10:30 PM; give it a
        // debt to move.
        for (var i = 1; i <= 8; i++) {
          await night(i, 400);
        }
        await SleepService.reloadFromDb();
        final plan = SleepService.bedtimePlan();
        expect(plan.catchUpMinutes, greaterThan(0));
        expect(WindDownService.minuteOfDay(), plan.windDownMinuteOfDay(30));
        expect(WindDownService.minuteOfDay(), isNot(22 * 60 + 30 - 0),
            reason: 'it has moved with the debt');
      });
    });

    test('rearm does nothing while the reminder is off', () async {
      await run(() async {
        await load(schedule: withReminder.copyWith(reminderEnabled: false));
        expect(await WindDownService.rearm(), 0);
        expect(scheduler.scheduled, isEmpty);
      });
    });

    test('rearm arms the reminder where it belongs', () async {
      await run(() async {
        await load(schedule: withReminder);
        expect(await WindDownService.rearm(), 1);
        final armed = scheduler.lastFor(NotificationService.bedtimeReminderId)!;
        expect(armed.when.hour, 22);
        expect(armed.when.minute, 0);
      });
    });

    test('and says 0 when the OS would not arm it', () async {
      await run(() async {
        NotificationService().schedulerForTesting = _RefusingScheduler();
        await load(schedule: withReminder);
        expect(await WindDownService.rearm(), 0,
            reason: 'the start-up pass counts what is armed, not what was asked');
      });
    });

    test('and, following the plan, at the plan\'s time', () async {
      await run(() async {
        for (var i = 1; i <= 8; i++) {
          await night(i, 400);
        }
        await load(schedule: withReminder.copyWith(followPlan: true));
        final want = SleepService.bedtimePlan().windDownMinuteOfDay(30);
        await WindDownService.rearm();
        final armed = scheduler.lastFor(NotificationService.bedtimeReminderId)!;
        expect(armed.when.hour * 60 + armed.when.minute, want);
      });
    });
  });
}

/// A scheduler whose every arming is refused, as when notifications are off.
class _RefusingScheduler extends RecordingNotificationScheduler {
  @override
  Future<void> zonedSchedule(
    int id,
    String? title,
    String? body,
    tz.TZDateTime when,
    NotificationDetails details, {
    required AndroidScheduleMode androidScheduleMode,
    DateTimeComponents? matchDateTimeComponents,
    String? payload,
  }) async =>
      throw StateError('notifications are off');
}
