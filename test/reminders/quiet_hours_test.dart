/// Quiet hours: the reminders a person made wait until the window ends.
///
/// The decisions worth pinning without a phone: WHICH reminders wait (Normal
/// ones — not the silent tier, not the two that mean "reach me whatever the
/// hour", never a medicine), WHEN they land, and that a repeat tied to weekdays
/// still lands on the right ones after being pushed past midnight.
library;

import 'package:clock/clock.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' show AppDatabase;
import 'package:tablet_remainder/core/health/quiet_window.dart';
import 'package:tablet_remainder/core/services/active_profile_service.dart';
import 'package:tablet_remainder/core/services/clean_storage_service.dart';
import 'package:tablet_remainder/core/services/notification_service.dart';
import 'package:tablet_remainder/core/services/reminder_reschedule_service.dart';
import 'package:tablet_remainder/features/reminders/models/reminder_model.dart';
import 'package:tablet_remainder/features/reminders/services/quiet_hours.dart';
import 'package:tablet_remainder/features/reminders/services/reminder_alarm.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../support/recording_notification_scheduler.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tz_data.initializeTimeZones();

  const night = QuietWindow(startMinute: 22 * 60, endMinute: 7 * 60);
  // Friday 13 March 2026, noon.
  final now = DateTime(2026, 3, 13, 12);

  DateTime at(int h, int m, {int day = 13}) => DateTime(2026, 3, day, h, m);

  ({DateTime time, RepeatType repeat, List<int>? days}) hold({
    QuietWindow? window = night,
    ReminderEscalation escalation = ReminderEscalation.standard,
    required DateTime time,
    RepeatType repeat = RepeatType.none,
    List<int>? days,
  }) =>
      QuietHours.hold(
          window: window,
          escalation: escalation,
          time: time,
          repeat: repeat,
          days: days,
          now: now);

  group('which reminders wait', () {
    test('a Normal one due in the window waits for its end', () {
      expect(hold(time: at(23, 0)).time, at(7, 0, day: 14));
    });

    test('with no window, nothing waits', () {
      final h = hold(window: null, time: at(23, 0));
      expect(h.time, at(23, 0));
    });

    test('a Quiet one is left alone: it makes no sound, so there is nothing to hold',
        () {
      expect(hold(escalation: ReminderEscalation.gentle, time: at(23, 0)).time,
          at(23, 0));
    });

    test('Insistent and Critical are never held: they mean reach me at any hour',
        () {
      for (final e in [ReminderEscalation.insistent, ReminderEscalation.critical]) {
        expect(hold(escalation: e, time: at(23, 0)).time, at(23, 0),
            reason: e.name);
      }
    });

    test('outside the window, nothing moves', () {
      expect(hold(time: at(15, 0)).time, at(15, 0));
      expect(hold(time: at(7, 0, day: 14)).time, at(7, 0, day: 14),
          reason: 'due the minute quiet ends');
    });

    test('a one-off already in the past is not waiting for anything', () {
      final past = DateTime(2026, 3, 13, 3, 0); // before `now`
      expect(hold(time: past).time, past);
    });
  });

  group('when it lands', () {
    test('after midnight it lands this morning, before midnight tomorrow', () {
      expect(hold(time: at(3, 0, day: 14)).time, at(7, 0, day: 14));
      expect(hold(time: at(22, 0)).time, at(7, 0, day: 14));
    });

    test('every held reminder lands on the same minute — the end of the window', () {
      final a = hold(time: at(22, 5)).time;
      final b = hold(time: at(23, 55)).time;
      final c = hold(time: at(2, 30, day: 14)).time;
      expect(a, at(7, 0, day: 14));
      expect(b, a);
      expect(c, a);
    });
  });

  group('a repeat that lands on a different day', () {
    test('daily keeps repeating, at the end of the window', () {
      final h = hold(time: at(23, 0), repeat: RepeatType.daily);
      expect(h.repeat, RepeatType.daily);
      expect(h.time.hour, 7);
      expect(h.time.minute, 0);
    });

    test('weekly follows the date: Friday 23:00 becomes Saturday 07:00', () {
      final h = hold(time: at(23, 0), repeat: RepeatType.weekly);
      expect(h.repeat, RepeatType.weekly);
      expect(h.time, at(7, 0, day: 14));
      expect(h.time.weekday, DateTime.saturday,
          reason: 'it was a Friday reminder; the weekly repeat is now Saturday');
    });

    test('weekdays pushed past midnight become Tuesday to Saturday', () {
      final h = hold(time: at(23, 0), repeat: RepeatType.weekdays);
      expect(h.repeat, RepeatType.custom);
      expect(h.days, [2, 3, 4, 5, 6],
          reason: 'a Monday 23:00 reminder arrives on Tuesday morning; saying '
              '"weekdays" would fire it Monday to Friday, a day early');
    });

    test('weekdays after midnight stay weekdays: the date does not change', () {
      final h = hold(time: at(3, 0, day: 14), repeat: RepeatType.weekdays);
      expect(h.repeat, RepeatType.weekdays);
      expect(h.time, at(7, 0, day: 14));
    });

    test('weekends pushed past midnight wrap: Saturday and Sunday become Sunday and Monday',
        () {
      final h = hold(time: at(23, 0), repeat: RepeatType.weekends);
      expect(h.repeat, RepeatType.custom);
      expect(h.days, [7, 1]);
    });

    test('chosen days move one on, Sunday wrapping to Monday', () {
      final h = hold(time: at(23, 0), repeat: RepeatType.custom, days: [1, 3, 7]);
      expect(h.repeat, RepeatType.custom);
      expect(h.days, [2, 4, 1]);
    });

    test('chosen days after midnight stay where they are', () {
      final h =
          hold(time: at(3, 0, day: 14), repeat: RepeatType.custom, days: [1, 3, 7]);
      expect(h.days, [1, 3, 7]);
      expect(h.time, at(7, 0, day: 14));
    });

    test('chosen days with none chosen are left alone', () {
      final h = hold(time: at(23, 0), repeat: RepeatType.custom, days: const []);
      expect(h.time, at(23, 0));
      expect(h.days, isEmpty);
    });

    test('a repeat armed natively is judged by its time of day, past or not', () {
      // A daily reminder's stored anchor is the day it was made; its time of day
      // is what repeats.
      final anchor = DateTime(2026, 1, 5, 23, 30);
      final h = hold(time: anchor, repeat: RepeatType.daily);
      expect(h.time.hour, 7);
    });
  });

  group('the setting', () {
    late AppDatabase db;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      db = AppDatabase.forTesting(NativeDatabase.memory());
      AppDatabase.setInstanceForTesting(db);
      ActiveProfileService().resetForTesting();
      CleanStorageService.resetForTesting();
      await CleanStorageService.init();
    });

    tearDown(() async => db.close());

    test('off by default, offering 22:00 to 07:00 when switched on', () {
      expect(QuietHours.enabled, isFalse);
      expect(QuietHours.active, isNull);
      expect(QuietHours.window, night);
    });

    test('a saved choice is read back', () async {
      await QuietHours.save(
          enabled: true,
          window: const QuietWindow(startMinute: 23 * 60 + 15, endMinute: 6 * 60 + 30));

      expect(QuietHours.enabled, isTrue);
      expect(QuietHours.active,
          const QuietWindow(startMinute: 23 * 60 + 15, endMinute: 6 * 60 + 30));
    });

    test('switched off, the window is remembered but not applied', () async {
      await QuietHours.save(
          enabled: false,
          window: const QuietWindow(startMinute: 21 * 60, endMinute: 6 * 60));

      expect(QuietHours.active, isNull);
      expect(QuietHours.window,
          const QuietWindow(startMinute: 21 * 60, endMinute: 6 * 60));
    });

    test('a window of no length is not applied even when on', () async {
      await QuietHours.save(
          enabled: true,
          window: const QuietWindow(startMinute: 600, endMinute: 600));

      expect(QuietHours.active, isNull);
    });

    test('a stored value that is not a minute of the day falls back', () async {
      await CleanStorageService.setAppPreference('quiet_hours_start', 99999);
      await CleanStorageService.setAppPreference('quiet_hours_end', -5);

      expect(QuietHours.window, night);
    });
  });

  group('arming a reminder', () {
    late AppDatabase db;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      db = AppDatabase.forTesting(NativeDatabase.memory());
      AppDatabase.setInstanceForTesting(db);
      ActiveProfileService().resetForTesting();
      CleanStorageService.resetForTesting();
      await CleanStorageService.init();
    });

    tearDown(() async => db.close());

    Reminder reminder(
      String id, {
      ReminderEscalation escalation = ReminderEscalation.standard,
      RepeatType repeat = RepeatType.daily,
      DateTime? at,
      DateTime? endsAt,
    }) =>
        Reminder(
          id: id,
          title: 'Water the plants',
          body: '',
          scheduledTime: at ?? DateTime(2026, 3, 1, 23, 0),
          repeatType: repeat,
          escalation: escalation,
          endsAt: endsAt,
        );

    Future<void> quietOn() =>
        QuietHours.save(enabled: true, window: night);

    test('off: it arms at its own time', () {
      withClock(Clock.fixed(now), () {
        final r = ReminderArmRequest.forNextOccurrence(reminder('a'))!;
        expect(r.scheduledTime.hour, 23);
      });
    });

    test('on: a daily Normal reminder arms at the end of quiet hours', () async {
      await quietOn();
      withClock(Clock.fixed(now), () {
        final r = ReminderArmRequest.forNextOccurrence(reminder('a'))!;
        expect(r.scheduledTime.hour, 7);
        expect(r.repeatType, RepeatType.daily);
      });
    });

    test('on: an Insistent reminder still arms at its own time', () async {
      await quietOn();
      withClock(Clock.fixed(now), () {
        final r = ReminderArmRequest.forNextOccurrence(
            reminder('a', escalation: ReminderEscalation.insistent))!;
        expect(r.scheduledTime.hour, 23);
      });
    });

    test('on: a one-off tonight waits until tomorrow morning', () async {
      await quietOn();
      withClock(Clock.fixed(now), () {
        final r = ReminderArmRequest.forNextOccurrence(reminder('a',
            repeat: RepeatType.none, at: DateTime(2026, 3, 13, 23, 30)))!;
        expect(r.scheduledTime, DateTime(2026, 3, 14, 7));
      });
    });

    test('on: a one-off in the daytime is untouched', () async {
      await quietOn();
      withClock(Clock.fixed(now), () {
        final r = ReminderArmRequest.forNextOccurrence(reminder('a',
            repeat: RepeatType.none, at: DateTime(2026, 3, 13, 18, 0)))!;
        expect(r.scheduledTime, DateTime(2026, 3, 13, 18));
      });
    });

    test('on: one that repeats until a date is held a night at a time', () async {
      await quietOn();
      withClock(Clock.fixed(now), () {
        final r = ReminderArmRequest.forNextOccurrence(reminder('a',
            repeat: RepeatType.daily,
            at: DateTime(2026, 3, 13, 23, 0),
            endsAt: DateTime(2026, 3, 30)))!;
        expect(r.repeatType, RepeatType.none,
            reason: 'a bounded repeat is armed one occurrence at a time');
        expect(r.scheduledTime, DateTime(2026, 3, 14, 7));
      });
    });

    test('on: weekdays reminders are armed on the days they now land on', () async {
      await quietOn();
      withClock(Clock.fixed(now), () {
        final r = ReminderArmRequest.forNextOccurrence(
            reminder('a', repeat: RepeatType.weekdays))!;
        expect(r.repeatType, RepeatType.custom);
        expect(r.customDays, [2, 3, 4, 5, 6]);
      });
    });

    test('a paused reminder is still not armed', () async {
      await quietOn();
      withClock(Clock.fixed(now), () {
        final paused = reminder('a').copyWith(isPaused: true);
        expect(ReminderArmRequest.forNextOccurrence(paused), isNull);
      });
    });

    test('the re-arm pass arms them held', () async {
      await quietOn();
      await CleanStorageService.saveReminder(reminder('a'));
      await CleanStorageService.saveReminder(
          reminder('b', escalation: ReminderEscalation.critical));
      final alarm = RecordingReminderAlarm();

      await withClock(
          Clock.fixed(now),
          () => ReminderRescheduleService.rescheduleGenericReminders(alarm: alarm));

      final hours = {for (final r in alarm.armed) r.reminderId: r.scheduledTime.hour};
      expect(hours, {'a': 7, 'b': 23});
    });
  });

  group('withdrawing a held weekday reminder', () {
    late RecordingNotificationScheduler os;

    setUp(() {
      tz.setLocalLocation(tz.UTC);
      os = RecordingNotificationScheduler();
      NotificationService().schedulerForTesting = os;
    });

    test('cancels the day it moved to, not only the days it lists', () async {
      // Armed as Tuesday..Saturday (held past midnight); the reminder itself still
      // says "weekdays", so Saturday is not in its list.
      await NotificationService()
          .cancelGenericReminder(1000, RepeatType.weekdays, null);

      expect(os.cancelled.toSet(), containsAll([1000, 1001, 1002, 1003, 1004, 1005, 1006, 1007]),
          reason: 'a Saturday notification left behind could never be cancelled');
    });

    test('weekends and chosen days cancel every day too', () async {
      await NotificationService()
          .cancelGenericReminder(2000, RepeatType.weekends, null);
      expect(os.cancelled.toSet(), containsAll([2006, 2007, 2001]));

      os.cancelled.clear();
      await NotificationService()
          .cancelGenericReminder(3000, RepeatType.custom, [1]);
      expect(os.cancelled.toSet(), containsAll([3001, 3002, 3007]));
    });

    test('a plain daily reminder still cancels only itself', () async {
      await NotificationService()
          .cancelGenericReminder(4000, RepeatType.daily, null);

      expect(os.cancelled.toSet(), {4000});
    });
  });
}
