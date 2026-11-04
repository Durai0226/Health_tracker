/// A medicine's chosen sound reaches an iPhone too.
///
/// The Android slot alarm carries it in its persisted entry; an iPhone arms one
/// notification per dose, whose payload is what the full-screen alarm a tap opens
/// is built from. The host these tests run on is not Android, so the service takes
/// the iPhone branch and the OS is a recording double.
library;

import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' as db;
import 'package:tablet_remainder/core/services/clean_storage_service.dart';
import 'package:tablet_remainder/core/services/notification_service.dart';
import 'package:tablet_remainder/features/medication/models/enhanced_medicine.dart';
import 'package:tablet_remainder/features/medication/models/medicine_enums.dart';
import 'package:tablet_remainder/features/medication/models/medicine_schedule.dart';
import 'package:tablet_remainder/features/medication/services/medication_reminder_service.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../support/recording_notification_scheduler.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tz_data.initializeTimeZones();

  final now = DateTime(2026, 10, 28, 10, 0);

  late RecordingNotificationScheduler os;
  late db.AppDatabase database;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    tz.setLocalLocation(tz.UTC);
    database = db.AppDatabase.forTesting(NativeDatabase.memory());
    db.AppDatabase.setInstanceForTesting(database);
    CleanStorageService.resetForTesting();
    await CleanStorageService.init();
    os = RecordingNotificationScheduler();
    NotificationService().schedulerForTesting = os;
  });

  tearDown(() async => database.close());

  EnhancedMedicine medicine({String? sound}) => EnhancedMedicine(
        id: 'm1',
        name: 'Metformin',
        dosageForm: DosageForm.tablet,
        dosageAmount: 1,
        schedule: MedicineSchedule(
            frequencyType: FrequencyType.onceDaily,
            times: [ScheduledTime(hour: 21, minute: 0)]),
        reminderSound: sound,
      );

  Future<Map<String, dynamic>> armedPayload(EnhancedMedicine m) async {
    await withClock(Clock.fixed(now),
        () => MedicationReminderService().scheduleReminders(m));
    final payload = os.scheduled.single.payload!;
    return jsonDecode(payload.substring('alarm:'.length)) as Map<String, dynamic>;
  }

  test('a chosen sound is in the payload the tap opens the alarm with', () async {
    final p = await armedPayload(medicine(sound: 'marimba'));

    expect(p['sound'], 'marimba');
    expect(p['medicineId'], 'm1');
  });

  test('no choice: the payload carries no sound at all', () async {
    final p = await armedPayload(medicine());

    expect(p.containsKey('sound'), isFalse);
  });

  test('a sound the app no longer has is not armed', () async {
    final p = await armedPayload(medicine(sound: 'removed_in_v9'));

    expect(p.containsKey('sound'), isFalse);
  });
}
