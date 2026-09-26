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
import 'package:tablet_remainder/features/medication/models/medicine_log.dart';
import 'package:tablet_remainder/features/medication/models/medicine_schedule.dart';
import 'package:tablet_remainder/features/medication/screens/analytics/nunito_adherence_report_screen.dart';
import 'package:tablet_remainder/features/medication/services/medicine_storage_service.dart';

/// Regression cover for the daily-adherence chart on the Adherence report.
///
/// The bar for a day was `taken / scheduled`, but the two sides were drawn from
/// DIFFERENT populations: the denominator counted slots of active, non-archived,
/// non-PRN medicines only, while the numerator counted every taken log in the
/// window — including PRN and archived medicines the denominator excludes. A day
/// with one scheduled dose and three unrelated PRN doses therefore rendered a
/// full "100%" bar. Both sides must use the same eligible-id set, exactly as
/// MedicineCleanStorageService.getAdherenceStats does.
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
  final yesterday = today.subtract(const Duration(days: 1));

  EnhancedMedicine scheduledMed({
    required String id,
    bool archived = false,
  }) =>
      EnhancedMedicine(
        id: id,
        name: 'Med $id',
        dosageForm: DosageForm.tablet,
        dosageAmount: 1,
        isArchived: archived,
        createdAt: today.subtract(const Duration(days: 10)),
        schedule: MedicineSchedule(
          frequencyType: FrequencyType.twiceDaily,
          times: [
            ScheduledTime(hour: 8, minute: 0),
            ScheduledTime(hour: 20, minute: 0),
          ],
        ),
      );

  EnhancedMedicine prnMed() => EnhancedMedicine(
        id: 'prn',
        name: 'Ibuprofen',
        dosageForm: DosageForm.tablet,
        dosageAmount: 1,
        createdAt: today.subtract(const Duration(days: 10)),
        schedule: MedicineSchedule.asNeeded(),
      );

  Future<void> logTaken(String medicineId, DateTime slot) =>
      MedicineCleanStorageService.addLog(MedicineLog.taken(
        id: MedicineCleanStorageService.doseLogId(medicineId, slot),
        medicineId: medicineId,
        scheduledTime: slot,
      ));

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      home: const NunitoAdherenceReportScreen(),
    ));
    await tester.pumpAndSettle();
  }

  /// Week view renders one bar per day, oldest first, ending with today —
  /// so yesterday is the second-to-last of the seven.
  double yesterdayBarFill(WidgetTester tester) {
    final bars = tester
        .widgetList<FractionallySizedBox>(find.byType(FractionallySizedBox))
        .toList();
    expect(bars.length, 7, reason: 'the Week view draws 7 daily bars');
    return bars[5].heightFactor!;
  }

  testWidgets(
      'a day bar counts only doses of the medicines its denominator includes',
      (tester) async {
    // Denominator: 2 due slots yesterday, from the one eligible medicine.
    await MedicineCleanStorageService.addMedicine(scheduledMed(id: 'active'),
        stampActiveProfile: false);
    // Excluded from the denominator — and now from the numerator too.
    await MedicineCleanStorageService.addMedicine(
        scheduledMed(id: 'archived', archived: true),
        stampActiveProfile: false);
    await MedicineCleanStorageService.addMedicine(prnMed(),
        stampActiveProfile: false);

    // One of the eligible medicine's two doses taken.
    await logTaken('active', yesterday.add(const Duration(hours: 8)));
    // Noise the old code folded into the same numerator.
    await logTaken('archived', yesterday.add(const Duration(hours: 8)));
    await logTaken('archived', yesterday.add(const Duration(hours: 20)));
    await logTaken('prn', yesterday.add(const Duration(hours: 13)));

    await pump(tester);

    // 1 of 2 eligible doses = 0.5. Before the fix this was (1+3)/2, clamped to
    // a full 1.0 bar — a perfect day that never happened.
    expect(yesterdayBarFill(tester), closeTo(0.5, 0.001));
  });

  testWidgets('a genuinely complete day still fills the bar', (tester) async {
    await MedicineCleanStorageService.addMedicine(scheduledMed(id: 'active'),
        stampActiveProfile: false);
    await logTaken('active', yesterday.add(const Duration(hours: 8)));
    await logTaken('active', yesterday.add(const Duration(hours: 20)));

    await pump(tester);

    expect(yesterdayBarFill(tester), closeTo(1.0, 0.001));
  });

  testWidgets('PRN doses alone never invent adherence for a day',
      (tester) async {
    await MedicineCleanStorageService.addMedicine(prnMed(),
        stampActiveProfile: false);
    await logTaken('prn', yesterday.add(const Duration(hours: 13)));

    await pump(tester);

    // Nothing was ever scheduled, so the chart must show its empty state
    // rather than a bar built from as-needed doses.
    expect(find.text('No doses scheduled in this period'), findsOneWidget);
    expect(find.byType(FractionallySizedBox), findsNothing);
  });

  testWidgets("a dose pre-logged for later today isn't today's adherence",
      (tester) async {
    // The denominator counts only slots already DUE, so a dose pre-logged for
    // tonight must not reach the numerator — it would be a numerator with no
    // denominator, and the 0..1 clamp would hide it as a perfect day.
    //
    // TWO layers enforce that now: the screen's single shared read ends at
    // `now`, and `_calculateDailyStats` re-applies the bound to what it is
    // handed. Either alone keeps this green — this asserts the OUTCOME, so it
    // fails if the read is ever widened without the in-memory bound (verified:
    // widening it to `dayOffset(now, 1)` with that filter dropped renders
    // today's bar at 1.0).
    //
    // Pinned to midday so "tonight" is genuinely in the future whatever time
    // the suite runs at.
    final noon = DateTime(today.year, today.month, today.day, 12);
    await withClock(Clock.fixed(noon), () async {
      await MedicineCleanStorageService.addMedicine(scheduledMed(id: 'active'),
          stampActiveProfile: false);
      // Today's 08:00 dose was NOT taken; tonight's 20:00 dose is pre-logged.
      await MedicineCleanStorageService.addLog(MedicineLog.preLogged(
        id: MedicineCleanStorageService.doseLogId(
            'active', today.add(const Duration(hours: 20))),
        medicineId: 'active',
        scheduledTime: today.add(const Duration(hours: 20)),
        actionTime: noon,
      ));

      await pump(tester);

      // Today is the last of the seven bars. 0 of the 1 due slot = empty.
      final bars = tester
          .widgetList<FractionallySizedBox>(find.byType(FractionallySizedBox))
          .toList();
      expect(bars.length, 7, reason: 'the Week view draws 7 daily bars');
      expect(bars.last.heightFactor, closeTo(0.0, 0.001));
    });
  });
}
