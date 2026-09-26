import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tablet_remainder/core/services/notification_service.dart';

/// The water-reminder sweep used to cancel 195 ids on every launch and every
/// Save — one `cancel()` platform round trip per id in both the current and the
/// legacy block, whether or not a single water reminder existed. Cancelling an
/// id that was never scheduled is a no-op with a round trip attached, so all of
/// that work bought nothing.
///
/// This file tests the decision — `staleWaterIdsIn`, the set intersection that
/// had the bug in it — as a pure function, with no service and no scheduler.
///
/// The cancelling itself is covered separately, in
/// `water_reminder_schedule_test.dart`, which drives `scheduleWaterReminderTimes`
/// through the `NotificationScheduler` seam and asserts what actually reaches the
/// OS. That split is deliberate: returning the right list and cancelling that
/// list are two different claims, and for a long time only the first was
/// asserted. (The seam did not exist when this file was written, which is why its
/// doc used to say the cancelling could not be observed headlessly. It can.)
void main() {
  const base = NotificationService.waterReminderBaseId; // 960000
  const legacy = NotificationService.legacyWaterReminderBaseId; // 900000

  group('the sweep only touches ids the OS actually holds', () {
    test('nothing pending means nothing cancelled', () {
      expect(NotificationService.staleWaterIdsIn(const []), isEmpty);
    });

    test('a user with three slots pays three cancels, not 195', () {
      final pending = [base, base + 1, base + 2];
      expect(NotificationService.staleWaterIdsIn(pending), pending);
    });

    test('ids in the range but NOT pending are never cancelled', () {
      // The regression: the old sweep generated the whole range regardless.
      final stale = NotificationService.staleWaterIdsIn([base + 7]);
      expect(stale, [base + 7]);
      expect(stale, isNot(contains(base)),
          reason: 'slot 0 was never scheduled, so there is nothing to cancel');
      expect(stale.length, lessThan(NotificationService.maxWaterReminders));
    });

    test('other features\' notifications are left alone', () {
      // Dose reminders, caregiver alerts, period reminders — all pending, none
      // of them water.
      final foreign = [100000, 100001, 920000, 930000, 990001];
      expect(NotificationService.staleWaterIdsIn(foreign), isEmpty);
    });
  });

  group('the legacy block is swept WITHOUT taking its squatters', () {
    // 900001 and 900020-900023 sit inside the legacy water range but belong to
    // onboarding and the four vitals reminders. A sweep that took them deleted
    // a user's blood-pressure reminder.
    const squatters = [900001, 900020, 900021, 900022, 900023];

    test('a leftover legacy water reminder is still cancelled', () {
      expect(NotificationService.staleWaterIdsIn([legacy + 5]), [legacy + 5]);
    });

    for (final id in squatters) {
      test('$id is never cancelled by a water sweep', () {
        expect(NotificationService.staleWaterIdsIn([id]), isEmpty);
      });
    }

    test('a mixed pending list keeps the squatters and drops the water', () {
      final pending = [...squatters, legacy + 5, base, 100000];
      final stale = NotificationService.staleWaterIdsIn(pending);
      expect(stale, containsAll([legacy + 5, base]));
      for (final id in squatters) {
        expect(stale, isNot(contains(id)));
      }
      expect(stale, isNot(contains(100000)));
    });
  });

  test('the batch checks permissions once, not once per slot', () {
    // `scheduleWaterReminder` checks permissions itself, so the scheduling loop
    // ran up to 100 permission round trips for one reschedule. The answer
    // cannot change midway through a loop that takes milliseconds.
    final src =
        File('lib/core/services/notification_service.dart').readAsStringSync();
    final from = src.indexOf('Future<int> scheduleWaterReminderTimes(');
    expect(from, greaterThan(-1), reason: 'method renamed? this guard is blind');
    // Bound to the next top-level declaration so the window cannot drift.
    final to = src.indexOf('DateTimeComponents _getMatchComponents(', from);
    expect(to, greaterThan(from));
    final body = src.substring(from, to);

    expect(body, contains('permissionsAlreadyChecked: true'),
        reason: 'the loop must tell scheduleWaterReminder the batch already '
            'checked, or every slot pays for its own check');
    expect(body, contains('await checkPermissions()'),
        reason: 'and the batch must actually check, once, up front');
  });
}
