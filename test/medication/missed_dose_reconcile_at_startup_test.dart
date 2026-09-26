import 'package:clock/clock.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' show AppDatabase;
import 'package:tablet_remainder/core/services/active_profile_service.dart';
import 'package:tablet_remainder/core/services/reminder_reschedule_service.dart';
import 'package:tablet_remainder/features/medication/models/enhanced_medicine.dart';
import 'package:tablet_remainder/features/medication/models/medicine_enums.dart';
import 'package:tablet_remainder/features/medication/models/medicine_log.dart';
import 'package:tablet_remainder/features/medication/models/medicine_schedule.dart';
import 'package:tablet_remainder/features/medication/services/medicine_storage_service.dart';

/// Adherence read 100% for someone who was missing doses every day.
///
/// `reconcileMissedDoses` writes the `missed` rows that are the DENOMINATOR of
/// every adherence figure — the streak, the dashboard card, the adherence
/// report, the CSV export. Its only caller was the Medication dashboard's load,
/// so a user who takes doses straight from the notification and never opens
/// that tab accumulated no `missed` rows at all: nothing was ever counted
/// against them, and every figure showed a perfect record.
///
/// It now also runs from the "rebuild everything" reminder pass, which happens
/// at every app start and on an exact-alarm grant — the same fix that was
/// applied to `reconcileMissedReminders` on the generic-reminders side.
///
/// TQ-22 — every test here runs inside `withClock`.
///
/// It used to seed off `DateTime.now()` while `reconcileMissedDoses` read the
/// same real clock, and the reconciler ignores any slot newer than a 3-hour
/// grace window. The medicine was scheduled at 08:00, so between 08:00 and
/// 11:00 local today's slot was inside that window and the reconciler never
/// considered it — and the last assertion ("nothing in the future is written
/// off") was trivially true before 08:00, because there was no past slot today
/// at all. Which of those the run exercised was decided by the hour the suite
/// happened to start.
///
/// The fix is not just to pin a convenient hour: [eachHourOfTheDay] replays
/// the whole scenario at all 24 of them, so an hour-shaped hole cannot hide.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    AppDatabase.setInstanceForTesting(db);
    ActiveProfileService().resetForTesting();
    await ActiveProfileService().init();
  });

  tearDown(() async {
    ActiveProfileService().resetForTesting();
    await db.close();
  });

  /// A Thursday well inside a month, at [hour]:17. The odd minute keeps the
  /// pinned instant from coinciding with a slot boundary.
  DateTime dayAt(int hour) => DateTime(2026, 3, 12, hour, 17);

  /// Runs [body] with the wall clock pinned to [at].
  ///
  /// `test(..., () => pinned(at, () async {...}))` rather than a wrapper around
  /// `test` itself: the clock has to be installed around the BODY, because
  /// `withClock` is zone-scoped and a `test` callback runs in its own zone.
  Future<void> pinned(DateTime at, Future<void> Function() body) =>
      withClock(Clock.fixed(at), body);

  /// Replays [body] at every hour of the day, resetting the database between
  /// runs. This is the assertion the wall-clock version could not make: that
  /// the result does not depend on when the suite is started.
  Future<void> eachHourOfTheDay(
      Future<void> Function(DateTime now) body) async {
    for (var hour = 0; hour < 24; hour++) {
      final at = dayAt(hour);
      await db.close();
      db = AppDatabase.forTesting(NativeDatabase.memory());
      AppDatabase.setInstanceForTesting(db);
      ActiveProfileService().resetForTesting();
      await ActiveProfileService().init();
      await withClock(Clock.fixed(at), () => body(at));
    }
  }

  /// A daily tablet whose slot yesterday is long past the 3h grace window and
  /// was never answered.
  Future<void> seedUnansweredDoseYesterday() async {
    final now = clock.now();
    await MedicineCleanStorageService.addMedicine(EnhancedMedicine(
      id: 'm1',
      name: 'Metformin',
      strength: '500mg',
      dosageForm: DosageForm.tablet,
      dosageAmount: 1,
      createdAt: DateTime(now.year, now.month, now.day - 3),
      schedule: MedicineSchedule(
        frequencyType: FrequencyType.onceDaily,
        times: [ScheduledTime(hour: 8, minute: 0)],
      ),
    ));
  }

  Future<List<MedicineLog>> allLogs() =>
      MedicineCleanStorageService.getAllLogs(scopeToActiveProfile: false);

  test('the app-start reminder pass writes the missed rows the dashboard used '
      'to be the only source of', () => pinned(dayAt(14), () async {
    await seedUnansweredDoseYesterday();
    expect(await allLogs(), isEmpty,
        reason: 'nothing has reconciled yet — this is the 100% state');

    // Never opens the Medication tab; the app just starts.
    await ReminderRescheduleService.rescheduleAllReminders();

    final missed = (await allLogs()).where((l) => l.isMissed).toList();
    expect(missed, isNotEmpty,
        reason: 'without a missed row there is no denominator and adherence '
            'reads 100% forever');
    expect(missed.every((l) => l.medicineId == 'm1'), isTrue);
  }));

  test('an answered slot is left alone while an unanswered one IS written off',
      () => pinned(dayAt(14), () async {
    // BOTH directions in ONE run, deliberately.
    //
    // A negative-only version of this test ("no extra row appears for an
    // answered slot") passes just as happily when the reconcile never runs at
    // all — it cannot tell "the guard works" from "nothing happened". Seeding
    // one answered slot AND one unanswered slot means removing the reconcile
    // fails the positive half, while over-firing fails the negative half.
    await seedUnansweredDoseYesterday();
    final now = clock.now();
    // Yesterday: answered. The day before: never answered.
    final answered = DateTime(now.year, now.month, now.day - 1, 8);
    final unanswered = DateTime(now.year, now.month, now.day - 2, 8);
    await MedicineCleanStorageService.addLog(MedicineLog.taken(
      id: MedicineCleanStorageService.doseLogId('m1', answered),
      medicineId: 'm1',
      scheduledTime: answered,
      actionTime: answered,
      dosageTaken: 1,
    ));

    await ReminderRescheduleService.rescheduleAllReminders();

    final logs = await allLogs();

    // Negative: the answered slot keeps its single, taken row.
    final forAnswered =
        logs.where((l) => l.scheduledTime.day == answered.day).toList();
    expect(forAnswered, hasLength(1),
        reason: 'the sweep must not add a second row for an answered slot');
    expect(forAnswered.single.isTaken, isTrue,
        reason: 'over-firing here would report a taken dose as missed');

    // Positive: the unanswered slot IS written off — so this test fails if the
    // reconcile stops running, which is the whole point of the pairing.
    final forUnanswered =
        logs.where((l) => l.scheduledTime.day == unanswered.day).toList();
    expect(forUnanswered, hasLength(1),
        reason: 'the sweep must still reconcile the slot nobody answered');
    expect(forUnanswered.single.isMissed, isTrue);

    // Tomorrow has not happened; marking it missed would be a fabricated
    // failure on the user's record.
    expect(logs.any((l) => l.scheduledTime.isAfter(now)), isFalse);
  }));

  test('the same sweep at every hour of the day writes off yesterday and '
      'never today\'s not-yet-due slot', () async {
    // The hour is what used to decide which half of this file was real.
    // 08:00 is the scheduled slot, so:
    //   before 08:00  -> today has no past slot at all;
    //   08:00-11:00   -> today's slot is past but inside the 3h grace window;
    //   after 11:00   -> today's slot is past AND outside the window.
    // All three must produce the same answer about YESTERDAY, and none of them
    // may write off a slot that has not come round yet.
    await eachHourOfTheDay((now) async {
      await seedUnansweredDoseYesterday();
      await ReminderRescheduleService.rescheduleAllReminders();

      final logs = await allLogs();
      final yesterdaySlot = DateTime(now.year, now.month, now.day - 1, 8);
      expect(
          logs.where((l) =>
              l.isMissed && l.scheduledTime.isAtSameMomentAs(yesterdaySlot)),
          hasLength(1),
          reason: 'yesterday 08:00 was not written off at ${now.hour}:00');

      expect(logs.any((l) => l.scheduledTime.isAfter(now)), isFalse,
          reason: 'a future slot was marked missed at ${now.hour}:00');

      final graceCutoff = now.subtract(const Duration(hours: 3));
      expect(logs.any((l) => l.scheduledTime.isAfter(graceCutoff)), isFalse,
          reason: 'a slot still inside the 3h grace window was written off at '
              '${now.hour}:00');
    });
  });

  test('the sweep behaves the same on the first day of a month', () async {
    // `DateTime(y, m, d - 3)` walks backwards over a month boundary here;
    // seeding off the real clock meant this path was only ever exercised on
    // three days of the month, and never deliberately.
    await withClock(Clock.fixed(DateTime(2026, 3, 1, 14, 17)), () async {
      await seedUnansweredDoseYesterday();
      await ReminderRescheduleService.rescheduleAllReminders();

      final missed = (await allLogs()).where((l) => l.isMissed).toList();
      expect(missed, isNotEmpty);
      expect(missed.map((l) => l.scheduledTime.month).toSet(), contains(2),
          reason: 'February slots before the 1st were never reconciled');
    });
  });
}
