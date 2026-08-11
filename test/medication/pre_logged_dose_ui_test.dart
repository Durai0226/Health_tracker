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
import 'package:tablet_remainder/features/medication/screens/nunito_take_medication_sheet.dart';
import 'package:tablet_remainder/features/medication/services/medicine_storage_service.dart';
import 'package:tablet_remainder/core/widgets/app/app_widgets.dart';

/// UI coverage for the "Log for a different time" pre-log entry point on the
/// take-medication sheet.
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

  Future<EnhancedMedicine> seedDailyMedicine() async {
    final med = EnhancedMedicine(
      id: 'm1',
      name: 'Levothyroxine',
      strength: '50mcg',
      dosageForm: DosageForm.tablet,
      dosageAmount: 1,
      createdAt: DateTime.now().subtract(const Duration(days: 30)),
      schedule: MedicineSchedule(
        frequencyType: FrequencyType.onceDaily,
        times: [ScheduledTime(hour: 8, minute: 0)],
      ),
    );
    await MedicineCleanStorageService.addMedicine(med, stampActiveProfile: false);
    return med;
  }

  Future<EnhancedMedicine> seedPrnMedicine() async {
    final med = EnhancedMedicine(
      id: 'p1',
      name: 'Ibuprofen',
      strength: '200mg',
      dosageForm: DosageForm.tablet,
      dosageAmount: 1,
      createdAt: DateTime.now().subtract(const Duration(days: 5)),
      schedule: MedicineSchedule.asNeeded(),
    );
    await MedicineCleanStorageService.addMedicine(med, stampActiveProfile: false);
    return med;
  }

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

  testWidgets('positive: a fixed-schedule medicine shows the pre-log link',
      (tester) async {
    final med = await seedDailyMedicine();
    await openSheet(tester, med);
    expect(find.text('Log for a different time'), findsOneWidget);
  });

  testWidgets('negative: a PRN medicine does not show the pre-log link',
      (tester) async {
    final med = await seedPrnMedicine();
    await openSheet(tester, med);
    expect(find.text('Log for a different time'), findsNothing);
  });

  testWidgets('positive: the picker lists at least one upcoming slot',
      (tester) async {
    final med = await seedDailyMedicine();
    await openSheet(tester, med);

    await tester.tap(find.text('Log for a different time'));
    await tester.pumpAndSettle();

    // Tapping a specific slot's persistence is covered at the service level
    // (test/medication/pre_logged_dose_test.dart) — nested modal bottom
    // sheets don't hit-test reliably in this harness, so this test stops at
    // confirming the picker itself renders real upcoming slots.
    expect(find.byType(AppListTile), findsWidgets);
    expect(find.textContaining('8:00 AM'), findsWidgets);
  });
}
