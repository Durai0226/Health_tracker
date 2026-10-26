import 'package:clock/clock.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' show AppDatabase;
import 'package:tablet_remainder/core/theme/app_theme.dart';
import 'package:tablet_remainder/features/medication/models/enhanced_medicine.dart';
import 'package:tablet_remainder/features/medication/models/medicine_enums.dart';
import 'package:tablet_remainder/features/medication/models/medicine_schedule.dart';
import 'package:tablet_remainder/features/medication/screens/nunito_medication_dashboard.dart';
import 'package:tablet_remainder/features/medication/services/medicine_storage_service.dart';
import 'package:tablet_remainder/features/medication/services/today_schedule_service.dart';

/// QA — a Take/Skip must land on the timeline on the SAME pass, with no manual
/// refresh, and must be undoable. Regression cover for the dose-action flow:
/// the sheet writes the log, the dashboard reflects it optimistically, then
/// reloads the derived stats quietly (no full-screen loader).
///
/// TQ-22 — the clock is pinned here, and the seed no longer straddles midnight.
///
/// `seedDueDose` builds its slot as `DateTime.now() - 30 minutes` and then
/// keeps only the HOUR and MINUTE, so the medicine is scheduled at that time
/// every day. Run the suite between 00:00 and 00:29 and that subtraction lands
/// on YESTERDAY: the slot the test believes is "30 minutes overdue" is today's
/// 23:xx, roughly 23 hours in the FUTURE. The dose-action assertions then meant
/// something entirely different from what the comment beside them claimed, for
/// 30 minutes out of every day.
///
/// Pinning removes that, and `seedDueDose` now ASSERTS the claim its own
/// comment makes rather than assuming it. The service-level test then replays
/// the whole scenario at all 24 hours, which is the assertion a wall-clock test
/// could never make: the outcome does not depend on when the suite is started.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    AppDatabase.setInstanceForTesting(db);
  });

  tearDown(() async => db.close());

  /// A Thursday well inside a month, at [hour]:30 — the half hour matters:
  /// it is what keeps `now - 30 minutes` on the same calendar day at hour 0.
  DateTime dayAt(int hour) => DateTime(2026, 3, 12, hour, 30);

  /// Runs [body] with the wall clock pinned to [at]. The clock is installed
  /// around the BODY, not around `test` — `withClock` is zone-scoped and a
  /// `test` callback runs in its own zone.
  Future<void> pinned(DateTime at, Future<void> Function() body) =>
      withClock(Clock.fixed(at), body);

  /// A medicine with one slot 30 minutes ago: overdue enough to be actionable,
  /// inside the 3h grace window so missed-reconciliation leaves it alone.
  Future<EnhancedMedicine> seedDueDose() async {
    final now = clock.now();
    final slot = now.subtract(const Duration(minutes: 30));
    // The claim the comment above makes, asserted rather than assumed: this
    // is the line that was false between 00:00 and 00:29 on the real clock.
    expect(slot.day, now.day,
        reason: 'the slot fell onto the previous day, so it is not overdue at '
            'all — it is ~23 hours in the future');
    final med = EnhancedMedicine(
      id: 'm1',
      name: 'Metformin',
      strength: '500mg',
      dosageForm: DosageForm.tablet,
      dosageAmount: 1,
      createdAt: now.subtract(const Duration(days: 3)),
      schedule: MedicineSchedule(
        frequencyType: FrequencyType.onceDaily,
        times: [ScheduledTime(hour: slot.hour, minute: slot.minute)],
      ),
    );
    await MedicineCleanStorageService.addMedicine(med);
    return med;
  }

  Future<void> pumpDashboard(WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      home: const NunitoMedicationDashboard(),
    ));
    await tester.pumpAndSettle(const Duration(seconds: 2));
  }

  Future<void> skipTheDose(WidgetTester tester) async {
    // The yesterday banner (a dose from before today went unlogged in this
    // fixture) pushes the schedule down, so scroll the target into view first.
    await tester.ensureVisible(find.textContaining('Take now').first);
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Take now').first);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(InkWell, 'Skip').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text(SkipReason.values.first.displayName).first);
    await tester.pumpAndSettle();
  }

  testWidgets('skipping a dose flips the row to Skipped with no manual refresh',
      (tester) => pinned(dayAt(14), () async {
    await seedDueDose();
    await pumpDashboard(tester);

    expect(find.text('Metformin'), findsWidgets);
    expect(find.textContaining('Take now'), findsOneWidget);

    await skipTheDose(tester);

    expect(find.text('Skipped'), findsOneWidget,
        reason: 'the timeline must show the outcome immediately');
    expect(find.textContaining('Take now'), findsNothing,
        reason: 'a skipped dose is terminal — it must not stay takeable');
  }));

  testWidgets('a skip is confirmed with an Undo that restores the open dose',
      (tester) => pinned(dayAt(14), () async {
    await seedDueDose();
    await pumpDashboard(tester);
    await skipTheDose(tester);

    expect(find.text('Metformin skipped'), findsOneWidget,
        reason: 'a silent skip gives the user nothing to act on');

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();

    expect(find.text('Skipped'), findsNothing);
    expect(find.textContaining('Take now'), findsOneWidget,
        reason: 'Undo must reopen the dose, not just hide the badge');
  }));

  test('a skipped dose is visible to the schedule service straight away, at '
      'every hour of the day', () async {
    // Replayed at all 24 hours, because "skip resolves the dose" must not be
    // a fact about the hour the suite happened to start.
    for (var hour = 0; hour < 24; hour++) {
      final at = dayAt(hour);
      await db.close();
      db = AppDatabase.forTesting(NativeDatabase.memory());
      AppDatabase.setInstanceForTesting(db);

      await pinned(at, () async {
        final med = await seedDueDose();
        final now = clock.now();

        var doses = await TodayScheduleService.getTodaysDoses(now);
        expect(doses.single.log, isNull, reason: 'at ${at.hour}:30');
        expect(doses.single.scheduledTime.isBefore(now), isTrue,
            reason: 'the seeded dose is not actually overdue at ${at.hour}:30');

        await MedicineCleanStorageService.markMedicineSkipped(
          medicineId: med.id,
          scheduledTime: doses.single.scheduledTime,
          reason: SkipReason.values.first,
        );

        doses = await TodayScheduleService.getTodaysDoses(now);
        expect(doses.single.isSkipped, isTrue, reason: 'at ${at.hour}:30');
        // Resolved, so it must not resurface as "up next".
        expect(TodayScheduleService.nextDose(doses, now), isNull,
            reason: 'a skipped dose came back as "up next" at ${at.hour}:30');
      });
    }
  });
}
