/// Removing a family member: their records either stay, under you, or go.
///
/// Until now removing a person quietly attached all their health records to the
/// account holder — and forgot their weight and mood, which kept the id of a
/// profile that no longer existed and showed under nobody.
library;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' show AppDatabase;
import 'package:tablet_remainder/core/services/active_profile_service.dart';
import 'package:tablet_remainder/core/services/notification_service.dart';
import 'package:tablet_remainder/features/medication/models/blood_pressure_reading.dart';
import 'package:tablet_remainder/features/medication/models/dependent_profile.dart';
import 'package:tablet_remainder/features/medication/models/doctor_pharmacy.dart';
import 'package:tablet_remainder/features/medication/models/enhanced_medicine.dart';
import 'package:tablet_remainder/features/medication/models/glucose_reading.dart';
import 'package:tablet_remainder/features/medication/models/medicine_enums.dart';
import 'package:tablet_remainder/features/medication/models/medicine_log.dart';
import 'package:tablet_remainder/features/medication/models/medicine_schedule.dart';
import 'package:tablet_remainder/features/medication/models/mood_entry.dart';
import 'package:tablet_remainder/features/medication/models/weight_reading.dart';
import 'package:tablet_remainder/features/medication/services/appointment_reminder_service.dart';
import 'package:tablet_remainder/features/medication/services/medicine_storage_service.dart';
import 'package:tablet_remainder/features/medication/services/vitals_storage_service.dart';
import 'package:tablet_remainder/features/medication/widgets/remove_person_sheet.dart';

