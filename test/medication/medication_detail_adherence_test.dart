import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' show AppDatabase;
import 'package:tablet_remainder/core/services/active_profile_service.dart';
import 'package:tablet_remainder/core/theme/app_theme.dart';
import 'package:tablet_remainder/core/widgets/app/app_widgets.dart' show StatTile;
import 'package:tablet_remainder/features/medication/models/enhanced_medicine.dart';
import 'package:tablet_remainder/features/medication/models/medicine_enums.dart';
import 'package:tablet_remainder/features/medication/models/medicine_log.dart';
import 'package:tablet_remainder/features/medication/models/medicine_schedule.dart';
import 'package:tablet_remainder/features/medication/screens/nunito_medication_detail_screen.dart';
import 'package:tablet_remainder/features/medication/services/medicine_storage_service.dart';

/// Regression cover for the "Adherence" stat on the medicine detail screen.
///
/// It used to be `taken / number-of-log-rows`, which is not adherence at all:
/// log rows are outcomes, not doses that were due. A brand-new medicine with no
/// logs read a damning 0%, and an as-needed medicine read a flattering 100%.
/// The denominator must be SCHEDULED doses, and with nothing scheduled the
/// screen must say so ("--") instead of printing a number, exactly as the
/// medication dashboard does.
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

  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);

  EnhancedMedicine twiceDaily({required DateTime createdAt}) => EnhancedMedicine(
        id: 'm1',
        name: 'Metformin',
        dosageForm: DosageForm.tablet,
        dosageAmount: 1,
        createdAt: createdAt,
        schedule: MedicineSchedule(
          frequencyType: FrequencyType.twiceDaily,
          times: [
            ScheduledTime(hour: 8, minute: 0),
            ScheduledTime(hour: 20, minute: 0),
          ],
        ),
      );

  EnhancedMedicine prn() => EnhancedMedicine(
        id: 'p1',
        name: 'Ibuprofen',
        dosageForm: DosageForm.tablet,
        dosageAmount: 1,
        createdAt: today.subtract(const Duration(days: 5)),
        schedule: MedicineSchedule.asNeeded(),
      );

  Future<void> logTaken(String medicineId, DateTime slot) =>
      MedicineCleanStorageService.addLog(MedicineLog.taken(
        id: MedicineCleanStorageService.doseLogId(medicineId, slot),
        medicineId: medicineId,
        scheduledTime: slot,
      ));

  Future<void> open(WidgetTester tester, EnhancedMedicine med) async {
    await MedicineCleanStorageService.addMedicine(med,
        stampActiveProfile: false);
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      home: NunitoMedicationDetailScreen(medicine: med),
    ));
    await tester.pumpAndSettle();
  }

  String statValue(WidgetTester tester, String label) =>
      tester.widget<StatTile>(find.widgetWithText(StatTile, label)).value;

  testWidgets('a brand-new medicine reports no data, not 0% adherence',
      (tester) async {
    // Created just now, so no slot has both fallen after creation and come due.
    await open(tester, twiceDaily(createdAt: DateTime.now()));

    expect(statValue(tester, 'Adherence'), '--');
    expect(statValue(tester, 'Scheduled'), '0');
    expect(find.text('no doses scheduled yet'), findsOneWidget);
  });

  testWidgets('an as-needed medicine never reports a fabricated 100%',
      (tester) async {
    final med = prn();
    await open(tester, med);
    await logTaken(med.id, today.subtract(const Duration(days: 1, hours: -13)));
    await logTaken(med.id, today.subtract(const Duration(days: 2, hours: -9)));
    // Reload through the same path the app uses when a dose is logged.
    MedicineCleanStorageService.revision.value++;
    await tester.pumpAndSettle();

    expect(statValue(tester, 'Adherence'), '--');
    expect(find.text('taken as needed — no fixed schedule'), findsOneWidget);
  });

  testWidgets('adherence is taken / scheduled doses, not taken / log rows',
      (tester) async {
    final med = twiceDaily(createdAt: today.subtract(const Duration(days: 4)));
    await open(tester, med);
    // Exactly one dose taken out of the many that came due over four days.
    await logTaken(med.id, today.subtract(const Duration(days: 1, hours: -8)));
    MedicineCleanStorageService.revision.value++;
    await tester.pumpAndSettle();

    final adherence = statValue(tester, 'Adherence');
    expect(adherence, isNot('--'), reason: 'doses were scheduled and due');
    // The old ratio was 1 taken / 1 log row = 100%.
    expect(adherence, isNot('100%'));
    expect(statValue(tester, 'Taken'), '1');
    expect(int.parse(statValue(tester, 'Scheduled')), greaterThanOrEqualTo(6));
  });
}
