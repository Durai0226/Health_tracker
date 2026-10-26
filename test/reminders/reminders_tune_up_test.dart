/// The tune-up, end to end: history in the database (and snoozes in
/// preferences) becomes one suggestion on the reminder's card, and tapping it
/// changes the reminder and its alarm. `reminder_tune_up_test` covers the rule;
/// this covers that real data reaches it and the result reaches the OS.
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
import 'package:tablet_remainder/core/services/snooze_log.dart';
import 'package:tablet_remainder/core/theme/app_theme.dart';
import 'package:tablet_remainder/features/reminders/models/reminder_model.dart';
import 'package:tablet_remainder/features/reminders/screens/reminders_screen.dart';
import 'package:tablet_remainder/features/reminders/services/reminder_service.dart';
import 'package:tablet_remainder/features/reminders/services/reminder_tune_up.dart';
import 'package:tablet_remainder/features/reminders/services/reminder_tune_up_service.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../support/recording_notification_scheduler.dart';

void main() {
  late AppDatabase db;
  late RecordingNotificationScheduler scheduler;

  // 8 March 2026 — the history below is 1-6 March.
  final now = DateTime(2026, 3, 8, 12, 0);
  const slot = 4242;

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
    await CleanStorageService.init();
    ActiveProfileService().resetForTesting();
    await ReminderService.instance.resetForTesting();
  });

  tearDown(() async {
    await ReminderService.instance.resetForTesting();
    await db.close();
  });

  Reminder daily({bool paused = false}) => Reminder(
        id: 'r-1',
        title: 'Stretch',
        body: '',
        scheduledTime: DateTime(2026, 3, 1, 20, 0),
        repeatType: RepeatType.daily,
        notificationId: slot,
        isPaused: paused,
      );

  /// Done at 21:40 every evening 1-6 March.
  Future<void> seedDoneLate() async {
    for (var d = 1; d <= 6; d++) {
      await CleanStorageService.recordReminderOutcome(
        reminderId: 'r-1',
        scheduledFor: DateTime(2026, 3, d, 20),
        outcome: ReminderOutcome.done,
        actedAt: DateTime(2026, 3, d, 21, 40),
        source: 'app',
      );
    }
  }

  Future<Reminder> stored() async =>
      (await CleanStorageService.getAllReminders()).singleWhere((r) => r.id == 'r-1');

  group('the service', () {
    test('real history becomes a suggestion', () async {
      await CleanStorageService.saveReminder(daily());
      await seedDoneLate();
      final t = await ReminderTuneUpService.forOne(daily(), now: now);
      expect(t?.kind, TuneUpKind.move);
      expect(t?.message, 'Usually done around 9:40 PM');
    });

    test('recorded snoozes lead the message', () async {
      await CleanStorageService.saveReminder(daily());
      await seedDoneLate();
      final prefs = await SharedPreferences.getInstance();
      for (final d in [1, 3, 4, 6]) {
        await SnoozeLog.record(prefs, slot, DateTime(2026, 3, d, 20, 10));
      }
      final t = await ReminderTuneUpService.forOne(daily(), now: now);
      expect(t?.message, 'Snoozed 4 of last 6 · usually done around 9:40 PM');
    });

    test('no history, no suggestion', () async {
      await CleanStorageService.saveReminder(daily());
      expect(await ReminderTuneUpService.forOne(daily(), now: now), isNull);
    });

    test('"not now" hides it for thirty days, then it may return', () async {
      await CleanStorageService.saveReminder(daily());
      await seedDoneLate();
      await ReminderTuneUpService.dismiss('r-1', TuneUpKind.move, now: now);
      expect(await ReminderTuneUpService.forOne(daily(), now: now), isNull);
      expect(
          await ReminderTuneUpService.forOne(daily(),
              now: now.add(const Duration(days: 29))),
          isNull);
      expect(
          await ReminderTuneUpService.forOne(daily(),
              now: now.add(const Duration(days: 31))),
          isNotNull);
    });

    test('dismissing one kind does not hide another', () async {
      await ReminderTuneUpService.dismiss('r-1', TuneUpKind.move, now: now);
      expect(ReminderTuneUpService.isDismissed('r-1', TuneUpKind.move, now: now), isTrue);
      expect(ReminderTuneUpService.isDismissed('r-1', TuneUpKind.pause, now: now), isFalse);
      expect(ReminderTuneUpService.isDismissed('r-2', TuneUpKind.move, now: now), isFalse);
    });

    test('applying "move" saves the new time and arms it', () async {
      await CleanStorageService.saveReminder(daily());
      await seedDoneLate();
      final t = (await ReminderTuneUpService.forOne(daily(), now: now))!;

      await withClock(Clock.fixed(now), () => ReminderTuneUpService.apply(daily(), t));

      final r = await stored();
      expect(r.scheduledTime.hour, 21);
      expect(r.scheduledTime.minute, 40);
      expect(scheduler.armedIds, contains(slot),
          reason: 'the new time has to reach the OS, not just the database');
    });

    test('applying "pause" pauses it and takes it off the OS', () async {
      await CleanStorageService.saveReminder(daily());
      const t = TuneUp(kind: TuneUpKind.pause, message: 'm', actionLabel: 'Pause it');
      await ReminderTuneUpService.apply(daily(), t);

      expect((await stored()).isPaused, isTrue);
      expect(scheduler.scheduled, isEmpty);
    });
  });

  group('the card', () {
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

    testWidgets('shows the suggestion; "Move it" applies it with an Undo',
        (tester) async {
      await withClock(Clock.fixed(now), () async {
        await CleanStorageService.saveReminder(daily());
        await seedDoneLate();
        await mount(tester);

        expect(find.text('Usually done around 9:40 PM'), findsOneWidget);
        await tester.tap(find.text('Move it'));
        await settle(tester);

        expect((await stored()).scheduledTime.hour, 21);
        expect(find.textContaining('Moved to'), findsOneWidget);
        expect(find.text('Usually done around 9:40 PM'), findsNothing,
            reason: 'once applied the suggestion has done its job');

        await tester.tap(find.text('Undo'));
        await settle(tester);
        expect((await stored()).scheduledTime.hour, 20);
        await unmount(tester);
      });
    });

    testWidgets('"Not now" removes it and keeps it away', (tester) async {
      await withClock(Clock.fixed(now), () async {
        await CleanStorageService.saveReminder(daily());
        await seedDoneLate();
        await mount(tester);

        await tester.tap(find.byTooltip('Not now'));
        await settle(tester);
        expect(find.text('Usually done around 9:40 PM'), findsNothing);
        expect((await stored()).scheduledTime.hour, 20,
            reason: 'dismissing changes nothing about the reminder');

        await unmount(tester);
        await mount(tester);
        expect(find.text('Usually done around 9:40 PM'), findsNothing,
            reason: 'and it does not come straight back');
        await unmount(tester);
      });
    });

    testWidgets('a reminder with no history shows nothing', (tester) async {
      await withClock(Clock.fixed(now), () async {
        await CleanStorageService.saveReminder(daily());
        await mount(tester);
        expect(find.text('Move it'), findsNothing);
        await unmount(tester);
      });
    });
  });
}
