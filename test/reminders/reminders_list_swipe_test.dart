/// The Reminders list: swipe right to finish, swipe left for Later, and Delete in
/// the card's menu with an Undo that brings the history back.
///
/// Driven through the real screen and the real scheduler seam (see
/// `tick_reports_arm_failure_test` for why a scheduler MUST be installed: an
/// un-injected `arm()` hangs headless and nothing after it ever runs).
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

  // Saturday 14 March 2026, 10:00 — before the 17:00 cutoff, so "Later" is the
  // same evening.
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

  Reminder oneOff() => Reminder(
        id: 'r-1',
        title: 'Call the bank',
        body: '',
        scheduledTime: DateTime(2026, 3, 14, 12, 0),
        notificationId: 4242,
      );

  Reminder daily() => Reminder(
        id: 'r-2',
        title: 'Water the plants',
        body: '',
        scheduledTime: DateTime(2026, 3, 14, 9, 0),
        repeatType: RepeatType.daily,
        notificationId: 4243,
      );

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 150));
    }
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 10));
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

  Future<Reminder> stored(String id) async =>
      (await CleanStorageService.getAllReminders()).singleWhere((r) => r.id == id);

  testWidgets('swipe right marks a one-off done, and the card is not removed',
      (tester) async {
    await withClock(Clock.fixed(now), () async {
      await CleanStorageService.saveReminder(oneOff());
      await mount(tester);

      await tester.drag(find.text('Call the bank'), const Offset(500, 0));
      await settle(tester);

      expect((await stored('r-1')).isCompleted, isTrue);
      expect(find.text('Call the bank'), findsOneWidget,
          reason: 'it moves to Completed; it must not be deleted by the swipe');
      expect(find.text('Marked done'), findsOneWidget);
      await unmount(tester);
    });
  });

  testWidgets('swipe left on a one-off moves it to this evening, with Undo',
      (tester) async {
    await withClock(Clock.fixed(now), () async {
      await CleanStorageService.saveReminder(oneOff());
      await mount(tester);

      await tester.drag(find.text('Call the bank'), const Offset(-500, 0));
      await settle(tester);

      final moved = await stored('r-1');
      expect(moved.scheduledTime, DateTime(2026, 3, 14, 18, 0));
      expect(moved.isCompleted, isFalse);
      expect(find.text('Moved to this evening'), findsOneWidget);
      expect(scheduler.armedIds, contains(4242),
          reason: 'the new time has to be armed, not just saved');

      // Undo puts the original time back.
      await tester.tap(find.text('Undo'));
      await settle(tester);
      expect((await stored('r-1')).scheduledTime, DateTime(2026, 3, 14, 12, 0));
      await unmount(tester);
    });
  });

  testWidgets('late in the day, Later means tomorrow morning', (tester) async {
    await withClock(Clock.fixed(DateTime(2026, 3, 14, 20, 0)), () async {
      await CleanStorageService.saveReminder(Reminder(
        id: 'r-1',
        title: 'Call the bank',
        body: '',
        scheduledTime: DateTime(2026, 3, 14, 21, 0),
        notificationId: 4242,
      ));
      await mount(tester);
      await tester.drag(find.text('Call the bank'), const Offset(-500, 0));
      await settle(tester);

      expect((await stored('r-1')).scheduledTime, DateTime(2026, 3, 15, 9, 30));
      expect(find.text('Moved to tomorrow morning'), findsOneWidget);
      await unmount(tester);
    });
  });

  testWidgets('a repeating reminder cannot be swiped to Later', (tester) async {
    await withClock(Clock.fixed(now), () async {
      await CleanStorageService.saveReminder(daily());
      await mount(tester);

      await tester.drag(find.text('Water the plants'), const Offset(-500, 0));
      await settle(tester);

      expect((await stored('r-2')).scheduledTime, DateTime(2026, 3, 14, 9, 0),
          reason: 'moving a repeating reminder would move every future one');
      expect(find.textContaining('Moved to'), findsNothing);
      await unmount(tester);
    });
  });

  testWidgets('a swipe left never deletes anything', (tester) async {
    await withClock(Clock.fixed(now), () async {
      await CleanStorageService.saveReminder(oneOff());
      await CleanStorageService.saveReminder(daily());
      await mount(tester);
      await tester.drag(find.text('Water the plants'), const Offset(-500, 0));
      await tester.drag(find.text('Call the bank'), const Offset(-500, 0));
      await settle(tester);

      expect(await CleanStorageService.getAllReminders(), hasLength(2));
      await unmount(tester);
    });
  });

  testWidgets('Delete lives in the card menu; Undo restores the reminder AND '
      'its history', (tester) async {
    await withClock(Clock.fixed(now), () async {
      await CleanStorageService.saveReminder(daily());
      await CleanStorageService.recordDueReminderOccurrences();
      await CleanStorageService.recordReminderOutcome(
        reminderId: 'r-2',
        scheduledFor: DateTime(2026, 3, 13, 9, 0),
        outcome: ReminderOutcome.done,
        source: 'app',
      );
      final before = (await CleanStorageService.getReminderOccurrences('r-2'));
      expect(before, isNotEmpty, reason: 'premise: there is history to lose');
      await mount(tester);

      await tester.tap(find.bySemanticsLabel('More options for Water the plants'));
      await settle(tester);
      await tester.tap(find.text('Delete'));
      await settle(tester);

      expect(await CleanStorageService.getAllReminders(), isEmpty);
      expect(await CleanStorageService.getReminderOccurrences('r-2'), isEmpty);
      expect(find.text('Deleted "Water the plants"'), findsOneWidget);

      await tester.tap(find.text('Undo'));
      await settle(tester);

      final back = await stored('r-2');
      expect(back.title, 'Water the plants');
      expect(back.notificationId, 4243, reason: 'the same alarm slot');
      final after = await CleanStorageService.getReminderOccurrences('r-2');
      expect(after.length, before.length);
      expect(
          after.firstWhere((o) => o.scheduledFor == DateTime(2026, 3, 13, 9, 0)).outcome,
          ReminderOutcome.done.name,
          reason: 'the tick the user made is part of what Undo restores');
      expect(scheduler.armedIds, contains(4243),
          reason: 'and it is armed again');
      await unmount(tester);
    });
  });
}
