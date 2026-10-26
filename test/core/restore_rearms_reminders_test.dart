import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' show AppDatabase;
import 'package:tablet_remainder/core/services/active_profile_service.dart';
import 'package:tablet_remainder/core/services/clean_storage_service.dart';
import 'package:tablet_remainder/core/services/notification_service.dart';
import 'package:tablet_remainder/features/medication/services/vitals_reminder_service.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../support/recording_notification_scheduler.dart';

/// Restoring a backup on a new phone brought the reminders' settings back and
/// armed none of them: that waited for the next app start, so the first day
/// after a restore had no reminders at all.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;
  late RecordingNotificationScheduler scheduler;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    AppDatabase.setInstanceForTesting(db);
    ActiveProfileService().resetForTesting();
    CleanStorageService.resetForTesting();
    await CleanStorageService.init();
    tz_data.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('UTC'));
    scheduler = RecordingNotificationScheduler();
    NotificationService().schedulerForTesting = scheduler;
  });

  tearDown(() async => db.close());

  test('a restored reminder switch is armed straight away', () async {
    final bp = VitalsReminderService.all.first;
    expect(scheduler.armedIds, isEmpty);

    await CleanStorageService.restoreBackup({
      'preferences': {
        '${bp.prefKey}_on': true,
        '${bp.prefKey}_h': 9,
        '${bp.prefKey}_m': 30,
      },
    });

    expect(scheduler.armedIds, contains(bp.id),
        reason: 'the switch came back on; the alarm has to as well');
  });

  test('a restore that carries no reminders arms none', () async {
    await CleanStorageService.restoreBackup({'preferences': {'x': 1}});
    expect(
        scheduler.armedIds
            .where((id) => VitalsReminderService.all.any((s) => s.id == id)),
        isEmpty);
  });
}
