/// The visit brief on screen, and the way into it from the appointment list.
library;

import 'dart:async';
import 'dart:typed_data';

import 'package:clock/clock.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' show AppDatabase;
import 'package:tablet_remainder/core/health/vitals_analyzer.dart' show GlucoseContext;
import 'package:tablet_remainder/core/services/active_profile_service.dart';
import 'package:tablet_remainder/core/services/clean_storage_service.dart';
import 'package:tablet_remainder/core/services/notification_service.dart';
import 'package:tablet_remainder/core/widgets/app/app_widgets.dart';
import 'package:tablet_remainder/features/medication/models/blood_pressure_reading.dart';
import 'package:tablet_remainder/features/medication/models/doctor_pharmacy.dart';
import 'package:tablet_remainder/features/medication/models/enhanced_medicine.dart';
import 'package:tablet_remainder/features/medication/models/glucose_reading.dart';
import 'package:tablet_remainder/features/medication/models/medicine_enums.dart';
import 'package:tablet_remainder/features/medication/models/medicine_log.dart';
import 'package:tablet_remainder/features/medication/models/medicine_schedule.dart';
import 'package:tablet_remainder/features/medication/models/weight_reading.dart';
import 'package:tablet_remainder/features/medication/screens/appointments/nunito_appointment_list_screen.dart';
import 'package:tablet_remainder/features/medication/screens/appointments/visit_brief_screen.dart';
import 'package:tablet_remainder/features/medication/services/medicine_storage_service.dart';
import 'package:tablet_remainder/features/medication/services/visit_brief_export.dart';
import 'package:tablet_remainder/features/medication/services/visit_brief_service.dart';
import 'package:tablet_remainder/features/medication/services/vitals_storage_service.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../support/font_free_theme.dart';
import '../support/recording_notification_scheduler.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  final now = DateTime(2026, 6, 20, 15, 30);
  final visit = DateTime(2026, 6, 25, 10, 30);

  setUpAll(() {
    tz_data.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('UTC'));
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    AppDatabase.setInstanceForTesting(db);
    ActiveProfileService().resetForTesting();
    CleanStorageService.resetForTesting();
    await CleanStorageService.init();
    NotificationService().schedulerForTesting = RecordingNotificationScheduler();
  });

  tearDown(() async {
    VisitBriefExport.shareOverride = null;
    await db.close();
  });

  Appointment appt(String id, DateTime at,
          {String doctor = 'Dr Anand',
          bool done = false,
          String? location,
          String? purpose,
          String? notes}) =>
      Appointment(
        id: id,
        doctorName: doctor,
        dateTime: at,
        isCompleted: done,
        location: location,
        purpose: purpose,
        notes: notes,
        reminderEnabled: false,
      );

  Future<void> save(Appointment a) =>
      MedicineCleanStorageService.addAppointment(a, stampActiveProfile: false);

  Future<void> seedHistory() async {
    await save(appt('old', DateTime(2026, 5, 4, 14), done: true));
    await MedicineCleanStorageService.addMedicine(
      EnhancedMedicine(
        id: 'm1',
        name: 'Metformin',
        strength: '500mg',
        dosageForm: DosageForm.tablet,
        dosageAmount: 1,
        createdAt: DateTime(2026, 1, 1),
        schedule: MedicineSchedule.onceDaily(
            hour: 8, minute: 0, startDate: DateTime(2026, 1, 1)),
      ),
      stampActiveProfile: false,
    );
    final days = <DateTime>[
      for (var d = 4; d <= 31; d++) DateTime(2026, 5, d, 8),
      for (var d = 1; d <= 20; d++) DateTime(2026, 6, d, 8),
    ];
    for (var i = 0; i < days.length; i++) {
      final at = days[i];
      final id = MedicineCleanStorageService.doseLogId('m1', at);
      if (i < 40) {
        await MedicineCleanStorageService.addLog(
            MedicineLog.taken(id: id, medicineId: 'm1', scheduledTime: at, actionTime: at));
      } else if (i < 45) {
        await MedicineCleanStorageService.addLog(
            MedicineLog.missed(id: id, medicineId: 'm1', scheduledTime: at));
      }
    }
    final at = DateTime(2026, 6, 10, 8);
    await VitalsStorageService.saveBp(
        BloodPressureReading(
            id: 'bp1', systolic: 128, diastolic: 82, takenAt: at, createdAt: at),
        stampActiveProfile: false,
        syncToHealthConnect: false);
    await VitalsStorageService.saveGlucose(
        GlucoseReading(
            id: 'g1',
            valueMgdl: 100,
            context: GlucoseContext.fasting,
            takenAt: at,
            createdAt: at),
        stampActiveProfile: false,
        syncToHealthConnect: false);
    await VitalsStorageService.saveWeight(
        WeightReading(id: 'w1', valueKg: 71.4, takenAt: at, createdAt: at),
        stampActiveProfile: false,
        syncToHealthConnect: false);
  }

  Future<void> frames(WidgetTester tester, [int n = 8]) async {
    for (var i = 0; i < n; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> open(WidgetTester tester, Appointment a,
      {double width = 430, double scale = 1}) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = Size(width, 3000);
    tester.platformDispatcher.textScaleFactorTestValue = scale;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
        theme: fontFreeTheme(), home: VisitBriefScreen(appointment: a)));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 250)));
    await frames(tester);
  }

  Future<R> pinned<R>(Future<R> Function() body) => withClock(Clock.fixed(now), body);

  group('the screen', () {
    testWidgets('the visit, what it covers, the doses, the readings', (tester) async {
      await pinned(() async {
        await seedHistory();
        final a = appt('v', visit, location: 'St Mary, clinic 3');
        await save(a);
        await open(tester, a);

        expect(find.text('Dr Anand'), findsOneWidget);
        expect(find.text('Thu, Jun 25 · 10:30 AM · St Mary, clinic 3'), findsOneWidget);
        expect(find.text('Covers since your last visit on May 4 (47 days)'), findsOneWidget);

        expect(find.text('83% of doses taken'), findsOneWidget);
        expect(find.text('40 of 48 scheduled · 5 missed · 0 skipped'), findsOneWidget);
        expect(find.text('Metformin 500mg: 83% · 5 missed'), findsOneWidget);

        expect(find.text('Readings'), findsOneWidget);
        expect(find.textContaining('Blood pressure: average 128/82 over 1 measurement'),
            findsOneWidget);
        expect(find.textContaining('Blood sugar: average 100 mg/dL over 1 reading'),
            findsOneWidget);
        expect(find.text('Weight: 71.4 kg'), findsOneWidget);
        expect(find.textContaining('It is not medical advice.'), findsOneWidget);
        await tester.pump(const Duration(seconds: 8));
      });
    });

    testWidgets('without an earlier visit: the last thirty days', (tester) async {
      await pinned(() async {
        final a = appt('v', visit);
        await save(a);
        await open(tester, a);
        expect(find.text('Covers the last 30 days'), findsOneWidget);
        await tester.pump(const Duration(seconds: 8));
      });
    });

    testWidgets('with nothing logged it says so, and shows no empty cards',
        (tester) async {
      await pinned(() async {
        final a = appt('v', visit);
        await save(a);
        await open(tester, a);
        expect(find.text('No medicines were being taken in this period.'), findsOneWidget);
        expect(find.text('Readings'), findsNothing);
        expect(find.text('Changes'), findsNothing);
        expect(find.text('To discuss'), findsNothing);
        await tester.pump(const Duration(seconds: 8));
      });
    });

    testWidgets('what you wanted to raise', (tester) async {
      await pinned(() async {
        final a = appt('v', visit, purpose: 'Six-month review', notes: 'Ask about the dizziness');
        await save(a);
        await open(tester, a);
        expect(find.text('To discuss'), findsOneWidget);
        expect(find.text('Six-month review'), findsOneWidget);
        expect(find.text('Ask about the dizziness'), findsOneWidget);
        await tester.pump(const Duration(seconds: 8));
      });
    });

    testWidgets('every medicine taken as scheduled says so', (tester) async {
      await pinned(() async {
        await MedicineCleanStorageService.addMedicine(
          EnhancedMedicine(
            id: 'm1',
            name: 'Aspirin',
            dosageForm: DosageForm.tablet,
            dosageAmount: 1,
            createdAt: DateTime(2026, 1, 1),
            schedule: MedicineSchedule.onceDaily(
                hour: 8, minute: 0, startDate: DateTime(2026, 1, 1)),
          ),
          stampActiveProfile: false,
        );
        // The last thirty days: May 21 to June 20, every morning.
        for (final at in [
          for (var d = 21; d <= 31; d++) DateTime(2026, 5, d, 8),
          for (var d = 1; d <= 20; d++) DateTime(2026, 6, d, 8),
        ]) {
          await MedicineCleanStorageService.addLog(MedicineLog.taken(
              id: MedicineCleanStorageService.doseLogId('m1', at),
              medicineId: 'm1',
              scheduledTime: at,
              actionTime: at));
        }
        final a = appt('v', visit);
        await save(a);
        await open(tester, a);
        expect(find.text('100% of doses taken'), findsOneWidget);
        expect(find.text('Every medicine was taken as scheduled.'), findsOneWidget);
        await tester.pump(const Duration(seconds: 8));
      });
    });

    testWidgets('the three that went least well, the worst first', (tester) async {
      await pinned(() async {
        // Four medicines, taken on 10, 12, 14 and 16 of the last 20 mornings.
        for (var i = 0; i < 4; i++) {
          await MedicineCleanStorageService.addMedicine(
            EnhancedMedicine(
              id: 'm$i',
              name: 'Medicine $i',
              dosageForm: DosageForm.tablet,
              dosageAmount: 1,
              createdAt: DateTime(2026, 1, 1),
              schedule: MedicineSchedule.onceDaily(
                  hour: 8, minute: 0, startDate: DateTime(2026, 6, 1)),
            ),
            stampActiveProfile: false,
          );
          for (var d = 1; d <= 20; d++) {
            final at = DateTime(2026, 6, d, 8);
            final id = MedicineCleanStorageService.doseLogId('m$i', at);
            await MedicineCleanStorageService.addLog(d <= 10 + 2 * i
                ? MedicineLog.taken(id: id, medicineId: 'm$i', scheduledTime: at, actionTime: at)
                : MedicineLog.missed(id: id, medicineId: 'm$i', scheduledTime: at));
          }
        }
        final a = appt('v', visit);
        await save(a);
        await open(tester, a);

        expect(find.text('Medicine 0: 50% · 10 missed'), findsOneWidget);
        expect(find.text('Medicine 1: 60% · 8 missed'), findsOneWidget);
        expect(find.text('Medicine 2: 70% · 6 missed'), findsOneWidget);
        expect(find.textContaining('Medicine 3'), findsNothing, reason: 'three, not four');
        await tester.pump(const Duration(seconds: 8));
      });
    });

    test('the covers line, for each kind of window', () async {
      final a = appt('v', visit);
      Future<VisitBrief> b() => withClock(Clock.fixed(now), () => VisitBriefService.build(a, now: now));
      await save(a);
      expect(VisitBriefScreen.coversLine(await b()), 'Covers the last 30 days');
      await save(appt('old', DateTime(2025, 12, 1), done: true));
      expect(VisitBriefScreen.coversLine(await b()), 'Covers the last 90 days',
          reason: 'too long ago to be one window');
    });
  });

  group('sharing', () {
    testWidgets('a PDF, named for the doctor and the day', (tester) async {
      await pinned(() async {
        await seedHistory();
        final a = appt('v', visit);
        await save(a);
        Uint8List? bytes;
        String? name;
        VisitBriefExport.shareOverride = (b, n) async {
          bytes = b;
          name = n;
        };
        await open(tester, a);

        await tester.runAsync(() async {
          await tester.tap(find.widgetWithText(AppButton, 'Share as PDF'));
          await Future<void>.delayed(const Duration(milliseconds: 600));
        });
        await frames(tester, 3);

        expect(bytes, isNotNull);
        expect(String.fromCharCodes(bytes!.sublist(0, 4)), '%PDF');
        expect(name, 'visit-brief-dr-anand-2026-06-25.pdf');
        await tester.pump(const Duration(seconds: 8));
      });
    });

    testWidgets('a second tap while the first is still sharing does nothing',
        (tester) async {
      await pinned(() async {
        final a = appt('v', visit);
        await save(a);
        final pending = Completer<void>();
        var calls = 0;
        VisitBriefExport.shareOverride = (_, _) {
          calls++;
          return pending.future;
        };
        await open(tester, a);

        // The big button first; while it spins, the header's is still there.
        for (final target in [
          find.widgetWithText(AppButton, 'Share as PDF'),
          find.byTooltip('Share as PDF'),
        ]) {
          await tester.runAsync(() async {
            await tester.tap(target);
            await Future<void>.delayed(const Duration(milliseconds: 400));
          });
          await frames(tester, 2);
        }
        expect(calls, 1);

        pending.complete();
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
        await frames(tester, 2);
        await tester.pump(const Duration(seconds: 8));
      });
    });

    testWidgets('the header button does the same', (tester) async {
      await pinned(() async {
        final a = appt('v', visit);
        await save(a);
        var shared = 0;
        VisitBriefExport.shareOverride = (_, _) async => shared++;
        await open(tester, a);
        await tester.runAsync(() async {
          await tester.tap(find.byTooltip('Share as PDF'));
          await Future<void>.delayed(const Duration(milliseconds: 600));
        });
        await frames(tester, 3);
        expect(shared, 1);
        await tester.pump(const Duration(seconds: 8));
      });
    });

    testWidgets('a share that fails says so, and the button is usable again',
        (tester) async {
      await pinned(() async {
        final a = appt('v', visit);
        await save(a);
        VisitBriefExport.shareOverride = (_, _) async => throw StateError('no share');
        await open(tester, a);
        await tester.runAsync(() async {
          await tester.tap(find.widgetWithText(AppButton, 'Share as PDF'));
          await Future<void>.delayed(const Duration(milliseconds: 600));
        });
        await frames(tester, 4);
        expect(find.text('Could not make the PDF. Please try again.'), findsOneWidget);
        expect(
            tester.widget<AppButton>(find.widgetWithText(AppButton, 'Share as PDF')).loading,
            isFalse);
        await tester.pump(const Duration(seconds: 8));
      });
    });

    test('file names are safe', () {
      expect(VisitBriefExport.filenameFor('Dr. R. Anand (clinic)', DateTime(2026, 6, 5)),
          'visit-brief-dr-r-anand-clinic-2026-06-05.pdf');
      expect(VisitBriefExport.filenameFor('', DateTime(2026, 6, 5)),
          'visit-brief-2026-06-05.pdf');
      expect(VisitBriefExport.filenameFor('Dr/..\\x', DateTime(2026, 12, 25)),
          'visit-brief-dr-x-2026-12-25.pdf');
    });
  });

  group('from the appointment list', () {
    Future<void> openList(WidgetTester tester) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(430, 2400);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
          theme: fontFreeTheme(), home: const NunitoAppointmentListScreen()));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 250)));
      await frames(tester);
    }

    // The list reads "upcoming" off the real clock.
    final soon = DateTime.now().add(const Duration(days: 9));
    final ago = DateTime.now().subtract(const Duration(days: 9));

    testWidgets('an upcoming visit offers its brief, which opens', (tester) async {
      await save(appt('up', soon));
      await openList(tester);
      expect(find.text('Visit brief'), findsOneWidget);

      await tester.tap(find.text('Visit brief'));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 250)));
      await frames(tester);
      expect(find.byType(VisitBriefScreen), findsOneWidget);
      await tester.pump(const Duration(seconds: 8));
    });

    testWidgets('a past visit does not', (tester) async {
      await save(appt('past', ago));
      await openList(tester);
      expect(find.text('Dr Anand'), findsOneWidget);
      expect(find.text('Visit brief'), findsNothing);
    });

    testWidgets('and neither does one marked done', (tester) async {
      await save(appt('done', soon, done: true));
      await openList(tester);
      expect(find.text('Visit brief'), findsNothing);
    });
  });

  for (final scale in [1.0, 2.0]) {
    testWidgets('fits at 320pt and ${scale}x text, with everything on it', (tester) async {
      await pinned(() async {
        await seedHistory();
        final a = appt('v', visit,
            doctor: 'Dr Anand Venkataraghavan, Consultant Endocrinologist',
            location: 'St Mary\'s Hospital, East Wing, Clinic 3',
            purpose: 'Six-month review of everything, at length',
            notes: 'Ask about the dizziness in the mornings and the new tablets');
        await save(a);
        final reports = <String>[];
        final prev = FlutterError.onError;
        FlutterError.onError = (d) => reports.add(d.toString());
        try {
          await open(tester, a, width: 320, scale: scale);
        } finally {
          FlutterError.onError = prev;
        }
        expect(find.text('Visit brief'), findsWidgets);
        expect(reports.where((r) => r.contains('visit_brief_screen.dart')), isEmpty,
            reason: reports.join('\n').split('\n').take(6).join('\n'));
        await tester.pump(const Duration(seconds: 8));
      });
    });
  }
}
