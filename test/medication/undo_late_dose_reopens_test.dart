import 'package:clock/clock.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' show AppDatabase;
import 'package:tablet_remainder/core/services/active_profile_service.dart';
import 'package:tablet_remainder/core/theme/app_theme.dart';
import 'package:tablet_remainder/features/medication/models/enhanced_medicine.dart';
import 'package:tablet_remainder/features/medication/models/medicine_enums.dart';
import 'package:tablet_remainder/features/medication/models/medicine_schedule.dart';
import 'package:tablet_remainder/features/medication/screens/nunito_medication_dashboard.dart';
import 'package:tablet_remainder/features/medication/services/medicine_storage_service.dart';

/// QA — Undo must reopen a dose whose slot has already aged past the
/// missed-dose grace window.
///
/// `reconcileMissedDoses` runs on every dashboard load and writes a `missed`
/// log for every past-due slot that carries no terminal outcome — which is
/// exactly the state Undo leaves behind. Once the slot is older than the 3h
/// grace window the row therefore came straight back as "Missed" in the same
/// reload: the Undo read as a no-op, and because missed is terminal the dose
/// could no longer be taken at all.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    AppDatabase.setInstanceForTesting(db);
    ActiveProfileService().resetForTesting();
  });

  tearDown(() async {
    ActiveProfileService().resetForTesting();
    await db.close();
  });

  /// One slot at 09:30 today, with the clock starting at 10:00 — overdue
  /// enough to be actionable, still inside the 3h grace window so the first
  /// load leaves it alone. [now] is advanced by the test to age it out.
  late DateTime now;

  Future<void> seedDueDose() async {
    await MedicineCleanStorageService.addMedicine(EnhancedMedicine(
      id: 'm1',
      name: 'Metformin',
      strength: '500mg',
      dosageForm: DosageForm.tablet,
      dosageAmount: 1,
      createdAt: now.subtract(const Duration(days: 3)),
      schedule: MedicineSchedule(
        frequencyType: FrequencyType.onceDaily,
        times: [ScheduledTime(hour: 9, minute: 30)],
      ),
    ));
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

  testWidgets('Undo reopens a dose whose slot is past the missed-dose grace window',
      (tester) async {
    // Pinned to the real calendar day (the screen reads DateTime.now() for
    // "is this a future day"), with only the time of day under our control.
    final today = DateTime.now();
    now = DateTime(today.year, today.month, today.day, 10, 0);

    await withClock(Clock(() => now), () async {
      await seedDueDose();
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.lightTheme,
        home: const NunitoMedicationDashboard(),
      ));
      await tester.pumpAndSettle(const Duration(seconds: 2));

      expect(find.textContaining('Take now'), findsOneWidget,
          reason: 'the 09:30 dose starts open');

      await skipTheDose(tester);
      expect(find.text('Skipped'), findsOneWidget);

      // The toast carries an action, so it stays up: the user can take it back
      // long after the slot has aged past the 3h grace window.
      now = DateTime(today.year, today.month, today.day, 14, 0);

      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();

      expect(find.text('Missed'), findsNothing,
          reason: 'Undo must not hand the slot straight back to the '
              'missed-dose reconcile');
      expect(find.textContaining('Take now'), findsOneWidget,
          reason: 'a reopened dose has to stay takeable');
    });
  });
}
