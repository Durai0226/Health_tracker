/// The Overdue heading's "Catch up": one sheet for a pile of overdue reminders,
/// driven through the real Reminders screen and the real scheduler seam.
///
/// The rules themselves (what moves, what is recorded, what Undo restores) are
/// in `overdue_triage_test.dart`. This is the wiring: that the entry point
/// appears only when it should, that the sheet says what each choice will do
/// before it is made, and that the toast's Undo takes back the whole heap.
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

  Reminder oneOff(String id, String title, DateTime at, int slot) => Reminder(
        id: id,
        title: title,
        body: '',
        scheduledTime: at,
        notificationId: slot,
      );

  Reminder daily() => Reminder(
        id: 'd-1',
        title: 'Water the plants',
        body: '',
        scheduledTime: DateTime(2026, 3, 14, 7, 0),
        repeatType: RepeatType.daily,
        notificationId: 5001,
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
    tester.view.physicalSize = const Size(400, 1800);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      home: const RemindersScreen(),
    ));
    await settle(tester);
  }

  Future<Reminder> stored(String id) async =>
      (await CleanStorageService.getAllReminders()).singleWhere((r) => r.id == id);

  Future<void> seedHeap() async {
    await CleanStorageService.saveReminder(
        oneOff('a', 'Call the bank', DateTime(2026, 3, 14, 8, 0), 4001));
    await CleanStorageService.saveReminder(
        oneOff('b', 'Post the parcel', DateTime(2026, 3, 13, 17, 0), 4002));
    await CleanStorageService.saveReminder(daily());
  }

  testWidgets('one overdue reminder is a swipe, not a triage', (tester) async {
    await withClock(Clock.fixed(now), () async {
      await CleanStorageService.saveReminder(
          oneOff('a', 'Call the bank', DateTime(2026, 3, 14, 8, 0), 4001));
      await mount(tester);

      expect(find.text('Overdue (1)'), findsOneWidget);
      expect(find.text('Catch up'), findsNothing);
      await unmount(tester);
    });
  });

  testWidgets('a heap of overdue reminders offers Catch up', (tester) async {
    await withClock(Clock.fixed(now), () async {
      await seedHeap();
      await mount(tester);

      expect(find.text('Overdue (3)'), findsOneWidget);
      expect(find.text('Catch up'), findsOneWidget);
      await unmount(tester);
    });
  });

  testWidgets('the sheet says what each choice will do before it is made',
      (tester) async {
    await withClock(Clock.fixed(now), () async {
      await seedHeap();
      await mount(tester);
      await tester.tap(find.text('Catch up'));
      await settle(tester);

      expect(find.text('3 reminders overdue.'), findsOneWidget);
      expect(find.textContaining('Call the bank'), findsWidgets);
      expect(find.text('This evening · 6:00 PM'), findsOneWidget);
      expect(find.text('Tomorrow morning · 9:30 AM'), findsOneWidget);
      expect(find.text('Skip all'), findsOneWidget);
      // Two are one-offs; the daily one keeps its schedule when moving.
      expect(
          find.text('Moves 2 reminders; repeating ones keep their schedule'),
          findsNWidgets(2));
      expect(
          find.text('Closes 2 reminders; repeating ones jump to their next '
              'time'),
          findsOneWidget);
      await unmount(tester);
    });
  });

  testWidgets('Tomorrow morning moves the one-offs and leaves the daily one',
      (tester) async {
    await withClock(Clock.fixed(now), () async {
      await seedHeap();
      await mount(tester);
      await tester.tap(find.text('Catch up'));
      await settle(tester);
      await tester.tap(find.text('Tomorrow morning · 9:30 AM'));
      await settle(tester);

      final tomorrow = DateTime(2026, 3, 15, 9, 30);
      expect((await stored('a')).scheduledTime, tomorrow);
      expect((await stored('b')).scheduledTime, tomorrow);
      expect((await stored('d-1')).scheduledTime, DateTime(2026, 3, 14, 7, 0),
          reason: 'a repeating reminder\'s time is its schedule');
      expect(find.text('Moved 2 to tomorrow morning'), findsOneWidget);
      expect(scheduler.armedIds, containsAll([4001, 4002]));
      await unmount(tester);
    });
  });

  testWidgets('Undo takes the whole move back', (tester) async {
    await withClock(Clock.fixed(now), () async {
      await seedHeap();
      await mount(tester);
      await tester.tap(find.text('Catch up'));
      await settle(tester);
      await tester.tap(find.text('Tomorrow morning · 9:30 AM'));
      await settle(tester);

      await tester.tap(find.text('Undo'));
      await settle(tester);

      expect((await stored('a')).scheduledTime, DateTime(2026, 3, 14, 8, 0));
      expect((await stored('b')).scheduledTime, DateTime(2026, 3, 13, 17, 0));
      expect(find.text('Overdue (3)'), findsOneWidget);
      await unmount(tester);
    });
  });

  testWidgets('Skip all closes the one-offs and rolls the daily one on',
      (tester) async {
    await withClock(Clock.fixed(now), () async {
      await seedHeap();
      await mount(tester);
      await tester.tap(find.text('Catch up'));
      await settle(tester);
      await tester.tap(find.text('Skip all'));
      await settle(tester);

      expect((await stored('a')).isCompleted, isTrue);
      expect((await stored('b')).isCompleted, isTrue);
      final rolled = await stored('d-1');
      expect(rolled.isCompleted, isFalse);
      expect(rolled.scheduledTime, DateTime(2026, 3, 15, 7, 0));
      expect(find.text('Skipped 3'), findsOneWidget);
      expect(find.text('Overdue (3)'), findsNothing);
      await unmount(tester);
    });
  });

  testWidgets('with only repeating reminders overdue there is nothing to move',
      (tester) async {
    await withClock(Clock.fixed(now), () async {
      await CleanStorageService.saveReminder(daily());
      await CleanStorageService.saveReminder(Reminder(
        id: 'd-2',
        title: 'Take vitamins',
        body: '',
        scheduledTime: DateTime(2026, 3, 14, 8, 0),
        repeatType: RepeatType.daily,
        notificationId: 5002,
      ));
      await mount(tester);
      await tester.tap(find.text('Catch up'));
      await settle(tester);

      expect(find.text('This evening · 6:00 PM'), findsNothing);
      expect(find.text('Tomorrow morning · 9:30 AM'), findsNothing);
      expect(find.text('Skip all'), findsOneWidget);
      expect(find.text('Repeating reminders jump to their next time'),
          findsOneWidget);
      await unmount(tester);
    });
  });

  testWidgets('late in the evening there is no "tonight" to offer',
      (tester) async {
    await withClock(Clock.fixed(DateTime(2026, 3, 14, 21, 30)), () async {
      await seedHeap();
      await mount(tester);
      await tester.tap(find.text('Catch up'));
      await settle(tester);

      expect(find.textContaining('This evening'), findsNothing);
      expect(find.textContaining('Tonight'), findsNothing);
      expect(find.text('Tomorrow morning · 9:30 AM'), findsOneWidget);
      await unmount(tester);
    });
  });

  testWidgets('a long list is previewed, not dumped', (tester) async {
    await withClock(Clock.fixed(now), () async {
      for (var i = 0; i < 6; i++) {
        await CleanStorageService.saveReminder(oneOff('r$i', 'Thing $i',
            DateTime(2026, 3, 14, 1 + i), 4100 + i));
      }
      await mount(tester);
      await tester.tap(find.text('Catch up'));
      await settle(tester);

      expect(find.text('6 reminders overdue.'), findsOneWidget);
      // The oldest four are listed, with their times; the other two are counted.
      expect(find.text('Thing 0 · 1:00 AM'), findsOneWidget);
      expect(find.text('Thing 3 · 4:00 AM'), findsOneWidget);
      expect(find.text('Thing 4 · 5:00 AM'), findsNothing);
      expect(find.text('and 2 more'), findsOneWidget);
      await unmount(tester);
    });
  });
}
