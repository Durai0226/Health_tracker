import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' show AppDatabase;
import 'package:tablet_remainder/core/services/active_profile_service.dart';
import 'package:tablet_remainder/core/services/clean_storage_service.dart';
import 'package:tablet_remainder/core/services/notification_service.dart';
import 'package:tablet_remainder/core/services/snooze_log.dart';
import 'package:tablet_remainder/features/reminders/models/reminder_model.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../support/recording_notification_scheduler.dart';

/// Every snooze is timestamped, so "snoozed 4 of your last 6" is knowable.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    tz_data.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('America/New_York'));
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  group('SnoozeLog', () {
    test('records and reads back, oldest first', () async {
      final prefs = await SharedPreferences.getInstance();
      await SnoozeLog.record(prefs, 7, DateTime(2026, 3, 2, 20));
      await SnoozeLog.record(prefs, 7, DateTime(2026, 3, 1, 20));
      final got = await SnoozeLog.read([7]);
      expect(got, [DateTime(2026, 3, 1, 20), DateTime(2026, 3, 2, 20)]);
    });

    test('keeps only the newest entries', () async {
      final prefs = await SharedPreferences.getInstance();
      for (var i = 0; i < SnoozeLog.maxKept + 10; i++) {
        await SnoozeLog.record(prefs, 7, DateTime(2026, 1, 1).add(Duration(days: i)));
      }
      final got = await SnoozeLog.read([7]);
      expect(got.length, SnoozeLog.maxKept);
      expect(got.first, DateTime(2026, 1, 1).add(const Duration(days: 10)),
          reason: 'the oldest ten were dropped');
    });

    test('merges every id given, as a weekday repeat needs', () async {
      final prefs = await SharedPreferences.getInstance();
      await SnoozeLog.record(prefs, 100, DateTime(2026, 3, 3));
      await SnoozeLog.record(prefs, 102, DateTime(2026, 3, 1));
      await SnoozeLog.record(prefs, 999, DateTime(2026, 3, 2)); // someone else
      expect(await SnoozeLog.read([100, 101, 102]),
          [DateTime(2026, 3, 1), DateTime(2026, 3, 3)]);
    });

    test('a reminder with no snoozes reads as empty', () async {
      expect(await SnoozeLog.read([42]), isEmpty);
    });

    test('garbage in the preference is skipped, not thrown', () async {
      SharedPreferences.setMockInitialValues({
        SnoozeLog.keyFor(5): ['not a date', '2026-03-01T20:00:00.000'],
      });
      expect(await SnoozeLog.read([5]), [DateTime(2026, 3, 1, 20)]);
    });
  });

  group('the real snooze path writes it', () {
    late AppDatabase db;
    late RecordingNotificationScheduler scheduler;

    setUp(() async {
      scheduler = RecordingNotificationScheduler();
      NotificationService().schedulerForTesting = scheduler;
      db = AppDatabase.forTesting(NativeDatabase.memory());
      AppDatabase.setInstanceForTesting(db);
      ActiveProfileService().resetForTesting();
      CleanStorageService.resetForTesting();
      await CleanStorageService.init();
    });

    tearDown(() async => db.close());

    test('NotificationService.snoozeReminder logs the snooze under its slot',
        () async {
      await CleanStorageService.saveReminder(Reminder(
        id: 'r-1',
        title: 'Stretch',
        body: '',
        scheduledTime: DateTime(2026, 3, 1, 20),
        repeatType: RepeatType.daily,
        notificationId: 4242,
      ));
      final before = DateTime.now();

      await NotificationService().snoozeReminder(4242, 10);

      final got = await SnoozeLog.read([4242]);
      expect(got, hasLength(1));
      expect(got.single.isBefore(before.subtract(const Duration(seconds: 2))),
          isFalse);
    });

    test('snoozing twice logs twice', () async {
      await CleanStorageService.saveReminder(Reminder(
        id: 'r-1',
        title: 'Stretch',
        body: '',
        scheduledTime: DateTime(2026, 3, 1, 20),
        repeatType: RepeatType.daily,
        notificationId: 4242,
      ));
      await NotificationService().snoozeReminder(4242, 10);
      await NotificationService().snoozeReminder(4242 + 100000, 10);
      expect(await SnoozeLog.read([4242]), hasLength(2));
    });
  });
}
