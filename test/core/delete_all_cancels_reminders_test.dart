import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' show AppDatabase;
import 'package:tablet_remainder/core/health/rest_days.dart';
import 'package:tablet_remainder/core/services/clean_storage_service.dart';
import 'package:tablet_remainder/core/services/emergency_contact.dart';
import 'package:tablet_remainder/core/services/notification_service.dart';
import 'package:tablet_remainder/core/services/rest_day_store.dart';
import 'package:tablet_remainder/features/medication/services/refill_loop.dart';
import 'package:tablet_remainder/features/medication/services/vitals_reminder_service.dart';
import 'package:tablet_remainder/features/medication/services/weight_goal.dart';
import 'package:tablet_remainder/features/steps/services/step_service.dart';
import 'package:tablet_remainder/features/water/models/water_reminder_config.dart';

import '../support/recording_notification_scheduler.dart';

/// "All data deleted." must not be followed by reminders for medicines that no
/// longer exist.
///
/// The wipe removed the rows and left everything already scheduled armed — and,
/// for the reminder families that are driven by a preference switch (vitals,
/// water, steps), left the switch on, so the next launch re-armed them too.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;
  late RecordingNotificationScheduler scheduler;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    AppDatabase.setInstanceForTesting(db);
    CleanStorageService.resetForTesting();
    await CleanStorageService.init();
    scheduler = RecordingNotificationScheduler();
    NotificationService().schedulerForTesting = scheduler;
  });

  tearDown(() async => db.close());

  test('everything already scheduled is cancelled', () async {
    expect(scheduler.cancelAllCount, 0);
    await CleanStorageService.clearAllPersistentData();
    expect(scheduler.cancelAllCount, 1);
  });

  test('reminder switches and personal settings do not survive the wipe',
      () async {
    for (final spec in VitalsReminderService.all) {
      await CleanStorageService.setAppPreference('${spec.prefKey}_on', true);
    }
    await StepService.setReminder(true, 19 * 60);
    await CleanStorageService.saveWaterReminderConfig(
        const WaterReminderConfig(enabled: true));
    await EmergencyContact.save(name: 'Priya', phone: '+91 98765 43210');
    await RestDayStore.markToday(RestKind.unwell);
    await WeightGoal.set(70);
    await RefillRequestState.set('m1', DateTime(2026, 3, 10));

    await CleanStorageService.clearAllPersistentData();

    for (final spec in VitalsReminderService.all) {
      expect(
          CleanStorageService.getAppPreference('${spec.prefKey}_on', false),
          isNot(true),
          reason: spec.prefKey);
    }
    expect(StepService.getReminderEnabled(), isFalse);
    expect(CleanStorageService.getWaterReminderConfig(), isNull);
    expect(EmergencyContact.isSet, isFalse,
        reason: 'a name and a phone number are personal data');
    expect(RestDayStore.kindToday(), isNull);
    expect(WeightGoal.get(), isNull);
    expect(RefillRequestState.requestedAt('m1'), isNull);
  });

  test('app appearance and other settings are left alone', () async {
    await CleanStorageService.setAppPreference('some_ui_setting', 'dark');
    await CleanStorageService.clearAllPersistentData();
    expect(CleanStorageService.getAppPreference('some_ui_setting', ''), 'dark');
  });
}
