/// The daily check-in: set at first run, and now changeable and stoppable.
///
/// What is proved is the decisions: what is recorded, what is armed and
/// withdrawn, and what "on" means for an install from before there was a switch.
/// That the notification is then delivered at the minute is the OS's part.
library;

import 'package:drift/native.dart';
import 'package:flutter/material.dart' show TimeOfDay;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' show AppDatabase;
import 'package:tablet_remainder/core/services/clean_storage_service.dart';
import 'package:tablet_remainder/core/services/daily_check_in.dart';
import 'package:tablet_remainder/core/services/notification_service.dart';
import 'package:tablet_remainder/core/services/reminder_reschedule_service.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../support/recording_notification_scheduler.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late RecordingNotificationScheduler scheduler;

  setUpAll(() {
    tz_data.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('UTC'));
  });

  Future<void> boot([Map<String, Object> prefs = const {}]) async {
    SharedPreferences.setMockInitialValues(prefs);
    db = AppDatabase.forTesting(NativeDatabase.memory());
    AppDatabase.setInstanceForTesting(db);
    CleanStorageService.resetForTesting();
    await CleanStorageService.init();
    scheduler = RecordingNotificationScheduler();
    NotificationService().schedulerForTesting = scheduler;
  }

  tearDown(() async => db.close());

  RecordedSchedule? armed() => scheduler.lastFor(DailyCheckIn.notificationId);

  group('the time', () {
    test('is 09:00 until one is chosen', () async {
      await boot();
      expect(DailyCheckIn.time, const TimeOfDay(hour: 9, minute: 0));
    });

    test('is what the setup recorded, under the keys it always used', () async {
      await boot({'preferredReminderHour': 7, 'preferredReminderMinute': 30});
      // App preferences come from the database, not SharedPreferences.
      await CleanStorageService.setAppPreference('preferredReminderHour', 7);
      await CleanStorageService.setAppPreference('preferredReminderMinute', 30);
      expect(DailyCheckIn.time, const TimeOfDay(hour: 7, minute: 30));
    });

    test('a value that is not a time falls back rather than being armed', () async {
      await boot();
      await CleanStorageService.setAppPreference('preferredReminderHour', 31);
      await CleanStorageService.setAppPreference('preferredReminderMinute', -4);
      expect(DailyCheckIn.time, const TimeOfDay(hour: 9, minute: 0));
      await CleanStorageService.setAppPreference('preferredReminderHour', 'nine');
      expect(DailyCheckIn.time.hour, 9);
    });
  });

  group('turning it on', () {
    test('records it, and arms one daily notification at that time', () async {
      await boot();

      await DailyCheckIn.apply(enabled: true, time: const TimeOfDay(hour: 8, minute: 15));

      expect(await DailyCheckIn.isEnabled(), isTrue);
      expect(DailyCheckIn.time, const TimeOfDay(hour: 8, minute: 15));
      final a = armed()!;
      expect(a.title, 'Daily check-in');
      expect([a.when.hour, a.when.minute], [8, 15]);
      expect(a.matchDateTimeComponents, DateTimeComponents.time,
          reason: 'a daily repeat, not a one-off');
    });

    test('without a time it uses the one already chosen', () async {
      await boot();
      await DailyCheckIn.apply(enabled: true, time: const TimeOfDay(hour: 6, minute: 45));
      scheduler.clear();

      await DailyCheckIn.apply(enabled: true);

      expect([armed()!.when.hour, armed()!.when.minute], [6, 45]);
    });

    test('moving the time arms the new one again under the same id', () async {
      await boot();
      await DailyCheckIn.apply(enabled: true, time: const TimeOfDay(hour: 8, minute: 0));
      await DailyCheckIn.apply(enabled: true, time: const TimeOfDay(hour: 21, minute: 30));

      final mine = scheduler.scheduled.where((s) => s.id == DailyCheckIn.notificationId);
      expect(mine.map((s) => s.when.hour), [8, 21]);
      expect(scheduler.lastFor(DailyCheckIn.notificationId)!.when.hour, 21,
          reason: 'arming replaces by id: the later one is what the OS holds');
    });
  });

  group('when it cannot be armed', () {
    // `scheduleDailyNotification` answers false rather than throwing. The choice
    // used to be recorded before it was asked, so a refusal left Settings saying
    // "on" and the next start arming a time the person had been told could not be
    // set — with nothing ever appearing.
    setUp(() async {
      await boot();
    });

    void refuseArming() {
      scheduler.refuseExactMidCall.add(DailyCheckIn.notificationId);
      scheduler.midCallError = StateError('the OS said no');
    }

    test('turning it on throws, and records nothing', () async {
      refuseArming();

      await expectLater(
          DailyCheckIn.apply(enabled: true, time: const TimeOfDay(hour: 8, minute: 15)),
          throwsStateError);

      expect(CleanStorageService.getAppPreference(DailyCheckIn.enabledKey, null), isNull);
      expect(DailyCheckIn.time, DailyCheckIn.defaultTime, reason: 'not the new time either');
      expect(await DailyCheckIn.rearm(), 0);
    });

    test('moving the time throws, and the old time and the "on" stay', () async {
      await DailyCheckIn.apply(enabled: true, time: const TimeOfDay(hour: 8, minute: 0));
      refuseArming();

      await expectLater(
          DailyCheckIn.apply(enabled: true, time: const TimeOfDay(hour: 21, minute: 0)),
          throwsStateError);

      expect(await DailyCheckIn.isEnabled(), isTrue);
      expect(DailyCheckIn.time, const TimeOfDay(hour: 8, minute: 0));
    });

    test('turning it off throws if it could not be withdrawn, and stays on', () async {
      await DailyCheckIn.apply(enabled: true, time: const TimeOfDay(hour: 8, minute: 0));
      scheduler.failCancel.add(DailyCheckIn.notificationId);

      await expectLater(DailyCheckIn.apply(enabled: false), throwsA(anything));

      expect(await DailyCheckIn.isEnabled(), isTrue,
          reason: 'it is still armed, so it still says so');
    });

    test('a first arm that is refused withdraws what it left, so nothing reads as "armed"',
        () async {
      refuseArming();

      await expectLater(
          DailyCheckIn.apply(enabled: true, time: const TimeOfDay(hour: 8, minute: 15)),
          throwsStateError);

      expect(scheduler.cancelled, contains(DailyCheckIn.notificationId));
    });

    test('but a time change that is refused leaves the check-in that is already set',
        () async {
      await DailyCheckIn.apply(enabled: true, time: const TimeOfDay(hour: 8, minute: 0));
      scheduler.cancelled.clear();
      refuseArming();

      await expectLater(
          DailyCheckIn.apply(enabled: true, time: const TimeOfDay(hour: 21, minute: 0)),
          throwsStateError);

      expect(scheduler.cancelled, isNot(contains(DailyCheckIn.notificationId)));
      expect(await DailyCheckIn.isEnabled(), isTrue);
    });

    test('re-arming one that cannot be armed is not counted', () async {
      await DailyCheckIn.apply(enabled: true, time: const TimeOfDay(hour: 8, minute: 0));
      scheduler.clear();
      refuseArming();

      expect(await DailyCheckIn.rearm(), 0);
    });
  });

  group('turning it off', () {
    test('records it and withdraws the notification', () async {
      await boot();
      await DailyCheckIn.apply(enabled: true, time: const TimeOfDay(hour: 8, minute: 0));

      await DailyCheckIn.apply(enabled: false);

      expect(await DailyCheckIn.isEnabled(), isFalse);
      expect(scheduler.cancelled, contains(DailyCheckIn.notificationId));
    });

    test('keeps the time, so turning it back on is where it was', () async {
      await boot();
      await DailyCheckIn.apply(enabled: true, time: const TimeOfDay(hour: 7, minute: 10));
      await DailyCheckIn.apply(enabled: false);

      expect(DailyCheckIn.time, const TimeOfDay(hour: 7, minute: 10));
    });
  });

  group('an install from before there was a switch', () {
    test('with the notification armed: it is on, and that is remembered', () async {
      await boot();
      scheduler.pending = [
        const PendingNotificationRequest(DailyCheckIn.notificationId, 'Daily check-in', '', null)
      ];

      expect(await DailyCheckIn.isEnabled(), isTrue);

      scheduler.pending = [];
      expect(await DailyCheckIn.isEnabled(), isTrue,
          reason: 'asked once, then recorded: it does not flip with the OS list');
    });

    test('with the Android alarm record present: it is on', () async {
      await boot({'alarm_900001': '{"hour":9,"minute":0}'});
      expect(await DailyCheckIn.isEnabled(), isTrue);
    });

    test('with nothing armed: it is off, but that is NOT written down', () async {
      // An empty list says "nothing armed" as readily as it says "the plugin was
      // not ready yet". Written down, the second reading became a decision nobody
      // made, and rearm() never armed it again.
      await boot();
      expect(await DailyCheckIn.isEnabled(), isFalse);
      expect(CleanStorageService.getAppPreference(DailyCheckIn.enabledKey, null), isNull);

      scheduler.pending = [
        const PendingNotificationRequest(DailyCheckIn.notificationId, 'x', '', null)
      ];
      expect(await DailyCheckIn.isEnabled(), isTrue,
          reason: 'the next look sees what was not there at the first');
    });

    test('a first look that fails reads as off for now, and is not held against it', () async {
      await boot();
      scheduler.pendingError = StateError('plugin not ready');

      expect(await DailyCheckIn.isEnabled(), isFalse);
      expect(await DailyCheckIn.rearm(), 0);
      expect(CleanStorageService.getAppPreference(DailyCheckIn.enabledKey, null), isNull);

      // The plugin is ready, and the notification the old build armed is there.
      scheduler.pendingError = null;
      scheduler.pending = [
        const PendingNotificationRequest(DailyCheckIn.notificationId, 'Daily check-in', '', null)
      ];
      expect(await DailyCheckIn.rearm(), 1);
      expect(await DailyCheckIn.isEnabled(), isTrue);
    });

    test('a yes, once seen, stays: it does not flip with the OS list', () async {
      await boot();
      scheduler.pending = [
        const PendingNotificationRequest(DailyCheckIn.notificationId, 'x', '', null)
      ];
      expect(await DailyCheckIn.isEnabled(), isTrue);

      scheduler.pending = [];
      expect(await DailyCheckIn.isEnabled(), isTrue);
    });

    test('someone who turned it off stays off even if something is armed', () async {
      await boot();
      await DailyCheckIn.apply(enabled: false);
      scheduler.pending = [
        const PendingNotificationRequest(DailyCheckIn.notificationId, 'x', '', null)
      ];
      expect(await DailyCheckIn.isEnabled(), isFalse);
    });
  });

  group('re-arming at start and after a restore', () {
    test('when it is on: armed again at its time, and counted', () async {
      await boot();
      await DailyCheckIn.apply(enabled: true, time: const TimeOfDay(hour: 8, minute: 20));
      scheduler.clear();

      final n = await DailyCheckIn.rearm();

      expect(n, 1);
      expect([armed()!.when.hour, armed()!.when.minute], [8, 20]);
    });

    test('when it is off: nothing is armed, and nothing counted', () async {
      await boot();
      await DailyCheckIn.apply(enabled: false);
      scheduler.clear();

      expect(await DailyCheckIn.rearm(), 0);
      expect(scheduler.scheduled, isEmpty);
    });

    test('on a new phone the restored preference arms it again', () async {
      // The preferences came back from a backup; nothing is armed on this phone.
      await boot();
      await CleanStorageService.setAppPreference(DailyCheckIn.enabledKey, true);
      await CleanStorageService.setAppPreference(DailyCheckIn.hourKey, 7);
      await CleanStorageService.setAppPreference(DailyCheckIn.minuteKey, 0);

      expect(await DailyCheckIn.rearm(), 1);
      expect(armed()!.when.hour, 7);
    });

    test('it is one of the families re-armed at every start', () async {
      await boot();
      expect(ReminderRescheduleService.familyNames, contains('daily check-in'));
    });
  });
}
