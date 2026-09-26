import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' show AppDatabase;
import 'package:tablet_remainder/core/services/active_profile_service.dart';
import 'package:tablet_remainder/core/theme/app_theme.dart';
import 'package:tablet_remainder/core/widgets/app/app_widgets.dart';
import 'package:tablet_remainder/features/medication/models/enhanced_medicine.dart';
import 'package:tablet_remainder/features/medication/models/medicine_enums.dart';
import 'package:tablet_remainder/features/medication/models/medicine_schedule.dart';
import 'package:tablet_remainder/features/medication/screens/nunito_take_medication_sheet.dart';
import 'package:tablet_remainder/features/medication/services/medicine_storage_service.dart';

/// Tier 2: caregiver-imposed PRN limits for dependents. The mechanical
/// enforcement (maxDailyDoses/minHoursBetweenDoses, checked in
/// _confirmPrnLimits) already worked for both self and dependents from a
/// prior round. What's new here is the FRICTION: overriding a caregiver's
/// safety limit on a dependent's medicine must require a deliberate
/// checkbox acknowledgment, not the same one-tap "Log anyway" a self-owned
/// medicine gets. DS-13 moved both branches off `AlertDialog` — the self-owned
/// one onto ConfirmationBottomSheet, the dependent-owned one onto the
/// [AppBottomSheet] it is built on — so the override control these tests probe
/// is an [AppButton] now rather than a `TextButton`.
///
/// NOTE on pumping: _takeMedication sets _isLoading (an indeterminate
/// spinner) BEFORE awaiting the PRN sheet, and that spinner never settles on
/// its own — pumpAndSettle() hangs for as long as it's on screen. Every pump
/// from the first tap until the sheet is actually popped uses a bounded
/// pump() instead; pumpAndSettle() is only safe once the flow has resolved
/// (sheet popped, or the guard reset _isLoading back to false).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    AppDatabase.setInstanceForTesting(db);
    ActiveProfileService().resetForTesting();
  });

  tearDown(() async => db.close());

  Future<EnhancedMedicine> seedPrnMedicine({String? dependentId}) async {
    final med = EnhancedMedicine(
      id: 'prn1',
      name: 'Ibuprofen',
      strength: '200mg',
      dosageForm: DosageForm.tablet,
      dosageAmount: 1,
      dependentId: dependentId,
      createdAt: DateTime.now(),
      schedule: MedicineSchedule.asNeeded(maxDailyDoses: 1),
    );
    await MedicineCleanStorageService.addMedicine(med, stampActiveProfile: false);
    return med;
  }

  Future<void> seedOneTakenDoseToday(String medicineId) async {
    await MedicineCleanStorageService.markMedicineTaken(
      medicineId: medicineId,
      scheduledTime: DateTime.now().subtract(const Duration(hours: 1)),
      dosageTaken: 1,
    );
  }

  Future<int> loggedDoses(String medicineId) async =>
      (await MedicineCleanStorageService.getLogsForMedicine(medicineId)).length;

  /// Opens the sheet the way the real app does — via showModalBottomSheet,
  /// pushing an actual route — so the sheet's own Navigator.pop() has
  /// somewhere valid to pop back to.
  Future<void> openSheet(WidgetTester tester, EnhancedMedicine med) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => showModalBottomSheet<Map<String, dynamic>>(
              context: context,
              isScrollControlled: true,
              builder: (_) => NunitoTakeMedicationSheet(
                  medicine: med, scheduledTime: DateTime.now()),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  Future<void> tapAndPumpBounded(WidgetTester tester, Finder finder,
      {bool warnIfMissed = true}) async {
    await tester.tap(finder, warnIfMissed: warnIfMissed);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets(
      'positive (self-owned): "Log anyway" is immediately tappable, no extra friction',
      (tester) async {
    final med = await seedPrnMedicine();
    await seedOneTakenDoseToday(med.id);
    await openSheet(tester, med);

    await tapAndPumpBounded(tester, find.text('Take medicine'));

    expect(find.text('PRN limit reached'), findsOneWidget);
    expect(find.byType(CheckboxListTile), findsNothing);

    await tapAndPumpBounded(tester, find.widgetWithText(AppButton, 'Log anyway'));
    await tester.pumpAndSettle();
    expect(find.text('PRN limit reached'), findsNothing);
  });

  testWidgets(
      'negative (dependent-owned): "Log anyway" is disabled until the caregiver checkbox is ticked',
      (tester) async {
    final med = await seedPrnMedicine(dependentId: 'dep1');
    await seedOneTakenDoseToday(med.id);
    // The take-sheet's PRN check reads logs scoped to the active profile —
    // it must match the dependent the log was actually stamped with.
    await ActiveProfileService().setActiveDependent('dep1');
    await openSheet(tester, med);

    await tapAndPumpBounded(tester, find.text('Take medicine'));

    expect(find.text('Caregiver safety limit reached'), findsOneWidget);
    final logAnywayFinder = find.widgetWithText(AppButton, 'Log anyway');
    expect(tester.widget<AppButton>(logAnywayFinder).onPressed, isNull,
        reason: 'must be disabled before the checkbox is ticked');

    // Tapping "Log anyway" while disabled must do nothing — the sheet stays up.
    await tapAndPumpBounded(tester, logAnywayFinder, warnIfMissed: false);
    expect(find.text('Caregiver safety limit reached'), findsOneWidget);
  });

  testWidgets('positive (dependent-owned): ticking the checkbox enables the override',
      (tester) async {
    final med = await seedPrnMedicine(dependentId: 'dep1');
    await seedOneTakenDoseToday(med.id);
    await ActiveProfileService().setActiveDependent('dep1');
    await openSheet(tester, med);

    await tapAndPumpBounded(tester, find.text('Take medicine'));
    await tapAndPumpBounded(tester, find.byType(CheckboxListTile));

    final logAnywayFinder = find.widgetWithText(AppButton, 'Log anyway');
    expect(tester.widget<AppButton>(logAnywayFinder).onPressed, isNotNull,
        reason: 'ticking the checkbox must enable the override');

    await tapAndPumpBounded(tester, logAnywayFinder);
    await tester.pumpAndSettle();

    expect(find.text('Caregiver safety limit reached'), findsNothing);
    // The sheet closing is not the outcome — the dose being written is. Without
    // this the whole caregiver branch could collapse to `return false` (confirm
    // becomes a no-op: sheet closes, nothing logged) and every assertion above
    // would still hold.
    expect(await loggedDoses(med.id), 2,
        reason: 'the acknowledged override must log the over-limit dose');
  });

  testWidgets(
      'negative (dependent-owned): dismissing the override sheet logs nothing',
      (tester) async {
    final med = await seedPrnMedicine(dependentId: 'dep1');
    await seedOneTakenDoseToday(med.id);
    await ActiveProfileService().setActiveDependent('dep1');
    await openSheet(tester, med);

    await tapAndPumpBounded(tester, find.text('Take medicine'));
    expect(find.text('Caregiver safety limit reached'), findsOneWidget);

    // Tap the barrier above the sheet — the dismissal that returns null, which
    // is the case `proceed ?? false` exists for. An override nobody
    // acknowledged must not slip through the way an unticked checkbox can't.
    await tester.tapAt(const Offset(400, 20));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    expect(find.text('Caregiver safety limit reached'), findsNothing);
    expect(await loggedDoses(med.id), 1,
        reason: 'a dismissed override must not log the over-limit dose');
    expect(find.text('Take medicine'), findsOneWidget,
        reason: 'the take sheet stays open so the caregiver can decide again');
  });
}
