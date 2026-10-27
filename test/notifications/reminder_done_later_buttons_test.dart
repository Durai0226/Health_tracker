/// A reminder's notification says what the person can do with it: Done, Snooze,
/// Later.
///
/// Until now a reminder they made — "call the clinic" — could be snoozed or
/// dismissed from its notification and nothing else. Dismissing it left it open,
/// overdue, in the list; there was no way to say "I did it" without opening the
/// app. These tests pin the buttons, and what carries a reminder's identity to
/// them.
library;

import 'dart:convert';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tablet_remainder/core/services/background_alarm_service.dart';
import 'package:tablet_remainder/features/reminders/utils/reminder_payload.dart';

void main() {
  List<String> ids(AlarmPresentation look) => look.actions.map((a) => a.id).toList();

  group('a reminder the person made', () {
    test('alarm-grade: Done, Snooze, Later — in that order', () {
      final look = alarmPresentationFor(ReminderKind.alarm,
          snoozeMinutes: 10, reminderActions: true);
      expect(ids(look), [ReminderActions.doneId, 'snooze', ReminderActions.laterId]);
      expect(look.actions[0].title, '✓ Done');
      expect(look.actions[1].title, contains('10'),
          reason: 'the snooze label must reflect the interval actually used');
      expect(look.actions[2].title, 'Later');
    });

    test('every button clears the notification, and none opens the app', () {
      final look = alarmPresentationFor(ReminderKind.alarm,
          snoozeMinutes: 10, reminderActions: true);
      for (final a in look.actions) {
        expect(a.showsUserInterface, isFalse, reason: '${a.id} runs in the background');
      }
      // Snooze clears itself natively (the default), as it always did; Done and
      // Later say so explicitly, because an ongoing alarm cannot be swiped away.
      final done = look.actions.firstWhere((a) => a.id == ReminderActions.doneId);
      final later = look.actions.firstWhere((a) => a.id == ReminderActions.laterId);
      expect(done.cancelNotification, isTrue);
      expect(later.cancelNotification, isTrue);
    });

    test('with Snooze switched off, Dismiss takes the third place', () {
      final look = alarmPresentationFor(ReminderKind.alarm,
          snoozeMinutes: 10, snoozeEnabled: false, reminderActions: true);
      expect(ids(look), [ReminderActions.doneId, ReminderActions.laterId, 'dismiss'],
          reason: 'the setting removed the button; it did not remove the rest');
    });

    test('a quiet one has Done and Later, never Snooze', () {
      final look = alarmPresentationFor(ReminderKind.gentle,
          snoozeMinutes: 10, reminderActions: true);
      expect(ids(look), [ReminderActions.doneId, ReminderActions.laterId],
          reason: 'a nudge that offers Snooze trains the user to dismiss it');
      expect(look.fullScreenIntent, isFalse, reason: 'quiet stays quiet');
      expect(look.ongoing, isFalse);
    });

    test('never more than the three buttons Android shows', () {
      for (final kind in ReminderKind.values) {
        for (final snooze in [true, false]) {
          final look = alarmPresentationFor(kind,
              snoozeMinutes: 10, snoozeEnabled: snooze, reminderActions: true);
          expect(look.actions.length, lessThanOrEqualTo(3),
              reason: 'a 4th makes the last silently disappear ($kind, snooze: $snooze)');
        }
      }
    });
  });

  group('everything else is as it was', () {
    test('an alarm that is not a reminder in the list: Snooze and Dismiss', () {
      final look = alarmPresentationFor(ReminderKind.alarm, snoozeMinutes: 10);
      expect(ids(look), ['snooze', 'dismiss'],
          reason: 'the wake alarm has no "done" to mark');
    });

    test('a nudge: no buttons', () {
      expect(alarmPresentationFor(ReminderKind.gentle, snoozeMinutes: 10).actions,
          isEmpty);
    });

    test('a dose keeps its own buttons, whatever it is told', () {
      final look = alarmPresentationFor(ReminderKind.dose,
          snoozeMinutes: 10, reminderActions: true);
      expect(ids(look), ['take', 'snooze', 'dismiss']);
      expect(look.offersDoseLogging, isTrue);
    });

    test('Done and Later are never on a dose, and Take is never on a reminder',
        () {
      final reminder = alarmPresentationFor(ReminderKind.alarm,
          snoozeMinutes: 10, reminderActions: true);
      expect(reminder.offersDoseLogging, isFalse);
    });

    test('a mood check-in keeps its answer buttons', () {
      final look = alarmPresentationFor(ReminderKind.gentle,
          snoozeMinutes: 10, answers: NudgeAnswers.mood);
      expect(ids(look), NudgeAnswers.actionIds.where((i) => i.startsWith('mood_')).toList());
    });
  });

  group('the action ids', () {
    test('are two, and distinct from every other id in the app', () {
      expect(ReminderActions.ids, {'reminder_done', 'reminder_later'});
      expect(ReminderActions.ids.intersection(NudgeAnswers.actionIds), isEmpty);
      for (final taken in ['take', 'skip', 'snooze', 'dismiss', waterLogActionId]) {
        expect(ReminderActions.ids, isNot(contains(taken)));
      }
    });
  });

  group('which reminder a notification is', () {
    String payload(Map<String, Object?> m) => 'alarm:${jsonEncode(m)}';

    test('the id rides in the alarm payload', () {
      expect(
          reminderIdFromAlarmPayload(payload({'id': 5, 'reminderId': 'r-1'})), 'r-1');
    });

    test('a payload that names no reminder has none', () {
      expect(reminderIdFromAlarmPayload(payload({'id': 5, 'title': 'Metformin'})),
          isNull);
      expect(reminderIdFromAlarmPayload(payload({'reminderId': ''})), isNull);
      expect(reminderIdFromAlarmPayload(payload({'reminderId': 42})), isNull,
          reason: 'an id is a string');
    });

    test('anything that is not an alarm payload has none', () {
      expect(reminderIdFromAlarmPayload(null), isNull);
      expect(reminderIdFromAlarmPayload(''), isNull);
      expect(reminderIdFromAlarmPayload('refill:abc'), isNull);
      expect(reminderIdFromAlarmPayload('{"reminderId":"r-1"}'), isNull,
          reason: 'the alarm: prefix is the gate, as it is everywhere');
    });

    test('the legacy and the broken forms do not throw', () {
      expect(reminderIdFromAlarmPayload('alarm:1234'), isNull);
      expect(reminderIdFromAlarmPayload('alarm:{not json'), isNull);
      expect(reminderIdFromAlarmPayload('alarm:[1,2]'), isNull);
    });
  });

  test('the Done button\'s notification action is the one declared above', () {
    // The presentation's ids are what the handlers switch on; a typo in either
    // would produce a button that does nothing.
    final done = alarmPresentationFor(ReminderKind.alarm,
            snoozeMinutes: 5, reminderActions: true)
        .actions
        .first;
    expect(done, isA<AndroidNotificationAction>());
    expect(ReminderActions.ids, contains(done.id));
  });
}
