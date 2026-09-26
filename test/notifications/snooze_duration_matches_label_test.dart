/// The Snooze button promised one duration and the alarm delivered another.
///
/// Every alert is LABELLED with the reminder's own snooze duration — the button
/// literally reads "⏰ Snooze 30min", built from `alarmData['snoozeDuration']`
/// in `alarmCallback`. Both reschedule paths then ignored that value and
/// rearmed off the GLOBAL `snoozeIntervalMinutesKey` preference, so a reminder
/// the user had configured to snooze 30 minutes offered "Snooze 30min" and came
/// back in 5. The label was a lie, and the shorter interval also burned through
/// the snooze cap six times faster than the user had asked for.
///
/// Both paths are covered because they reschedule through different mechanisms:
/// an AlarmManager alarm carries a persisted `alarm_$id` blob, while a
/// `zonedSchedule` notification has nothing but its `alarm:{json}` payload.
///
/// Also covered: the "Snooze enabled" setting. It is mirrored into the alarm
/// isolate and was read by nothing, so a user who turned snoozing OFF was still
/// handed a Snooze button on every alert.
library;

import 'dart:convert';
import 'dart:ui' show CallbackHandle;

import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart'
    show AndroidFlutterLocalNotificationsPlugin;
// ignore: depend_on_referenced_packages
import 'package:flutter_local_notifications_platform_interface/flutter_local_notifications_platform_interface.dart'
    show FlutterLocalNotificationsPlatform;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/services/background_alarm_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  /// flutter_local_notifications' one method channel.
  const notificationsChannel =
      MethodChannel('dexterous.com/flutter/local_notifications');

  const baseId = 7711;
  const refireId = baseId + snoozeIdOffset;
  const snoozeTwinId = (refireId + snoozeIdOffset) & 0x7FFFFFFF;

  /// Every `Alarm.oneShotAt` registration, argument list as the plugin sends it
  /// (index 5 is the fire time in epoch milliseconds).
  late List<List<dynamic>> alarmRegistrations;

  /// Every `zonedSchedule` argument map.
  late List<Map<Object?, Object?>> zonedSchedules;

  /// Every `show` argument map — what a fired alarm actually posts.
  late List<Map<Object?, Object?>> shown;

  setUp(() {
    alarmRegistrations = [];
    zonedSchedules = [];
    shown = [];
    // A real callback handle is unavailable in a headless test, and without one
    // the plugin returns false before it ever reaches the channel.
    AndroidAlarmManager.setTestOverrides(
        getCallbackHandle: (_) => CallbackHandle.fromRawHandle(42));
    messenger.setMockMethodCallHandler(AndroidAlarmManager.channel,
        (call) async {
      if (call.method == 'Alarm.oneShotAt') {
        alarmRegistrations.add(call.arguments as List<dynamic>);
      }
      return true;
    });
    messenger.setMockMethodCallHandler(notificationsChannel, (call) async {
      if (call.method == 'zonedSchedule') {
        zonedSchedules.add(call.arguments as Map<Object?, Object?>);
      }
      if (call.method == 'show') {
        shown.add(call.arguments as Map<Object?, Object?>);
      }
      return true;
    });
    // flutter_local_notifications picks its platform implementation in its
    // constructor off dart:io's `Platform.isAndroid`, which is false on the
    // test host — so without this every call throws a LateInitializationError
    // before it can reach the mocked channel.
    FlutterLocalNotificationsPlatform.instance =
        AndroidFlutterLocalNotificationsPlugin();
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(AndroidAlarmManager.channel, null);
    messenger.setMockMethodCallHandler(notificationsChannel, null);
  });

  /// A persisted AlarmManager blob — the path a medicine alarm snoozes down.
  String blob({int? snoozeDuration}) => jsonEncode({
        'title': 'Take Metformin',
        'body': '500mg',
        'channelId': 'medicine_channel',
        'hour': 8,
        'minute': 0,
        'baseId': baseId,
        if (snoozeDuration != null) 'snoozeDuration': snoozeDuration,
      });

  /// An `alarm:` payload — the path a zonedSchedule'd generic reminder snoozes
  /// down (water, weekly/custom reminders, focus).
  String payload({int? snoozeDuration}) => 'alarm:${jsonEncode({
        'id': baseId,
        'title': 'Stretch your legs',
        'body': 'Been sitting a while',
        'baseId': baseId,
        if (snoozeDuration != null) 'snoozeDuration': snoozeDuration,
      })}';

  /// Minutes from now that the blob path armed its re-fire.
  int armedMinutesFromNow() {
    final startMillis = alarmRegistrations.single[5] as int;
    return DateTime.fromMillisecondsSinceEpoch(startMillis)
        .difference(DateTime.now())
        .inSeconds ~/
        60;
  }

  /// Minutes from now that the payload path armed its re-fire.
  int scheduledMinutesFromNow() {
    final iso = zonedSchedules.single['scheduledDateTimeISO8601'] as String;
    return DateTime.parse(iso).difference(DateTime.now()).inSeconds ~/ 60;
  }

  group('the reschedule honours the duration the button advertised', () {
    test('blob path: a 30-minute reminder comes back in 30, not the global 5',
        () async {
      SharedPreferences.setMockInitialValues({
        snoozeIntervalMinutesKey: 5,
        'alarm_$refireId': blob(snoozeDuration: 30),
      });

      await handleSnoozeAction(refireId, null);

      expect(alarmRegistrations, hasLength(1),
          reason: 'the snooze must actually be armed');
      expect(armedMinutesFromNow(), inInclusiveRange(29, 30),
          reason: 'the button said 30min; 5 is the global preference');

      // And the value survives the hop, so a second snooze is also 30.
      final prefs = await SharedPreferences.getInstance();
      final carried =
          jsonDecode(prefs.getString('alarm_$snoozeTwinId')!) as Map;
      expect(carried['snoozeDuration'], 30);
    });

    test('payload path: the same reminder rearms 30 minutes out', () async {
      SharedPreferences.setMockInitialValues({snoozeIntervalMinutesKey: 5});

      await handleSnoozeAction(refireId, payload(snoozeDuration: 30));

      expect(zonedSchedules, hasLength(1),
          reason: 'the snooze must actually be scheduled');
      expect(scheduledMinutesFromNow(), inInclusiveRange(29, 30));
    });
  });

  group('the global preference still applies when there is no per-reminder one',
      () {
    test('blob path falls back to the mirrored setting, not to 30', () async {
      SharedPreferences.setMockInitialValues({
        snoozeIntervalMinutesKey: 12,
        'alarm_$refireId': blob(),
      });

      await handleSnoozeAction(refireId, null);

      expect(armedMinutesFromNow(), inInclusiveRange(11, 12),
          reason: 'a reminder with no duration of its own uses the setting');
    });

    test('payload path falls back to the documented default with no setting',
        () async {
      SharedPreferences.setMockInitialValues({});

      await handleSnoozeAction(refireId, payload());

      expect(scheduledMinutesFromNow(),
          inInclusiveRange(defaultSnoozeIntervalMinutes - 1,
              defaultSnoozeIntervalMinutes));
    });
  });

  group('"Snooze enabled: off" removes the button', () {
    test('no snooze action on a dose or an alarm when it is off', () {
      for (final kind in [ReminderKind.dose, ReminderKind.alarm]) {
        for (final grouped in [false, true]) {
          final look = alarmPresentationFor(kind,
              isGroup: grouped, snoozeMinutes: 30, snoozeEnabled: false);
          expect(look.actions.map((a) => a.id), isNot(contains('snooze')),
              reason: '$kind (grouped: $grouped) offered Snooze after the '
                  'user turned snoozing off');
          expect(look.actions.length, lessThanOrEqualTo(3),
              reason: 'Android silently drops a 4th action');
        }
      }
    });

    test('the button is still there by default — the guard must not over-fire',
        () {
      for (final kind in [ReminderKind.dose, ReminderKind.alarm]) {
        final look = alarmPresentationFor(kind, snoozeMinutes: 30);
        expect(look.actions.map((a) => a.id), contains('snooze'));
      }
      // A gentle nudge never had one, on purpose.
      expect(
          alarmPresentationFor(ReminderKind.gentle, snoozeMinutes: 30).actions,
          isEmpty);
    });

    test('a dose keeps Take when Snooze is dropped', () {
      // The whole point of the notification: losing "✓ Take" to a settings
      // change would be a far worse regression than the one being fixed.
      final look = alarmPresentationFor(ReminderKind.dose,
          snoozeMinutes: 30, snoozeEnabled: false);
      expect(look.actions.map((a) => a.id), contains('take'));
      expect(look.offersDoseLogging, isTrue);
    });
  });

  group('a fired alarm reads the mirrored setting', () {
    /// The action ids on the notification the alarm actually posted.
    List<String> postedActionIds() {
      final specifics = shown.single['platformSpecifics'] as Map<Object?, Object?>;
      final actions = (specifics['actions'] as List).cast<Map<Object?, Object?>>();
      return actions.map((a) => a['id'].toString()).toList();
    }

    /// A plain generic reminder alarm — `ReminderKind.alarm`, so Snooze +
    /// Dismiss.
    String firedBlob() => jsonEncode({
          'title': 'Call Dr Rao',
          'body': 'Follow-up',
          'channelId': 'reminders_channel',
          'hour': 9,
          'minute': 0,
          'snoozeDuration': 30,
        });

    test('with snoozing turned off, no Snooze button is attached', () async {
      SharedPreferences.setMockInitialValues({
        snoozeEnabledKey: false,
        'alarm_$baseId': firedBlob(),
      });

      await alarmCallback(baseId);

      expect(shown, hasLength(1), reason: 'the alarm must still fire');
      expect(postedActionIds(), isNot(contains('snooze')),
          reason: 'the setting was mirrored to this isolate and read by '
              'nothing, so turning snoozing off did nothing at all');
      expect(postedActionIds(), contains('dismiss'),
          reason: 'the alert must stay dismissible');
    });

    test('with the setting absent the button is still offered', () async {
      SharedPreferences.setMockInitialValues({'alarm_$baseId': firedBlob()});

      await alarmCallback(baseId);

      expect(postedActionIds(), contains('snooze'),
          reason: 'snoozing is on unless the user turned it off');
    });
  });
}
