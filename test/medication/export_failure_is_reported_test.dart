import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' show AppDatabase;
import 'package:tablet_remainder/core/services/active_profile_service.dart';
import 'package:tablet_remainder/features/medication/models/enhanced_medicine.dart';
import 'package:tablet_remainder/features/medication/models/medicine_enums.dart';
import 'package:tablet_remainder/features/medication/models/medicine_schedule.dart';
import 'package:tablet_remainder/features/medication/screens/nunito_medication_list_screen.dart';
import 'package:tablet_remainder/features/medication/services/medicine_storage_service.dart';

/// QA — "Share with your doctor" is the one place this screen touches the
/// filesystem and the OS share sheet, so it is the one place that will fail
/// in the field. It has to fail as a sentence, not as a crash.
///
/// Both exports gathered their dose logs OUTSIDE their own `try`, so a
/// storage error there escaped as an unhandled exception: no toast, no log
/// line, and a share sheet that simply never appeared.
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

  testWidgets('an export that cannot read the dose log says so', (tester) async {
    await MedicineCleanStorageService.addMedicine(EnhancedMedicine(
      id: 'm1',
      name: 'Metformin',
      strength: '500mg',
      dosageForm: DosageForm.tablet,
      dosageAmount: 1,
      createdAt: DateTime.now().subtract(const Duration(days: 3)),
      schedule: MedicineSchedule(
        frequencyType: FrequencyType.onceDaily,
        times: [ScheduledTime(hour: 9, minute: 0)],
      ),
    ));
    // The read the export depends on, made to fail the way a corrupt or
    // migrating database does.
    await db.customStatement('DROP TABLE medicine_logs');

    await tester.pumpWidget(const MaterialApp(
      home: NunitoMedicationListScreen(),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Share with your doctor'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dose log (CSV)'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull,
        reason: 'a failed export must not escape as an unhandled exception');
    expect(find.text('Could not create the report. Please try again.'),
        findsOneWidget);
  });
}
