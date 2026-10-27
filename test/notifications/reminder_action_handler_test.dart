/// What the Done and Later buttons do when they are tapped — in the background
/// isolate with the app closed, or the foreground handler with it open.
///
/// Neither can write the database from where the tap lands (a background isolate
/// has no Drift), so the answer is queued for the main isolate. What cannot wait
/// happens at once: a Later rings again at its time, a Done withdraws the
/// follow-up that would nag about something finished.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_local_notifications_platform_interface/flutter_local_notifications_platform_interface.dart'
    show FlutterLocalNotificationsPlatform;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/services/background_alarm_service.dart';
import 'package:tablet_remainder/core/services/notification_service.dart';
import 'package:tablet_remainder/core/services/reminder_action_queue.dart';
import 'package:tablet_remainder/core/services/snooze_log.dart';
import 'package:tablet_remainder/features/reminders/utils/reminder_later.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// Everything asked of the two plugins this code reaches, answered "fine".
  final alarmManagerCalls = <MethodCall>[];
  final notificationCalls = <MethodCall>[];

  setUp(() {
    alarmManagerCalls.clear();
    notificationCalls.clear();
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
        // The questions the code asks before it schedules.
        return switch (call.method) {
          'canScheduleExactNotifications' => true,
          'initialize' => true,
          _ => null,
        };
      },
    );
    // The plugin picks its implementation from the platform. Say Android, so the
    // calls it makes are the ones a phone would receive — buttons included.
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

  const notificationId = 5000;
  final tap = DateTime(2026, 10, 27, 13, 0);

  String payload({String? reminderId = 'r-1', Map<String, Object?> extra = const {}}) =>
      'alarm:${jsonEncode({
        'id': notificationId,
        'title': 'Call the clinic',
        'body': 'About the results',
        'snoozeDuration': 10,
        'baseId': notificationId,
        if (reminderId != null) 'reminderId': reminderId,
        ...extra,
      })}';

  /// The blob an AlarmManager-armed reminder leaves behind. With [carriedBaseId]
  /// it is the re-fire of a snooze: the base its count belongs to rides along.
  String alarmBlob({int? carriedBaseId}) => jsonEncode({
        'title': 'Call the clinic',
        'body': 'About the results',
        'channelId': 'reminders_channel',
        'channelName': 'General Reminders',
        'isRepeating': false,
        'snoozeDuration': 10,
        'payload': payload(),
        if (carriedBaseId != null) 'baseId': carriedBaseId,
      });

  Future<SharedPreferences> prefsWith(Map<String, Object> initial) async {
    SharedPreferences.setMockInitialValues(initial);
    return SharedPreferences.getInstance();
  }

  group('Done', () {
    test('is queued, with who and the moment of the tap', () async {
      await prefsWith({});
      final ours = await handleReminderAction(
          notificationId, payload(), ReminderActions.doneId, at: tap);

      expect(ours, isTrue);
      final pending = await ReminderActionQueue.drain();
      expect(pending, hasLength(1));
      expect(pending.single.reminderId, 'r-1');
      expect(pending.single.action, ReminderNotificationAction.done);
      expect(pending.single.at, tap);
      expect(pending.single.laterAt, isNull);
    });

    test('a payload that names no reminder is ours, and queues nothing', () async {
      await prefsWith({});
      final ours = await handleReminderAction(
          notificationId, payload(reminderId: null), ReminderActions.doneId,
          at: tap);
      expect(ours, isTrue, reason: 'the tap was ours; there is just nothing to do');
      expect(await ReminderActionQueue.drain(), isEmpty);
    });

    test('withdraws the follow-up of THIS reminder, and stamps its occurrence resolved',
        () async {
      final dueMs = tap.millisecondsSinceEpoch;
      final prefs = await prefsWith({
        'alarm_${notificationId + 2000}': jsonEncode({
          'isReminderFollowUp': true,
          'reminderId': 'r-1',
          'occurrenceMs': dueMs,
          'title': 'Still pending: Call the clinic',
        }),
        // Another reminder's follow-up, and an ordinary alarm: neither is ours.
        'alarm_7100': jsonEncode({
          'isReminderFollowUp': true,
          'reminderId': 'r-2',
          'occurrenceMs': dueMs,
        }),
        'alarm_8000': jsonEncode({'title': 'Metformin', 'reminderId': 'r-1'}),
      });

      await handleReminderAction(
          notificationId, payload(), ReminderActions.doneId, at: tap);

      expect(prefs.getString('alarm_${notificationId + 2000}'), isNull,
          reason: 'the follow-up is gone: "Still pending" about a finished thing');
      expect(
          prefs.getBool(reminderResolvedKey(
              'r-1', DateTime.fromMillisecondsSinceEpoch(dueMs))),
          isTrue,
          reason: 'and if it fires anyway, it finds the occurrence resolved');
      expect(prefs.getString('alarm_7100'), isNotNull,
          reason: 'another reminder\'s follow-up is not touched');
      expect(prefs.getString('alarm_8000'), isNotNull,
          reason: 'nor an alarm that is not a follow-up');
      expect(prefs.getBool(reminderResolvedKey(
              'r-2', DateTime.fromMillisecondsSinceEpoch(dueMs))),
          isNull);
    });

    test('with no follow-up armed, there is simply nothing to withdraw',
        () async {
      final prefs = await prefsWith({'alarm_9': 'not json at all'});
      await handleReminderAction(
          notificationId, payload(), ReminderActions.doneId, at: tap);
      expect(prefs.getString('alarm_9'), 'not json at all',
          reason: 'a blob it cannot read is left as it was');
      expect((await ReminderActionQueue.drain()), hasLength(1));
    });
  });

  group('Later', () {
    test('is queued with the time it was set to ring again', () async {
      await prefsWith({'alarm_$notificationId': alarmBlob()});
      await handleReminderAction(
          notificationId, payload(), ReminderActions.laterId, at: tap);

      final pending = await ReminderActionQueue.drain();
      expect(pending.single.action, ReminderNotificationAction.later);
      expect(pending.single.reminderId, 'r-1');
      expect(pending.single.laterAt, DateTime(2026, 10, 27, 18),
          reason: 'before 17:00: this evening');
    });

    test('after 17:00 it is tomorrow morning', () async {
      await prefsWith({'alarm_$notificationId': alarmBlob()});
      final evening = DateTime(2026, 10, 27, 19, 30);
      await handleReminderAction(
          notificationId, payload(), ReminderActions.laterId, at: evening);
      final laterAt = (await ReminderActionQueue.drain()).single.laterAt;
      expect(laterAt, ReminderLater.from(evening));
      expect(laterAt, DateTime(2026, 10, 28, 9, 30));
    });

    test('rings again at that time, as itself: the same title, no snooze marker',
        () async {
      final prefs = await prefsWith({'alarm_$notificationId': alarmBlob()});
      await handleReminderAction(
          notificationId, payload(), ReminderActions.laterId, at: tap);

      final ringId = notificationId + snoozeIdOffset;
      final again = jsonDecode(prefs.getString('alarm_$ringId')!) as Map;
      expect(again['title'], 'Call the clinic',
          reason: 'a Later is not a snooze: no "⏰" in front of it');
      expect(again['isRepeating'], isFalse);
      expect(again['payload'], contains('"reminderId":"r-1"'),
          reason: 'the re-fire still knows which reminder it is, so it has Done too');

      final armed = alarmManagerCalls.where((c) => c.method == 'Alarm.oneShotAt');
      expect(armed, hasLength(1));
      final args = armed.single.arguments as List;
      expect(args[0], ringId);
      expect(args[5], DateTime(2026, 10, 27, 18).millisecondsSinceEpoch,
          reason: 'at the evening slot exactly, not "snooze minutes from now"');
    });

    test('is not a snooze: no count, no log, and the cap does not stop it',
        () async {
      // Tapped on the re-fire of a reminder already snoozed past its cap: a
      // snooze would be refused here, with a final "no more snoozing" notice.
      final counterKey = snoozeCountKeyFor(notificationId);
      const refireId = notificationId + snoozeIdOffset;
      final prefs = await prefsWith({
        'alarm_$refireId': alarmBlob(carriedBaseId: notificationId),
        maxSnoozeCountKey: 1,
        counterKey: 5,
      });

      await handleReminderAction(refireId, payload(), ReminderActions.laterId,
          at: tap);

      expect(prefs.getInt(counterKey), 5, reason: 'not counted as a snooze');
      expect(prefs.getStringList(SnoozeLog.keyFor(notificationId)), isNull,
          reason: 'nor logged: the tune-up would tell them they snooze it');
      expect(prefs.getString('alarm_${refireId + snoozeIdOffset}'), isNotNull,
          reason: 'a person who has snoozed to the cap can still put it off to '
              'the evening — that is the point of Later');
    });

    test('a reminder armed by zonedSchedule (no blob) rings again from its payload',
        () async {
      final prefs = await prefsWith({});
      await handleReminderAction(
          notificationId, payload(), ReminderActions.laterId, at: tap);

      final scheduled =
          notificationCalls.where((c) => c.method == 'zonedSchedule').toList();
      expect(scheduled, hasLength(1),
          reason: 'registered through the one guarded scheduler');
      final args = Map<String, Object?>.from(scheduled.single.arguments as Map);
      expect(args['id'], notificationId + snoozeIdOffset);
      expect(args['title'], 'Call the clinic', reason: 'not "⏰ Snoozed: …"');
      expect(args['payload'], contains('"reminderId":"r-1"'));
      expect(prefs.getInt(snoozeCountKeyFor(notificationId)), isNull,
          reason: 'not counted');
      // At the evening slot exactly, not "snooze minutes from now".
      // The plugin writes the wall time in the zone it was given; this isolate's
      // zone is UTC here (no device to ask), so the string is UTC without a mark.
      final raw = args['scheduledDateTime'] as String;
      final instant = DateTime.parse(RegExp(r'(Z|[+-]\d\d:?\d\d)$').hasMatch(raw) ? raw : '${raw}Z');
      expect(instant.isAtSameMomentAs(DateTime(2026, 10, 27, 18)), isTrue,
          reason: 'got $raw');

      // The re-fire carries the buttons the reminder was first shown with: a
      // Later that dropped Done would be the one place the person cannot say it.
      final buttons = [
        for (final a in (args['platformSpecifics'] as Map)['actions'] as List)
          (a as Map)['id']
      ];
      expect(buttons, [ReminderActions.doneId, 'snooze', ReminderActions.laterId]);
    });

    test('through its payload, the cap does not stop it either', () async {
      final counterKey = snoozeCountKeyFor(notificationId);
      final prefs = await prefsWith({maxSnoozeCountKey: 1, counterKey: 5});
      await handleReminderAction(
          notificationId + snoozeIdOffset, payload(), ReminderActions.laterId,
          at: tap);

      expect(prefs.getInt(counterKey), 5);
      expect(prefs.getStringList(SnoozeLog.keyFor(notificationId)), isNull);
      expect(
          notificationCalls.where((c) => c.method == 'zonedSchedule'), hasLength(1),
          reason: 'it rang again rather than showing the "snooze limit reached" '
              'notice');
    });

    test('a payload with no reminder in it keeps the old Snooze and Dismiss',
        () async {
      await prefsWith({});
      await handleSnoozeAction(notificationId, payload(reminderId: null));
      final scheduled =
          notificationCalls.where((c) => c.method == 'zonedSchedule').toList();
      final args = Map<String, Object?>.from(scheduled.single.arguments as Map);
      final buttons = [
        for (final a in (args['platformSpecifics'] as Map)['actions'] as List)
          (a as Map)['id']
      ];
      expect(buttons, ['snooze', 'dismiss'],
          reason: 'a dose or a water nudge is not a reminder with a "done"');
    });
  });

  group('not ours', () {
    test('an action the reminders do not own is declined, and nothing is queued',
        () async {
      await prefsWith({});
      for (final id in ['take', 'snooze', 'dismiss', 'mood_good', null]) {
        expect(await handleReminderAction(notificationId, payload(), id, at: tap),
            isFalse,
            reason: '$id');
      }
      expect(await ReminderActionQueue.drain(), isEmpty);
    });
  });

  group('the background handler', () {
    NotificationResponse response(String actionId) => NotificationResponse(
          notificationResponseType: NotificationResponseType.selectedNotificationAction,
          id: notificationId,
          actionId: actionId,
          payload: payload(),
        );

    test('routes Done and Later to the one function', () async {
      await prefsWith({'alarm_$notificationId': alarmBlob()});
      notificationTapBackground(response(ReminderActions.doneId));
      notificationTapBackground(response(ReminderActions.laterId));
      await Future<void>.delayed(const Duration(milliseconds: 100));

      final pending = await ReminderActionQueue.drain();
      expect(pending.map((p) => p.action), unorderedEquals([
        ReminderNotificationAction.done,
        ReminderNotificationAction.later,
      ]));
    });
  });

  group('the foreground handler', () {
    NotificationResponse response(String actionId, {String? body}) =>
        NotificationResponse(
          notificationResponseType: NotificationResponseType.selectedNotificationAction,
          id: notificationId,
          actionId: actionId,
          payload: body ?? payload(),
        );

    test('a Done tapped with the app open queues the same answer', () async {
      await prefsWith({});
      NotificationService().onNotificationResponseForTesting(
          response(ReminderActions.doneId));
      // The handler is fire-and-forget (a notification callback is void), so
      // give its async body a turn.
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final pending = await ReminderActionQueue.drain();
      expect(pending, hasLength(1));
      expect(pending.single.reminderId, 'r-1');
      expect(pending.single.action, ReminderNotificationAction.done);
    });

    test('a Later tapped with the app open queues and rings again too', () async {
      await prefsWith({'alarm_$notificationId': alarmBlob()});
      NotificationService().onNotificationResponseForTesting(
          response(ReminderActions.laterId));
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final pending = await ReminderActionQueue.drain();
      expect(pending.single.action, ReminderNotificationAction.later);
      expect(
          alarmManagerCalls.where((c) => c.method == 'Alarm.oneShotAt'), hasLength(1));
    });
  });

  // Three response handlers receive a notification's buttons — the background
  // one, the one `alarmCallback` registers, and the foreground one — because
  // flutter_local_notifications keeps ONE app-wide background callback and which
  // it is depends on what ran last. Each must know the two ids, or a Done tapped
  // under one of them does nothing. The first and third are exercised above; the
  // one inside `alarmCallback` cannot be called, so it is pinned here.
  test('alarmCallback\'s own response handler routes them too', () {
    final src = File('lib/core/services/background_alarm_service.dart')
        .readAsStringSync();
    final start = src.indexOf('onDidReceiveNotificationResponse: (NotificationResponse response) async {');
    expect(start, greaterThan(0));
    final end = src.indexOf('onDidReceiveBackgroundNotificationResponse', start);
    final handler = src.substring(start, end);
    expect(handler, contains('ReminderActions.ids.contains(response.actionId)'));
    expect(handler, contains('handleReminderAction('));
  });
}
