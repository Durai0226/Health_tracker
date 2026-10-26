import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' show AppDatabase;
import 'package:tablet_remainder/core/health/measurement_plan.dart';
import 'package:tablet_remainder/core/services/clean_storage_service.dart';
import 'package:tablet_remainder/core/services/notification_service.dart';
import 'package:tablet_remainder/features/medication/models/enhanced_medicine.dart';
import 'package:tablet_remainder/features/medication/models/medicine_enums.dart';
import 'package:tablet_remainder/features/medication/models/medicine_schedule.dart';
import 'package:tablet_remainder/features/medication/services/measurement_plan_service.dart';
import 'package:tablet_remainder/features/medication/services/vitals_reminder_service.dart';
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

  late RecordingNotificationScheduler scheduler;

  setUpAll(() {
    tz_data.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('America/New_York'));
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    AppDatabase.setInstanceForTesting(db);
    addTearDown(() async => db.close());
    CleanStorageService.resetForTesting();
    await CleanStorageService.init();
    scheduler = RecordingNotificationScheduler();
    NotificationService().schedulerForTesting = scheduler;
  });

  test('a new blood-pressure pill is offered the BP routine', () async {
    final offers = await MeasurementPlanService.offerFor(_med('Amlodipine'));
    expect(offers.map((o) => o.kind), [MeasurementKind.bloodPressure]);
  });

  test('a medicine with no matching reading is offered nothing', () async {
    expect(await MeasurementPlanService.offerFor(_med('Paracetamol')), isEmpty);
  });

  test('offering turns nothing on', () async {
    await MeasurementPlanService.offerFor(_med('Metformin'));
    for (final spec in VitalsReminderService.all) {
      expect(VitalsReminderService.isEnabled(spec), isFalse, reason: spec.prefKey);
    }
    expect(scheduler.scheduled, isEmpty);
  });

  test('accepting BP arms BOTH slots at the routine times', () async {
    final offer = (await MeasurementPlanService.offerFor(_med('Amlodipine'))).single;
    await MeasurementPlanService.accept(offer);

    expect(VitalsReminderService.isEnabled(VitalsReminderService.bp), isTrue);
    expect(
        VitalsReminderService.isEnabled(VitalsReminderService.bpEvening), isTrue);
    expect(VitalsReminderService.timeOf(VitalsReminderService.bp).hour, 8);
    expect(VitalsReminderService.timeOf(VitalsReminderService.bpEvening).hour, 19);
    expect(MeasurementPlanService.isOn(MeasurementKind.bloodPressure), isTrue);
    // And it reached the scheduler, not just the prefs — a toggle that reads
    // "On" with nothing armed is the failure this suite exists for.
    expect(scheduler.armedIds,
        containsAll([VitalsReminderService.bp.id, VitalsReminderService.bpEvening.id]));
  });

  test('once on, the same reading is not offered for the next pill', () async {
    final offer = (await MeasurementPlanService.offerFor(_med('Amlodipine'))).single;
    await MeasurementPlanService.accept(offer);
    expect(await MeasurementPlanService.offerFor(_med('Losartan')), isEmpty);
  });

  test('a reminder the user already runs themselves counts as set up', () async {
    await VitalsReminderService.apply(VitalsReminderService.bp,
        enabled: true, hour: 6, minute: 15);
    expect(await MeasurementPlanService.offerFor(_med('Amlodipine')), isEmpty);
    expect(VitalsReminderService.timeOf(VitalsReminderService.bp).hour, 6,
        reason: 'their own time must not be overwritten');
  });

  test('declining is remembered and survives re-reading the prefs', () async {
    await MeasurementPlanService.decline([MeasurementKind.bloodGlucose]);
    expect(MeasurementPlanService.declined(), {MeasurementKind.bloodGlucose});
    expect(await MeasurementPlanService.offerFor(_med('Metformin')), isEmpty);
    // Other readings are unaffected.
    expect(await MeasurementPlanService.offerFor(_med('Amlodipine')),
        isNotEmpty);
  });

  test('declining twice keeps the earlier answer', () async {
    await MeasurementPlanService.decline([MeasurementKind.bloodGlucose]);
    await MeasurementPlanService.decline([MeasurementKind.weight]);
    expect(MeasurementPlanService.declined(),
        {MeasurementKind.bloodGlucose, MeasurementKind.weight});
  });

  test('every reading maps to at least as many specs as it has slots', () {
    for (final k in MeasurementKind.values) {
      final slots = MeasurementPlan.suggestionFor(k, 'X').slots.length;
      expect(MeasurementPlanService.specsFor(k).length, greaterThanOrEqualTo(slots),
          reason: k.name);
    }
  });
}
