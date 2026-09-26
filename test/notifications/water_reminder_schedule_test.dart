import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/services/notification_service.dart';
import 'package:tablet_remainder/core/services/reminder_budget.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../support/recording_notification_scheduler.dart';

/// `scheduleWaterReminderTimes` — driven, not grepped.
///
/// This method had **no test that ran it**. Its sibling,
/// `water_reminder_sweep_test.dart`, tests `staleWaterIdsIn` — the pure set
/// intersection that decides *which* ids are stale — under a doc comment
/// explaining that the cancelling itself could not be observed headlessly,
/// because `FlutterLocalNotificationsPlugin` is a concrete class with no
/// injection seam. That was true when it was written and is not true now:
/// `NotificationScheduler` is the seam, and everything the method does to the
/// OS — what it cancels, in which order, under which id, at which wall time,
/// and how much of the batch survives the pending-notification budget — is a
/// recorded call on the double.
///
/// The distinction matters because `staleWaterIdsIn` returning the right list
/// and `scheduleWaterReminderTimes` actually cancelling that list are two
/// different claims. The first was asserted; the second never was.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const base = NotificationService.waterReminderBaseId; // 960000
  const legacy = NotificationService.legacyWaterReminderBaseId; // 900000

  late RecordingNotificationScheduler scheduler;

  setUpAll(() {
    tz_data.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('America/New_York'));
  });

  setUp(() {
    // `zonedScheduleGuarded` records the exact-alarm downgrade flag here.
    SharedPreferences.setMockInitialValues(<String, Object>{});
    scheduler = RecordingNotificationScheduler();
    NotificationService().schedulerForTesting = scheduler;
  });

  /// One pending registration as the OS would report it.
  PendingNotificationRequest pendingId(int id) =>
      PendingNotificationRequest(id, null, null, null);

  // 08:00 and 12:30, as minutes since midnight.
  const morning = 8 * 60;
  const midday = 12 * 60 + 30;

  group('the stale sweep', () {
    test('cancels only the water ids the OS actually holds', () async {
      // The regression this guards: the sweep used to cancel all 195 ids in
      // both blocks unconditionally, on every launch and every Save.
      scheduler.pending = [
        pendingId(base),
        pendingId(base + 1),
        pendingId(base + 7),
      ];

      await NotificationService().scheduleWaterReminderTimes([morning]);

      expect(scheduler.cancelled, [base, base + 1, base + 7]);
      expect(scheduler.cancelled.length,
          lessThan(NotificationService.maxWaterReminders),
          reason: 'three pending slots must cost three cancels, not 195');
    });

    test('nothing pending costs no cancels at all', () async {
      scheduler.pending = [];

      await NotificationService().scheduleWaterReminderTimes([morning]);

      expect(scheduler.cancelled, isEmpty);
    });

    test('ids another feature owns in the legacy block survive', () async {
      // 900020-900023 are the vitals reminders and 900001 is onboarding's daily
      // check-in. They sit inside the legacy water range, and a water sweep that
      // took the whole range deleted them outright.
      scheduler.pending = [
        pendingId(legacy + 20), // vitals: blood pressure
        pendingId(legacy + 1), // onboarding daily check-in
        pendingId(legacy + 30), // a genuinely stale legacy water reminder
      ];

      await NotificationService().scheduleWaterReminderTimes([morning]);

      expect(scheduler.cancelled, [legacy + 30]);
      expect(scheduler.cancelled, isNot(contains(legacy + 20)));
      expect(scheduler.cancelled, isNot(contains(legacy + 1)));
    });

    test('other features\' notifications are never touched', () async {
      scheduler.pending = [
        pendingId(100000), // a dose slot
        pendingId(920000), // a caregiver alert
        pendingId(990001), // a period reminder
      ];

      await NotificationService().scheduleWaterReminderTimes([morning]);

      expect(scheduler.cancelled, isEmpty);
      expect(scheduler.cancelAllCount, 0,
          reason: 'a water reschedule must never reach for cancelAll');
    });

    test('every cancel precedes every arm', () async {
      // Ordering is the whole safety property: arming base+0 before cancelling
      // the old base+0 leaves the OS holding a registration nothing can reach.
      scheduler.pending = [pendingId(base), pendingId(base + 1)];

      await NotificationService()
          .scheduleWaterReminderTimes([morning, midday]);

      final lastCancel =
          scheduler.sequence.lastIndexWhere((s) => s.startsWith('cancel:'));
      final firstArm =
          scheduler.sequence.indexWhere((s) => s.startsWith('arm:'));

      expect(lastCancel, greaterThanOrEqualTo(0));
      expect(firstArm, greaterThanOrEqualTo(0));
      expect(lastCancel, lessThan(firstArm),
          reason: 'sequence was ${scheduler.sequence}');
    });
  });

  group('what gets armed', () {
    test('one reminder per requested time, at base + index', () async {
      final count = await NotificationService()
          .scheduleWaterReminderTimes([morning, midday]);

      expect(count, 2);
      expect(scheduler.armedIds, [base, base + 1]);
    });

    test('each is armed at the wall time asked for', () async {
      await NotificationService()
          .scheduleWaterReminderTimes([morning, midday]);

      final first = scheduler.lastFor(base)!;
      final second = scheduler.lastFor(base + 1)!;

      expect([first.when.hour, first.when.minute], [8, 0]);
      expect([second.when.hour, second.when.minute], [12, 30]);
    });

    test('each repeats daily rather than firing once', () async {
      // Without `DateTimeComponents.time` the reminder fires tomorrow and then
      // never again — and the settings toggle still reads "On".
      await NotificationService().scheduleWaterReminderTimes([morning]);

      expect(scheduler.lastFor(base)!.matchDateTimeComponents,
          DateTimeComponents.time);
    });

    test('a time already past today is armed for tomorrow, never the past',
        () async {
      // Arming an instant in the past makes the OS fire immediately, so a user
      // saving an 08:00 slot in the afternoon got an instant buzz.
      //
      // Clamped rather than skipped. Written as a bare `- 5` it goes negative
      // for the first five minutes of the local day, and the guard that
      // protected against that was `if (justPast < 0) return;` — an early
      // return that reports a PASS for a scenario it never reached. Minute 0 is
      // itself in the past by however many seconds have elapsed, because the
      // slot is built with hour/minute and zero seconds, so the clamp keeps the
      // case reachable at every instant instead.
      final now = tz.TZDateTime.now(tz.local);
      final nowMinutes = now.hour * 60 + now.minute;
      final justPast = nowMinutes >= 5 ? nowMinutes - 5 : 0;

      await NotificationService().scheduleWaterReminderTimes([justPast]);

      expect(scheduler.lastFor(base)!.when.isAfter(now), isTrue,
          reason: 'armed at ${scheduler.lastFor(base)!.when}, now is $now');
    });

    test('requesting none arms none', () async {
      final count = await NotificationService().scheduleWaterReminderTimes([]);

      expect(count, 0);
      expect(scheduler.scheduled, isEmpty);
    });
  });

  group('the pending-notification budget', () {
    test('water yields when the OS ceiling is nearly full', () async {
      // iOS keeps only the soonest-firing 64 pending requests and silently
      // discards the rest, so an unbounded water fan-out does not merely fail to
      // arm — it evicts dose reminders, which are further out. Water is a
      // `gentle` nudge and yields first, by design.
      //
      // The pending count is derived, not hardcoded: the ceiling is the iOS cap
      // only on iOS, and this test runs on the host, where `Platform.isIOS` is
      // false and the Android cap applies. A hardcoded 200 left 292 slots free
      // and truncated nothing — the test passed only once this was computed.
      final usable =
          ReminderBudget.usable(ReminderBudget.ceilingFor());
      scheduler.pending = [
        for (int i = 0; i < usable - 1; i++) pendingId(100000 + i),
      ];

      final count = await NotificationService()
          .scheduleWaterReminderTimes([morning, midday, 14 * 60]);

      expect(count, 1,
          reason: 'one free slot must arm exactly one of the three requested');
      expect(scheduler.scheduled.length, count,
          reason: 'the returned count must match what was actually armed');
    });

    test('a ceiling already exceeded arms nothing rather than overflowing',
        () async {
      final usable = ReminderBudget.usable(ReminderBudget.ceilingFor());
      scheduler.pending = [
        for (int i = 0; i < usable + 50; i++) pendingId(100000 + i),
      ];

      final count = await NotificationService()
          .scheduleWaterReminderTimes([morning, midday]);

      expect(count, 0);
      expect(scheduler.scheduled, isEmpty);
    });

    test('slots just cancelled do not count against their own headroom',
        () async {
      // The reschedule re-uses the ids it just swept, so counting them as
      // occupied would shrink the budget by exactly the amount being freed.
      //
      // THE CEILING MUST BE NEARLY FULL for this to mean anything. Written with
      // three pending slots against a 492-slot budget it passed whether the
      // sweep was subtracted or not — 489 slots were free either way, so the
      // branch it names was never reached. Mutation-checked: with the ceiling
      // filled, dropping `- cancelled` arms 1 of the 3 instead of 3.
      final usable = ReminderBudget.usable(ReminderBudget.ceilingFor());
      const waterHeld = NotificationService.maxWaterReminders; // 100, all swept
      scheduler.pending = [
        for (int i = 0; i < waterHeld; i++) pendingId(base + i),
        // Foreign ids filling the rest of the budget bar one slot. These are
        // NOT swept, so they are the only thing that may count against it.
        for (int i = 0; i < usable - waterHeld - 1; i++) pendingId(100000 + i),
      ];

      final count = await NotificationService()
          .scheduleWaterReminderTimes([morning, midday, 14 * 60]);

      expect(count, 3,
          reason: 'the 100 water slots just cancelled are free again; only the '
              'foreign ids may reduce the budget');
      expect(scheduler.armedIds, [base, base + 1, base + 2]);
    });
  });
}
