import 'package:clock/clock.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' show AppDatabase;
import 'package:tablet_remainder/core/services/active_profile_service.dart';
import 'package:tablet_remainder/core/services/clean_storage_service.dart';
import 'package:tablet_remainder/core/services/reminder_reschedule_service.dart';
import 'package:tablet_remainder/core/services/vacation_mode.dart';
import 'package:tablet_remainder/features/reminders/models/reminder_model.dart';
import 'package:tablet_remainder/features/reminders/services/reminder_alarm.dart';

/// Vacation mode and the Reminders feature: nothing fires, nothing is counted
/// as missed — and it all comes back when the vacation is over.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  // Friday 13 March 2026, noon.
  final now = DateTime(2026, 3, 13, 12);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    AppDatabase.setInstanceForTesting(db);
    ActiveProfileService().resetForTesting();
    CleanStorageService.resetForTesting();
    await CleanStorageService.init();
  });

  tearDown(() async => db.close());

  Reminder daily(String id) => Reminder(
        id: id,
        title: 'Water the plants',
        body: '',
        scheduledTime: DateTime(2026, 3, 1, 9),
        repeatType: RepeatType.daily,
      );

  group('arming', () {
    test('a reminder arms normally with no vacation', () {
      withClock(Clock.fixed(now), () {
        expect(ReminderArmRequest.forNextOccurrence(daily('a')), isNotNull);
      });
    });

    test('on vacation there is nothing to arm', () async {
      await withClock(Clock.fixed(now), () async {
        await VacationMode.start(until: DateTime(2026, 3, 20));
        expect(ReminderArmRequest.forNextOccurrence(daily('a')), isNull);
      });
    });

    test('the day after the vacation ends it arms again', () async {
      await VacationMode.start(until: DateTime(2026, 3, 20), now: now);
      withClock(Clock.fixed(DateTime(2026, 3, 21, 8)), () {
        expect(ReminderArmRequest.forNextOccurrence(daily('a')), isNotNull);
      });
    });
  });

  group('the re-arm pass', () {
    test('disarms generic reminders on vacation and arms none', () async {
      await withClock(Clock.fixed(now), () async {
        await CleanStorageService.saveReminder(daily('a'));
        await CleanStorageService.saveReminder(daily('b'));
        await VacationMode.start(until: DateTime(2026, 3, 20));
        final alarm = RecordingReminderAlarm();

        final armed =
            await ReminderRescheduleService.rescheduleGenericReminders(alarm: alarm);

        expect(armed, 0);
        expect(alarm.armed, isEmpty);
        expect(alarm.disarmed, hasLength(2),
            reason: 'both are taken off the OS so nothing fires while away');
      });
    });

    test('after the vacation the same pass arms them again', () async {
      await CleanStorageService.saveReminder(daily('a'));
      await VacationMode.start(until: DateTime(2026, 3, 20), now: now);
      final alarm = RecordingReminderAlarm();

      final armed = await withClock(
          Clock.fixed(DateTime(2026, 3, 21, 8)),
          () => ReminderRescheduleService.rescheduleGenericReminders(alarm: alarm));

      expect(armed, 1);
      expect(alarm.armed, hasLength(1));
    });

    test('ending the vacation early re-arms on the next pass', () async {
      await withClock(Clock.fixed(now), () async {
        await CleanStorageService.saveReminder(daily('a'));
        await VacationMode.start(until: DateTime(2026, 3, 20));
        await VacationMode.endNow();
        final alarm = RecordingReminderAlarm();
        final armed = await ReminderRescheduleService.rescheduleGenericReminders(
            alarm: alarm);
        expect(armed, 1);
      });
    });
  });

  group('the occurrence log', () {
    test('vacation days are not recorded as due, so nothing can be "missed"',
        () async {
      await withClock(Clock.fixed(now), () async {
        await CleanStorageService.saveReminder(daily('a'));
        // Away Mon 9 – Wed 11 March, now back on Friday the 13th.
        await VacationMode.start(
            until: DateTime(2026, 3, 11), now: DateTime(2026, 3, 9));

        await CleanStorageService.recordDueReminderOccurrences();
        final rows = await CleanStorageService.getReminderOccurrences('a');
        final days = rows.map((o) => o.scheduledFor.day).toSet();

        expect(days.containsAll([9, 10, 11]), isFalse,
            reason: 'nothing was due on the days spent away: $days');
        expect(days.contains(12), isTrue, reason: 'the day after is ordinary');
        expect(days.contains(8), isTrue, reason: 'and so is the day before');
      });
    });

    test('without a vacation every day is recorded, as before', () async {
      await withClock(Clock.fixed(now), () async {
        await CleanStorageService.saveReminder(daily('a'));
        await CleanStorageService.recordDueReminderOccurrences();
        final days = (await CleanStorageService.getReminderOccurrences('a'))
            .map((o) => o.scheduledFor.day)
            .toSet();
        expect(days.containsAll([9, 10, 11, 12]), isTrue);
      });
    });
  });
}
