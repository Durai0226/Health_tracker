import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' show AppDatabase;
import 'package:tablet_remainder/core/services/clean_storage_service.dart';
import 'package:tablet_remainder/core/theme/app_theme.dart';
import 'package:tablet_remainder/features/medication/models/enhanced_medicine.dart';
import 'package:tablet_remainder/features/medication/models/medicine_enums.dart';
import 'package:tablet_remainder/features/medication/models/medicine_schedule.dart';
import 'package:tablet_remainder/features/medication/screens/nunito_medication_dashboard.dart';
import 'package:tablet_remainder/features/medication/services/medicine_storage_service.dart';

/// QA — the pillbox-tray layout is a toggle-able alternative to the timeline
/// for today's schedule. It must reuse the exact same doses/status the
/// timeline is built from: same medicines, grouped by time-of-day slot, with
/// the same taken/skipped terminal rules, and the same take-medication sheet
/// behind an untaken tap.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    AppDatabase.setInstanceForTesting(db);
    // Without this, CleanStorageService's cached DB/preference reference
    // from a PRIOR test in this file survives into the next one — that
    // prior test's `db` is already closed by then, so any preference write
    // (e.g. persisting the pillbox/timeline view-mode choice) throws "Can't
    // re-open a database after closing it," which then cascades into
    // whichever test runs next.
    CleanStorageService.resetForTesting();
  });

  tearDown(() async => db.close());

  /// A medicine with one slot 30 minutes ago (overdue enough to be
  /// actionable, inside the missed-reconciliation grace window), explicitly
  /// labeled "Morning" so the pillbox grouping doesn't depend on what time of
  /// day the test happens to run.
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
        times: [
          ScheduledTime(hour: slot.hour, minute: slot.minute, label: 'Morning'),
        ],
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

  Future<void> switchToPillboxView(WidgetTester tester) async {
    await tester.tap(find.byTooltip('Pillbox view'));
    await tester.pumpAndSettle();
  }

  Future<void> skipTheDose(WidgetTester tester) async {
    await tester.tap(find.textContaining('Take Now').first);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(InkWell, 'Skip').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text(SkipReason.values.first.displayName).first);
    await tester.pumpAndSettle();
  }

  testWidgets(
      'toggling to pillbox view renders a pill per due dose grouped by time-of-day slot',
      (tester) async {
    await seedDueDose();
    await pumpDashboard(tester);

    // Starts on the timeline by default.
    expect(find.textContaining('Take Now'), findsOneWidget);

    await switchToPillboxView(tester);

    // The compartment header for the dose's slot, and the medicine itself.
    expect(find.text('Morning'), findsOneWidget);
    expect(find.text('Metformin'), findsOneWidget);
    // Timeline-only chrome is gone — this really swapped layouts, not just
    // added to it.
    expect(find.textContaining('Take Now'), findsNothing);

    // Toggling back restores the timeline.
    await tester.tap(find.byTooltip('Timeline view'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Take Now'), findsOneWidget);
    expect(find.text('Morning'), findsNothing);
  });

  testWidgets('tapping an untaken pill opens the take-medication sheet',
      (tester) async {
    await seedDueDose();
    await pumpDashboard(tester);
    await switchToPillboxView(tester);

    await tester.tap(find.text('Metformin'));
    await tester.pumpAndSettle();

    expect(find.text('Take Medication'), findsOneWidget,
        reason:
            'an untaken pillbox pill must open the same take-medication sheet as the timeline');
  });

  testWidgets(
      'a skipped dose renders as a visually distinct, non-interactive pill',
      (tester) async {
    await seedDueDose();
    await pumpDashboard(tester);

    // Resolve the dose from the (default) timeline view first, reusing the
    // existing skip flow.
    await skipTheDose(tester);
    expect(find.text('Skipped'), findsOneWidget,
        reason: 'sanity check: the timeline reflects the skip before we switch views');

    await switchToPillboxView(tester);

    // The pill is still shown...
    expect(find.text('Metformin'), findsOneWidget);
    // ...marked with the skipped badge (the dashboard's only close_rounded
    // icon, reserved for this exact overlay)...
    expect(
      find.byWidgetPredicate(
          (w) => w is Icon && w.icon == Symbols.close_rounded),
      findsOneWidget,
      reason: 'a skipped pill must be visually distinct from an untaken one',
    );

    // ...and tapping it must NOT reopen the take sheet — a terminal dose
    // can't be re-taken from the pillbox view either.
    await tester.tap(find.text('Metformin'));
    await tester.pumpAndSettle();
    expect(find.text('Take Medication'), findsNothing);
  });

  testWidgets('the chosen view mode is persisted across a fresh mount',
      (tester) async {
    await seedDueDose();
    await pumpDashboard(tester);
    await switchToPillboxView(tester);
    expect(find.text('Morning'), findsOneWidget);

    // Remount the dashboard (simulates reopening the screen/app) without
    // resetting storage — the preference must survive.
    await tester.pumpWidget(const SizedBox());
    await pumpDashboard(tester);

    expect(find.text('Morning'), findsOneWidget,
        reason: 'medicationViewMode should have been restored as pillbox');
    expect(find.textContaining('Take Now'), findsNothing);
  });
}