import '../support/font_free_theme.dart';
import '../support/recording_notification_scheduler.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;
  late RecordingNotificationScheduler scheduler;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    AppDatabase.setInstanceForTesting(db);
    ActiveProfileService().resetForTesting();
    scheduler = RecordingNotificationScheduler();
    NotificationService().schedulerForTesting = scheduler;
    await ActiveProfileService().init();
    await MedicineCleanStorageService.addDependent(DependentProfile(
        id: 'dep-a', name: 'Maya', relationship: RelationshipType.child));
    await MedicineCleanStorageService.addDependent(DependentProfile(
        id: 'dep-b', name: 'Sam', relationship: RelationshipType.child));
  });

  tearDown(() async => db.close());

  final day = DateTime(2026, 6, 1, 9);

  EnhancedMedicine med(String id, {String? dependentId, bool archived = false}) =>
      EnhancedMedicine(
        id: id,
        name: 'Med $id',
        dosageForm: DosageForm.tablet,
        dosageAmount: 1,
        dependentId: dependentId,
        isArchived: archived,
        schedule: MedicineSchedule(
          frequencyType: FrequencyType.onceDaily,
          times: [ScheduledTime(hour: 8, minute: 0)],
        ),
      );

  /// One of everything, for [person] (null is the account holder).
  Future<void> fill(String? person, String tag) async {
    await MedicineCleanStorageService.addMedicine(med('med-$tag', dependentId: person));
    await MedicineCleanStorageService.addMedicine(
        med('old-$tag', dependentId: person, archived: true));
    await MedicineCleanStorageService.markMedicineTaken(
        medicineId: 'med-$tag', scheduledTime: day);
    await VitalsStorageService.saveBp(
        BloodPressureReading(
            id: 'bp-$tag',
            systolic: 120,
            diastolic: 80,
            takenAt: day,
            createdAt: day,
            dependentId: person),
        stampActiveProfile: false,
        syncToHealthConnect: false);
    await VitalsStorageService.saveGlucose(
        GlucoseReading(
            id: 'gl-$tag',
            valueMgdl: 100,
            takenAt: day,
            createdAt: day,
            dependentId: person),
        stampActiveProfile: false,
        syncToHealthConnect: false);
    await VitalsStorageService.saveWeight(
        WeightReading(
            id: 'wt-$tag',
            valueKg: 60,
            takenAt: day,
            createdAt: day,
            dependentId: person),
        stampActiveProfile: false,
        syncToHealthConnect: false);
    await VitalsStorageService.saveMood(
        MoodEntry(
            id: 'md-$tag',
            moodIndex: 1,
            takenAt: day,
            createdAt: day,
            dependentId: person),
        stampActiveProfile: false);
    await MedicineCleanStorageService.addAppointment(Appointment(
        id: 'ap-$tag',
        doctorName: 'Dr $tag',
        dateTime: DateTime.now().add(const Duration(days: 5)),
        dependentId: person));
  }

  Future<Set<String>> idsOf(String? person) async {
    // Unscoped: what the app holds, whoever is active.
    final meds = await MedicineCleanStorageService.getAllMedicines(
        includeArchived: true, scopeToActiveProfile: false);
    final logs = await MedicineCleanStorageService.getAllLogs(scopeToActiveProfile: false);
    return {
      for (final m in meds) if (m.dependentId == person) m.id,
      for (final l in logs) if (l.dependentId == person) 'log:${l.medicineId}',
      for (final r in await VitalsStorageService.getAllBp(scopeToActiveProfile: false))
        if (r.dependentId == person) r.id,
      for (final r in await VitalsStorageService.getAllGlucose(scopeToActiveProfile: false))
        if (r.dependentId == person) r.id,
      for (final r in await VitalsStorageService.getAllWeight(scopeToActiveProfile: false))
        if (r.dependentId == person) r.id,
      for (final r in await VitalsStorageService.getAllMood(scopeToActiveProfile: false))
        if (r.dependentId == person) r.id,
      for (final a in await MedicineCleanStorageService.getAllAppointments(
          scopeToActiveProfile: false))
        if (a.dependentId == person) a.id,
    };
  }

  Future<bool> profileExists(String id) async =>
      (await MedicineCleanStorageService.getAllDependents()).any((d) => d.id == id);

  group('keeping their records', () {
    test('their weight and mood come to you, like everything else', () async {
      await fill('dep-a', 'a');
      expect(await idsOf('dep-a'), containsAll(['wt-a', 'md-a']));

      await MedicineCleanStorageService.deleteDependent('dep-a');

      expect(await idsOf('dep-a'), isEmpty,
          reason: 'nothing is left attributed to a profile that no longer exists');
      expect(await idsOf(null),
          containsAll(['med-a', 'old-a', 'bp-a', 'gl-a', 'wt-a', 'md-a', 'ap-a', 'log:med-a']));
      expect(await profileExists('dep-a'), isFalse);
    });

    test('and they show under you, in the screens that read your own', () async {
      await fill('dep-a', 'a');
      await MedicineCleanStorageService.deleteDependent('dep-a');
      await ActiveProfileService().setActiveDependent(null);

      expect((await VitalsStorageService.getAllWeight()).map((r) => r.id), contains('wt-a'));
      expect((await VitalsStorageService.getAllMood()).map((r) => r.id), contains('md-a'));
    });

    test('someone else\'s records are not touched', () async {
      await fill('dep-a', 'a');
      await fill('dep-b', 'b');
      await MedicineCleanStorageService.deleteDependent('dep-a');
      expect(await idsOf('dep-b'),
          containsAll(['med-b', 'old-b', 'bp-b', 'gl-b', 'wt-b', 'md-b', 'ap-b']));
    });
  });

  group('deleting their records too', () {
    test('everything held for them is gone, archived medicines and all', () async {
      await fill('dep-a', 'a');

      await MedicineCleanStorageService.deleteRecordsOf('dep-a');
      await MedicineCleanStorageService.deleteDependent('dep-a');

      expect(await idsOf('dep-a'), isEmpty);
      expect(await idsOf(null), isEmpty,
          reason: 'and none of it was quietly handed to you instead');
      expect(await profileExists('dep-a'), isFalse);
    });

    test('yours, and everyone else\'s, are left exactly as they were', () async {
      await fill(null, 'me');
      await fill('dep-a', 'a');
      await fill('dep-b', 'b');
      final mine = await idsOf(null);
      final sams = await idsOf('dep-b');

      await MedicineCleanStorageService.deleteRecordsOf('dep-a');
      await MedicineCleanStorageService.deleteDependent('dep-a');

      expect(await idsOf(null), mine);
      expect(await idsOf('dep-b'), sams);
    });

    test('their medicines\' reminders are cancelled, so nothing rings for them',
        () async {
      // Only a medicine, so nothing else can be what cancelled.
      await MedicineCleanStorageService.addMedicine(med('med-a', dependentId: 'dep-a'));
      scheduler.cancelled.clear();

      await MedicineCleanStorageService.deleteRecordsOf('dep-a');

      expect(scheduler.cancelled, isNotEmpty,
          reason: 'a deleted medicine must not keep firing orphaned reminders');
    });

    test('and their appointments\' notices, the visit and its brief', () async {
      // Only an appointment, so the medicines\' cancels are not what is seen.
      await MedicineCleanStorageService.addAppointment(Appointment(
          id: 'ap-a',
          doctorName: 'Dr a',
          dateTime: DateTime.now().add(const Duration(days: 5)),
          dependentId: 'dep-a'));
      scheduler.cancelled.clear();

      await MedicineCleanStorageService.deleteRecordsOf('dep-a');

      expect(scheduler.cancelled,
          containsAll([
            AppointmentReminderService.notificationIdFor('ap-a'),
            AppointmentReminderService.briefNotificationIdFor('ap-a'),
          ]));
    });

    test('a log attributed to them for a medicine that is not theirs goes too',
        () async {
      // Someone else's medicine, with a dose logged against Maya (a row the
      // app's own paths do not write, but a restored backup can carry).
      await MedicineCleanStorageService.addMedicine(med('shared'));
      await MedicineCleanStorageService.addLog(MedicineLog(
          id: 'stray',
          medicineId: 'shared',
          scheduledTime: day,
          status: MedicineStatus.taken,
          dependentId: 'dep-a'));
      expect(await idsOf('dep-a'), contains('log:shared'), reason: 'the premise');

      await MedicineCleanStorageService.deleteRecordsOf('dep-a');

      expect(await idsOf('dep-a'), isEmpty);
      expect((await idsOf(null)), contains('shared'),
          reason: 'the medicine itself was never theirs');
    });

    test('a person with nothing recorded is simply removed', () async {
      await MedicineCleanStorageService.deleteRecordsOf('dep-a');
      await MedicineCleanStorageService.deleteDependent('dep-a');
      expect(await profileExists('dep-a'), isFalse);
      expect(await profileExists('dep-b'), isTrue);
    });
  });

  group('the sheet', () {
    Future<void> pump(WidgetTester tester, void Function(RemovePersonChoice) onChoose,
        {VoidCallback? onClose, double width = 400, double scale = 1}) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = Size(width, 1600);
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        theme: fontFreeTheme(),
        home: Scaffold(
          body: SingleChildScrollView(
            child: RemovePersonBody(
                name: 'Maya', onChoose: onChoose, onClose: onClose ?? () {}),
          ),
        ),
      ));
      await tester.pump();
    }

    testWidgets('offers both, in plain words, naming the person', (tester) async {
      await pump(tester, (_) {});
      expect(find.textContaining('What is recorded for Maya is yours to decide'), findsOneWidget);
      expect(find.text('Remove them, keep the records'), findsOneWidget);
      expect(find.text('Remove them and delete everything'), findsOneWidget);
      expect(find.textContaining('under you'), findsOneWidget);
      expect(find.textContaining('cannot be undone'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
    });

    testWidgets('keep is keep', (tester) async {
      RemovePersonChoice? got;
      await pump(tester, (c) => got = c);
      await tester.tap(find.text('Remove them, keep the records'));
      expect(got, RemovePersonChoice.keepRecords);
    });

    testWidgets('delete is delete', (tester) async {
      RemovePersonChoice? got;
      await pump(tester, (c) => got = c);
      await tester.tap(find.text('Remove them and delete everything'));
      expect(got, RemovePersonChoice.deleteRecords);
    });

    testWidgets('cancel chooses nothing', (tester) async {
      RemovePersonChoice? got;
      var closed = false;
      await pump(tester, (c) => got = c, onClose: () => closed = true);
      await tester.tap(find.text('Cancel'));
      expect(got, isNull);
      expect(closed, isTrue);
    });

    for (final (width, scale) in [(320.0, 1.0), (320.0, 2.0)]) {
      testWidgets('fits $width wide at ${scale}x text', (tester) async {
        final errors = <FlutterErrorDetails>[];
        final prev = FlutterError.onError;
        FlutterError.onError = errors.add;
        try {
          await pump(tester, (_) {}, width: width, scale: scale);
        } finally {
          FlutterError.onError = prev;
        }
        expect(errors.where((e) => '${e.exception}'.contains('overflowed')), isEmpty);
      });
    }
  });
}
