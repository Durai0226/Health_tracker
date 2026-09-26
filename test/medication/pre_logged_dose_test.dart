import 'package:clock/clock.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' show AppDatabase;
import 'package:tablet_remainder/features/medication/models/enhanced_medicine.dart';
import 'package:tablet_remainder/features/medication/models/medicine_enums.dart';
import 'package:tablet_remainder/features/medication/models/medicine_log.dart';
import 'package:tablet_remainder/features/medication/models/medicine_schedule.dart';
import 'package:tablet_remainder/features/medication/services/medicine_storage_service.dart';
import 'package:tablet_remainder/features/medication/services/today_schedule_service.dart';

/// Tier 2: pre-logged/travel dose status. This is the highest-risk item in
/// the tier — MedicineLogs stores status as independent booleans, not an
/// enum index, and dedupeByDose/reconcileMissedDoses/adherence all had to be
/// updated in lockstep. These tests target exactly the failure modes flagged
/// during design: the reconciler silently overwriting a pre-log, the two
/// duplicated rank() functions disagreeing, and future-day resolution.
///
/// EVERY test here runs inside `withClock(Clock.fixed(_now))`.
///
/// It used to read the real wall clock, and that made two of them mean
/// different things depending on the hour the suite happened to run. The
/// reconciler ignores any slot newer than a 3-hour grace window, and the aged
/// slot was built as `DateTime(now.year, now.month, now.day, 8)` — so between
/// 08:00 and 11:00 local that slot was INSIDE the grace window and the
/// reconciler never considered it at all. The test still passed, because a
/// pre-log the reconciler never looks at is trivially "not clobbered". It was
/// green for the wrong reason for three hours a day.
///
/// Pinning the clock also costs nothing in realism: the production reads are
/// `clock.now()`, which IS `DateTime.now()` outside a `withClock` zone.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;

  // 14:30 on a Thursday. Chosen so 08:00 the same day is 6h30m old — safely
  // past the reconciler's 3h grace window — and so "tomorrow" and "+2 days"
  // are unambiguous. Nothing here depends on the date being near today.
  final now = DateTime(2026, 3, 12, 14, 30);

  /// Runs [body] with the wall clock pinned to [now].
  ///
  /// `test(..., () => pinned(() async {...}))` rather than a wrapper around
  /// `test` itself: the clock has to be installed around the BODY, because
  /// `withClock` is zone-scoped and a `test` callback runs in its own zone.
  Future<void> pinned(Future<void> Function() body) =>
      withClock(Clock.fixed(now), body);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    AppDatabase.setInstanceForTesting(db);
  });

  tearDown(() async => db.close());

  /// A once-daily medicine at 08:00, created well before the pinned `now` so
  /// both past and future slots relative to it are reachable.
  ///
  /// `startDate` is explicit: `addMedicine` defaults it to the current time,
  /// and a medicine whose schedule starts after the slot under test is not
  /// active on that day — which would quietly empty every assertion below.
  Future<EnhancedMedicine> seedDailyMedicine({String id = 'm1'}) async {
    final med = EnhancedMedicine(
      id: id,
      name: 'Levothyroxine',
      strength: '50mcg',
      dosageForm: DosageForm.tablet,
      dosageAmount: 1,
      createdAt: now.subtract(const Duration(days: 30)),
      schedule: MedicineSchedule(
        frequencyType: FrequencyType.onceDaily,
        times: [ScheduledTime(hour: 8, minute: 0)],
        startDate: now.subtract(const Duration(days: 30)),
      ),
    );
    await MedicineCleanStorageService.addMedicine(med, stampActiveProfile: false);
    return med;
  }

  group('markMedicinePreLogged', () {
    test('positive: persists and reads back as MedicineStatus.preLogged',
        () => pinned(() async {
              await seedDailyMedicine();
              final tomorrow8am = DateTime(now.year, now.month, now.day + 1, 8);

              final log =
                  await MedicineCleanStorageService.markMedicinePreLogged(
                medicineId: 'm1',
                scheduledTime: tomorrow8am,
                dosageTaken: 1,
              );
              expect(log.status, MedicineStatus.preLogged);
              expect(log.isPreLogged, isTrue);
              expect(log.countsAsTaken, isTrue);

              final fetched =
                  await MedicineCleanStorageService.getLog(log.id);
              expect(fetched?.status, MedicineStatus.preLogged);
            }));

    test('positive: decrements stock immediately, matching markMedicineTaken',
        () => pinned(() async {
              final med = EnhancedMedicine(
                id: 'm2',
                name: 'Med with stock',
                strength: '1',
                dosageForm: DosageForm.tablet,
                dosageAmount: 1,
                currentStock: 10,
                refillReminderEnabled: true,
                createdAt: now.subtract(const Duration(days: 5)),
                schedule: MedicineSchedule(
                  frequencyType: FrequencyType.onceDaily,
                  times: [ScheduledTime(hour: 8, minute: 0)],
                  startDate: now.subtract(const Duration(days: 5)),
                ),
              );
              await MedicineCleanStorageService.addMedicine(med,
                  stampActiveProfile: false);

              await MedicineCleanStorageService.markMedicinePreLogged(
                medicineId: 'm2',
                scheduledTime: DateTime(now.year, now.month, now.day + 1, 8),
                dosageTaken: 1,
              );
              final updated =
                  await MedicineCleanStorageService.getMedicine('m2');
              expect(updated?.currentStock, 9);
            }));
  });

  group('dedupeByDose rank ordering', () {
    test('positive: taken beats preLogged beats skipped beats missed', () {
      final scheduled = DateTime(2026, 1, 1, 8);
      final id = MedicineCleanStorageService.doseLogId('m1', scheduled);
      final preLogged = MedicineLog.preLogged(
          id: id, medicineId: 'm1', scheduledTime: scheduled);
      final missed = MedicineLog.missed(
          id: id, medicineId: 'm1', scheduledTime: scheduled);

      final result =
          MedicineCleanStorageService.dedupeByDose([missed, preLogged]);
      expect(result.single.status, MedicineStatus.preLogged);
    });
  });

  group('TodayScheduleService with a pre-logged future dose', () {
    test(
        "positive: getTodaysDoses(futureDate) shows the pre-log as resolved immediately",
        () => pinned(() async {
              await seedDailyMedicine();
              final future = DateTime(now.year, now.month, now.day + 2, 8);

              await MedicineCleanStorageService.markMedicinePreLogged(
                medicineId: 'm1',
                scheduledTime: future,
              );

              final futureDoses =
                  await TodayScheduleService.getTodaysDoses(future);
              expect(futureDoses.single.isPreLogged, isTrue);
              // Never offered as "up next" — it's already resolved.
              expect(TodayScheduleService.nextDose(futureDoses, future), isNull);
            }));

    test("negative: a future pre-log does not affect today's doses or nextDose",
        () => pinned(() async {
              await seedDailyMedicine();
              final future = DateTime(now.year, now.month, now.day + 2, 8);
              await MedicineCleanStorageService.markMedicinePreLogged(
                medicineId: 'm1',
                scheduledTime: future,
              );

              final todaysDoses =
                  await TodayScheduleService.getTodaysDoses(now);
              expect(todaysDoses, isNotEmpty);
              expect(todaysDoses.every((d) => !d.isPreLogged), isTrue);
            }));
  });

  group('reconcileMissedDoses regression: must not clobber a pre-log', () {
    test(
        'a pre-logged slot that ages past the grace window is NOT overwritten with a missed row',
        () => pinned(() async {
              // Two identical medicines at 08:00 today — 6h30m before the
              // pinned now, so both slots are well past the 3h grace window.
              await seedDailyMedicine(id: 'm1');
              await seedDailyMedicine(id: 'control');
              final agedSlot = DateTime(now.year, now.month, now.day, 8);

              await MedicineCleanStorageService.markMedicinePreLogged(
                medicineId: 'm1',
                scheduledTime: agedSlot,
              );

              await MedicineCleanStorageService.reconcileMissedDoses(
                  lookbackDays: 3);

              bool sameSlot(MedicineLog l) =>
                  l.scheduledTime.year == agedSlot.year &&
                  l.scheduledTime.month == agedSlot.month &&
                  l.scheduledTime.day == agedSlot.day &&
                  l.scheduledTime.hour == agedSlot.hour &&
                  l.scheduledTime.minute == agedSlot.minute;

              // The control proves the reconciler actually SWEPT this slot.
              // Without it the test passes for free whenever the reconciler
              // looked at a different window than the one being seeded — which
              // is exactly what happens if a production read goes back to
              // `DateTime.now()` while the test pins `clock.now()`.
              final controlLogs = await MedicineCleanStorageService
                  .getLogsForMedicine('control');
              final controlMatching = controlLogs.where(sameSlot);
              expect(controlMatching, hasLength(1),
                  reason: 'the reconciler did not run over the seeded window, '
                      'so this test proves nothing about the pre-log');
              expect(controlMatching.single.status, MedicineStatus.missed);

              final logs =
                  await MedicineCleanStorageService.getLogsForMedicine('m1');
              final matching = logs.where(sameSlot);
              expect(matching, hasLength(1),
                  reason: 'the reconciler must not have inserted a second row');
              expect(matching.single.status, MedicineStatus.preLogged,
                  reason:
                      'the pre-log must survive, not be overwritten as missed');
            }));

    test('a slot still inside the 3h grace window is left alone entirely',
        () => pinned(() async {
              // 13:00 today is 1h30m before the pinned now. The reconciler must
              // not touch it — the dose is not late yet.
              final med = EnhancedMedicine(
                id: 'grace',
                name: 'Recent',
                strength: '1',
                dosageForm: DosageForm.tablet,
                dosageAmount: 1,
                createdAt: now.subtract(const Duration(days: 5)),
                schedule: MedicineSchedule(
                  frequencyType: FrequencyType.onceDaily,
                  times: [ScheduledTime(hour: 13, minute: 0)],
                  startDate: now.subtract(const Duration(days: 5)),
                ),
              );
              await MedicineCleanStorageService.addMedicine(med,
                  stampActiveProfile: false);

              await MedicineCleanStorageService.reconcileMissedDoses(
                  lookbackDays: 1);

              final logs = await MedicineCleanStorageService
                  .getLogsForMedicine('grace');
              final today = logs.where((l) =>
                  l.scheduledTime.day == now.day &&
                  l.scheduledTime.hour == 13);
              expect(today, isEmpty,
                  reason: "a dose 90 minutes late is not a missed dose");
            }));
  });
}
