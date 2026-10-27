/// "Quiet — a silent notification" is silent.
///
/// The picker promised it, and the reminder went to the same channel as Normal,
/// which makes a sound: the two tiers differed only on the picker. A Quiet
/// reminder now has a channel with no sound and no vibration (a channel's sound is
/// fixed when it is created, so silence cannot be a per-notification option), and
/// puts itself off to Later quietly too.
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_local_notifications_platform_interface/flutter_local_notifications_platform_interface.dart'
    show FlutterLocalNotificationsPlatform;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/services/background_alarm_service.dart';
import 'package:tablet_remainder/core/services/notification_service.dart';
import 'package:tablet_remainder/features/reminders/models/reminder_model.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../support/recording_notification_scheduler.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('the kind', () {
    test('a quiet reminder is not alarm-grade, and is not a check-in either', () {
      expect(ReminderKind.quiet.isAlarmGrade, isFalse);
      expect(ReminderKind.gentle.isAlarmGrade, isFalse);
      expect(ReminderKind.dose.isAlarmGrade, isTrue);
      expect(ReminderKind.alarm.isAlarmGrade, isTrue);
      expect(ReminderKind.quiet, isNot(ReminderKind.gentle));
    });

    test('is written to an alarm blob by name and read back', () {
      expect(ReminderKind.fromBlob({'kind': 'quiet'}), ReminderKind.quiet);
      expect(ReminderKind.fromBlob({'kind': ReminderKind.quiet.name}), ReminderKind.quiet);
    });

    test('the Quiet tier is the quiet kind, and no other tier is', () {
      expect([
        for (final e in ReminderEscalation.values)
          if (e.kind == ReminderKind.quiet) e
      ], [ReminderEscalation.gentle]);
    });
  });

  group('the presentation', () {
    test('has no sound, no buzz, no screen takeover and sits low', () {
      final look = alarmPresentationFor(ReminderKind.quiet, snoozeMinutes: 5);
      expect(look.channelId, quietChannelId);
      expect(look.playSound, isFalse);
      expect(look.vibrates, isFalse);
      expect(look.vibrationPattern, isEmpty);
      expect(look.importance, Importance.low);
      expect(look.priority, Priority.low);
      expect(look.fullScreenIntent, isFalse);
      expect(look.ongoing, isFalse);
      expect(look.autoCancel, isTrue);
      expect(look.audioUsage, AudioAttributesUsage.notification);
    });

    test('keeps Done and Later for a reminder the person made, and never Snooze', () {
      final look = alarmPresentationFor(ReminderKind.quiet,
          snoozeMinutes: 5, reminderActions: true);
      expect([for (final a in look.actions) a.id],
          [ReminderActions.doneId, ReminderActions.laterId]);
    });

    test('has no buttons for something that is not a reminder in the list', () {
      expect(
          alarmPresentationFor(ReminderKind.quiet, snoozeMinutes: 5).actions, isEmpty);
    });

    test('and a requested alarm channel never overrides it', () {
      final look = alarmPresentationFor(ReminderKind.quiet,
          snoozeMinutes: 5, requestedChannelId: 'reminders_channel');
      expect(look.channelId, quietChannelId,
          reason: 'reminders_channel is created on the alarm stream: a Quiet '
              'reminder posted there rings');
    });

    test('Normal still makes its sound: the negative control', () {
      final look = alarmPresentationFor(ReminderKind.gentle, snoozeMinutes: 5);
      expect(look.channelId, 'checkin_channel');
      expect(look.playSound, isTrue);
      expect(look.vibrates, isTrue);
    });
  });

  group('armed on a schedule', () {
    late RecordingNotificationScheduler rec;

    setUpAll(() {
      tz_data.initializeTimeZones();
      tz.setLocalLocation(tz.getLocation('UTC'));
    });

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      rec = RecordingNotificationScheduler();
      NotificationService().schedulerForTesting = rec;
    });

    final monday9 = DateTime(2030, 1, 7, 9);

    Future<void> arm(ReminderEscalation escalation,
        {RepeatType repeat = RepeatType.weekly, String? reminderId = 'r-1'}) async {
      final ok = await NotificationService().scheduleGenericReminder(
        id: 4321,
        title: 'Water the plants',
        body: '',
        scheduledTime: monday9,
        repeatType: repeat,
        escalation: escalation,
        reminderId: reminderId,
      );
      expect(ok, isTrue);
    }

    AndroidNotificationDetails android(RecordedSchedule s) => s.details!.android!;

    test('a Quiet weekly reminder: its own channel, no sound, no buzz', () async {
      await arm(ReminderEscalation.gentle);
      final a = android(rec.scheduled.single);
      expect(a.channelId, quietChannelId);
      expect(a.playSound, isFalse);
      expect(a.enableVibration, isFalse);
      expect(a.importance, Importance.low);
      expect(a.fullScreenIntent, isFalse);
      expect(rec.scheduled.single.details!.iOS!.presentSound, isFalse,
          reason: 'and on iPhone');
    });

    test('a Normal one is untouched: the check-in channel, with its sound', () async {
      await arm(ReminderEscalation.standard);
      final a = android(rec.scheduled.single);
      expect(a.channelId, 'checkin_channel');
      expect(a.playSound, isTrue);
      expect(a.enableVibration, isTrue);
      expect(rec.scheduled.single.details!.iOS!.presentSound, isTrue);
    });

    test('an Insistent one is still the alarm', () async {
      await arm(ReminderEscalation.insistent);
      final a = android(rec.scheduled.single);
      expect(a.channelId, 'alarm_channel');
      expect(a.playSound, isTrue);
    });

    test('every weekday of a Quiet weekdays reminder is quiet', () async {
      await arm(ReminderEscalation.gentle, repeat: RepeatType.weekdays);
      expect(rec.scheduled, hasLength(5));
      for (final s in rec.scheduled) {
        expect(android(s).channelId, quietChannelId, reason: '${s.id}');
        expect(android(s).playSound, isFalse, reason: '${s.id}');
      }
    });

    test('its payload says it is quiet, so a Later brings it back quiet; Normal does not',
        () async {
      await arm(ReminderEscalation.gentle);
      final quiet = jsonDecode(
          rec.scheduled.single.payload!.substring('alarm:'.length)) as Map;
      expect(quiet['quiet'], isTrue);

      rec.scheduled.clear();
      await arm(ReminderEscalation.standard);
      final normal = jsonDecode(
          rec.scheduled.single.payload!.substring('alarm:'.length)) as Map;
      expect(normal.containsKey('quiet'), isFalse);
    });

    test('every registration of a repeat on chosen days knows it is quiet', () async {
      for (final repeat in [RepeatType.weekdays, RepeatType.weekends]) {
        rec.scheduled.clear();
        await arm(ReminderEscalation.gentle, repeat: repeat);
        expect(rec.scheduled, isNotEmpty);
        for (final s in rec.scheduled) {
          final payload =
              jsonDecode(s.payload!.substring('alarm:'.length)) as Map;
          expect(payload['quiet'], isTrue,
              reason: '$repeat registration ${s.id}: a Later tapped on any one of '
                  'them is rebuilt from this payload alone');
        }
      }

      rec.scheduled.clear();
      final ok = await NotificationService().scheduleGenericReminder(
        id: 4322,
        title: 'Water the plants',
        body: '',
        scheduledTime: monday9,
        repeatType: RepeatType.custom,
        customDays: const [1, 3, 5],
        escalation: ReminderEscalation.gentle,
        reminderId: 'r-2',
      );
      expect(ok, isTrue);
      expect(rec.scheduled, hasLength(3));
      for (final s in rec.scheduled) {
        expect((jsonDecode(s.payload!.substring('alarm:'.length)) as Map)['quiet'],
            isTrue);
      }
    });

    test('a Quiet reminder still carries Done and Later', () async {
      await arm(ReminderEscalation.gentle);
      expect([for (final a in android(rec.scheduled.single).actions ?? const <AndroidNotificationAction>[]) a.id],
          [ReminderActions.doneId, ReminderActions.laterId]);
    });
  });

  group('put off to Later, and fired', () {
    final notificationCalls = <MethodCall>[];
    final alarmManagerCalls = <MethodCall>[];

    setUp(() {
      notificationCalls.clear();
      alarmManagerCalls.clear();
      SharedPreferences.setMockInitialValues({});
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(
        const MethodChannel(
            'dev.fluttercommunity.plus/android_alarm_manager', JSONMethodCodec()),
        (call) async {
          alarmManagerCalls.add(call);
          return true;
        },
      );
      messenger.setMockMethodCallHandler(
        const MethodChannel('dexterous.com/flutter/local_notifications'),
        (call) async {
          notificationCalls.add(call);
          return switch (call.method) {
            'canScheduleExactNotifications' => true,
            'initialize' => true,
            _ => null,
          };
        },
      );
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      FlutterLocalNotificationsPlatform.instance =
          AndroidFlutterLocalNotificationsPlugin();
    });

    tearDown(() {
      debugDefaultTargetPlatformOverride = null;
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(
          const MethodChannel('dev.fluttercommunity.plus/android_alarm_manager',
              JSONMethodCodec()),
          null);
      messenger.setMockMethodCallHandler(
          const MethodChannel('dexterous.com/flutter/local_notifications'), null);
    });

    const id = 5000;
    final tap = DateTime(2026, 10, 27, 13, 0);

    String payload({bool quiet = false}) => 'alarm:${jsonEncode({
          'id': id,
          'title': 'Water the plants',
          'body': '',
          'snoozeDuration': 10,
          'baseId': id,
          'reminderId': 'r-1',
          if (quiet) 'quiet': true,
        })}';

    Map<String, Object?> laterDetails() {
      final scheduled =
          notificationCalls.where((c) => c.method == 'zonedSchedule').toList();
      expect(scheduled, hasLength(1), reason: 'registered once');
      final args = Map<String, Object?>.from(scheduled.single.arguments as Map);
      return Map<String, Object?>.from(args['platformSpecifics'] as Map);
    }

    test('a Quiet reminder comes back quiet: no sound, no screen takeover', () async {
      await handleReminderAction(id, payload(quiet: true), ReminderActions.laterId,
          at: tap);

      final d = laterDetails();
      expect(d['channelId'], quietChannelId);
      expect(d['playSound'], isFalse);
      expect(d['enableVibration'], isFalse);
      expect(d['fullScreenIntent'], anyOf(isNull, isFalse),
          reason: 'it used to return as a full-screen alarm');
    });

    test('and keeps Done and Later on the re-fire', () async {
      await handleReminderAction(id, payload(quiet: true), ReminderActions.laterId,
          at: tap);
      final actions = (laterDetails()['actions'] as List)
          .map((a) => (a as Map)['id'])
          .toList();
      expect(actions, [ReminderActions.doneId, ReminderActions.laterId]);
    });

    test('a Normal reminder\'s Later is as it was: the alarm channel', () async {
      await handleReminderAction(id, payload(), ReminderActions.laterId, at: tap);
      final d = laterDetails();
      expect(d['channelId'], 'alarm_channel');
      expect(d['playSound'], isTrue);
    });

    group('and when the alarm fires', () {
      String blob(String kind) => jsonEncode({
            'title': 'Water the plants',
            'body': '',
            'channelId': 'reminders_channel',
            'channelName': 'General Reminders',
            'kind': kind,
            'isRepeating': false,
            'snoozeDuration': 10,
            'payload': payload(quiet: kind == 'quiet'),
          });

      Map<String, Object?> posted() {
        final shown = notificationCalls.where((c) => c.method == 'show').toList();
        expect(shown, hasLength(1), reason: 'the alarm must still fire');
        final args = Map<String, Object?>.from(shown.single.arguments as Map);
        return Map<String, Object?>.from(args['platformSpecifics'] as Map);
      }

      test('a Quiet one posts to the quiet channel with no sound and no buzz',
          () async {
        SharedPreferences.setMockInitialValues({'alarm_$id': blob('quiet')});
        await alarmCallback(id);

        final d = posted();
        expect(d['channelId'], quietChannelId,
            reason: 'not the reminders_channel its caller asked for: that one is '
                'on the alarm stream, and a Quiet reminder posted there rings');
        expect(d['playSound'], isFalse);
        expect(d['enableVibration'], isFalse);
        expect(d['fullScreenIntent'], anyOf(isNull, isFalse));
        expect([for (final a in d['actions'] as List) (a as Map)['id']],
            [ReminderActions.doneId, ReminderActions.laterId]);
      });

      test('an alarm-grade one is as it was', () async {
        SharedPreferences.setMockInitialValues({'alarm_$id': blob('alarm')});
        await alarmCallback(id);

        final d = posted();
        expect(d['channelId'], 'reminders_channel');
        expect(d['playSound'], isTrue);
        expect(d['enableVibration'], isTrue);
        expect(d['fullScreenIntent'], isTrue);
      });
    });
  });
}
