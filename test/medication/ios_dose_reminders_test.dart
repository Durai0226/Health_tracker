/// What an iPhone is actually given for a medicine that is not "every day".
///
/// The host these tests run on is not Android, so the service takes the same
/// branch an iPhone does, and the OS is a recording double.
///
/// Every medicine used to be armed as "this time, every day". A once-a-week tablet
/// reminded the user on the six days it must not be taken.
library;

import 'package:clock/clock.dart';
import 'package:drift/native.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' as db;
import 'package:tablet_remainder/core/services/clean_storage_service.dart';
import 'package:tablet_remainder/core/services/notification_service.dart';
import 'package:tablet_remainder/core/services/reminder_budget.dart';
import 'package:tablet_remainder/features/medication/models/enhanced_medicine.dart';
import 'package:tablet_remainder/features/medication/models/medicine_enums.dart';
import 'package:tablet_remainder/features/medication/models/medicine_schedule.dart';
import 'package:tablet_remainder/features/medication/services/medication_reminder_service.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../support/recording_notification_scheduler.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tz_data.initializeTimeZones();

  // Wednesday 28 October 2026, ten in the morning.
  final now = DateTime(2026, 10, 28, 10, 0);

  late RecordingNotificationScheduler os;
  late db.AppDatabase database;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    tz.setLocalLocation(tz.UTC);
    database = db.AppDatabase.forTesting(NativeDatabase.memory());
    db.AppDatabase.setInstanceForTesting(database);
    CleanStorageService.resetForTesting();
    await CleanStorageService.init();
    os = RecordingNotificationScheduler();
    NotificationService().schedulerForTesting = os;
  });

  tearDown(() async => database.close());

  EnhancedMedicine medicine(MedicineSchedule s, {String id = 'm1'}) =>
      EnhancedMedicine(
        id: id,
        name: 'Methotrexate',
        dosageForm: DosageForm.tablet,
        dosageAmount: 1,
        schedule: s,
      );

  ScheduledTime at(int h, [int m = 0]) => ScheduledTime(hour: h, minute: m);

  Future<List<int>> arm(EnhancedMedicine m) => withClock(
      Clock.fixed(now), () => MedicationReminderService().scheduleReminders(m));

  String when(RecordedSchedule r) =>
      '${r.when.year}-${r.when.month.toString().padLeft(2, '0')}-'
      '${r.when.day.toString().padLeft(2, '0')} '
      '${r.when.hour.toString().padLeft(2, '0')}:${r.when.minute.toString().padLeft(2, '0')}';

  test('a once-a-week medicine is armed weekly, on its day, and only that', () async {
    final ids = await arm(medicine(MedicineSchedule(
        frequencyType: FrequencyType.specificDays,
        times: [at(8)],
        specificDays: [DateTime.thursday])));

    expect(ids.length, 1, reason: 'one reminder, not seven');
    final r = os.scheduled.single;
    expect(r.matchDateTimeComponents, DateTimeComponents.dayOfWeekAndTime,
        reason: 'repeats on that weekday, not every day');
    expect(when(r), '2026-10-29 08:00');
    expect(r.when.weekday, DateTime.thursday);
  });

  test('two days a week at two times is four reminders, each on its own day', () async {
    await arm(medicine(MedicineSchedule(
        frequencyType: FrequencyType.specificDays,
        times: [at(8), at(20)],
        specificDays: [DateTime.monday, DateTime.friday])));

    expect(os.scheduled.length, 4);
    expect({for (final r in os.scheduled) (r.when.weekday, r.when.hour)}, {
      (DateTime.monday, 8),
      (DateTime.monday, 20),
      (DateTime.friday, 8),
      (DateTime.friday, 20),
    });
    expect(
        os.scheduled.every(
            (r) => r.matchDateTimeComponents == DateTimeComponents.dayOfWeekAndTime),
        isTrue);
    expect(os.armedIds.toSet().length, 4, reason: 'each its own id');
  });

  test('a plain daily medicine is still one repeating daily reminder', () async {
    final ids = await arm(medicine(MedicineSchedule(
        frequencyType: FrequencyType.onceDaily, times: [at(21)])));

    expect(ids.length, 1);
    final r = os.scheduled.single;
    expect(r.matchDateTimeComponents, DateTimeComponents.time);
    expect(when(r), '2026-10-28 21:00');
  });

  test('every three days is one reminder for each dose due, none for the days between',
      () async {
    await arm(medicine(MedicineSchedule(
        frequencyType: FrequencyType.everyXDays,
        times: [at(8)],
        intervalDays: 3,
        startDate: DateTime(2026, 10, 25))));

    final days = [for (final r in os.scheduled) when(r)];
    expect(days.take(4), [
      '2026-10-31 08:00',
      '2026-11-03 08:00',
      '2026-11-06 08:00',
      '2026-11-09 08:00',
    ], reason: 'the 29th and 30th, which it used to remind on, are not here');
    expect(os.scheduled.every((r) => r.matchDateTimeComponents == null), isTrue,
        reason: 'each is one-off: it does not come round tomorrow');
    expect(os.scheduled.length, 24, reason: 'as many as fit for one medicine');
    expect(os.armedIds.toSet().length, 24);
  });

  test('a course that is over has nothing armed', () async {
    final ids = await arm(medicine(MedicineSchedule(
        frequencyType: FrequencyType.onceDaily,
        times: [at(8)],
        endDate: DateTime(2026, 10, 27))));

    expect(ids, isEmpty);
    expect(os.scheduled, isEmpty,
        reason: 'it used to keep reminding every day after the last dose');
  });

  test('a course with an end date stops on it', () async {
    await arm(medicine(MedicineSchedule(
        frequencyType: FrequencyType.onceDaily,
        times: [at(8)],
        endDate: DateTime(2026, 10, 30))));

    expect([for (final r in os.scheduled) when(r)],
        ['2026-10-29 08:00', '2026-10-30 08:00']);
  });

  test('the notification names the medicine and carries its id and time', () async {
    await arm(medicine(MedicineSchedule(
        frequencyType: FrequencyType.specificDays,
        times: [at(8, 30)],
        specificDays: [DateTime.thursday])));

    final r = os.scheduled.single;
    expect(r.body, contains('Methotrexate'));
    expect(r.payload, contains('m1'), reason: 'the dose can be taken from it');
    expect(r.payload, contains('"hour":8'));
    expect(r.payload, contains('"minute":30'));
  });

  group('when the phone is nearly full of reminders', () {
    final room = ReminderBudget.usable(ReminderBudget.ceilingFor());

    void alreadyPending(int n) => os.pending = [
          for (var i = 0; i < n; i++) PendingNotificationRequest(i, null, null, null)
        ];

    final everyThree = MedicineSchedule(
        frequencyType: FrequencyType.everyXDays,
        times: [at(8)],
        intervalDays: 3,
        startDate: DateTime(2026, 10, 25));

    test('only what fits is armed, and it is the doses that come first', () async {
      alreadyPending(room - 2);

      final ids = await arm(medicine(everyThree));

      expect(ids.length, 2);
      expect([for (final r in os.scheduled) when(r)],
          ['2026-10-31 08:00', '2026-11-03 08:00']);
    });

    test('nothing is armed when there is no room, and it does not throw', () async {
      alreadyPending(room + 10);
      expect(await arm(medicine(everyThree)), isEmpty);
      expect(os.scheduled, isEmpty);
    });
  });

  group('what is already on the phone counts for the others, not for this medicine', () {
    final room = ReminderBudget.usable(ReminderBudget.ceilingFor());
    // The first medicine to be armed has the first block of ids.
    final own = [for (var i = 0; i < 24; i++) 100000 + i];

    void pending(List<int> ids) => os.pending = [
          for (final id in ids) PendingNotificationRequest(id, null, null, null)
        ];

    final everyThree = MedicineSchedule(
        frequencyType: FrequencyType.everyXDays,
        times: [at(8)],
        intervalDays: 3,
        startDate: DateTime(2026, 10, 25));

    test('arming a medicine again is not refused room by the doses it is replacing',
        () async {
      // The phone is full: 24 of its own reminders from the last time, and others
      // up to within twelve of the limit. Counting its own, there is no room for
      // any; they are about to be replaced.
      pending([...own, for (var i = 0; i < room - 12; i++) 500000 + i]);

      final ids = await arm(medicine(everyThree));

      expect(ids.length, 12, reason: 'the twelve that fit, soonest first');
      expect(when(os.scheduled.first), '2026-10-31 08:00');
      expect(os.cancelled.toSet().containsAll(own.skip(12)), isTrue,
          reason: 'and the rest of its old ones are withdrawn, not left holding doses '
              'the new arming has dropped');
    });

    test('with room to spare it re-arms every dose and withdraws none that are wanted',
        () async {
      pending(own);
      final ids = await arm(medicine(everyThree));
      expect(ids.length, 24);
      expect(os.cancelled.toSet().intersection(own.toSet()), isEmpty,
          reason: 'all twenty-four are in the plan, replaced in place');
    });
  });

  group('snoozing from the dose sheet', () {
    test('does not withdraw any reminder: the ids a plan arms are not the dose\'s slot',
        () async {
      // Due Monday and Thursday: the plan holds Thursday (tomorrow) at id 0 and
      // next Monday at id 1. A snooze that looked up "this dose's slot" and cancelled
      // it would take one of those down.
      final m = medicine(MedicineSchedule(
          frequencyType: FrequencyType.specificDays,
          times: [at(8)],
          specificDays: [DateTime.monday, DateTime.thursday]));
      final armed = await arm(m);
      expect(armed.length, 2, reason: 'premise');
      os.cancelled.clear();

      final ok = await withClock(
          Clock.fixed(now),
          () => MedicationReminderService().snoozeReminderForDose(
              m, DateTime(2026, 10, 29, 8), 10));

      expect(ok, isTrue);
      expect(os.cancelled.toSet().intersection(armed.toSet()), isEmpty,
          reason: 'Monday\'s repeating reminder is not Thursday\'s to cancel');
      final snooze = os.scheduled.last;
      expect(snooze.title, contains('Snoozed'));
      expect(snooze.payload, contains('m1'), reason: 'and it still names the dose');
    });
  });

  test('cancelling a medicine withdraws every one of them', () async {
    final m = medicine(MedicineSchedule(
        frequencyType: FrequencyType.everyXDays,
        times: [at(8)],
        intervalDays: 2,
        startDate: DateTime(2026, 10, 26)));
    final ids = await arm(m);
    expect(ids.length, greaterThan(1), reason: 'premise');

    await MedicationReminderService().cancelReminders(m);

    expect(os.cancelled.toSet().containsAll(ids), isTrue,
        reason: 'one left behind would keep ringing for a dose that is not due');
  });

  test('arming it again after a change replaces, not adds', () async {
    final weekly = medicine(MedicineSchedule(
        frequencyType: FrequencyType.specificDays,
        times: [at(8)],
        specificDays: [DateTime.thursday]));
    final first = await arm(weekly);
    final again = await arm(weekly);

    expect(again, first, reason: 'the same ids, so the second call replaces the first');
  });
}
