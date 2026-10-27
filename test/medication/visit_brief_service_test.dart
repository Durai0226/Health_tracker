/// The visit brief, from what the app really holds.
library;

import 'package:clock/clock.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' show AppDatabase;
import 'package:tablet_remainder/core/health/vitals_analyzer.dart' show GlucoseContext;
import 'package:tablet_remainder/core/services/active_profile_service.dart';
import 'package:tablet_remainder/core/services/clean_storage_service.dart';
import 'package:tablet_remainder/core/services/notification_service.dart';
import 'package:tablet_remainder/features/medication/models/blood_pressure_reading.dart';
import 'package:tablet_remainder/features/medication/models/dependent_profile.dart';
import 'package:tablet_remainder/features/medication/models/doctor_pharmacy.dart';
import 'package:tablet_remainder/features/medication/models/enhanced_medicine.dart';
import 'package:tablet_remainder/features/medication/models/glucose_reading.dart';
import 'package:tablet_remainder/features/medication/models/medicine_enums.dart';
import 'package:tablet_remainder/features/medication/models/medicine_log.dart';
import 'package:tablet_remainder/features/medication/models/medicine_schedule.dart';
import 'package:tablet_remainder/features/medication/models/weight_reading.dart';
import 'package:tablet_remainder/features/medication/services/adherence_report_service.dart';
import 'package:tablet_remainder/features/medication/services/medicine_storage_service.dart';
import 'package:tablet_remainder/features/medication/services/visit_brief_service.dart';
import 'package:tablet_remainder/features/medication/services/vitals_storage_service.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../support/recording_notification_scheduler.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  final now = DateTime(2026, 6, 20, 15, 30);
  final visitAt = DateTime(2026, 6, 25, 10, 30);

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

  Appointment appt(String id, DateTime at,
          {String doctor = 'Dr Anand',
          String? doctorId,
          bool done = false,
          String? dependentId,
          String? purpose,
          String? notes,
          List<String>? medicineIds}) =>
      Appointment(
        id: id,
        doctorId: doctorId,
        doctorName: doctor,
        dateTime: at,
        isCompleted: done,
        dependentId: dependentId,
        purpose: purpose,
        notes: notes,
        medicineIds: medicineIds,
        reminderEnabled: false,
      );

  Future<void> save(Appointment a) =>
      MedicineCleanStorageService.addAppointment(a, stampActiveProfile: false);

  Future<EnhancedMedicine> medicine(String id, String name,
      {String? dependentId,
      bool active = true,
      bool archived = false,
      DateTime? createdAt,
      DateTime? updatedAt}) async {
    final m = EnhancedMedicine(
      id: id,
      name: name,
      dosageForm: DosageForm.tablet,
      dosageAmount: 1,
      createdAt: createdAt ?? DateTime(2026, 1, 1),
      updatedAt: updatedAt,
      dependentId: dependentId,
      isActive: active,
      isArchived: archived,
      // A schedule starts the day it is made (by the real clock): these began
      // in January.
      schedule: MedicineSchedule.onceDaily(
          hour: 8, minute: 0, startDate: DateTime(2026, 1, 1)),
    );
    await MedicineCleanStorageService.addMedicine(m, stampActiveProfile: false);
    return m;
  }

  DateTime slot(int month, int day) => DateTime(2026, month, day, 8);

  Future<void> taken(String med, DateTime at) => MedicineCleanStorageService.addLog(
      MedicineLog.taken(
          id: MedicineCleanStorageService.doseLogId(med, at),
          medicineId: med,
          scheduledTime: at,
          actionTime: at));

  Future<void> missed(String med, DateTime at) => MedicineCleanStorageService.addLog(
      MedicineLog.missed(
          id: MedicineCleanStorageService.doseLogId(med, at),
          medicineId: med,
          scheduledTime: at));

  Future<VisitBrief> brief(Appointment a) =>
      withClock(Clock.fixed(now), () => VisitBriefService.build(a, now: now));

  group('the window', () {
    test('with no earlier visit: the last thirty days', () async {
      final a = appt('v', visitAt);
      await save(a);
      final b = await brief(a);
      expect(b.window.sinceVisit, isNull);
      expect(b.window.days, 30);
    });

    test('since the last visit with the same doctor', () async {
      final a = appt('v', visitAt);
      await save(a);
      await save(appt('old', DateTime(2026, 5, 4, 14), done: true));
      final b = await brief(a);
      expect(b.window.sinceVisit, DateTime(2026, 5, 4, 14));
      expect(b.window.from, DateTime(2026, 5, 4));
    });

    test('a visit not marked done still happened, if its day has passed', () async {
      final a = appt('v', visitAt);
      await save(a);
      await save(appt('old', DateTime(2026, 5, 4, 14)));
      expect((await brief(a)).window.sinceVisit, DateTime(2026, 5, 4, 14));
    });

    test('a visit still to come is not an earlier visit', () async {
      final a = appt('v', visitAt);
      await save(a);
      await save(appt('later', DateTime(2026, 6, 22, 9)));
      expect((await brief(a)).window.sinceVisit, isNull);
    });

    test('another doctor\'s visit is not this doctor\'s', () async {
      final a = appt('v', visitAt);
      await save(a);
      await save(appt('gp', DateTime(2026, 5, 4, 14), doctor: 'Dr Rao', done: true));
      expect((await brief(a)).window.sinceVisit, isNull);
    });

    test('the same doctor by id, whatever the name says', () async {
      final a = appt('v', visitAt, doctor: 'Dr Anand', doctorId: 'doc-1');
      await save(a);
      await save(appt('old', DateTime(2026, 5, 4, 14),
          doctor: 'Dr. R. Anand (clinic)', doctorId: 'doc-1', done: true));
      expect((await brief(a)).window.sinceVisit, isNotNull);
    });

    test('and different ids are different doctors even with the same name',
        () async {
      final a = appt('v', visitAt, doctorId: 'doc-1');
      await save(a);
      await save(appt('old', DateTime(2026, 5, 4, 14), doctorId: 'doc-2', done: true));
      expect((await brief(a)).window.sinceVisit, isNull);
    });

    test('the name is compared without case or stray spaces', () async {
      final a = appt('v', visitAt, doctor: 'dr anand ');
      await save(a);
      await save(appt('old', DateTime(2026, 5, 4, 14), doctor: 'Dr Anand', done: true));
      expect((await brief(a)).window.sinceVisit, isNotNull);
    });

    test('a visit of someone else\'s is not yours', () async {
      await MedicineCleanStorageService.addDependent(DependentProfile(
          id: 'kid', name: 'Aarav', relationship: RelationshipType.child));
      final a = appt('v', visitAt);
      await save(a);
      await save(appt('kid-visit', DateTime(2026, 5, 4, 14), dependentId: 'kid', done: true));
      expect((await brief(a)).window.sinceVisit, isNull);
    });
  });

  group('the doses', () {
    test('how many came due, were taken and were missed since the last visit',
        () async {
      final a = appt('v', visitAt);
      await save(a);
      await save(appt('old', DateTime(2026, 5, 4, 14), done: true));
      await medicine('m1', 'Metformin');
      // May 4 to June 20: 48 mornings at 08:00.
      final days = <DateTime>[
        for (var d = 4; d <= 31; d++) slot(5, d),
        for (var d = 1; d <= 20; d++) slot(6, d),
      ];
      expect(days, hasLength(48));
      for (var i = 0; i < days.length; i++) {
        if (i < 40) {
          await taken('m1', days[i]);
        } else if (i < 45) {
          await missed('m1', days[i]);
        } else if (i == 45) {
          await MedicineCleanStorageService.addLog(MedicineLog.skipped(
              id: MedicineCleanStorageService.doseLogId('m1', days[i]),
              medicineId: 'm1',
              scheduledTime: days[i],
              reason: SkipReason.other));
        } // the last two have no log at all
      }
      final b = await brief(a);
      expect(b.due, 48, reason: 'what came due, not the rows there are');
      expect(b.taken, 40);
      expect(b.missed, 5);
      expect(b.skipped, 1);
      expect(b.overallPercent, 83);
    });

    test('doses before the window are not in it', () async {
      final a = appt('v', visitAt);
      await save(a);
      await save(appt('old', DateTime(2026, 5, 4, 14), done: true));
      await medicine('m1', 'Metformin');
      await missed('m1', slot(5, 3));
      await missed('m1', slot(4, 20));
      expect((await brief(a)).missed, 0);
    });

    test('the one that went least well comes first', () async {
      final a = appt('v', visitAt);
      await save(a);
      await medicine('good', 'Aspirin');
      await medicine('poor', 'Metformin');
      for (var d = 1; d <= 20; d++) {
        await taken('good', slot(6, d));
        if (d <= 10) {
          await taken('poor', slot(6, d));
        } else {
          await missed('poor', slot(6, d));
        }
      }
      final b = await brief(a);
      expect(b.medicines.map((m) => m.medicine.name), ['Metformin', 'Aspirin']);
      expect(b.medicines.first.percent, lessThan(b.medicines.last.percent!));
    });

    test('a stopped medicine is not on the list of what is taken', () async {
      final a = appt('v', visitAt);
      await save(a);
      await medicine('m1', 'Metformin');
      await medicine('m2', 'Old thing', active: false);
      expect((await brief(a)).medicines.map((m) => m.medicine.name), ['Metformin']);
    });

    test('with nothing due there is no percentage to quote', () async {
      final a = appt('v', visitAt);
      await save(a);
      final b = await brief(a);
      expect(b.due, 0);
      expect(b.overallPercent, isNull);
      expect(b.medicines, isEmpty);
    });
  });

  group('what was measured', () {
    test('blood pressure: sessions, not single readings', () async {
      final a = appt('v', visitAt);
      await save(a);
      Future<void> bp(String id, DateTime at, int s, int d) =>
          VitalsStorageService.saveBp(
              BloodPressureReading(
                  id: id, systolic: s, diastolic: d, takenAt: at, createdAt: at),
              stampActiveProfile: false,
              syncToHealthConnect: false);
      // Two readings a minute apart are one measurement: 130/80 and 126/78.
      await bp('a1', DateTime(2026, 6, 10, 8, 0), 130, 80);
      await bp('a2', DateTime(2026, 6, 10, 8, 1), 126, 78);
      await bp('b', DateTime(2026, 6, 12, 8, 0), 140, 90);
      await bp('c', DateTime(2026, 6, 14, 8, 0), 118, 70);

      final s = (await brief(a)).bp!;
      expect(s.readings, 4);
      expect(s.sessions, 3);
      expect(s.avgSystolic, 129, reason: '(128 + 140 + 118) / 3');
      expect(s.avgDiastolic, 80, reason: '(79 + 90 + 70) / 3');
      expect(s.minSystolic, 118);
      expect(s.maxSystolic, 140);
      expect(s.minDiastolic, 70);
      expect(s.maxDiastolic, 90);
    });

    test('readings outside the window are not in it', () async {
      final a = appt('v', visitAt);
      await save(a);
      await VitalsStorageService.saveBp(
          BloodPressureReading(
              id: 'old',
              systolic: 150,
              diastolic: 95,
              takenAt: DateTime(2026, 4, 1, 8),
              createdAt: DateTime(2026, 4, 1, 8)),
          stampActiveProfile: false,
          syncToHealthConnect: false);
      expect((await brief(a)).bp, isNull);
    });

    test('blood sugar: the average, the range and the share in target', () async {
      final a = appt('v', visitAt);
      await save(a);
      Future<void> g(String id, int v, GlucoseContext c) => VitalsStorageService.saveGlucose(
          GlucoseReading(
              id: id,
              valueMgdl: v,
              context: c,
              takenAt: DateTime(2026, 6, 12, 8),
              createdAt: DateTime(2026, 6, 12, 8)),
          stampActiveProfile: false,
          syncToHealthConnect: false);
      await g('1', 95, GlucoseContext.fasting);
      await g('2', 110, GlucoseContext.fasting);
      await g('3', 200, GlucoseContext.afterMeal);
      await g('4', 130, GlucoseContext.fasting);
      final s = (await brief(a)).glucose!;
      expect(s.readings, 4);
      expect(s.avgMgdl, 134);
      expect(s.minMgdl, 95);
      expect(s.maxMgdl, 200);
      expect(s.inRangePercent, isNotNull);
      expect(s.inRangePercent, inInclusiveRange(0, 100));
    });

    test('weight: first to last in the window', () async {
      final a = appt('v', visitAt);
      await save(a);
      Future<void> w(String id, DateTime at, double kg) => VitalsStorageService.saveWeight(
          WeightReading(id: id, valueKg: kg, takenAt: at, createdAt: at),
          stampActiveProfile: false,
          syncToHealthConnect: false);
      await w('2', DateTime(2026, 6, 15, 7), 70.2);
      await w('1', DateTime(2026, 6, 2, 7), 71.4);
      final s = (await brief(a)).weight!;
      expect(s.firstKg, 71.4);
      expect(s.lastKg, 70.2);
      expect(s.changeKg, closeTo(-1.2, 1e-9));
      expect(s.readings, 2);
    });

    test('none logged: nothing to say, and hasVitals knows', () async {
      final a = appt('v', visitAt);
      await save(a);
      final b = await brief(a);
      expect(b.bp, isNull);
      expect(b.glucose, isNull);
      expect(b.weight, isNull);
      expect(b.hasVitals, isFalse);
    });
  });

  group('what changed on the list', () {
    test('started and stopped within the window', () async {
      final a = appt('v', visitAt);
      await save(a);
      await medicine('new', 'Amlodipine', createdAt: DateTime(2026, 6, 5));
      await medicine('old', 'Metformin', createdAt: DateTime(2025, 1, 1));
      await medicine('gone', 'Ibuprofen',
          createdAt: DateTime(2025, 3, 1),
          active: false,
          updatedAt: DateTime(2026, 6, 9));
      await medicine('long-gone', 'Lisinopril',
          createdAt: DateTime(2025, 3, 1),
          active: false,
          updatedAt: DateTime(2026, 1, 9));
      final b = await brief(a);
      expect(b.started.map((m) => m.name), ['Amlodipine']);
      expect(b.stopped.map((m) => m.name), ['Ibuprofen']);
    });

    test('shelved counts as stopped, and one still in use does not', () async {
      final a = appt('v', visitAt);
      await save(a);
      await medicine('shelved', 'Shelved',
          createdAt: DateTime(2025, 3, 1), archived: true, updatedAt: DateTime(2026, 6, 9));
      await medicine('live', 'Still taken',
          createdAt: DateTime(2025, 3, 1), updatedAt: DateTime(2026, 6, 9));
      final b = await brief(a);
      expect(b.stopped.map((m) => m.name), ['Shelved']);
    });

    test('what happened after the window is not in it', () async {
      final a = appt('v', visitAt);
      await save(a);
      await medicine('later', 'Later one', createdAt: DateTime(2026, 7, 1));
      await medicine('shelved-later', 'Shelved later',
          createdAt: DateTime(2025, 3, 1), active: false, updatedAt: DateTime(2026, 7, 1));
      final b = await brief(a);
      expect(b.started, isEmpty);
      expect(b.stopped, isEmpty);
    });
  });

  group('what to discuss', () {
    test('the purpose, the notes and the medicines linked to the visit', () async {
      await medicine('m1', 'Metformin');
      await medicine('m2', 'Aspirin');
      final a = appt('v', visitAt,
          purpose: 'Six-month review',
          notes: ' Ask about the dizziness ',
          medicineIds: ['m1', 'missing', 'm2']);
      await save(a);
      expect((await brief(a)).discuss, [
        'Six-month review',
        'Ask about the dizziness',
        'Medicines to talk about: Metformin, Aspirin',
      ]);
    });

    test('blank ones are left out', () async {
      final a = appt('v', visitAt, purpose: '  ', notes: '');
      await save(a);
      expect((await brief(a)).discuss, isEmpty);
    });
  });

  group('someone you look after', () {
    test('their medicines, their readings, their name', () async {
      await MedicineCleanStorageService.addDependent(DependentProfile(
          id: 'kid', name: 'Aarav', relationship: RelationshipType.child));
      await medicine('mine', 'Metformin');
      await medicine('kids', 'Calpol', dependentId: 'kid');
      for (var d = 1; d <= 20; d++) {
        await taken('mine', slot(6, d));
      }
      final at = DateTime(2026, 6, 10, 7);
      await VitalsStorageService.saveWeight(
          WeightReading(id: 'mine-w', valueKg: 70, takenAt: at, createdAt: at),
          stampActiveProfile: false,
          syncToHealthConnect: false);
      await VitalsStorageService.saveBp(
          BloodPressureReading(
              id: 'mine-bp', systolic: 120, diastolic: 80, takenAt: at, createdAt: at),
          stampActiveProfile: false,
          syncToHealthConnect: false);
      await VitalsStorageService.saveGlucose(
          GlucoseReading(id: 'mine-g', valueMgdl: 100, takenAt: at, createdAt: at),
          stampActiveProfile: false,
          syncToHealthConnect: false);
      final a = appt('v', visitAt, doctor: 'Dr Paediatrics', dependentId: 'kid');
      await save(a);

      var b = await brief(a);
      expect(b.patientName, 'Aarav');
      expect(b.medicines.map((m) => m.medicine.name), ['Calpol']);
      expect(b.weight, isNull, reason: 'the weight on file is yours');
      expect(b.bp, isNull, reason: 'the blood pressure on file is yours');
      expect(b.glucose, isNull, reason: 'the blood sugar on file is yours');
      expect(b.taken, 0, reason: 'the doses logged are yours');

      // Theirs, once there are some.
      await VitalsStorageService.saveWeight(
          WeightReading(
              id: 'kid-w', dependentId: 'kid', valueKg: 22, takenAt: at, createdAt: at),
          stampActiveProfile: false,
          syncToHealthConnect: false);
      await VitalsStorageService.saveBp(
          BloodPressureReading(
              id: 'kid-bp',
              dependentId: 'kid',
              systolic: 100,
              diastolic: 60,
              takenAt: at,
              createdAt: at),
          stampActiveProfile: false,
          syncToHealthConnect: false);
      await VitalsStorageService.saveGlucose(
          GlucoseReading(
              id: 'kid-g', dependentId: 'kid', valueMgdl: 90, takenAt: at, createdAt: at),
          stampActiveProfile: false,
          syncToHealthConnect: false);
      b = await brief(a);
      expect(b.weight!.lastKg, 22);
      expect(b.bp!.avgSystolic, 100);
      expect(b.glucose!.avgMgdl, 90);
    });

    test('and for yourself, no name is printed', () async {
      final a = appt('v', visitAt);
      await save(a);
      expect((await brief(a)).patientName, isNull);
    });
  });

  test('a database that cannot be read still gives a brief', () async {
    final a = appt('v', visitAt, purpose: 'Review');
    await db.close();
    final b = await brief(a);
    expect(b.appointment.id, 'v');
    expect(b.window.days, 30);
    expect(b.medicines, isEmpty);
    expect(b.discuss, ['Review']);
  });

  group('MedicineAdherence.leastWellFirst', () {
    EnhancedMedicine med(String name) => EnhancedMedicine(
          id: name,
          name: name,
          dosageForm: DosageForm.tablet,
          dosageAmount: 1,
          createdAt: DateTime(2026),
          schedule: MedicineSchedule.onceDaily(hour: 8, minute: 0),
        );
    MedicineAdherence m(String name, {int due = 10, int taken = 10, int missed = 0}) =>
        MedicineAdherence(
            medicine: med(name),
            logs: const [],
            due: due,
            taken: taken,
            missed: missed,
            skipped: 0);

    test('lowest percent first, then most missed, then name', () {
      final list = [
        m('C', taken: 9, missed: 1),
        m('A', taken: 5, missed: 5),
        m('B', taken: 5, missed: 3),
        m('D', taken: 5, missed: 5),
        m('Z', due: 0, taken: 0),
        m('Y', due: 0, taken: 0),
      ]..sort(MedicineAdherence.leastWellFirst);
      expect(list.map((x) => x.medicine.name), ['A', 'D', 'B', 'C', 'Y', 'Z']);
    });
  });
}
