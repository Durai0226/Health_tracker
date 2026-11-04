/// The notification shown when the snooze cap is reached honours "Vibration".
///
/// With the switch off, the alarm itself, its snoozes and its escalations all went
/// out on the channel without the buzz — and the LAST notification of a missed
/// dose, shown when the cap is reached, still buzzed: it had vibration hardcoded on
/// and the alarm channel, created with vibration, hardcoded in. On Android 8 and
/// later that is a property of the channel, so "off" has to mean the twin channel.
library;

import 'package:drift/native.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' show AppDatabase;
import 'package:tablet_remainder/core/services/active_profile_service.dart';
import 'package:tablet_remainder/core/services/background_alarm_service.dart';
import 'package:tablet_remainder/core/services/clean_storage_service.dart';
import 'package:tablet_remainder/core/services/notification_service.dart';
import 'package:tablet_remainder/features/reminders/models/reminder_model.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../support/recording_notification_scheduler.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    tz_data.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('America/New_York'));
  });

  group('what it looks like', () {
    test('with vibration on: the alarm channel, buzzing', () {
      final d = snoozeLimitDetails(vibrate: true);

      expect(d.channelId, 'alarm_channel');
      expect(d.channelName, 'Alarm Reminders');
      expect(d.enableVibration, isTrue);
    });

    test('with it off: the twin channel that does not, and no buzz asked for', () {
      final d = snoozeLimitDetails(vibrate: false);

      expect(d.channelId, 'alarm_channel_still');
      expect(d.channelName, 'Alarm Reminders (no vibration)');
      expect(d.enableVibration, isFalse);
    });

    test('a channel the alarm carries with it gets its own twin', () {
      final on = snoozeLimitDetails(
          vibrate: true, channelId: 'medicine_channel', channelName: 'Medicine Reminders');
      final off = snoozeLimitDetails(
          vibrate: false, channelId: 'medicine_channel', channelName: 'Medicine Reminders');

      expect(on.channelId, 'medicine_channel');
      expect(off.channelId, 'medicine_channel_still');
      expect(off.channelName, 'Medicine Reminders (no vibration)');
    });

    test('the quiet channel has no buzz to remove, and is left as it is', () {
      final d = snoozeLimitDetails(
          vibrate: false, channelId: quietChannelId, channelName: 'Quiet Reminders');

      expect(d.channelId, quietChannelId);
      expect(d.channelName, 'Quiet Reminders');
    });

    test('a twin is not made twice', () {
      final d = snoozeLimitDetails(
          vibrate: false,
          channelId: 'alarm_channel_still',
          channelName: 'Alarm Reminders (no vibration)');

      expect(d.channelId, 'alarm_channel_still');
      expect(d.channelName, 'Alarm Reminders (no vibration)');
    });

    test('either way it is the alarm it is the end of, so a twin it creates first is a true twin',
        () {
      // A channel is created by whatever posts to it first, with that
      // notification's importance and audio attributes, and Android never lets them
      // change. Posted as an ordinary heads-up, this would have made
      // `alarm_channel_still` a high-importance channel on the notification stream.
      for (final vibrate in [true, false]) {
        for (final id in ['alarm_channel', 'medicine_channel', 'health_channel']) {
          final d = snoozeLimitDetails(vibrate: vibrate, channelId: id, channelName: id);

          expect(d.importance, Importance.max, reason: '$id vibrate=$vibrate');
          expect(d.priority, Priority.max);
          expect(d.audioAttributesUsage, AudioAttributesUsage.alarm);
        }
      }
    });

    test('either way it can be dismissed, and goes when tapped', () {
      for (final vibrate in [true, false]) {
        final d = snoozeLimitDetails(vibrate: vibrate, dismissLabel: '✕ Dismiss');

        expect(d.autoCancel, isTrue);
        expect(d.actions!.single.id, 'dismiss');
        expect(d.actions!.single.title, '✕ Dismiss');
        expect(d.actions!.single.cancelNotification, isTrue);
        expect(d.actions!.single.showsUserInterface, isFalse);
      }
    });
  });

  group('the foreground path', () {
    late AppDatabase db;
    late RecordingNotificationScheduler scheduler;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      scheduler = RecordingNotificationScheduler();
      NotificationService().schedulerForTesting = scheduler;
      db = AppDatabase.forTesting(NativeDatabase.memory());
      AppDatabase.setInstanceForTesting(db);
      ActiveProfileService().resetForTesting();
      CleanStorageService.resetForTesting();
      await CleanStorageService.init();
      await CleanStorageService.saveReminder(Reminder(
        id: 'r-1',
        title: 'Stretch',
        body: '',
        scheduledTime: DateTime(2026, 3, 1, 20),
        repeatType: RepeatType.daily,
        notificationId: 4242,
      ));
    });

    tearDown(() async => db.close());

    /// Snooze until the cap says no, and return what it showed instead.
    Future<RecordedShow> reachTheCap() async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(maxSnoozeCountKey, 1);
      await prefs.setInt(snoozeCountKeyFor(4242), 1);

      await NotificationService().snoozeReminder(4242 + 100000, 10);

      expect(scheduler.shown, hasLength(1), reason: 'the premise: the cap was reached');
      return scheduler.shown.single;
    }

    test('with vibration on, it is the alarm channel as it always was', () async {
      final shown = await reachTheCap();

      final android = shown.details!.android!;
      expect(android.channelId, 'alarm_channel');
      expect(android.enableVibration, isTrue);
    });

    test('with vibration off, it is the channel without the buzz', () async {
      await CleanStorageService.saveUserSettings(
          CleanStorageService.getUserSettings().copyWith(vibrationEnabled: false));

      final shown = await reachTheCap();

      final android = shown.details!.android!;
      expect(android.channelId, 'alarm_channel_still');
      expect(android.enableVibration, isFalse);
    });
  });
}
