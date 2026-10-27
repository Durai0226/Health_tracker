/// Three things that were missing from the medicine screens:
///
///  * a dose row on the dashboard that was not due (taken, skipped, or still to
///    come) went nowhere when tapped, and a due one could not reach its medicine
///    at all;
///  * the Refill & supply overview was only reachable while a medicine was
///    already flagged low or expiring;
///  * the Adherence report, where the numbers are, had no way to share them.
library;

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
import 'package:tablet_remainder/features/medication/screens/nunito_medication_dashboard.dart';
import 'package:tablet_remainder/features/medication/screens/nunito_medication_detail_screen.dart';
import 'package:tablet_remainder/features/medication/screens/nunito_medication_list_screen.dart';
import 'package:tablet_remainder/features/medication/screens/refill_overview_screen.dart';
import 'package:tablet_remainder/features/medication/services/medicine_storage_service.dart';

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

  late DateTime now;

  Future<void> seed({int? stock}) =>
      MedicineCleanStorageService.addMedicine(EnhancedMedicine(
        id: 'm1',
        name: 'Metformin',
        strength: '500mg',
        dosageForm: DosageForm.tablet,
        dosageAmount: 1,
        currentStock: stock,
        createdAt: now.subtract(const Duration(days: 3)),
        schedule: MedicineSchedule(
          frequencyType: FrequencyType.onceDaily,
          times: [ScheduledTime(hour: 9, minute: 30)],
        ),
      ));

  Future<void> open(WidgetTester tester, Widget screen) async {
    tester.view.devicePixelRatio = 1.0;
    // Wide enough for the medicine detail screen, which these taps open and
    // whose own layout at phone widths is tracked by the responsive harness.
    tester.view.physicalSize = const Size(900, 1600);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(theme: AppTheme.lightTheme, home: screen));
    await tester.pumpAndSettle(const Duration(seconds: 2));
  }

  Future<void> run(
      WidgetTester tester, Future<void> Function() body) async {
    final t = DateTime.now();
    now = DateTime(t.year, t.month, t.day, 14);
    await withClock(Clock(() => now), body);
  }

  group('a dose row reaches its medicine', () {
    Future<void> takenAt930() => MedicineCleanStorageService.addLog(MedicineLog.taken(
          id: MedicineCleanStorageService.doseLogId(
              'm1', DateTime(now.year, now.month, now.day, 9, 30)),
          medicineId: 'm1',
          scheduledTime: DateTime(now.year, now.month, now.day, 9, 30),
        ));

    testWidgets('tapping a dose that is already taken opens the medicine',
        (tester) async {
      await run(tester, () async {
        await seed();
        await takenAt930();
        await open(tester, const NunitoMedicationDashboard());

        await tester.ensureVisible(find.text('Metformin').last);
        await tester.tap(find.text('Metformin').last);
        await tester.pumpAndSettle();

        expect(find.byType(NunitoMedicationDetailScreen), findsOneWidget);
      });
    });

    testWidgets('a missed dose still opens its recovery sheet on a tap',
        (tester) async {
      await run(tester, () async {
        await seed();
        await open(tester, const NunitoMedicationDashboard());

        await tester.ensureVisible(find.text('Missed'));
        await tester.tap(find.text('Missed'));
        await tester.pumpAndSettle();

        expect(find.text('Missed dose'), findsOneWidget);
        expect(find.byType(NunitoMedicationDetailScreen), findsNothing);
      });
    });

    testWidgets('and its medicine on a long press', (tester) async {
      await run(tester, () async {
        await seed();
        await open(tester, const NunitoMedicationDashboard());

        await tester.ensureVisible(find.text('Missed'));
        await tester.longPress(find.text('Missed'));
        await tester.pumpAndSettle();

        expect(find.byType(NunitoMedicationDetailScreen), findsOneWidget);
        expect(find.text('Missed dose'), findsNothing,
            reason: 'a long press is not also a tap');
      });
    });

    testWidgets('every row offers it to a screen reader as an action',
        (tester) async {
      await run(tester, () async {
        await seed();
        await open(tester, const NunitoMedicationDashboard());

        final rows = find.byWidgetPredicate((w) =>
            w is Semantics &&
            (w.properties.customSemanticsActions?.keys
                    .any((a) => a.label == 'Open medicine details') ??
                false));
        expect(rows, findsOneWidget);
      });
    });
  });

  group('Refill & supply', () {
    testWidgets('is on the Medicines screen even when nothing is flagged',
        (tester) async {
      await run(tester, () async {
        // No medicines at all: nothing low, nothing expiring, no banner.
        await open(tester, const NunitoMedicationListScreen());

        expect(find.byTooltip('Refill & supply'), findsOneWidget);
        await tester.tap(find.byTooltip('Refill & supply'));
        await tester.pumpAndSettle();

        expect(find.byType(RefillOverviewScreen), findsOneWidget);
        expect(find.text('No supply tracked'), findsOneWidget);
      });
    });
  });

  group('the Adherence report can be shared', () {
    testWidgets('its header offers the same two exports as the list',
        (tester) async {
      await run(tester, () async {
        await seed();
        await open(tester, const NunitoAdherenceReportScreen());

        expect(find.byTooltip('Share with your doctor'), findsOneWidget);
        await tester.tap(find.byTooltip('Share with your doctor'));
        await tester.pumpAndSettle();

        expect(find.text('Adherence report (PDF)'), findsOneWidget);
        expect(find.text('Dose log (CSV)'), findsOneWidget);
      });
    });

    testWidgets('and the list screen still has it, from the same sheet',
        (tester) async {
      await run(tester, () async {
        await seed();
        await open(tester, const NunitoMedicationListScreen());

        await tester.tap(find.byTooltip('Share with your doctor'));
        await tester.pumpAndSettle();

        expect(find.text('Adherence report (PDF)'), findsOneWidget);
        expect(find.text('Dose log (CSV)'), findsOneWidget);
      });
    });
  });
}
