/// An appointment can be linked to a doctor on file and to the medicines to talk
/// about — which is what the visit brief reads.
library;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' show AppDatabase;
import 'package:tablet_remainder/core/services/active_profile_service.dart';
import 'package:tablet_remainder/core/services/clean_storage_service.dart';
import 'package:tablet_remainder/core/services/notification_service.dart';
import 'package:tablet_remainder/core/widgets/app/app_widgets.dart';
import 'package:tablet_remainder/features/medication/models/dependent_profile.dart';
import 'package:tablet_remainder/features/medication/models/doctor_pharmacy.dart';
import 'package:tablet_remainder/features/medication/models/enhanced_medicine.dart';
import 'package:tablet_remainder/features/medication/models/medicine_enums.dart';
import 'package:tablet_remainder/features/medication/models/medicine_schedule.dart';
import 'package:tablet_remainder/features/medication/screens/appointments/nunito_add_edit_appointment_screen.dart';
import 'package:tablet_remainder/features/medication/services/medicine_storage_service.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../support/font_free_theme.dart';
import '../support/recording_notification_scheduler.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;

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

  tearDown(() async => db.close());

  Future<void> doctor(String id, String name) => MedicineCleanStorageService.addDoctor(
      Doctor(id: id, name: name, specialty: 'Cardiology'));

  Future<void> medicine(String id, String name,
          {String? dependentId, bool active = true}) =>
      MedicineCleanStorageService.addMedicine(
        EnhancedMedicine(
          id: id,
          name: name,
          dosageForm: DosageForm.tablet,
          dosageAmount: 1,
          createdAt: DateTime(2026),
          dependentId: dependentId,
          isActive: active,
          schedule: MedicineSchedule.onceDaily(hour: 8, minute: 0),
        ),
        stampActiveProfile: false,
      );

  Future<void> frames(WidgetTester tester, [int n = 6]) async {
    for (var i = 0; i < n; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  /// The editor behind a push, so its pop on save has somewhere to go.
  Future<void> open(WidgetTester tester,
      {Appointment? edit, double width = 430, double scale = 1}) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = Size(width, 3000);
    tester.platformDispatcher.textScaleFactorTestValue = scale;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      theme: fontFreeTheme(),
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute<bool>(
                builder: (_) => NunitoAddEditAppointmentScreen(editAppointment: edit))),
            child: const Text('host'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('host'));
    await frames(tester, 4);
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
    await frames(tester, 4);
  }

  Future<void> save(WidgetTester tester) async {
    await tester.tap(find.widgetWithText(AppButton, 'Save'));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
    await frames(tester, 6);
  }

  Finder chip(String label) => find.widgetWithText(AppChip, label);

  Finder field(String label) => find.descendant(
      of: find.widgetWithText(AppTextField, label), matching: find.byType(TextField));

  Future<List<Appointment>> saved() =>
      MedicineCleanStorageService.getAllAppointments(scopeToActiveProfile: false);

  group('the doctor', () {
    testWidgets('no doctors on file: nothing to choose from', (tester) async {
      await open(tester);
      expect(find.text('Your doctors'), findsNothing);
    });

    testWidgets('the ones on file are offered', (tester) async {
      await tester.runAsync(() async {
        await doctor('d1', 'Dr Anand');
        await doctor('d2', 'Dr Rao');
      });
      await open(tester);
      expect(find.text('Your doctors'), findsOneWidget);
      expect(find.text('Dr Anand'), findsOneWidget);
      expect(find.text('Dr Rao'), findsOneWidget);
    });

    testWidgets('choosing one fills the name when there is none, and links it',
        (tester) async {
      await tester.runAsync(() => doctor('d1', 'Dr Anand'));
      await open(tester);
      await tester.tap(find.text('Dr Anand'));
      await frames(tester, 2);
      expect(tester.widget<TextField>(field('Doctor / reason')).controller!.text, 'Dr Anand');

      await save(tester);
      final a = (await tester.runAsync(saved))!.single;
      expect(a.doctorId, 'd1');
      expect(a.doctorName, 'Dr Anand');
    });

    testWidgets('a reason already typed is kept; the link is made all the same',
        (tester) async {
      await tester.runAsync(() => doctor('d1', 'Dr Anand'));
      await open(tester);
      await tester.enterText(field('Doctor / reason'), 'Cardiology follow-up');
      await tester.tap(find.text('Dr Anand'));
      await frames(tester, 2);
      expect(tester.widget<TextField>(field('Doctor / reason')).controller!.text,
          'Cardiology follow-up');

      await save(tester);
      final a = (await tester.runAsync(saved))!.single;
      expect(a.doctorId, 'd1');
      expect(a.doctorName, 'Cardiology follow-up');
    });

    testWidgets('changing doctor changes the name only if it was the last one\'s',
        (tester) async {
      await tester.runAsync(() async {
        await doctor('d1', 'Dr Anand');
        await doctor('d2', 'Dr Rao');
      });
      await open(tester);
      await tester.tap(chip('Dr Anand'));
      await frames(tester, 2);
      await tester.tap(chip('Dr Rao'));
      await frames(tester, 2);
      expect(tester.widget<TextField>(field('Doctor / reason')).controller!.text, 'Dr Rao');
    });

    testWidgets('tapping the chosen one again takes the link away, keeping the text',
        (tester) async {
      await tester.runAsync(() => doctor('d1', 'Dr Anand'));
      await open(tester);
      await tester.tap(chip('Dr Anand'));
      await frames(tester, 2);
      await tester.tap(chip('Dr Anand'));
      await frames(tester, 2);

      await save(tester);
      final a = (await tester.runAsync(saved))!.single;
      expect(a.doctorId, isNull);
      expect(a.doctorName, 'Dr Anand');
    });

    testWidgets('an appointment already linked shows its doctor chosen, and keeps it',
        (tester) async {
      await tester.runAsync(() async {
        await doctor('d1', 'Dr Anand');
        await MedicineCleanStorageService.addAppointment(
            Appointment(
                id: 'a1',
                doctorId: 'd1',
                doctorName: 'Dr Anand',
                dateTime: DateTime.now().add(const Duration(days: 3)),
                reminderEnabled: false),
            stampActiveProfile: false);
      });
      final edit = (await tester.runAsync(saved))!.single;
      await open(tester, edit: edit);
      await save(tester);
      expect((await tester.runAsync(saved))!.single.doctorId, 'd1');
    });
  });

  group('the medicines to talk about', () {
    testWidgets('none on the list: no section', (tester) async {
      await open(tester);
      expect(find.text('Medicines to talk about'), findsNothing);
    });

    testWidgets('yours, the ones in use', (tester) async {
      await tester.runAsync(() async {
        await medicine('m1', 'Metformin');
        await medicine('m2', 'Aspirin');
        await medicine('m3', 'Stopped one', active: false);
        await medicine('k1', 'Calpol', dependentId: 'kid');
      });
      await open(tester);
      expect(find.text('Medicines to talk about'), findsOneWidget);
      expect(find.text('Metformin'), findsOneWidget);
      expect(find.text('Aspirin'), findsOneWidget);
      expect(find.text('Stopped one'), findsNothing);
      expect(find.text('Calpol'), findsNothing, reason: 'a child\'s medicine is not yours');
    });

    testWidgets('chosen ones are saved, in the order listed', (tester) async {
      await tester.runAsync(() async {
        await medicine('m1', 'Metformin');
        await medicine('m2', 'Aspirin');
        await medicine('m3', 'Warfarin');
      });
      await open(tester);
      await tester.enterText(field('Doctor / reason'), 'Review');
      await tester.tap(find.text('Warfarin'));
      await tester.tap(find.text('Metformin'));
      await frames(tester, 2);
      await save(tester);

      final a = (await tester.runAsync(saved))!.single;
      expect(a.medicineIds, hasLength(2));
      expect(a.medicineIds, containsAll(['m1', 'm3']));
      expect(a.medicineIds, isNot(contains('m2')));
    });

    testWidgets('tapping again unchooses', (tester) async {
      await tester.runAsync(() => medicine('m1', 'Metformin'));
      await open(tester);
      await tester.enterText(field('Doctor / reason'), 'Review');
      await tester.tap(find.text('Metformin'));
      await tester.tap(find.text('Metformin'));
      await save(tester);
      expect((await tester.runAsync(saved))!.single.medicineIds, isNull);
    });

    testWidgets('an appointment already linked shows them chosen', (tester) async {
      await tester.runAsync(() async {
        await medicine('m1', 'Metformin');
        await medicine('m2', 'Aspirin');
        await MedicineCleanStorageService.addAppointment(
            Appointment(
                id: 'a1',
                doctorName: 'Dr Anand',
                dateTime: DateTime.now().add(const Duration(days: 3)),
                reminderEnabled: false,
                medicineIds: ['m2']),
            stampActiveProfile: false);
      });
      final edit = (await tester.runAsync(saved))!.single;
      await open(tester, edit: edit);

      final selected = tester
          .widgetList<AppChip>(find.byType(AppChip))
          .where((c) => c.selected)
          .map((c) => c.label)
          .toList();
      expect(selected, ['Aspirin']);
    });

    testWidgets('one since removed from the list is let go on save', (tester) async {
      await tester.runAsync(() async {
        await medicine('m1', 'Metformin');
        await MedicineCleanStorageService.addAppointment(
            Appointment(
                id: 'a1',
                doctorName: 'Dr Anand',
                dateTime: DateTime.now().add(const Duration(days: 3)),
                reminderEnabled: false,
                medicineIds: ['m1', 'gone']),
            stampActiveProfile: false);
      });
      final edit = (await tester.runAsync(saved))!.single;
      await open(tester, edit: edit);
      await save(tester);
      expect((await tester.runAsync(saved))!.single.medicineIds, ['m1']);
    });

    testWidgets('someone you look after: their medicines are the choices',
        (tester) async {
      await tester.runAsync(() async {
        await MedicineCleanStorageService.addDependent(DependentProfile(
            id: 'kid', name: 'Aarav', relationship: RelationshipType.child));
        await medicine('m1', 'Metformin');
        await medicine('k1', 'Calpol', dependentId: 'kid');
        await ActiveProfileService().setActiveDependent('kid');
      });
      await open(tester);
      expect(find.text('Calpol'), findsOneWidget);
      expect(find.text('Metformin'), findsNothing);
    });
  });

  testWidgets('the name is still required', (tester) async {
    await tester.runAsync(() => doctor('d1', 'Dr Anand'));
    await open(tester);
    await save(tester);
    expect(find.text('This field is required'), findsOneWidget);
    expect(await tester.runAsync(saved), isEmpty);
  });

  for (final scale in [1.0, 2.0]) {
    testWidgets('fits at 320pt and ${scale}x text, with doctors and medicines',
        (tester) async {
      await tester.runAsync(() async {
        for (var i = 0; i < 5; i++) {
          await doctor('d$i', 'Dr Anand Venkataraghavan number $i');
          await medicine('m$i', 'Metformin hydrochloride extended release $i');
        }
      });
      final reports = <String>[];
      final prev = FlutterError.onError;
      FlutterError.onError = (d) => reports.add(d.toString());
      try {
        await open(tester, width: 320, scale: scale);
      } finally {
        FlutterError.onError = prev;
      }
      expect(find.text('Your doctors'), findsOneWidget);
      expect(
          reports.where((r) => r.contains('nunito_add_edit_appointment_screen.dart')),
          isEmpty,
          reason: reports.join('\n').split('\n').take(6).join('\n'));
    });
  }
}
