/// The full-screen alarm for a reminder has a way to say "I did it".
///
/// A medicine alarm has Take and Skip. A reminder — "call the clinic" — had only
/// Snooze and Dismiss, so the one honest answer, done, meant opening the app and
/// finding the card. "Mark done" is the same completion the notification's Done
/// button and the list's tick share.
library;

import 'package:clock/clock.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' as db;
import 'package:tablet_remainder/core/services/active_profile_service.dart';
import 'package:tablet_remainder/core/services/clean_storage_service.dart';
import 'package:tablet_remainder/core/services/notification_service.dart';
import 'package:tablet_remainder/features/reminders/models/reminder_model.dart';
import 'package:tablet_remainder/features/reminders/screens/alarm_screen.dart';
import 'package:tablet_remainder/features/reminders/services/reminder_service.dart';

import '../support/font_free_theme.dart';
import '../support/recording_notification_scheduler.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late db.AppDatabase database;

  final now = DateTime(2026, 6, 20, 13, 0);
  final due = DateTime(2026, 6, 20, 12, 0);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    database = db.AppDatabase.forTesting(NativeDatabase.memory());
    db.AppDatabase.setInstanceForTesting(database);
    CleanStorageService.resetForTesting();
    ActiveProfileService().resetForTesting();
    await ReminderService.instance.resetForTesting();
    NotificationService().schedulerForTesting = RecordingNotificationScheduler();
  });

  tearDown(() async {
    await ReminderService.instance.resetForTesting();
    await database.close();
  });

  Future<void> pump(WidgetTester tester, Map<String, dynamic> payload) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(390, 900);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
      theme: fontFreeTheme(),
      routes: {'/home': (_) => const Scaffold(body: Text('home'))},
      home: AlarmScreen(payload: payload),
    ));
    await tester.pump(const Duration(milliseconds: 1200));
  }

  testWidgets('a reminder\'s alarm offers Mark done, beside Snooze and Dismiss',
      (tester) async {
    await withClock(Clock.fixed(now), () async {
      await pump(tester, {
        'id': 5000,
        'title': 'Call the clinic',
        'body': 'About the results',
        'reminderId': 'r-1',
      });

      expect(find.text('Mark done'), findsOneWidget);
      expect(find.text('Take now'), findsNothing,
          reason: 'a reminder has nothing to take');
      expect(find.textContaining('Snooze'), findsOneWidget);
      expect(find.text('Dismiss'), findsOneWidget);
    });
  });

  testWidgets('an alarm that is not a reminder in the list has no Mark done',
      (tester) async {
    await withClock(Clock.fixed(now), () async {
      await pump(tester, {'id': 5000, 'title': 'Wake up', 'body': ''});
      expect(find.text('Mark done'), findsNothing);
      expect(find.textContaining('Snooze'), findsOneWidget);
    });
  });

  testWidgets('a medicine alarm keeps Take and Skip, and gains no Mark done',
      (tester) async {
    await withClock(Clock.fixed(now), () async {
      await pump(tester, {
        'id': 5000,
        'title': 'Time for your Metformin',
        'body': '',
        'medicineId': 'm-1',
        // A reminder id on a dose payload would be a bug; a dose is not one.
        'reminderId': 'r-1',
      });
      expect(find.text('Take now'), findsOneWidget);
      expect(find.text('Mark done'), findsNothing);
    });
  });

  testWidgets('tapping it completes the reminder, as the alarm, and leaves',
      (tester) async {
    await withClock(Clock.fixed(now), () async {
      await tester.runAsync(() async {
        await CleanStorageService.saveReminder(Reminder(
            id: 'r-1',
            title: 'Call the clinic',
            body: '',
            scheduledTime: due));
      });
      await pump(tester, {
        'id': 5000,
        'title': 'Call the clinic',
        'body': '',
        'reminderId': 'r-1',
      });

      await tester.tap(find.text('Mark done'));
      await tester.pump();
      // The write is real I/O: let it finish outside the fake clock.
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 300)));
      await tester.pump(const Duration(milliseconds: 500));

      final reminder = CleanStorageService.getReminders()
          .firstWhere((r) => r.id == 'r-1');
      expect(reminder.isCompleted, isTrue);
      final o = await tester.runAsync(
          () => database.remindersDao.getOccurrence('r-1', due));
      expect(o!.outcome, 'done');
      expect(o.source, 'alarm');
      expect(find.text('home'), findsOneWidget,
          reason: 'the alarm closes: it is answered');
    });
  });
}
