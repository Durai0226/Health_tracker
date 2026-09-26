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

/// What `AddReminderScreen` does with input a user should not be able to save.
///
/// The screen had no widget test of any kind. The only two references to it in
/// the whole suite were a `find.byType(AddReminderScreen)` navigation assertion
/// and a device e2e suite — and nothing drove an empty title, a whitespace-only
/// title, a one-off already in the past, or an end date before the start.
///
/// Every test here asserts on what was actually **persisted**, not on what the
/// form displayed. A validation message that appears while the reminder is saved
/// anyway is the failure mode worth catching, and only a read-back can tell the
/// two apart.
void main() {
  setUpAll(() {
    // `scheduleGenericReminder` does `tz.TZDateTime.from(…, tz.local)`, and an
    // uninitialised `tz.local` throws a LateInitializationError that the method's
    // own outer `catch` swallows into `return false`. Without this the arming
    // assertions below pass or fail on a timezone error rather than on the
    // reminder logic — which is how the "an expired repeat arms nothing" test
    // first passed: nothing was ever armed, expired or not.
    tz_data.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('America/New_York'));
  });

  /// `testWidgets` inside a pinned clock zone, with the reminder harness set up
  /// and torn down.
  ///
  /// The screen reads `clock.now()` when deciding whether a one-off is in the
  /// past, so without the pin the roll-forward tests would pass or fail
  /// depending on the hour the suite happened to run.
  void reminderWidgetTest(
    String description,
    Future<void> Function(WidgetTester tester, DateTime now) body, {
    DateTime? at,
  }) {
    testWidgets(description, (tester) async {
      final real = DateTime.now();
      final pinned = at ?? DateTime(real.year, real.month, real.day, 13, 0);
      await withClock(Clock.fixed(pinned), () async {
        final h = await reminderSetUp(at: pinned);
        // The save path arms through `NotificationReminderAlarm`, which reaches
        // `NotificationService`. The scheduler seam is what keeps that headless.
        NotificationService().schedulerForTesting =
            RecordingNotificationScheduler();
        try {
          await body(tester, pinned);
        } finally {
          await h.tearDown();
        }
      });
    });
  }

  Future<void> pumpScreen(
    WidgetTester tester, {
    DateTime? initialTime,
    DateTime? initialEndsAt,
    RepeatType? initialRepeat,
    String? initialTitle,
  }) async {
    await tester.pumpWidget(MaterialApp(
      home: AddReminderScreen(
        initialTitle: initialTitle,
        initialTime: initialTime,
        initialEndsAt: initialEndsAt,
        initialRepeat: initialRepeat,
      ),
    ));
    await tester.pump(const Duration(milliseconds: 300));
  }

  Finder titleField() => find.byType(TextFormField).first;
  Finder saveButton() => find.text('Create Reminder');

  Future<void> tapSave(WidgetTester tester) async {
    await tester.ensureVisible(saveButton());
    await tester.tap(saveButton());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  Future<List<Reminder>> stored() => CleanStorageService.getAllReminders();

  group('a title that is not really a title', () {
    reminderWidgetTest('an empty title is refused, and nothing is saved',
        (tester, now) async {
      await pumpScreen(tester);
      await tapSave(tester);

      expect(find.text('Please enter a title'), findsOneWidget);
      expect(await stored(), isEmpty,
          reason: 'the validation message must mean the save did not happen');
    });

    reminderWidgetTest('a whitespace-only title is refused too',
        (tester, now) async {
      // The validator tested `value.isEmpty`, which is false for '   ' — so the
      // form validated, and `title: _titleController.text.trim()` then stored a
      // reminder with an EMPTY title. In the list it is a blank row; in the
      // notification it is a blank heading.
      await pumpScreen(tester);
      await tester.enterText(titleField(), '   ');
      await tapSave(tester);

      expect(find.text('Please enter a title'), findsOneWidget);
      expect(await stored(), isEmpty,
          reason: 'trim() at save time means whitespace saves an empty title');
    });

    reminderWidgetTest('a tab-and-newline title is refused', (tester, now) async {
      await pumpScreen(tester);
      await tester.enterText(titleField(), '\t\n ');
      await tapSave(tester);

      expect(await stored(), isEmpty);
    });

    reminderWidgetTest('a real title surrounded by spaces is accepted, trimmed',
        (tester, now) async {
      // The guard must not overreach: padding is not emptiness.
      await pumpScreen(tester);
      await tester.enterText(titleField(), '  Take vitamins  ');
      await tapSave(tester);

      final saved = await stored();
      expect(saved, hasLength(1));
      expect(saved.single.title, 'Take vitamins');
    });
  });

  group('a one-off whose time has already passed', () {
    reminderWidgetTest('is rolled to tomorrow rather than fired instantly',
        (tester, now) async {
      // Picking 11:00 when it is already 13:00 used to arm an instant in the
      // past, which `zonedSchedule` delivers immediately — the reminder rings
      // while the user is still looking at the screen that created it.
      final twoHoursAgo = now.subtract(const Duration(hours: 2));
      await pumpScreen(tester, initialTime: twoHoursAgo, initialTitle: 'Walk');
      await tapSave(tester);

      final saved = await stored();
      expect(saved, hasLength(1));
      expect(saved.single.scheduledTime.isAfter(now), isTrue,
          reason: 'stored ${saved.single.scheduledTime}, now is $now');
    });

    reminderWidgetTest('keeps the clock time the user actually chose',
        (tester, now) async {
      // Rolling forward must move the DATE, not the time — arriving at 13:00
      // tomorrow when 11:00 was asked for is a different reminder.
      final twoHoursAgo = now.subtract(const Duration(hours: 2));
      await pumpScreen(tester, initialTime: twoHoursAgo, initialTitle: 'Walk');
      await tapSave(tester);

      final saved = (await stored()).single;
      expect(saved.scheduledTime.hour, twoHoursAgo.hour);
      expect(saved.scheduledTime.minute, twoHoursAgo.minute);
    });

    reminderWidgetTest('a future one-off is left exactly where it was put',
        (tester, now) async {
      // The roll-forward must not fire on a time that has not passed.
      final later = now.add(const Duration(hours: 2));
      await pumpScreen(tester, initialTime: later, initialTitle: 'Walk');
      await tapSave(tester);

      final saved = (await stored()).single;
      expect(saved.scheduledTime.day, later.day);
      expect(saved.scheduledTime.hour, later.hour);
    });
  });

  group('an end date that is before the start', () {
    reminderWidgetTest('leaves nothing armed', (tester, now) async {
      // A repeat that ended before it began has no occurrence to arm. What must
      // not happen is the screen reporting success and leaving a stale alarm.
      final scheduler = RecordingNotificationScheduler();
      NotificationService().schedulerForTesting = scheduler;

      await pumpScreen(
        tester,
        initialTitle: 'Stretch',
        initialTime: now.add(const Duration(hours: 1)),
        initialRepeat: RepeatType.daily,
        initialEndsAt: now.subtract(const Duration(days: 3)),
      );
      await tapSave(tester);

      expect(scheduler.scheduled, isEmpty,
          reason: 'an already-expired repeat must arm no notification');
    });

    reminderWidgetTest('an end date after the start still arms', (tester, now) async {
      // The complement, so the test above cannot pass by arming nothing ever.
      final scheduler = RecordingNotificationScheduler();
      NotificationService().schedulerForTesting = scheduler;

      await pumpScreen(
        tester,
        initialTitle: 'Stretch',
        initialTime: now.add(const Duration(hours: 1)),
        initialRepeat: RepeatType.daily,
        initialEndsAt: now.add(const Duration(days: 30)),
      );
      await tapSave(tester);

      expect(scheduler.scheduled, isNotEmpty);
    });
  });
}
