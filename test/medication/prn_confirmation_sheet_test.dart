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

/// DS-13: the PRN limit warning moved off `AlertDialog` onto
/// [ConfirmationBottomSheet]. The grammar changed; the CONTRACT must not.
/// `_confirmPrnLimits` branches on a nullable bool, so the two outcomes that
/// matter are the two this file pins: a dismissed sheet (null) must log
/// nothing, and a confirmed one must log the dose past the limit.
///
/// The sibling file prn_caregiver_friction_test.dart covers the dependent-owned
/// branch, which keeps its checkbox gate.
///
/// NOTE on pumping (same trap as that file): _takeMedication sets _isLoading —
/// an indeterminate spinner — BEFORE awaiting the confirmation, and that
/// spinner never settles on its own. pumpAndSettle() is only safe once the
/// flow has resolved.
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

  /// A self-owned PRN medicine capped at one dose a day, with that one dose
  /// already logged — so the next Take is over the limit.
  Future<EnhancedMedicine> seedAtLimit() async {
    final med = EnhancedMedicine(
      id: 'prn1',
      name: 'Ibuprofen',
      strength: '200mg',
      dosageForm: DosageForm.tablet,
      dosageAmount: 1,
      createdAt: DateTime.now(),
      schedule: MedicineSchedule.asNeeded(maxDailyDoses: 1),
    );
    await MedicineCleanStorageService.addMedicine(med, stampActiveProfile: false);
    await MedicineCleanStorageService.markMedicineTaken(
      medicineId: med.id,
      scheduledTime: DateTime.now().subtract(const Duration(hours: 1)),
      dosageTaken: 1,
    );
    return med;
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

  Future<void> tapAndPumpBounded(WidgetTester tester, Finder finder) async {
    await tester.tap(finder);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('the PRN warning is a sheet, not an AlertDialog', (tester) async {
    final med = await seedAtLimit();
    await openSheet(tester, med);

    await tapAndPumpBounded(tester, find.text('Take medicine'));

    expect(find.text('PRN limit reached'), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.widgetWithText(AppButton, 'Log anyway'), findsOneWidget);
    expect(find.widgetWithText(AppButton, 'Cancel'), findsOneWidget);
  });

  testWidgets('(a) dismissing the sheet logs nothing and keeps the take sheet open',
      (tester) async {
    final med = await seedAtLimit();
    await openSheet(tester, med);

    await tapAndPumpBounded(tester, find.text('Take medicine'));
    expect(find.text('PRN limit reached'), findsOneWidget);

    // Tap the barrier above the sheet — the dismissal that returns null, which
    // is the case `proceed ?? false` exists for.
    await tester.tapAt(const Offset(400, 20));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    expect(find.text('PRN limit reached'), findsNothing);
    expect(await loggedDoses(med.id), 1,
        reason: 'a dismissed warning must not log the over-limit dose');
    expect(find.text('Take medicine'), findsOneWidget,
        reason: 'the take sheet stays open so the user can decide again');
  });

  testWidgets('(b) confirming logs the over-limit dose and closes the take sheet',
      (tester) async {
    final med = await seedAtLimit();
    await openSheet(tester, med);

    await tapAndPumpBounded(tester, find.text('Take medicine'));
    await tapAndPumpBounded(
        tester, find.widgetWithText(AppButton, 'Log anyway'));
    await tester.pumpAndSettle();

    expect(await loggedDoses(med.id), 2,
        reason: 'confirming must log the dose the warning was about');
    expect(find.text('Take medicine'), findsNothing,
        reason: 'the take sheet pops once the dose is logged');
  });
}
