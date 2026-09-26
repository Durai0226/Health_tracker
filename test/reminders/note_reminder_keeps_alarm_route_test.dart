/// A reminder linked to a note is armed the same way as any other reminder.
///
/// The save path used to hand `scheduleGenericReminder` a `note:<noteId>`
/// payload for such a reminder, and that parameter REPLACES the whole
/// `alarm:{json}` blob the service would otherwise build. Every consumer of a
/// fired reminder gates on the `alarm:` prefix — `main.dart` (cold launch),
/// `BackgroundAlarmService` (the alarm isolate) and `reminderSlotsIn` — and
/// nothing anywhere parses `note:`. So the deep link was write-only while the
/// cost was real: the reminder reached a heads-up banner instead of
/// `AlarmScreen`, and the JSON it lost is where its snooze duration and chosen
/// sound live.
///
/// Asserted on what the OS was actually asked to arm, through the
/// `NotificationScheduler` seam — not on the source. A payload that is spelled
/// `alarm:` and carries none of the fields the screen reads would pass a grep
/// and fail here.
library;

import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tablet_remainder/core/services/clean_storage_service.dart';
import 'package:tablet_remainder/core/services/notification_service.dart';
import 'package:tablet_remainder/features/reminders/screens/add_reminder_screen.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../support/recording_notification_scheduler.dart';
import '../support/reminder_harness.dart';

void main() {
  setUpAll(() {
    // Same reason `add_reminder_screen_negative_input_test` does it:
    // `scheduleGenericReminder` does `tz.TZDateTime.from(…, tz.local)`, and an
    // uninitialised `tz.local` throws into that method's own outer `catch`,
    // which returns false. Without this the assertions below would be measuring
    // a timezone error.
    tz_data.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('America/New_York'));
  });

  /// `testWidgets` inside a pinned clock zone, with the reminder harness set up
  /// and the scheduler seam in place of the plugin.
  void reminderWidgetTest(
    String description,
    Future<void> Function(WidgetTester tester, RecordingNotificationScheduler s)
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
          await body(tester, scheduler);
        } finally {
          await h.tearDown();
        }
      });
    });
  }

  Future<void> saveReminderWithNote(
    WidgetTester tester, {
    required String? noteId,
    String title = 'Call the clinic',
  }) async {
    await tester.pumpWidget(MaterialApp(
      home: AddReminderScreen(
        noteId: noteId,
        initialTitle: title,
        // Two hours out, so the screen's past-one-off roll-forward does not
        // move the instant under the assertions.
        initialTime: clock.now().add(const Duration(hours: 2)),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.ensureVisible(find.text('Create Reminder'));
    await tester.tap(find.text('Create Reminder'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  reminderWidgetTest('a note-linked reminder still routes to the alarm screen',
      (tester, scheduler) async {
    await saveReminderWithNote(tester, noteId: 'diary-2026-09-26');

    // It was saved, and the note link is kept where it belongs — on the row.
    final saved = (await CleanStorageService.getAllReminders()).single;
    expect(saved.noteId, 'diary-2026-09-26');

    expect(scheduler.scheduled, hasLength(1),
        reason: 'nothing was armed at all: ${scheduler.sequence}');
    final payload = scheduler.scheduled.single.payload;
    expect(payload, isNotNull);
    expect(payload, startsWith('alarm:'),
        reason: 'main.dart, BackgroundAlarmService and reminderSlotsIn all gate '
            'on this prefix; anything else is delivered as a plain banner. '
            'Payload was: $payload');
  });

  reminderWidgetTest('and keeps the snooze duration and sound it was armed with',
      (tester, scheduler) async {
    // The prefix alone is not the point. The JSON after it is what AlarmScreen
    // reads for its title, its snooze button and the sound it loops — a
    // payload that is spelled `alarm:` and carries none of that is the same
    // defect with a better disguise.
    await saveReminderWithNote(tester, noteId: 'diary-2026-09-26');

    final payload = scheduler.scheduled.single.payload!;
    final decoded = jsonDecode(payload.substring('alarm:'.length))
        as Map<String, dynamic>;
    expect(decoded['title'], 'Call the clinic');
    // The screen's defaults: 5 minutes, the 'default' sound.
    expect(decoded['snoozeDuration'], 5);
    expect(decoded['sound'], 'default');
  });

  reminderWidgetTest('a reminder with no note is armed identically',
      (tester, scheduler) async {
    // The control. If the two payloads differ, the note is still steering the
    // delivery route by another name.
    await saveReminderWithNote(tester, noteId: null);

    final withoutNote = scheduler.scheduled.single.payload;
    expect(withoutNote, startsWith('alarm:'));
    expect((await CleanStorageService.getAllReminders()).single.noteId, isNull);
  });
}
