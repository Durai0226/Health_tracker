import 'dart:convert';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/services/background_alarm_service.dart';
import 'package:tablet_remainder/core/services/dose_action_queue.dart';
import 'package:tablet_remainder/core/services/notification_service.dart'
    show notificationTapBackground;
import 'package:tablet_remainder/features/medication/services/reminder_window_nudges.dart';

/// Safety-critical reminder plumbing: a dose must be logged against the day it
/// was actually due, a repeating alarm must never skip a day, and a "✓ Take"
/// tapped on a notification must reach the dose queue no matter WHICH of the
/// app's two background handlers Android happens to invoke.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('resolveDoseInstant — the day a dose belongs to', () {
    test('a tap just after midnight belongs to YESTERDAY\'s dose', () {
      // 23:55 reminder, user taps "Take" at 00:05. Attributing it to "today"
      // logged the dose against the NEXT night's slot: the real dose stayed
      // missed and tomorrow showed a dose taken before it was even due.
      final tappedAt = DateTime(2026, 3, 2, 0, 5);
      expect(resolveDoseInstant(tappedAt, 23, 55), DateTime(2026, 3, 1, 23, 55));
    });

    test('a same-day tap keeps today', () {
      final tappedAt = DateTime(2026, 3, 1, 8, 5);
      expect(resolveDoseInstant(tappedAt, 8, 0), DateTime(2026, 3, 1, 8, 0));
    });

    test('an alarm delivered a hair EARLY still counts as today', () {
      // Within the grace window — must not be thrown a whole day back.
      final firedAt = DateTime(2026, 3, 1, 7, 59, 59);
      expect(resolveDoseInstant(firedAt, 8, 0), DateTime(2026, 3, 1, 8, 0));
    });

    test('crossing a month boundary rolls back to the right date', () {
      final tappedAt = DateTime(2026, 4, 1, 0, 10);
      expect(resolveDoseInstant(tappedAt, 23, 30), DateTime(2026, 3, 31, 23, 30));
    });

    test('crossing a year boundary rolls back to the right date', () {
      final tappedAt = DateTime(2027, 1, 1, 0, 10);
      expect(
          resolveDoseInstant(tappedAt, 23, 30), DateTime(2026, 12, 31, 23, 30));
    });
  });

  group('nextRepeatOccurrence — a repeating alarm must not skip a day', () {
    test('an ON-TIME fire arms tomorrow', () {
      final firedAt = DateTime(2026, 3, 1, 8, 0);
      expect(nextRepeatOccurrence(firedAt, 8, 0), DateTime(2026, 3, 2, 8, 0));
    });

    test('a LATE fire (reboot catch-up) still arms TODAY\'s dose', () {
      // The phone was off at 08:00 on the 1st; it boots at 07:00 on the 2nd and
      // AlarmManager delivers the overdue alarm immediately. The old
      // "today + 1 day" armed the 3rd and dropped the 2nd's dose entirely.
      final firedAt = DateTime(2026, 3, 2, 7, 0);
      expect(nextRepeatOccurrence(firedAt, 8, 0), DateTime(2026, 3, 2, 8, 0));
    });

    test('a fire a few seconds EARLY does not re-arm the same instant', () {
      final firedAt = DateTime(2026, 3, 1, 7, 59, 55);
      expect(nextRepeatOccurrence(firedAt, 8, 0), DateTime(2026, 3, 2, 8, 0));
    });

    test('month rollover', () {
      final firedAt = DateTime(2026, 3, 31, 8, 0);
      expect(nextRepeatOccurrence(firedAt, 8, 0), DateTime(2026, 4, 1, 8, 0));
    });

    test('weekdays frequency skips the weekend', () {
      // 2026-03-06 is a Friday.
      final friday = DateTime(2026, 3, 6, 8, 0);
      expect(friday.weekday, DateTime.friday);
      final next = nextRepeatOccurrence(friday, 8, 0, frequency: 'weekdays');
      expect(next, DateTime(2026, 3, 9, 8, 0));
      expect(next.weekday, DateTime.monday);
    });

    test('weekdays + a LATE Monday-morning delivery keeps Monday', () {
      final mondayEarly = DateTime(2026, 3, 9, 7, 0);
      expect(mondayEarly.weekday, DateTime.monday);
      expect(nextRepeatOccurrence(mondayEarly, 8, 0, frequency: 'weekdays'),
          DateTime(2026, 3, 9, 8, 0));
    });

    test('weekends frequency lands on a weekend day', () {
      final saturday = DateTime(2026, 3, 7, 8, 0);
      expect(saturday.weekday, DateTime.saturday);
      final next = nextRepeatOccurrence(saturday, 8, 0, frequency: 'weekends');
      expect(next, DateTime(2026, 3, 8, 8, 0));
      expect(next.weekday, DateTime.sunday);
    });
  });

  group('handleDoseNotificationAction', () {
    String payloadFor(Map<String, dynamic> data) => 'alarm:${jsonEncode(data)}';

    test('queues the dose at the instant stamped when the alarm fired', () async {
      final dose = DateTime(2026, 3, 1, 23, 55);
      await handleDoseNotificationAction(
        payloadFor({
          'medicineId': 'm1',
          'hour': 23,
          'minute': 55,
          'doseEpochMs': dose.millisecondsSinceEpoch,
        }),
        DoseActionQueue.actionTake,
      );

      final queued = await DoseActionQueue.drain();
      expect(queued, hasLength(1));
      expect(queued.single.medicineId, 'm1');
      expect(queued.single.scheduledTime, dose);
      expect(queued.single.isTake, isTrue);

      // The window-nudge suppression flag must key off the SAME instant, or a
      // later nudge would re-alert a dose the user already took.
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(nudgeResolvedKey('m1', dose)), isTrue);
    });

    test('an older payload with only hour:minute resolves to the most recent '
        'occurrence, never a future one', () async {
      final tenMinutesAgo = DateTime.now().subtract(const Duration(minutes: 10));
      await handleDoseNotificationAction(
        payloadFor({
          'medicineId': 'm1',
          'hour': tenMinutesAgo.hour,
          'minute': tenMinutesAgo.minute,
        }),
        DoseActionQueue.actionSkip,
      );

      final queued = await DoseActionQueue.drain();
      expect(queued, hasLength(1));
      expect(queued.single.isTake, isFalse);
      expect(
        queued.single.scheduledTime,
        DateTime(tenMinutesAgo.year, tenMinutesAgo.month, tenMinutesAgo.day,
            tenMinutesAgo.hour, tenMinutesAgo.minute),
      );
      expect(queued.single.scheduledTime.isAfter(DateTime.now()), isFalse);
    });

    test('"Take all" on a grouped slot queues every medicine at one instant',
        () async {
      final dose = DateTime(2026, 3, 1, 8, 0);
      await handleDoseNotificationAction(
        payloadFor({
          'medicines': [
            {'medicineId': 'm1', 'name': 'Metformin'},
            {'medicineId': 'm2', 'name': 'Ramipril'},
          ],
          'hour': 8,
          'minute': 0,
          'doseEpochMs': dose.millisecondsSinceEpoch,
        }),
        DoseActionQueue.actionTake,
      );

      final queued = await DoseActionQueue.drain();
      expect(queued.map((a) => a.medicineId), ['m1', 'm2']);
      expect(queued.every((a) => a.scheduledTime == dose), isTrue);
    });

    test('a non-medicine payload queues nothing', () async {
      await handleDoseNotificationAction(
          payloadFor({'title': 'Drink water'}), DoseActionQueue.actionTake);
      expect(await DoseActionQueue.drain(), isEmpty);
    });
  });

  group('notificationTapBackground (the handler a cold start installs)', () {
    test('"✓ Take" reaches the dose queue', () async {
      // flutter_local_notifications keeps ONE app-wide background callback
      // handle, so after any cold start it is THIS handler — not the alarm
      // isolate's — that Android invokes for a notification action. It used to
      // ignore take/skip outright, so the dose was never recorded.
      final dose = DateTime(2026, 3, 1, 8, 0);
      notificationTapBackground(NotificationResponse(
        notificationResponseType:
            NotificationResponseType.selectedNotificationAction,
        id: 100480,
        actionId: 'take',
        payload: 'alarm:${jsonEncode({
              'medicineId': 'm1',
              'hour': 8,
              'minute': 0,
              'doseEpochMs': dose.millisecondsSinceEpoch,
            })}',
      ));
      await pumpEventQueue();

      final queued = await DoseActionQueue.drain();
      expect(queued, hasLength(1));
      expect(queued.single.medicineId, 'm1');
      expect(queued.single.scheduledTime, dose);
      expect(queued.single.isTake, isTrue);
    });

    test('"✕ Skip" reaches the dose queue', () async {
      final dose = DateTime(2026, 3, 1, 8, 0);
      notificationTapBackground(NotificationResponse(
        notificationResponseType:
            NotificationResponseType.selectedNotificationAction,
        id: 100480,
        actionId: 'skip',
        payload: 'alarm:${jsonEncode({
              'medicineId': 'm1',
              'hour': 8,
              'minute': 0,
              'doseEpochMs': dose.millisecondsSinceEpoch,
            })}',
      ));
      await pumpEventQueue();

      final queued = await DoseActionQueue.drain();
      expect(queued, hasLength(1));
      expect(queued.single.isTake, isFalse);
    });
  });
}
