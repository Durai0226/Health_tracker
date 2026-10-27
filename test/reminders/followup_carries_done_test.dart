/// "Still pending: Call the clinic" is where Done matters most.
///
/// An insistent reminder arms a second notification half an hour after the first,
/// for something not yet marked done. That follow-up used to carry no payload, so
/// it had no reminder to act on: no Done, no Later, and nothing for a tap on its
/// body to open. It now names the reminder like the first notification does.
library;

import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/services/background_alarm_service.dart';
import 'package:tablet_remainder/features/reminders/models/reminder_escalation.dart';
import 'package:tablet_remainder/features/reminders/utils/reminder_payload.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel(
          'dev.fluttercommunity.plus/android_alarm_manager', JSONMethodCodec()),
      (call) async => true,
    );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('dev.fluttercommunity.plus/android_alarm_manager',
                JSONMethodCodec()),
            null);
  });

  Future<Map<String, dynamic>> armFollowUp() async {
    final due = DateTime(2030, 1, 7, 9);
    final ok = await BackgroundAlarmService().scheduleReminderFollowUp(
      id: 7000,
      reminderId: 'r-1',
      occurrenceDue: due,
      fireAt: due.add(const Duration(minutes: 30)),
      title: 'Still pending: Call the clinic',
      body: 'About the results',
      escalation: ReminderEscalation.insistent,
    );
    expect(ok, isTrue);
    final prefs = await SharedPreferences.getInstance();
    return jsonDecode(prefs.getString('alarm_7000')!) as Map<String, dynamic>;
  }

  test('the follow-up\'s payload names its reminder', () async {
    final blob = await armFollowUp();
    expect(reminderIdFromAlarmPayload(blob['payload'] as String?), 'r-1');
  });

  test('and carries what the alarm screen and the buttons read', () async {
    final blob = await armFollowUp();
    final payload = blob['payload'] as String;
    final m = jsonDecode(payload.substring('alarm:'.length)) as Map;
    expect(m['id'], 7000, reason: 'its own notification id, so dismiss and snooze act on it');
    expect(m['title'], 'Still pending: Call the clinic');
    expect(m['body'], 'About the results');
  });

  test('so its notification offers Done and Later', () async {
    final blob = await armFollowUp();
    final kind = ReminderKind.fromBlob(blob);
    final look = alarmPresentationFor(kind,
        snoozeMinutes: 5,
        reminderActions: reminderIdFromAlarmPayload(blob['payload'] as String?) != null);
    expect(look.actions.map((a) => a.id),
        containsAll([ReminderActions.doneId, ReminderActions.laterId]));
  });

  test('the rest of the blob is as it was: still a follow-up, still resolvable',
      () async {
    final blob = await armFollowUp();
    expect(blob['isReminderFollowUp'], isTrue);
    expect(blob['reminderId'], 'r-1');
    expect(blob['occurrenceMs'], DateTime(2030, 1, 7, 9).millisecondsSinceEpoch);
    expect(blob['escalation'], 'insistent');
  });

  test('a Done tapped on the follow-up takes the follow-up itself away', () async {
    final blob = await armFollowUp();
    await handleReminderAction(7000, blob['payload'] as String?,
        ReminderActions.doneId, at: DateTime(2030, 1, 7, 9, 31));
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('alarm_7000'), isNull,
        reason: 'it must not go on asking about something that is done');
    expect(
        prefs.getBool(reminderResolvedKey('r-1', DateTime(2030, 1, 7, 9))), isTrue);
  });
}
