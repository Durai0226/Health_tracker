/// Editing a reminder Smart Add made repeat.
///
/// "Every 3 days" is an RFC 5545 rule the repeat dropdown cannot express. The
/// form carried it through save untouched and showed "Does not repeat" beside it
/// — a reminder that repeats, reading as one that does not — and offered no way
/// to change it short of replacing it. Now it says what it is, moves further
/// apart or closer together, and can be swapped for a standard repeat on purpose.
library;

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tablet_remainder/core/services/clean_storage_service.dart';
import 'package:tablet_remainder/core/services/notification_service.dart';
import 'package:tablet_remainder/features/reminders/models/reminder_model.dart';
import 'package:tablet_remainder/features/reminders/screens/add_reminder_screen.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../support/recording_notification_scheduler.dart';
import '../support/reminder_harness.dart';

void main() {
  setUpAll(() {
    tz_data.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('America/New_York'));
  });

  void reminderWidgetTest(
    String description,
    Future<void> Function(WidgetTester tester, DateTime now) body,
  ) {
    testWidgets(description, (tester) async {
      final real = DateTime.now();
      final pinned = DateTime(real.year, real.month, real.day, 13, 0);
      await withClock(Clock.fixed(pinned), () async {
        final h = await reminderSetUp(at: pinned);
        NotificationService().schedulerForTesting = RecordingNotificationScheduler();
        try {
          await body(tester, pinned);
        } finally {
          await h.tearDown();
        }
      });
    });
  }

  Reminder everyThreeDays(DateTime now, {String rule = 'RRULE:FREQ=DAILY;INTERVAL=3'}) =>
      Reminder(
        id: 'r-1',
        title: 'Rotate the stock',
        body: '',
        scheduledTime: now.add(const Duration(hours: 2)),
        recurrenceRule: rule,
      );

  Future<void> pump(WidgetTester tester, Reminder reminder) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(400, 3000);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: AddReminderScreen(reminder: reminder)));
    await tester.pump(const Duration(milliseconds: 300));
  }

  Future<void> save(WidgetTester tester) async {
    final b = find.text('Save Changes');
    await tester.ensureVisible(b);
    await tester.tap(b);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  Future<Reminder> stored() async => (await CleanStorageService.getAllReminders()).single;

  reminderWidgetTest('says "Every 3 days", not "Does not repeat"', (tester, now) async {
    await CleanStorageService.saveReminder(everyThreeDays(now));
    await pump(tester, everyThreeDays(now));

    expect(find.text('Every 3 days'), findsOneWidget);
    expect(find.text('Does not repeat'), findsNothing);
    expect(find.text('Ends'), findsOneWidget,
        reason: 'it repeats, so it can end');
  });

  reminderWidgetTest('moving it further apart is saved, and it stays a rule',
      (tester, now) async {
    await CleanStorageService.saveReminder(everyThreeDays(now));
    await pump(tester, everyThreeDays(now));

    await tester.ensureVisible(find.byTooltip('Less often'));
    await tester.tap(find.byTooltip('Less often'));
    await tester.pump();
    expect(find.text('Every 4 days'), findsOneWidget);

    await save(tester);

    final r = await stored();
    expect(r.recurrenceRule, contains('INTERVAL=4'));
    expect(r.recurrenceRule, contains('FREQ=DAILY'));
    expect(r.repeatType, RepeatType.none,
        reason: 'a rule is still a rule; the six-value repeat stays out of it');
  });

  reminderWidgetTest('and closer together', (tester, now) async {
    await CleanStorageService.saveReminder(everyThreeDays(now));
    await pump(tester, everyThreeDays(now));

    await tester.ensureVisible(find.byTooltip('More often'));
    await tester.tap(find.byTooltip('More often'));
    await tester.pump();
    await tester.tap(find.byTooltip('More often'));
    await tester.pump();
    expect(find.text('Every day'), findsOneWidget);

    await save(tester);

    final r = await stored();
    expect(r.recurrenceRule, isNot(contains('INTERVAL')));
    expect(r.recurrenceRule, contains('FREQ=DAILY'));
  });

  reminderWidgetTest('a weekday in the rule is kept through a change',
      (tester, now) async {
    final r = everyThreeDays(now, rule: 'RRULE:FREQ=WEEKLY;INTERVAL=2;BYDAY=TU');
    await CleanStorageService.saveReminder(r);
    await pump(tester, r);

    await tester.ensureVisible(find.byTooltip('Less often'));
    await tester.tap(find.byTooltip('Less often'));
    await tester.pump();
    await save(tester);

    expect((await stored()).recurrenceRule,
        allOf(contains('BYDAY=TU'), contains('INTERVAL=3'), contains('FREQ=WEEKLY')));
  });

  reminderWidgetTest('left alone, it is saved exactly as it was', (tester, now) async {
    await CleanStorageService.saveReminder(everyThreeDays(now));
    await pump(tester, everyThreeDays(now));

    await save(tester);

    expect((await stored()).recurrenceRule, 'RRULE:FREQ=DAILY;INTERVAL=3');
  });

  reminderWidgetTest(
      '"Use a standard repeat instead" swaps it for the dropdown, on the same unit',
      (tester, now) async {
    await CleanStorageService.saveReminder(everyThreeDays(now));
    await pump(tester, everyThreeDays(now));

    await tester.ensureVisible(find.text('Use a standard repeat instead'));
    await tester.tap(find.text('Use a standard repeat instead'));
    await tester.pump();

    expect(find.text('Every 3 days'), findsNothing);
    expect(find.text('Every Day'), findsOneWidget,
        reason: 'pre-selected, so saving at once does not quietly stop it repeating');

    await save(tester);

    final r = await stored();
    expect(r.recurrenceRule, isNull, reason: 'the rule is gone');
    expect(r.repeatType, RepeatType.daily);
  });

  reminderWidgetTest('a rule with nothing like a standard repeat starts at "Does not repeat"',
      (tester, now) async {
    final r = everyThreeDays(now, rule: 'RRULE:FREQ=MONTHLY;BYMONTHDAY=15');
    await CleanStorageService.saveReminder(r);
    await pump(tester, r);

    await tester.ensureVisible(find.text('Use a standard repeat instead'));
    await tester.tap(find.text('Use a standard repeat instead'));
    await tester.pump();

    expect(find.text('Does not repeat'), findsOneWidget,
        reason: 'there is no standard "monthly on the 15th"; the person chooses');
  });

  reminderWidgetTest('an ordinary reminder has no rule editor', (tester, now) async {
    final r = Reminder(
        id: 'r-2',
        title: 'Water the plants',
        body: '',
        scheduledTime: now.add(const Duration(hours: 2)),
        repeatType: RepeatType.daily);
    await CleanStorageService.saveReminder(r);
    await pump(tester, r);

    expect(find.text('Use a standard repeat instead'), findsNothing);
    expect(find.text('Every Day'), findsOneWidget);
  });
}
