import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' show AppDatabase;
import 'package:tablet_remainder/core/theme/app_theme.dart';
import 'package:tablet_remainder/features/medication/models/enhanced_medicine.dart';
import 'package:tablet_remainder/features/medication/models/medicine_enums.dart';
import 'package:tablet_remainder/features/medication/models/medicine_schedule.dart';
import 'package:tablet_remainder/features/medication/screens/nunito_take_medication_sheet.dart';
import 'package:tablet_remainder/features/medication/services/medicine_storage_service.dart';

/// `effectivenessRating` has existed on `MedicineLog` and on
/// `markMedicineTaken` since before Phase 2, but no UI ever wrote it — so it
/// never appeared in a report. This is the regression cover for the new "How
/// well did it work?" picker actually reaching the stored log, the same way
/// `_selectedMood` already does.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    AppDatabase.setInstanceForTesting(db);
  });

  tearDown(() async => db.close());

  EnhancedMedicine med() => EnhancedMedicine(
        id: 'm1',
        name: 'Metformin',
        strength: '500mg',
        dosageForm: DosageForm.tablet,
        dosageAmount: 1,
        schedule: MedicineSchedule(
          frequencyType: FrequencyType.onceDaily,
          times: [ScheduledTime(hour: 8, minute: 0)],
        ),
      );

  Future<void> pumpSheet(WidgetTester tester, EnhancedMedicine medicine) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(
        body: NunitoTakeMedicationSheet(
          medicine: medicine,
          scheduledTime: DateTime(2026, 3, 1, 8),
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('picking "Good" and taking the dose stores effectivenessRating=4',
      (tester) async {
    final medicine = med();
    await MedicineCleanStorageService.addMedicine(medicine);
    await pumpSheet(tester, medicine);

    await tester.tap(find.text('Add details'));
    await tester.pumpAndSettle();

    expect(find.text('How well did it work?'), findsOneWidget);
    // index 3 -> rating 4, mirroring the mood picker's index+1 mapping.
    await tester.tap(find.text('Good'));
    await tester.pumpAndSettle();

    // The details expander pushes the primary action below the fold in the
    // test viewport — scroll it into view before tapping.
    await tester.ensureVisible(find.text('Take Medication'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Take Medication'));
    await tester.pumpAndSettle();

    final logs = await MedicineCleanStorageService.getLogsForMedicine(medicine.id);
    expect(logs, hasLength(1));
    expect(logs.single.effectivenessRating, 4);
  });

  testWidgets('taking a dose without opening details leaves effectivenessRating null',
      (tester) async {
    final medicine = med();
    await MedicineCleanStorageService.addMedicine(medicine);
    await pumpSheet(tester, medicine);

    await tester.tap(find.text('Take Medication'));
    await tester.pumpAndSettle();

    final logs = await MedicineCleanStorageService.getLogsForMedicine(medicine.id);
    expect(logs.single.effectivenessRating, isNull);
    expect(logs.single.moodRating, isNull);
  });
}
