import 'package:clock/clock.dart';
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
import 'package:tablet_remainder/features/medication/screens/nunito_medication_dashboard.dart';
import 'package:tablet_remainder/features/medication/services/late_dose_recovery.dart';
import 'package:tablet_remainder/features/medication/services/medicine_storage_service.dart';
import 'package:tablet_remainder/features/medication/models/medicine_log.dart';
import 'package:tablet_remainder/features/medication/widgets/late_dose_sheets.dart';

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

  MissedDose dose() => MissedDose(
        MedicineLog.missed(
            id: 'l1',
            medicineId: 'm1',
            scheduledTime: DateTime(2026, 3, 10, 8)),
        EnhancedMedicine(
          id: 'm1',
          name: 'Metformin',
          dosageForm: DosageForm.tablet,
          dosageAmount: 1,
          schedule: MedicineSchedule(
              frequencyType: FrequencyType.onceDaily,
              times: [ScheduledTime(hour: 8, minute: 0)]),
        ),
      );

  Widget host(Widget child) => MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(body: SingleChildScrollView(child: child)),
      );

  group('LateDoseForm', () {
    Future<LateChoice?> tapAndRead(WidgetTester tester, String label) async {
      LateChoice? got;
      await tester.pumpWidget(host(LateDoseForm(
          dose: dose(), onChoice: (c) => got = c)));
      await tester.tap(find.text(label));
      await tester.pump();
      return got;
    }

    testWidgets('names the medicine and when it was due', (tester) async {
      await tester.pumpWidget(
          host(LateDoseForm(dose: dose(), onChoice: (_) {})));
      expect(find.text('Metformin'), findsOneWidget);
      expect(find.textContaining('8:00 AM'), findsWidgets);
    });

    testWidgets('Take now', (tester) async {
      expect((await tapAndRead(tester, 'Take now'))?.outcome,
          LateOutcome.takeNow);
    });

    testWidgets('Took it at the scheduled time', (tester) async {
      expect((await tapAndRead(tester, 'Took it at 8:00 AM'))?.outcome,
          LateOutcome.tookOnTime);
    });

    testWidgets('Skip it', (tester) async {
      expect((await tapAndRead(tester, 'Skip it'))?.outcome,
          LateOutcome.skipped);
    });
  });

  group('YesterdayTidyForm', () {
    List<MissedDose> two() {
      final a = dose();
      final b = MissedDose(
        MedicineLog.missed(
            id: 'l2',
            medicineId: 'm1',
            scheduledTime: DateTime(2026, 3, 10, 20)),
        a.medicine,
      );
      return [a, b];
    }

    bool saveEnabled(WidgetTester tester) => tester
            .widget<AppButton>(find.widgetWithText(AppButton, 'Save'))
            .onPressed !=
        null;

    testWidgets('Save is off until something changes', (tester) async {
      await tester.pumpWidget(
          host(YesterdayTidyForm(doses: two(), onSave: (_) {})));
      expect(saveEnabled(tester), isFalse);
    });

    testWidgets('"I took all of them" then Save returns every dose as taken',
        (tester) async {
      Map<String, TidyChoice>? got;
      await tester.pumpWidget(
          host(YesterdayTidyForm(doses: two(), onSave: (m) => got = m)));
      await tester.tap(find.text('I took all of them'));
      await tester.pump();
      expect(saveEnabled(tester), isTrue);
      await tester.tap(find.text('Save'));
      expect(got, {'l1': TidyChoice.taken, 'l2': TidyChoice.taken});
    });

    testWidgets('only the doses that were changed come back', (tester) async {
      Map<String, TidyChoice>? got;
      await tester.pumpWidget(
          host(YesterdayTidyForm(doses: two(), onSave: (m) => got = m)));
      await tester.tap(find.text('Skipped').last);
      await tester.pump();
      await tester.tap(find.text('Save'));
      expect(got, {'l2': TidyChoice.skipped});
    });
  });

  group('YesterdayTidyBanner', () {
    testWidgets('renders nothing for zero', (tester) async {
      await tester.pumpWidget(host(YesterdayTidyBanner(
          count: 0, onTidy: () {}, onDismiss: () {})));
      expect(find.textContaining('yesterday'), findsNothing);
    });

    testWidgets('says one dose, or many', (tester) async {
      await tester.pumpWidget(host(YesterdayTidyBanner(
          count: 1, onTidy: () {}, onDismiss: () {})));
      expect(find.text("1 dose from yesterday wasn't logged"), findsOneWidget);
      await tester.pumpWidget(host(YesterdayTidyBanner(
          count: 3, onTidy: () {}, onDismiss: () {})));
      expect(find.text("3 doses from yesterday weren't logged"), findsOneWidget);
    });
  });

  group('on the medication dashboard', () {
    late DateTime now;

    Future<void> seed() => MedicineCleanStorageService.addMedicine(EnhancedMedicine(
          id: 'm1',
          name: 'Metformin',
          strength: '500mg',
          dosageForm: DosageForm.tablet,
          dosageAmount: 1,
          currentStock: 30,
          createdAt: now.subtract(const Duration(days: 3)),
          schedule: MedicineSchedule(
            frequencyType: FrequencyType.onceDaily,
            times: [ScheduledTime(hour: 9, minute: 30)],
          ),
        ));

    Future<void> open(WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.lightTheme,
        home: const NunitoMedicationDashboard(),
      ));
      await tester.pumpAndSettle(const Duration(seconds: 2));
    }

    testWidgets('a missed dose can be tapped, logged as taken, and undone',
        (tester) async {
      final t = DateTime.now();
      now = DateTime(t.year, t.month, t.day, 14);
      await withClock(Clock(() => now), () async {
        await seed();
        await open(tester);
        expect(find.text('Missed'), findsOneWidget,
            reason: "today's 09:30 dose is past its grace window");

        await tester.ensureVisible(find.text('Missed'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Missed'));
        await tester.pumpAndSettle();
        expect(find.text('Missed dose'), findsOneWidget);

        await tester.tap(find.text('Took it at 9:30 AM'));
        await tester.pumpAndSettle();
        expect(find.text('Missed'), findsNothing);
        expect(find.text('Metformin taken'), findsOneWidget);

        await tester.tap(find.text('Undo'));
        await tester.pumpAndSettle();
        expect(find.text('Missed'), findsOneWidget,
            reason: 'Undo returns the dose to missed, not to nothing');
      });
    });

    testWidgets('yesterday has a banner, and tidying it clears it',
        (tester) async {
      final t = DateTime.now();
      now = DateTime(t.year, t.month, t.day, 14);
      await withClock(Clock(() => now), () async {
        await seed();
        await open(tester);
        expect(find.text("1 dose from yesterday wasn't logged"), findsOneWidget);

        await tester.tap(find.text("1 dose from yesterday wasn't logged"));
        await tester.pumpAndSettle();
        expect(find.text('Yesterday'), findsOneWidget);

        await tester.tap(find.text('Took it'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Save'));
        await tester.pumpAndSettle();

        expect(find.text("1 dose from yesterday wasn't logged"), findsNothing);
        expect(find.text('Yesterday updated'), findsOneWidget);
      });
    });

    testWidgets('dismissing the banner hides it for that day', (tester) async {
      final t = DateTime.now();
      now = DateTime(t.year, t.month, t.day, 14);
      await withClock(Clock(() => now), () async {
        await seed();
        await open(tester);
        await tester.tap(find.byTooltip('Not now'));
        await tester.pumpAndSettle();
        expect(find.textContaining('from yesterday'), findsNothing);
      });
    });
  });
}
