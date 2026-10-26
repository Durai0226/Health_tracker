import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' show AppDatabase;
import 'package:tablet_remainder/core/health/measurement_plan.dart';
import 'package:tablet_remainder/core/services/clean_storage_service.dart';
import 'package:tablet_remainder/core/services/notification_service.dart';
import 'package:tablet_remainder/core/theme/app_theme.dart';
import 'package:tablet_remainder/features/medication/models/enhanced_medicine.dart';
import 'package:tablet_remainder/features/medication/models/medicine_enums.dart';
import 'package:tablet_remainder/features/medication/models/medicine_schedule.dart';
import 'package:tablet_remainder/features/medication/services/measurement_plan_service.dart';
import 'package:tablet_remainder/features/medication/services/vitals_reminder_service.dart';
import 'package:tablet_remainder/features/medication/widgets/measurement_plan_sheet.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../support/recording_notification_scheduler.dart';

EnhancedMedicine _med(String name) => EnhancedMedicine(
      id: 'm-$name',
      name: name,
      strength: '10mg',
      dosageForm: DosageForm.tablet,
      dosageAmount: 1,
      schedule: MedicineSchedule(
        frequencyType: FrequencyType.onceDaily,
        times: [ScheduledTime(hour: 8, minute: 0)],
      ),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    tz_data.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('America/New_York'));
  });

  Widget host(Widget child) => MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(body: SingleChildScrollView(child: child)),
      );

  group('MeasurementPlanBody', () {
    final bp =
        MeasurementPlan.suggestionFor(MeasurementKind.bloodPressure, 'Amlodipine');
    final weight =
        MeasurementPlan.suggestionFor(MeasurementKind.weight, 'Furosemide');

    testWidgets('lists each offer, with its times, and arms nothing by itself',
        (tester) async {
      final accepted = <MeasurementKind>[];
      await tester.pumpWidget(host(MeasurementPlanBody(
        offers: [bp, weight],
        onAccept: (s) async => accepted.add(s.kind),
        onDone: () {},
      )));
      expect(find.text('Blood pressure, morning and evening'), findsOneWidget);
      expect(find.text('Daily weight'), findsOneWidget);
      expect(find.text('8:00 AM and 7:00 PM'), findsOneWidget);
      expect(find.text('Remind me'), findsNWidgets(2));
      expect(accepted, isEmpty, reason: 'offered, never switched on silently');
      expect(find.text('Not now'), findsOneWidget);
    });

    testWidgets('Remind me accepts that one offer and shows it is on',
        (tester) async {
      final accepted = <MeasurementKind>[];
      await tester.pumpWidget(host(MeasurementPlanBody(
        offers: [bp, weight],
        onAccept: (s) async => accepted.add(s.kind),
        onDone: () {},
      )));
      await tester.tap(find.text('Remind me').first);
      await tester.pump();
      await tester.pump();

      expect(accepted, [MeasurementKind.bloodPressure]);
      expect(find.text('Reminders on'), findsOneWidget);
      expect(find.text('Remind me'), findsOneWidget, reason: 'the other is untouched');
      expect(find.text('Not now'), findsOneWidget,
          reason: 'one offer is still open, so this is not yet "Done"');
    });

    testWidgets('when every offer is on the footer reads Done', (tester) async {
      await tester.pumpWidget(host(MeasurementPlanBody(
        offers: [bp],
        onAccept: (_) async {},
        onDone: () {},
      )));
      await tester.tap(find.text('Remind me'));
      await tester.pump();
      await tester.pump();
      expect(find.text('Done'), findsOneWidget);
      expect(find.text('Not now'), findsNothing);
    });

    testWidgets('a failed schedule does not read as On and can be retried',
        (tester) async {
      var calls = 0;
      await tester.pumpWidget(host(MeasurementPlanBody(
        offers: [bp],
        onAccept: (_) async {
          calls++;
          throw StateError('no alarm permission');
        },
        onDone: () {},
      )));
      await tester.tap(find.text('Remind me'));
      await tester.pump();
      await tester.pump();

      expect(find.text('Reminders on'), findsNothing);
      expect(find.text('Remind me'), findsOneWidget);
      await tester.tap(find.text('Remind me'));
      await tester.pump();
      expect(calls, 2);
    });

    testWidgets('the footer button calls onDone', (tester) async {
      var done = 0;
      await tester.pumpWidget(host(MeasurementPlanBody(
        offers: [bp],
        onAccept: (_) async {},
        onDone: () => done++,
      )));
      await tester.tap(find.text('Not now'));
      expect(done, 1);
    });
  });

  group('MeasurementPlanSheet.maybeShow', () {
    late RecordingNotificationScheduler scheduler;

    Future<void> prepare(WidgetTester tester) => tester.runAsync(() async {
          SharedPreferences.setMockInitialValues(<String, Object>{});
          final db = AppDatabase.forTesting(NativeDatabase.memory());
          AppDatabase.setInstanceForTesting(db);
          addTearDown(() async => db.close());
          CleanStorageService.resetForTesting();
          await CleanStorageService.init();
          scheduler = RecordingNotificationScheduler();
          NotificationService().schedulerForTesting = scheduler;
        });

    /// Real asset and database reads do not complete under FakeAsync, so every
    /// await in the offer path needs the real clock to move.
    Future<void> settle(WidgetTester tester) async {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 150)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
    }

    Future<void> open(WidgetTester tester, String medicine) async {
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.lightTheme,
        home: Builder(
          builder: (ctx) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => MeasurementPlanSheet.maybeShow(ctx, _med(medicine)),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('open'));
      await settle(tester);
    }

    testWidgets('a medicine with nothing to offer shows no sheet', (tester) async {
      await prepare(tester);
      await open(tester, 'Paracetamol');
      expect(find.textContaining('Track what'), findsNothing);
    });

    testWidgets('closing without accepting is remembered as not-now',
        (tester) async {
      await prepare(tester);
      await open(tester, 'Metformin');
      expect(find.text('Track what Metformin affects?'), findsOneWidget);

      await tester.tap(find.text('Not now'));
      await settle(tester);

      expect(MeasurementPlanService.declined(), {MeasurementKind.bloodGlucose});
      expect(scheduler.scheduled, isEmpty, reason: 'nothing was switched on');
      expect(VitalsReminderService.isEnabled(VitalsReminderService.glucose), isFalse);
    });

    testWidgets('accepting arms the reminder and declines nothing', (tester) async {
      await prepare(tester);
      await open(tester, 'Metformin');

      await tester.runAsync(() async {
        await tester.tap(find.text('Remind me'));
        await Future<void>.delayed(const Duration(milliseconds: 150));
      });
      await tester.pump();
      expect(find.text('Reminders on'), findsOneWidget);

      await tester.tap(find.text('Done'));
      await settle(tester);

      expect(VitalsReminderService.isEnabled(VitalsReminderService.glucose), isTrue);
      expect(scheduler.armedIds, contains(VitalsReminderService.glucose.id));
      expect(MeasurementPlanService.declined(), isEmpty);
    });
  });
}
