/// Ticking a repeating reminder rolls it on to its next time. Two repeats used to
/// fall through that and finish for good, and one that had nothing left to come
/// was "rolled" to the instant it already had:
///
///  * a Smart Add repeat ("every 3 days") has `repeatType: none` plus an RRULE,
///    and the tick tested only the enum — so the first tick completed it;
///  * a repeat past its end date has no next occurrence, and was written back at
///    its old time, not completed — overdue for ever.
library;

import 'package:clock/clock.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' show AppDatabase;
import 'package:tablet_remainder/core/services/active_profile_service.dart';
import 'package:tablet_remainder/core/services/clean_storage_service.dart';
import 'package:tablet_remainder/core/services/notification_service.dart';
import 'package:tablet_remainder/core/theme/app_theme.dart';
import 'package:tablet_remainder/features/reminders/models/reminder_model.dart';
import 'package:tablet_remainder/features/reminders/screens/reminders_screen.dart';
import 'package:tablet_remainder/features/reminders/services/reminder_service.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../support/recording_notification_scheduler.dart';

void main() {
  late AppDatabase db;
  late RecordingNotificationScheduler scheduler;

  // Saturday 14 March 2026, 10:00.
  final now = DateTime(2026, 3, 14, 10, 0);

  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    tz_data.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('America/New_York'));
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    scheduler = RecordingNotificationScheduler();
    NotificationService().schedulerForTesting = scheduler;
    db = AppDatabase.forTesting(NativeDatabase.memory());
    AppDatabase.setInstanceForTesting(db);
    CleanStorageService.resetForTesting();
    ActiveProfileService().resetForTesting();
    await ReminderService.instance.resetForTesting();
  });

  tearDown(() async {
    await ReminderService.instance.resetForTesting();
    await db.close();
  });

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 150));
    }
  }

  Future<void> mount(WidgetTester tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(400, 1600);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      home: const RemindersScreen(),
    ));
    await settle(tester);
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 10));
  }

  Future<Reminder> stored(String id) async =>
      (await CleanStorageService.getAllReminders()).singleWhere((r) => r.id == id);

  testWidgets('a Smart Add "every 3 days" rolls to its next day, not to Completed',
      (tester) async {
    await withClock(Clock.fixed(now), () async {
      await CleanStorageService.saveReminder(Reminder(
        id: 'rule',
        title: 'Water the ferns',
        body: '',
        // Due at 08:00 today; the first instance was three days ago.
        scheduledTime: DateTime(2026, 3, 14, 8, 0),
        recurrenceRule: 'RRULE:FREQ=DAILY;INTERVAL=3',
        notificationId: 6001,
      ));
      await mount(tester);

      await tester.drag(find.text('Water the ferns'), const Offset(500, 0));
      await settle(tester);

      final after = await stored('rule');
      expect(after.isCompleted, isFalse,
          reason: 'it repeats; the tick finished it for good');
      expect(after.scheduledTime, DateTime(2026, 3, 17, 8, 0));
      expect(find.text('Marked done'), findsOneWidget);
      expect(scheduler.armedIds, contains(6001),
          reason: 'and the next one is armed, at the next day, not the one '
              'after it');
      await unmount(tester);
    });
  });

  testWidgets('a repeat past its end date is finished by the tick',
      (tester) async {
    await withClock(Clock.fixed(now), () async {
      await CleanStorageService.saveReminder(Reminder(
        id: 'ended',
        title: 'Take antibiotics',
        body: '',
        scheduledTime: DateTime(2026, 3, 12, 9, 0),
        repeatType: RepeatType.daily,
        endsAt: DateTime(2026, 3, 13),
        notificationId: 6002,
      ));
      await mount(tester);

      await tester.drag(find.text('Take antibiotics'), const Offset(500, 0));
      await settle(tester);

      expect((await stored('ended')).isCompleted, isTrue,
          reason: 'it was "rolled" to its own old time and stayed overdue');
      await unmount(tester);
    });
  });

  testWidgets('ticking a PAUSED repeat leaves it exactly as it was',
      (tester) async {
    await withClock(Clock.fixed(now), () async {
      await CleanStorageService.saveReminder(Reminder(
        id: 'paused',
        title: 'Stretch',
        body: '',
        scheduledTime: DateTime(2026, 3, 14, 8, 0),
        repeatType: RepeatType.daily,
        isPaused: true,
        notificationId: 6005,
      ));
      await mount(tester);

      await tester.drag(find.text('Stretch'), const Offset(500, 0));
      await settle(tester);

      final after = await stored('paused');
      expect(after.isCompleted, isFalse,
          reason: 'paused is not finished: it would never repeat again');
      expect(after.scheduledTime, DateTime(2026, 3, 14, 8, 0));
      await unmount(tester);
    });
  });

  testWidgets('an ordinary daily reminder still rolls on, as ever',
      (tester) async {
    await withClock(Clock.fixed(now), () async {
      await CleanStorageService.saveReminder(Reminder(
        id: 'daily',
        title: 'Stretch',
        body: '',
        scheduledTime: DateTime(2026, 3, 14, 8, 0),
        repeatType: RepeatType.daily,
        notificationId: 6003,
      ));
      await mount(tester);

      await tester.drag(find.text('Stretch'), const Offset(500, 0));
      await settle(tester);

      final after = await stored('daily');
      expect(after.isCompleted, isFalse);
      expect(after.scheduledTime, DateTime(2026, 3, 15, 8, 0));
      await unmount(tester);
    });
  });

  testWidgets('a one-off is still just completed', (tester) async {
    await withClock(Clock.fixed(now), () async {
      await CleanStorageService.saveReminder(Reminder(
        id: 'one',
        title: 'Call the bank',
        body: '',
        scheduledTime: DateTime(2026, 3, 14, 8, 0),
        notificationId: 6004,
      ));
      await mount(tester);

      await tester.drag(find.text('Call the bank'), const Offset(500, 0));
      await settle(tester);

      expect((await stored('one')).isCompleted, isTrue);
      await unmount(tester);
    });
  });
}
