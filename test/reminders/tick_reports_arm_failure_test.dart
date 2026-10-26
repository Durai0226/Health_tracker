/// Ticking a repeating reminder confirms only what actually happened.
///
/// `_toggle` rolls a repeating reminder forward and re-arms it, then tells the
/// user "Marked done" — and it used to say that whatever `arm` answered.
/// `arm` is not decorative: `scheduleGenericReminder` returns the OS's verdict,
/// and on Android 14+ with SCHEDULE_EXACT_ALARM revoked AlarmManager refuses.
/// So the card vanished from Today under a success toast while its next
/// occurrence was never scheduled — the one thing the user has no way to check.
///
/// Driven through the real screen and the real `NotificationScheduler` seam, so
/// the refusal enters the app exactly where the OS's would.
///
/// Note for anyone extending this file: installing a scheduler is not optional
/// even when the test does not read it. `NotificationService().init()` never
/// completes in a headless test (it reaches for the timezone and the plugin),
/// so an un-injected `arm()` hangs forever and EVERYTHING after it in `_toggle`
/// — `_load()` and the toast — silently never runs. `schedulerForTesting` sets
/// `_isInitialized`, which is what makes the toast observable at all.
library;

import 'package:clock/clock.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart'
    show AppDatabase;
import 'package:tablet_remainder/core/database/daos/reminders_dao.dart'
    show genericReminderFollowUpOffset;
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

  /// Now, pinned. The anchor sits three days back so the reminder is overdue
  /// and the tick genuinely rolls it forward.
  final now = DateTime(2026, 6, 20, 12, 0);
  final anchor = DateTime(2026, 6, 17, 9, 0);

  /// A stable notification slot, so the refusal can be aimed at this reminder
  /// rather than at whatever `id.hashCode` happens to produce.
  const slot = 4242;

  setUpAll(() {
    // `scheduleGenericReminder` does `tz.TZDateTime.from(…, tz.local)`; an
    // uninitialised `tz.local` throws into its own outer catch and returns
    // false, which would make the FAILURE case pass for the wrong reason.
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

  Reminder daily() => Reminder(
        id: 'r-1',
        title: 'Water the plants',
        body: '',
        scheduledTime: anchor,
        repeatType: RepeatType.daily,
        notificationId: slot,
      );

  /// Fixed-frame pump, never `pumpAndSettle` — this screen runs animations that
  /// never settle.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 150));
    }
  }

  /// Drift's stream-query cancel schedules a zero-duration timer when the
  /// `StreamBuilder` unmounts; left to teardown it fails the test as a pending
  /// timer.
  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 10));
  }

  /// Mount the list and tick "Water the plants" off.
  Future<void> tickIt(WidgetTester tester) async {
    await CleanStorageService.saveReminder(daily());
    await CleanStorageService.recordDueReminderOccurrences();
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      home: const RemindersScreen(),
    ));
    await settle(tester);
    expect(find.text('Water the plants'), findsOneWidget,
        reason: 'the reminder must be on the list to be ticked');

    // The card's 44pt tick hit target, scoped to this card's row.
    final tick = find.descendant(
      of: find.ancestor(
          of: find.text('Water the plants'),
          matching: find.byType(IntrinsicHeight)),
      matching: find.byWidgetPredicate(
          (w) => w is SizedBox && w.width == 44 && w.height == 44),
    );
    // The card also carries a 44pt More trigger, LAST in the row; the tick is
    // the first of the two.
    expect(tick, findsNWidgets(2));
    await tester.tap(tick.first);
    await settle(tester);
  }

  testWidgets('a refused re-arm is reported, not confirmed as done',
      (tester) async {
    await withClock(Clock.fixed(now), () async {
      // The OS refuses with something that is NOT a permission downgrade, so
      // `zonedScheduleGuarded` rethrows instead of quietly falling back to an
      // inexact alarm — which is the shape that reaches
      // `scheduleGenericReminder`'s outer catch and makes `arm` answer false.
      scheduler.midCallError = PlatformException(
          code: 'invalid_argument', message: 'refused by the OS');
      scheduler.refuseExactMidCall.add(slot);

      await tickIt(tester);

      // The tick itself still stuck — this is a warning about the schedule,
      // not a failed tick.
      final rolled = (await CleanStorageService.getAllReminders()).single;
      expect(rolled.scheduledTime, DateTime(2026, 6, 21, 9, 0),
          reason: 'the roll-forward is persisted either way');

      expect(find.textContaining("couldn't be scheduled"), findsOneWidget,
          reason: 'the next occurrence was never armed and the user was told '
              'only "Marked done". Toast text on screen: '
              '${tester.widgetList<Text>(find.byType(Text)).map((t) => t.data)}');
      expect(find.text('Open settings'), findsOneWidget,
          reason: 'a warning with no way to act on it is still a dead end');
      expect(find.text('Marked done'), findsNothing,
          reason: 'a plain success toast is the defect');

      await unmount(tester);
    });
  });

  testWidgets('a successful re-arm still confirms with Undo', (tester) async {
    await withClock(Clock.fixed(now), () async {
      // The control. Without it, "always warn" would pass the test above.
      await tickIt(tester);

      expect(scheduler.armedIds, contains(slot),
          reason: 'the happy path must really arm — otherwise this control '
              'proves nothing');
      expect(find.text('Marked done'), findsOneWidget);
      expect(find.text('Undo'), findsOneWidget);
      expect(find.textContaining("couldn't be scheduled"), findsNothing);

      await unmount(tester);
    });
  });

  testWidgets('Undo survives an arm that throws', (tester) async {
    await withClock(Clock.fixed(now), () async {
      await tickIt(tester);
      expect(find.text('Undo'), findsOneWidget);

      // `arm` runs from the toast's action callback. An escaping throw there is
      // an unhandled async error that also skips `_load()`, so the row is put
      // back in the database while the list keeps showing the ticked state.
      //
      // Aimed at the FOLLOW-UP withdrawal, not at the schedule: `arm` calls
      // `cancelNotification(id + genericReminderFollowUpOffset)` outside any
      // guard, whereas `scheduleGenericReminder` catches its own failures and
      // returns false. Only the former can make `arm` actually throw.
      scheduler.failCancel.add(slot + genericReminderFollowUpOffset);

      await tester.tap(find.text('Undo'));
      await settle(tester);

      expect(tester.takeException(), isNull,
          reason: 'the throw escaped the toast action callback');
      final restored = (await CleanStorageService.getAllReminders()).single;
      expect(restored.scheduledTime, anchor,
          reason: 'Undo must roll scheduledTime back');
      expect(find.text('Water the plants'), findsOneWidget,
          reason: 'the list must have reloaded — _load() was skipped when the '
              'throw escaped');

      await unmount(tester);
    });
  });
}
