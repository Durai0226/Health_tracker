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
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    AppDatabase.setInstanceForTesting(db);
  });

  tearDown(() async => db.close());

  /// A medicine with one slot 30 minutes ago: overdue enough to be actionable,
  /// inside the 3h grace window so missed-reconciliation leaves it alone.
  Future<EnhancedMedicine> seedDueDose() async {
    final now = DateTime.now();
    final slot = now.subtract(const Duration(minutes: 30));
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
    await tester.tap(find.textContaining('Take Now').first);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(InkWell, 'Skip').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text(SkipReason.values.first.displayName).first);
    await tester.pumpAndSettle();
  }

  testWidgets('skipping a dose flips the row to Skipped with no manual refresh',
      (tester) async {
    await seedDueDose();
    await pumpDashboard(tester);

    expect(find.text('Metformin'), findsWidgets);
    expect(find.textContaining('Take Now'), findsOneWidget);

    await skipTheDose(tester);

    expect(find.text('Skipped'), findsOneWidget,
        reason: 'the timeline must show the outcome immediately');
    expect(find.textContaining('Take Now'), findsNothing,
        reason: 'a skipped dose is terminal — it must not stay takeable');
  });

  testWidgets('a skip is confirmed with an Undo that restores the open dose',
      (tester) async {
    await seedDueDose();
    await pumpDashboard(tester);
    await skipTheDose(tester);

    expect(find.text('Metformin skipped'), findsOneWidget,
        reason: 'a silent skip gives the user nothing to act on');

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();

    expect(find.text('Skipped'), findsNothing);
    expect(find.textContaining('Take Now'), findsOneWidget,
        reason: 'Undo must reopen the dose, not just hide the badge');
  });

  test('a skipped dose is visible to the schedule service straight away',
      () async {
    final now = DateTime.now();
    final slot = now.subtract(const Duration(minutes: 30));
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

    var doses = await TodayScheduleService.getTodaysDoses(now);
    expect(doses.single.log, isNull);

    await MedicineCleanStorageService.markMedicineSkipped(
      medicineId: med.id,
      scheduledTime: doses.single.scheduledTime,
      reason: SkipReason.values.first,
    );

    doses = await TodayScheduleService.getTodaysDoses(now);
    expect(doses.single.isSkipped, isTrue);
    // Resolved, so it must not resurface as "up next".
    expect(TodayScheduleService.nextDose(doses, now), isNull);
  });
}
