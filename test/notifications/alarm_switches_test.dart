/// Vibration, Keep on screen and Full-screen alerts are honoured by the alarm.
///
/// Three switches on the Notification settings screen were read by the
/// notifications the app posts itself and by nothing on the alarm path — which is
/// where every Android medicine reminder goes. `alarmPresentationFor` hardcoded
/// all three, so turning them off changed nothing about the notification that
/// matters most. They are mirrored into preferences for the alarm isolate (it has
/// no database) and read from there on every path that rings: the alarm itself,
/// the re-fire after Snooze or Later, and a reminder armed on a schedule.
///
/// Everything defaults to what the alarm always did.
library;

import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_local_notifications_platform_interface/flutter_local_notifications_platform_interface.dart'
    show FlutterLocalNotificationsPlatform;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' show AppDatabase;
import 'package:tablet_remainder/core/models/user_settings.dart';
import 'package:tablet_remainder/core/services/background_alarm_service.dart';
import 'package:tablet_remainder/core/services/clean_storage_service.dart';
import 'package:tablet_remainder/core/services/notification_service.dart';
import 'package:tablet_remainder/features/reminders/models/reminder_model.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../support/recording_notification_scheduler.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const off = AlarmSwitches(vibrate: false, fullScreen: false, persistent: false);

  AlarmPresentation look(ReminderKind kind, {AlarmSwitches? switches}) =>
      alarmPresentationFor(kind,
          snoozeMinutes: 10,
          switches: switches ?? const AlarmSwitches());

  group('the presentation, with every switch on — as it always was', () {
    test('a dose or an alarm buzzes, takes the screen and stays until answered', () {
      for (final kind in [ReminderKind.dose, ReminderKind.alarm]) {
        final l = look(kind);
        expect(l.vibrationPattern, [0, 1000, 500, 1000, 500, 1000], reason: '$kind');
        expect(l.fullScreenIntent, isTrue, reason: '$kind');
        expect(l.ongoing, isTrue, reason: '$kind');
        expect(l.autoCancel, isFalse, reason: '$kind');
      }
    });

    test('a nudge buzzes lightly and goes when swiped', () {
      final l = look(ReminderKind.gentle);
      expect(l.vibrationPattern, [0, 250, 250, 250]);
      expect(l.fullScreenIntent, isFalse);
      expect(l.ongoing, isFalse);
      expect(l.autoCancel, isTrue);
    });

    test('a quiet reminder makes no sound and no buzz', () {
      final l = look(ReminderKind.quiet);
      expect(l.vibrates, isFalse);
      expect(l.playSound, isFalse);
    });
  });

  group('the channel without the buzz', () {
    // On Android 8+ a channel's vibration is fixed when it is created, and every
    // alarm-grade channel was created with it on: `enableVibration` on a single
    // notification is ignored. So Vibration off has to be a different channel.
    test('is the same id with a suffix, and the quiet channel is left alone', () {
      expect(stillChannelId('alarm_channel'), 'alarm_channel_still');
      expect(stillChannelId('medicine_channel'), 'medicine_channel_still');
      expect(stillChannelId(quietChannelId), quietChannelId,
          reason: 'it has no vibration to remove');
    });

    test('asking twice gives the same channel, not a suffix on a suffix', () {
      expect(stillChannelId(stillChannelId('alarm_channel')), 'alarm_channel_still');
      expect(stillChannelName(stillChannelName('Alarm Reminders')),
          'Alarm Reminders (no vibration)');
    });

    test('is what a person reads in the phone\'s settings', () {
      expect(stillChannelName('Medicine Reminders'), 'Medicine Reminders (no vibration)');
    });
  });

  group('Vibration off', () {
    test('posts every buzzing kind to the channel without the buzz', () {
      for (final kind in [ReminderKind.dose, ReminderKind.alarm]) {
        final l = look(kind, switches: const AlarmSwitches(vibrate: false));
        expect(l.channelId, 'alarm_channel_still', reason: '$kind');
        expect(l.channelName, 'Alarm Reminders (no vibration)', reason: '$kind');
      }
      final asked = alarmPresentationFor(ReminderKind.dose,
          snoozeMinutes: 10,
          requestedChannelId: 'medicine_channel',
          requestedChannelName: 'Medicine Reminders',
          switches: const AlarmSwitches(vibrate: false));
      expect(asked.channelId, 'medicine_channel_still');
      expect(asked.channelName, 'Medicine Reminders (no vibration)');
      final nudge = look(ReminderKind.gentle, switches: const AlarmSwitches(vibrate: false));
      expect(nudge.channelId, 'checkin_channel_still');
    });

    test('and a quiet reminder stays where it was', () {
      final l = look(ReminderKind.quiet, switches: const AlarmSwitches(vibrate: false));
      expect(l.channelId, quietChannelId);
      expect(l.channelName, 'Quiet Reminders');
    });

    test('with it on, the channels are the ones they always were', () {
      expect(look(ReminderKind.dose).channelId, 'alarm_channel');
      expect(look(ReminderKind.gentle).channelId, 'checkin_channel');
      expect(look(ReminderKind.quiet).channelId, quietChannelId);
    });

    test('silences the buzz of every kind', () {
      for (final kind in ReminderKind.values) {
        final l = look(kind, switches: const AlarmSwitches(vibrate: false));
        expect(l.vibrates, isFalse, reason: '$kind');
        expect(l.vibrationPattern, isEmpty, reason: '$kind');
      }
    });

    test('and nothing else about a dose alarm', () {
      final l = look(ReminderKind.dose, switches: const AlarmSwitches(vibrate: false));
      expect(l.fullScreenIntent, isTrue);
      expect(l.ongoing, isTrue);
      expect(l.playSound, isTrue, reason: 'the sound is the channel\'s, and unchanged');
    });
  });

  group('Full-screen alerts off', () {
    test('a dose or an alarm no longer takes the screen', () {
      for (final kind in [ReminderKind.dose, ReminderKind.alarm]) {
        final l = look(kind, switches: const AlarmSwitches(fullScreen: false));
        expect(l.fullScreenIntent, isFalse, reason: '$kind');
        expect(l.category, AndroidNotificationCategory.alarm, reason: 'it is still an alarm');
        expect(l.vibrates, isTrue);
        expect(l.ongoing, isTrue);
      }
    });

    test('a nudge never did, and still does not', () {
      expect(look(ReminderKind.gentle).fullScreenIntent, isFalse);
      expect(look(ReminderKind.gentle, switches: off).fullScreenIntent, isFalse);
    });
  });

  group('Keep on screen off', () {
    test('a dose or an alarm can be swiped away', () {
      for (final kind in [ReminderKind.dose, ReminderKind.alarm]) {
        final l = look(kind, switches: const AlarmSwitches(persistent: false));
        expect(l.ongoing, isFalse, reason: '$kind');
        expect(l.autoCancel, isTrue, reason: '$kind');
        expect(l.fullScreenIntent, isTrue);
        expect(l.vibrates, isTrue);
      }
    });

    test('a nudge was always swipeable', () {
      final l = look(ReminderKind.gentle, switches: const AlarmSwitches(persistent: false));
      expect(l.ongoing, isFalse);
      expect(l.autoCancel, isTrue);
    });
  });

  group('the switches as stored', () {
    test('are on when nothing has been stored', () async {
      SharedPreferences.setMockInitialValues({});
      final s = AlarmSwitches.fromPrefs(await SharedPreferences.getInstance());
      expect((s.vibrate, s.fullScreen, s.persistent), (true, true, true));
    });

    test('are read as stored', () async {
      SharedPreferences.setMockInitialValues({
        kAlarmVibrationPref: false,
        kAlarmFullScreenPref: true,
        kAlarmPersistentPref: false,
      });
      final s = AlarmSwitches.fromPrefs(await SharedPreferences.getInstance());
      expect((s.vibrate, s.fullScreen, s.persistent), (false, true, false));
    });

    test('are mirrored from the settings when they are saved', () async {
      SharedPreferences.setMockInitialValues({});
      await CleanStorageService.mirrorSettingsForAlarmIsolate(UserSettings(
        vibrationEnabled: false,
        fullScreenNotification: false,
        persistentNotification: false,
      ));
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(kAlarmVibrationPref), isFalse);
      expect(prefs.getBool(kAlarmFullScreenPref), isFalse);
      expect(prefs.getBool(kAlarmPersistentPref), isFalse);

      await CleanStorageService.mirrorSettingsForAlarmIsolate(UserSettings());
      expect(prefs.getBool(kAlarmVibrationPref), isTrue);
      expect(prefs.getBool(kAlarmFullScreenPref), isTrue);
      expect(prefs.getBool(kAlarmPersistentPref), isTrue);
    });

    test('each is mirrored from its own setting, not from another', () async {
      SharedPreferences.setMockInitialValues({});
      await CleanStorageService.mirrorSettingsForAlarmIsolate(
          UserSettings(vibrationEnabled: false));
      var prefs = await SharedPreferences.getInstance();
      expect((prefs.getBool(kAlarmVibrationPref), prefs.getBool(kAlarmFullScreenPref),
          prefs.getBool(kAlarmPersistentPref)), (false, true, true));

      await CleanStorageService.mirrorSettingsForAlarmIsolate(
          UserSettings(fullScreenNotification: false));
      prefs = await SharedPreferences.getInstance();
      expect((prefs.getBool(kAlarmVibrationPref), prefs.getBool(kAlarmFullScreenPref),
          prefs.getBool(kAlarmPersistentPref)), (true, false, true));

      await CleanStorageService.mirrorSettingsForAlarmIsolate(
          UserSettings(persistentNotification: false));
      prefs = await SharedPreferences.getInstance();
      expect((prefs.getBool(kAlarmVibrationPref), prefs.getBool(kAlarmFullScreenPref),
          prefs.getBool(kAlarmPersistentPref)), (true, true, false));
    });
  });

  group('on the platform channel, where the notification is actually posted', () {
    final notificationCalls = <MethodCall>[];

    setUp(() {
      notificationCalls.clear();
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(
        const MethodChannel(
            'dev.fluttercommunity.plus/android_alarm_manager', JSONMethodCodec()),
        (call) async => true,
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
    // The real now, not a date picked when the test was written: the plugin refuses
    // to schedule a time that has passed by the REAL clock, and a Later is set for
    // 18:00 or tomorrow at 09:30 from the tap — so a fixed tap passed on the day it
    // was written and failed from the evening on.
    final tap = DateTime.now();

    String payload() => 'alarm:${jsonEncode({
          'id': id,
          'title': 'Water the plants',
          'body': '',
          'snoozeDuration': 10,
          'baseId': id,
          'reminderId': 'r-1',
        })}';

    String blob(String kind) => jsonEncode({
          'title': 'Water the plants',
          'body': '',
          'channelId': 'reminders_channel',
          'channelName': 'General Reminders',
          'kind': kind,
          'isRepeating': false,
          'snoozeDuration': 10,
          'payload': payload(),
        });

    Map<String, Object?> posted() {
      final shown = notificationCalls.where((c) => c.method == 'show').toList();
      expect(shown, hasLength(1), reason: 'the alarm must still fire');
      final args = Map<String, Object?>.from(shown.single.arguments as Map);
      return Map<String, Object?>.from(args['platformSpecifics'] as Map);
    }

    Map<String, Object?> laterDetails() {
      final scheduled =
          notificationCalls.where((c) => c.method == 'zonedSchedule').toList();
      expect(scheduled, hasLength(1), reason: 'registered once');
      final args = Map<String, Object?>.from(scheduled.single.arguments as Map);
      return Map<String, Object?>.from(args['platformSpecifics'] as Map);
    }

    group('when the alarm fires', () {
      test('with every switch on it is as it was', () async {
        SharedPreferences.setMockInitialValues({'alarm_$id': blob('dose')});
        await alarmCallback(id);

        final d = posted();
        expect(d['enableVibration'], isTrue);
        expect(d['fullScreenIntent'], isTrue);
        expect(d['ongoing'], isTrue);
        expect(d['autoCancel'], isFalse);
      });

      test('Vibration off: it does not buzz — it posts to the channel that cannot', () async {
        SharedPreferences.setMockInitialValues({
          'alarm_$id': blob('dose'),
          kAlarmVibrationPref: false,
        });
        await alarmCallback(id);

        final d = posted();
        expect(d['channelId'], 'reminders_channel_still',
            reason: 'Android 8+ ignores the per-notification flag: the channel decides');
        expect(d['enableVibration'], isFalse);
        expect(d['vibrationPattern'], isNull);
        expect(d['fullScreenIntent'], isTrue, reason: 'only the one switch');
        expect(d['ongoing'], isTrue);
      });

      test('Full-screen alerts off: it does not take the screen', () async {
        SharedPreferences.setMockInitialValues({
          'alarm_$id': blob('dose'),
          kAlarmFullScreenPref: false,
        });
        await alarmCallback(id);

        final d = posted();
        expect(d['fullScreenIntent'], anyOf(isNull, isFalse));
        expect(d['enableVibration'], isTrue);
        expect(d['ongoing'], isTrue);
      });

      test('Keep on screen off: it can be swiped away', () async {
        SharedPreferences.setMockInitialValues({
          'alarm_$id': blob('dose'),
          kAlarmPersistentPref: false,
        });
        await alarmCallback(id);

        final d = posted();
        expect(d['ongoing'], anyOf(isNull, isFalse));
        expect(d['autoCancel'], isTrue);
        expect(d['fullScreenIntent'], isTrue);
        expect(d['enableVibration'], isTrue);
      });
    });

    group('a window nudge, "Still time for X"', () {
      // The follow-ups of a dose whose window is still open posted to
      // `medicine_channel` — which was created buzzing — whatever Vibration said, so
      // with it off the first alarm was silent and "Still time for X" was not.
      String nudgeBlob() => jsonEncode({
            'title': 'Time for Metformin',
            'body': 'Medicine reminder',
            'channelId': 'medicine_channel',
            'channelName': 'Medicine Reminders',
            'kind': 'dose',
            'isWindowNudge': true,
            'isRepeating': false,
            'medicineId': 'm-1',
            'medicineName': 'Metformin',
            'hour': 8,
            'minute': 0,
            'nudgeIndex': 1,
            'nudgeMinutes': [0, 30, 60],
          });

      Map<String, Object?> nudgePosted() {
        final shown = notificationCalls.where((c) => c.method == 'show').toList();
        expect(shown, hasLength(1), reason: 'the nudge must still be shown');
        final args = Map<String, Object?>.from(shown.single.arguments as Map);
        return Map<String, Object?>.from(args['platformSpecifics'] as Map);
      }

      test('with every switch on it is as it was: the medicine channel, buzzing', () async {
        SharedPreferences.setMockInitialValues({'alarm_$id': nudgeBlob()});
        await alarmCallback(id);

        final d = nudgePosted();
        expect(d['channelId'], 'medicine_channel');
        expect(d['enableVibration'], isTrue);
      });

      test('Vibration off: the channel that does not buzz, and no buzz asked for', () async {
        SharedPreferences.setMockInitialValues({
          'alarm_$id': nudgeBlob(),
          kAlarmVibrationPref: false,
        });
        await alarmCallback(id);

        final d = nudgePosted();
        expect(d['channelId'], 'medicine_channel_still');
        expect(d['channelName'], 'Medicine Reminders (no vibration)');
        expect(d['enableVibration'], isFalse);
      });

      test('and as the dose alarm that shares the channel posts it: a true twin', () async {
        // Whichever of the two posts to `medicine_channel_still` first creates it, with
        // its importance and audio, which Android never lets change. If the nudge made
        // it a high-importance channel on the notification stream, every dose alarm
        // after it would stop ringing as an alarm.
        SharedPreferences.setMockInitialValues({
          'alarm_$id': nudgeBlob(),
          kAlarmVibrationPref: false,
        });
        await alarmCallback(id);

        final d = nudgePosted();
        final dose = alarmPresentationFor(ReminderKind.dose,
            snoozeMinutes: 10,
            requestedChannelId: 'medicine_channel',
            requestedChannelName: 'Medicine Reminders',
            switches: const AlarmSwitches(vibrate: false));
        expect(d['importance'], dose.importance.value);
        expect(d['priority'], dose.priority.value);
        expect(d['audioAttributesUsage'], dose.audioUsage.value);
        expect(d['channelId'], dose.channelId);
      });
    });

    group('put off to Later, it comes back the same way', () {
      test('with every switch on, as it did', () async {
        SharedPreferences.setMockInitialValues({});
        await handleReminderAction(id, payload(), ReminderActions.laterId, at: tap);

        final d = laterDetails();
        expect(d['channelId'], 'alarm_channel');
        expect(d['enableVibration'], isTrue);
        expect(d['fullScreenIntent'], isTrue);
        expect(d['ongoing'], isTrue);
        expect(d['autoCancel'], isFalse);
      });

      test('Vibration off', () async {
        SharedPreferences.setMockInitialValues({kAlarmVibrationPref: false});
        await handleReminderAction(id, payload(), ReminderActions.laterId, at: tap);

        final d = laterDetails();
        expect(d['channelId'], 'alarm_channel_still');
        expect(d['enableVibration'], isFalse);
        expect(d['vibrationPattern'], isNull);
        expect(d['fullScreenIntent'], isTrue);
      });

      test('Full-screen alerts off', () async {
        SharedPreferences.setMockInitialValues({kAlarmFullScreenPref: false});
        await handleReminderAction(id, payload(), ReminderActions.laterId, at: tap);

        final d = laterDetails();
        expect(d['fullScreenIntent'], anyOf(isNull, isFalse));
        expect(d['enableVibration'], isTrue);
      });

      test('Keep on screen off', () async {
        SharedPreferences.setMockInitialValues({kAlarmPersistentPref: false});
        await handleReminderAction(id, payload(), ReminderActions.laterId, at: tap);

        final d = laterDetails();
        expect(d['ongoing'], anyOf(isNull, isFalse));
        expect(d['autoCancel'], isTrue);
        expect(d['fullScreenIntent'], isTrue);
      });
    });
  });

  group('a notification the app posts itself', () {
    setUpAll(() {
      tz_data.initializeTimeZones();
      tz.setLocalLocation(tz.getLocation('UTC'));
    });

    late AppDatabase db;
    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      AppDatabase.setInstanceForTesting(db);
    });
    tearDown(() async => db.close());

    Future<AndroidNotificationDetails> post({required bool vibration}) async {
      SharedPreferences.setMockInitialValues({});
      CleanStorageService.resetForTesting();
      await CleanStorageService.setAppPreference('vibrationEnabled', vibration);
      final rec = RecordingNotificationScheduler();
      NotificationService().schedulerForTesting = rec;
      final ok = await NotificationService().scheduleNotification(
        id: 4400,
        title: 'Appointment',
        body: 'Tomorrow at 10',
        scheduledDate: DateTime(2030, 1, 7, 9),
      );
      expect(ok, isTrue);
      return rec.scheduled.single.details!.android!;
    }

    test('with Vibration on, its channel, buzzing', () async {
      final a = await post(vibration: true);
      expect(a.channelId, 'alarm_channel');
      expect(a.enableVibration, isTrue);
    });

    test('with it off, the channel that does not', () async {
      final a = await post(vibration: false);
      expect(a.channelId, 'alarm_channel_still');
      expect(a.channelName, 'Alarm Reminders (no vibration)');
      expect(a.enableVibration, isFalse);
    });

    group('every other reminder the app posts itself', () {
      // Each of these named its own channel and passed `enableVibration:` — a flag
      // Android 8+ ignores once the channel exists. All of them were created buzzing.
      late RecordingNotificationScheduler rec;

      Future<void> setVibration(bool on) async {
        SharedPreferences.setMockInitialValues({});
        CleanStorageService.resetForTesting();
        await CleanStorageService.setAppPreference('vibrationEnabled', on);
        rec = RecordingNotificationScheduler();
        NotificationService().schedulerForTesting = rec;
      }

      Future<AndroidNotificationDetails> bedtime(bool vibration) async {
        await setVibration(vibration);
        expect(
            await NotificationService()
                .scheduleBedtimeReminder(enabled: true, minuteOfDay: 22 * 60),
            isTrue);
        return rec.scheduled.single.details!.android!;
      }

      Future<AndroidNotificationDetails> steps(bool vibration) async {
        await setVibration(vibration);
        expect(
            await NotificationService()
                .scheduleStepReminder(enabled: true, minuteOfDay: 18 * 60),
            isTrue);
        return rec.scheduled.first.details!.android!;
      }

      Future<AndroidNotificationDetails> caregiver(bool vibration) async {
        await setVibration(vibration);
        expect(
            await NotificationService().showCaregiverAlert(
                title: 'Missed dose', body: 'Sam missed a dose', dedupeKey: 'sam'),
            isTrue);
        return rec.shown.single.details!.android!;
      }

      Future<AndroidNotificationDetails> focus(bool vibration) async {
        await setVibration(vibration);
        expect(
            await NotificationService()
                .showFocusNotification(title: 'Round done', body: 'Take a break'),
            isTrue);
        return rec.shown.single.details!.android!;
      }

      final posters = <String, (Future<AndroidNotificationDetails> Function(bool), String, String)>{
        'a bedtime reminder': (bedtime, 'sleep_channel', 'Sleep & Bedtime'),
        'a step reminder': (steps, 'steps_channel', 'Step Reminders'),
        'a caregiver alert': (caregiver, 'medicine_channel', 'Medicine Reminders'),
        'a focus notification': (focus, 'focus_channel', 'Focus Sessions'),
      };

      for (final entry in posters.entries) {
        final (post, channel, name) = entry.value;

        test('${entry.key}: with Vibration on, its own channel, buzzing', () async {
          final a = await post(true);

          expect(a.channelId, channel);
          expect(a.enableVibration, isTrue);
        });

        test('${entry.key}: with it off, the channel that does not', () async {
          final a = await post(false);

          expect(a.channelId, '${channel}_still');
          expect(a.channelName, '$name (no vibration)');
          expect(a.enableVibration, isFalse);
        });
      }

      test('with no settings loaded it buzzes, as every reminder did before the switch', () async {
        SharedPreferences.setMockInitialValues({});
        CleanStorageService.resetForTesting(); // nothing loaded
        final rec = RecordingNotificationScheduler();
        NotificationService().schedulerForTesting = rec;

        final ok = await NotificationService()
            .showFocusNotification(title: 'Round done', body: 'Take a break');

        expect(ok, isTrue);
        final a = rec.shown.single.details!.android!;
        expect(a.channelId, 'focus_channel', reason: 'as every reminder was before the switch');
        expect(a.enableVibration, isTrue);
      });

      test('and each twin is made as its original is (see init), since the first post creates it',
          () async {
        // Nudge-grade channels: high importance on the notification stream.
        for (final post in [bedtime, steps, focus]) {
          final a = await post(false);
          expect(a.importance, Importance.high, reason: a.channelId);
          expect(a.audioAttributesUsage, AudioAttributesUsage.notification,
              reason: '${a.channelId}: the default, as init creates them');
        }
        // `medicine_channel` is alarm-grade, shared with the dose alarms: a twin the
        // caregiver ping made weaker would make every dose after it ring weaker.
        final c = await caregiver(false);
        expect(c.importance, Importance.max);
        expect(c.audioAttributesUsage, AudioAttributesUsage.alarm);
      });
    });

    group('a water reminder', () {
      // `water_channel` was created buzzing, and a per-notification flag does nothing
      // on Android 8+: with Vibration off every water reminder buzzed all the same.
      Future<AndroidNotificationDetails> water({required bool vibration}) async {
        SharedPreferences.setMockInitialValues({});
        CleanStorageService.resetForTesting();
        await CleanStorageService.setAppPreference('vibrationEnabled', vibration);
        final rec = RecordingNotificationScheduler();
        NotificationService().schedulerForTesting = rec;
        final ok = await NotificationService().scheduleWaterReminder(
            id: 4600, hour: 10, minute: 30, permissionsAlreadyChecked: true);
        expect(ok, isTrue);
        return rec.scheduled.single.details!.android!;
      }

      test('with Vibration on, its own channel, buzzing', () async {
        final a = await water(vibration: true);

        expect(a.channelId, 'water_channel');
        expect(a.enableVibration, isTrue);
      });

      test('with it off, the channel that does not', () async {
        final a = await water(vibration: false);

        expect(a.channelId, 'water_channel_still');
        expect(a.channelName, 'Water Reminders (no vibration)');
        expect(a.enableVibration, isFalse);
      });

      test('and Sound off does not make the twin silent for good', () async {
        // A channel's sound is fixed when it is created. The twin is created by the
        // first reminder posted with Vibration off; if that one carried Sound off, the
        // twin was silent for the life of the install, whatever Sound said afterwards.
        SharedPreferences.setMockInitialValues({});
        CleanStorageService.resetForTesting();
        await CleanStorageService.setAppPreference('vibrationEnabled', false);
        await CleanStorageService.setAppPreference('soundEnabled', false);
        final rec = RecordingNotificationScheduler();
        NotificationService().schedulerForTesting = rec;

        await NotificationService().scheduleWaterReminder(
            id: 4600, hour: 10, minute: 30, permissionsAlreadyChecked: true);

        final a = rec.scheduled.single.details!.android!;
        expect(a.channelId, 'water_channel_still');
        expect(a.playSound, isTrue, reason: 'as its original was created');
      });

      test('and the twin is made as the original is: maximum importance, on the alarm stream',
          () async {
        // See init: `water_channel` is created that way, and a twin takes whatever the
        // first notification posted to it asks for.
        final a = await water(vibration: false);

        expect(a.importance, Importance.max);
        expect(a.audioAttributesUsage, AudioAttributesUsage.alarm);
      });
    });
  });

  group('a reminder armed on a schedule', () {
    late RecordingNotificationScheduler rec;
    final monday9 = DateTime(2030, 1, 7, 9);

    setUpAll(() {
      tz_data.initializeTimeZones();
      tz.setLocalLocation(tz.getLocation('UTC'));
    });

    Future<AndroidNotificationDetails> arm(Map<String, Object> prefs) async {
      SharedPreferences.setMockInitialValues(prefs);
      rec = RecordingNotificationScheduler();
      NotificationService().schedulerForTesting = rec;
      final ok = await NotificationService().scheduleGenericReminder(
        id: 4321,
        title: 'Water the plants',
        body: '',
        scheduledTime: monday9,
        repeatType: RepeatType.weekly,
        escalation: ReminderEscalation.insistent,
        reminderId: 'r-1',
      );
      expect(ok, isTrue);
      return rec.scheduled.single.details!.android!;
    }

    test('with every switch on it is as it was', () async {
      final a = await arm({});
      expect(a.enableVibration, isTrue);
      expect(a.fullScreenIntent, isTrue);
      expect(a.ongoing, isTrue);
      expect(a.autoCancel, isFalse);
    });

    test('Vibration off', () async {
      final a = await arm({kAlarmVibrationPref: false});
      expect(a.channelId, 'alarm_channel_still');
      expect(a.enableVibration, isFalse);
      expect(a.vibrationPattern, isNull);
      expect(a.fullScreenIntent, isTrue);
    });

    test('Full-screen alerts off', () async {
      final a = await arm({kAlarmFullScreenPref: false});
      expect(a.fullScreenIntent, isFalse);
      expect(a.enableVibration, isTrue);
    });

    test('Keep on screen off', () async {
      final a = await arm({kAlarmPersistentPref: false});
      expect(a.ongoing, isFalse);
      expect(a.autoCancel, isTrue);
      expect(a.fullScreenIntent, isTrue);
    });
  });

  group('the alarm isolate reads them freshly', () {
    // The switches are written by the app's own isolate; the alarm runs in another,
    // which keeps the copy of the preferences it loaded the first time it looked and
    // can outlive an earlier alarm. Without a reload, a switch changed since would
    // still read as it was: Vibration turned off, and the next medicine alarm buzzes.
    // `QueueSignal.freshPrefs` is what the hand-off queues use for the same reason.
    //
    // A second isolate cannot be stood up here, so this reads the source: every read
    // of the switches in the alarm file must follow the nearest acquisition of its
    // preferences, and that must be a fresh one.
    test('each read follows a reload', () {
      final lines = File('lib/core/services/background_alarm_service.dart')
          .readAsLinesSync();
      final reads = <int>[
        for (var i = 0; i < lines.length; i++)
          if (lines[i].contains('AlarmSwitches.fromPrefs(') &&
              !lines[i].contains('static AlarmSwitches fromPrefs'))
            i,
      ];
      expect(reads, isNotEmpty, reason: 'the premise: the alarm file reads the switches');

      final stale = <String>[];
      for (final at in reads) {
        var j = at;
        while (j >= 0 && !RegExp(r'final prefs = await ').hasMatch(lines[j])) {
          j--;
        }
        if (j < 0 || !lines[j].contains('QueueSignal.freshPrefs()')) {
          stale.add('line ${at + 1}: ${lines[at].trim()}  (prefs from line ${j + 1}: '
              '${j < 0 ? 'none' : lines[j].trim()})');
        }
      }
      expect(stale, isEmpty,
          reason: 'these read the switches from a copy that may be stale:\n${stale.join('\n')}');
    });
  });
}
