/// Arming an iPhone medicine again, days later, must replace what was armed — not
/// sit beside it.
///
/// A reminder armed for one dose is a notification with an id. The ids are numbered
/// by position in the plan (0, 1, 2 …), and the plan is recomputed from "now" every
/// time, so the same dose can move from id 22 to id 0 between two arms. Writing the
/// new plan over ids 0..n and leaving 23 … n+1 where they were then holds the same
/// dose twice, and the phone rings twice for it.
library;

import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/services/notification_service.dart';
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

  late LivePendingNotificationScheduler os;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    tz.setLocalLocation(tz.UTC);
    os = LivePendingNotificationScheduler();
    NotificationService().schedulerForTesting = os;
  });

  EnhancedMedicine medicine(MedicineSchedule s) => EnhancedMedicine(
        id: 'm1',
        name: 'Methotrexate',
        dosageForm: DosageForm.tablet,
        dosageAmount: 1,
        schedule: s,
      );

  Future<void> armAt(DateTime now, EnhancedMedicine m) => withClock(
      Clock.fixed(now), () => MedicationReminderService().scheduleAllReminders([m]));

  /// What the phone would hold at [now]: each id's last arming, unless it was
  /// withdrawn after that, and not counting what has already come and gone — the
  /// phone drops a one-off once it has been delivered.
  List<DateTime> held(DateTime now) {
    os.asOf = now;
    return [
      for (final r in os.held)
        DateTime(r.when.year, r.when.month, r.when.day, r.when.hour, r.when.minute)
    ]..sort();
  }

  final everyOtherDay = MedicineSchedule(
    frequencyType: FrequencyType.everyXDays,
    times: [ScheduledTime(hour: 8, minute: 0)],
    intervalDays: 2,
    startDate: DateTime(2026, 10, 1),
    endDate: DateTime(2026, 12, 24),
  );

  test('arming it again as the course nears its end holds each dose once', () async {
    final m = medicine(everyOtherDay);
    final first = DateTime(2026, 12, 8, 10);
    await armAt(first, m);
    expect(held(first).length, 8, reason: 'premise: 10, 12, … 24 December');

    // Two days later there is one dose fewer to arm, so the plan is shorter than
    // the one before it.
    final later = DateTime(2026, 12, 10, 10);
    await armAt(later, m);

    final doses = held(later);
    expect(doses.length, 7);
    expect(doses.toSet().length, 7,
        reason: 'the 24th held twice: once from the older, longer plan');
    expect(doses.first, DateTime(2026, 12, 12, 8));
    expect(doses.last, DateTime(2026, 12, 24, 8));
  });

  test('and when the plan is as long as before, it still holds each dose once',
      () async {
    final m = medicine(everyOtherDay);
    await armAt(DateTime(2026, 10, 28, 10), m);
    final later = DateTime(2026, 10, 30, 10);
    await armAt(later, m);

    final doses = held(later);
    expect(doses.length, 24);
    expect(doses.toSet().length, 24, reason: 'no dose twice');
    expect(doses.first, DateTime(2026, 10, 31, 8));
  });

  test('a schedule that changed under it (a restore, say) drops the old doses, all of them',
      () async {
    final first = DateTime(2026, 10, 28, 10);
    await armAt(first, medicine(everyOtherDay));
    expect(held(first).length, 24, reason: 'premise: a full batch, ids 0 to 23');

    // The same medicine, now a short course. Nothing cancelled it first.
    final short = MedicineSchedule(
      frequencyType: FrequencyType.everyXDays,
      times: [ScheduledTime(hour: 8, minute: 0)],
      intervalDays: 2,
      startDate: DateTime(2026, 10, 1),
      endDate: DateTime(2026, 10, 31),
    );
    await armAt(first, medicine(short));

    expect(held(first), [DateTime(2026, 10, 29, 8), DateTime(2026, 10, 31, 8)],
        reason: 'every one of the other twenty-two, including the last id, gone');
  });

  group('a medicine that is no longer to be reminded of has nothing held', () {
    final armedAt = DateTime(2026, 10, 28, 10);

    Future<void> thenChange(EnhancedMedicine Function(EnhancedMedicine) change) async {
      final m = medicine(everyOtherDay);
      await armAt(armedAt, m);
      expect(held(armedAt), isNotEmpty, reason: 'premise');
      await armAt(armedAt, change(m));
    }

    test('its reminders switched off', () async {
      await thenChange((m) => m.copyWith(reminderEnabled: false));
      expect(held(armedAt), isEmpty);
    });

    test('archived', () async {
      await thenChange((m) => m.copyWith(isArchived: true));
      expect(held(armedAt), isEmpty);
    });

    test('made inactive', () async {
      await thenChange((m) => m.copyWith(isActive: false));
      expect(held(armedAt), isEmpty);
    });

    test('left with no times', () async {
      await thenChange((m) => m.copyWith(
          schedule: MedicineSchedule(
              frequencyType: FrequencyType.everyXDays,
              times: const [],
              intervalDays: 2,
              startDate: DateTime(2026, 10, 1))));
      expect(held(armedAt), isEmpty);
    });

    test('changed to as-needed', () async {
      await thenChange((m) => m.copyWith(
          schedule: MedicineSchedule(
              frequencyType: FrequencyType.asNeeded,
              times: const [],
              isPRN: true)));
      expect(held(armedAt), isEmpty);
    });
  });

  test('when the phone cannot say what is pending, arming fails as it always did and changes nothing',
      () async {
    final first = DateTime(2026, 12, 8, 10);
    await armAt(first, medicine(everyOtherDay));
    final armedBefore = held(first).length;

    os.pendingError = StateError('not ready');
    await expectLater(armAt(DateTime(2026, 12, 10, 10), medicine(everyOtherDay)),
        throwsStateError,
        reason: 'a phone that cannot list what is pending is not ready to be armed');
    os.pendingError = null;

    expect(held(first).length, armedBefore,
        reason: 'and nothing that was armed has been touched');
  });

  test('a medicine with its reminders off is left alone when the phone cannot say what is pending',
      () async {
    os.pendingError = StateError('not ready');
    final off = medicine(everyOtherDay).copyWith(reminderEnabled: false);

    await armAt(DateTime(2026, 12, 8, 10), off); // must not throw

    expect(os.scheduled, isEmpty);
  });

  test('withdrawing one medicine\'s old doses leaves another medicine\'s alone', () async {
    final now = DateTime(2026, 12, 8, 10);
    final first = medicine(everyOtherDay); // id m1
    final other = EnhancedMedicine(
      id: 'm2',
      name: 'Folic acid',
      dosageForm: DosageForm.tablet,
      dosageAmount: 1,
      schedule: MedicineSchedule(
          frequencyType: FrequencyType.specificDays,
          times: [ScheduledTime(hour: 9, minute: 0)],
          specificDays: [DateTime.friday]),
    );
    await withClock(Clock.fixed(now),
        () => MedicationReminderService().scheduleAllReminders([other, first]));
    final otherBefore = os.held.where((r) => r.payload?.contains('m2') ?? false).length;
    expect(otherBefore, 1, reason: 'premise: the weekly one is armed');

    // The first medicine is armed AFTER the other, and its plan is shorter two days
    // later, so it withdraws its tail with the other's reminder already in place.
    final later = DateTime(2026, 12, 10, 10);
    await withClock(Clock.fixed(later),
        () => MedicationReminderService().scheduleAllReminders([other, first]));

    expect(os.held.where((r) => r.payload?.contains('m2') ?? false).length, 1,
        reason: 'the other medicine\'s reminder is not in the first one\'s block of ids');
  });

  test('a course that has ended since leaves nothing held', () async {
    final m = medicine(everyOtherDay);
    final first = DateTime(2026, 12, 20, 10);
    await armAt(first, m);
    expect(held(first), isNotEmpty, reason: 'premise');

    final after = DateTime(2026, 12, 26, 10);
    await armAt(after, m);

    expect(held(after), isEmpty);
    expect(held(first), isEmpty,
        reason: 'and not by their dates having passed: they were withdrawn, so '
            'nothing for a course that is over can fire');
  });
}
