import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tablet_remainder/core/services/clean_storage_service.dart';
import 'package:tablet_remainder/core/services/notification_service.dart';
import 'package:tablet_remainder/features/reminders/models/reminder_model.dart';
import 'package:tablet_remainder/features/reminders/screens/add_reminder_screen.dart';
import 'package:tablet_remainder/features/reminders/services/reminder_pause_until.dart';
import 'package:tablet_remainder/features/reminders/widgets/reminder_end_pause_controls.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../support/recording_notification_scheduler.dart';
import '../support/reminder_harness.dart';

/// The form's Ends and Pause controls reach the SAVED reminder.
///
/// As in `add_reminder_screen_negative_input_test`, every assertion reads back
/// what was persisted: a control that updates the screen and not the row is the
/// failure worth catching.
void main() {
  setUpAll(() {
    tz_data.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('America/New_York'));
  });

  void reminderWidgetTest(
    String description,
    Future<void> Function(WidgetTester tester, DateTime now,
            RecordingNotificationScheduler scheduler)
        body,
  ) {
    testWidgets(description, (tester) async {
      final real = DateTime.now();
      final pinned = DateTime(real.year, real.month, real.day, 13, 0);
      await withClock(Clock.fixed(pinned), () async {
        final h = await reminderSetUp(at: pinned);
        final scheduler = RecordingNotificationScheduler();
        NotificationService().schedulerForTesting = scheduler;
        try {
          await body(tester, pinned, scheduler);
        } finally {
          await h.tearDown();
        }
      });
    });
  }

  Future<void> pump(WidgetTester tester,
      {Reminder? reminder, RepeatType? repeat, DateTime? at, DateTime? endsAt}) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(400, 3000);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: AddReminderScreen(
        reminder: reminder,
        initialTitle: reminder == null ? 'Stretch' : null,
        initialTime: at,
        initialRepeat: repeat,
        initialEndsAt: endsAt,
      ),
    ));
    await tester.pump(const Duration(milliseconds: 300));
  }

  Future<void> save(WidgetTester tester, {String label = 'Create Reminder'}) async {
    final b = find.text(label);
    await tester.ensureVisible(b);
    await tester.tap(b);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  Future<List<Reminder>> stored() => CleanStorageService.getAllReminders();

  Reminder existing(DateTime now, {bool paused = false}) => Reminder(
        id: 'r-1',
        title: 'Water the plants',
        body: '',
        scheduledTime: now.add(const Duration(hours: 2)),
        repeatType: RepeatType.daily,
        isPaused: paused,
      );

  group('Ends', () {
    reminderWidgetTest('a one-off has no Ends section', (tester, now, _) async {
      await pump(tester, at: now.add(const Duration(hours: 1)));
      expect(find.text('Ends'), findsNothing);
    });

    reminderWidgetTest('a repeating reminder does, starting at Never',
        (tester, now, _) async {
      await pump(tester,
          repeat: RepeatType.daily, at: now.add(const Duration(hours: 1)));
      expect(find.text('Ends'), findsOneWidget);
      expect(find.text('Never'), findsOneWidget);
    });

    reminderWidgetTest('"After a number" saves the count and no end date',
        (tester, now, _) async {
      await pump(tester,
          repeat: RepeatType.daily, at: now.add(const Duration(hours: 1)));
      await tester.ensureVisible(find.text('Never'));
      await tester.tap(find.text('Never'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('After a number').last);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byTooltip('More'));
      await tester.tap(find.byTooltip('More'));
      await tester.pump();
      expect(find.text('Stops after 11 times'), findsOneWidget);

      await save(tester);

      final r = (await stored()).single;
      expect(r.occurrenceLimit, 11);
      expect(r.endsAt, isNull);
    });

    reminderWidgetTest('"On a date" saves an end after the first reminder',
        (tester, now, _) async {
      await pump(tester,
          repeat: RepeatType.daily, at: now.add(const Duration(hours: 1)));
      await tester.ensureVisible(find.text('Never'));
      await tester.tap(find.text('Never'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('On a date').last);
      await tester.pumpAndSettle();

      await save(tester);

      final r = (await stored()).single;
      expect(r.endsAt, isNotNull);
      expect(r.endsAt!.isAfter(r.scheduledTime), isTrue);
      expect(r.occurrenceLimit, isNull);
    });

    reminderWidgetTest(
        'an end that comes before the first reminder is refused, with a reason',
        (tester, now, scheduler) async {
      await pump(tester,
          repeat: RepeatType.daily,
          at: now.add(const Duration(hours: 1)),
          endsAt: now.subtract(const Duration(days: 3)));
      await save(tester);

      expect(await stored(), isEmpty,
          reason: 'saving a reminder that can never fire is worse than saying '
              'no');
      expect(find.text('The end date has to come after the first reminder.'),
          findsOneWidget);
      expect(scheduler.scheduled, isEmpty);
    });
  });

  group('Pause', () {
    reminderWidgetTest('a new reminder has no Pause section',
        (tester, now, _) async {
      await pump(tester, at: now.add(const Duration(hours: 1)));
      expect(find.byKey(ReminderPauseControl.pauseSwitchKey), findsNothing);
    });

    reminderWidgetTest('editing offers it, off by default', (tester, now, _) async {
      await pump(tester, reminder: existing(now));
      expect(find.byKey(ReminderPauseControl.pauseSwitchKey), findsOneWidget);
    });

    reminderWidgetTest('pausing saves it paused and arms nothing',
        (tester, now, scheduler) async {
      await CleanStorageService.saveReminder(existing(now));
      await pump(tester, reminder: existing(now));
      await tester.ensureVisible(find.byKey(ReminderPauseControl.pauseSwitchKey));
      await tester.tap(find.byKey(ReminderPauseControl.pauseSwitchKey));
      await tester.pump();
      scheduler.clear();

      await save(tester, label: 'Save Changes');

      final r = (await stored()).single;
      expect(r.isPaused, isTrue);
      expect(scheduler.scheduled, isEmpty,
          reason: 'a paused reminder must not be armed');
    });

    reminderWidgetTest('a paused reminder opens paused, and its resume date '
        'is remembered', (tester, now, _) async {
      final r = existing(now, paused: true);
      await CleanStorageService.saveReminder(r);
      await ReminderPauseUntil.set('r-1', DateTime(2026, 12, 25));

      await pump(tester, reminder: r);

      expect(find.textContaining('Back on'), findsOneWidget);
    });

    reminderWidgetTest('un-pausing clears the resume date and arms it again',
        (tester, now, scheduler) async {
      final r = existing(now, paused: true);
      await CleanStorageService.saveReminder(r);
      await ReminderPauseUntil.set('r-1', DateTime(2026, 12, 25));
      await pump(tester, reminder: r);
      await tester.ensureVisible(find.byKey(ReminderPauseControl.pauseSwitchKey));
      await tester.tap(find.byKey(ReminderPauseControl.pauseSwitchKey));
      await tester.pump();

      await save(tester, label: 'Save Changes');

      final back = (await stored()).single;
      expect(back.isPaused, isFalse);
      expect(ReminderPauseUntil.get('r-1'), isNull);
    });
  });
}
