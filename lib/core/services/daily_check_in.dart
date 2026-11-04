import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show TimeOfDay;
import 'package:shared_preferences/shared_preferences.dart';

import 'clean_storage_service.dart';
import 'notification_service.dart';

/// The "Daily check-in": one gentle notification a day, at a time the person
/// chooses.
///
/// The first-run setup scheduled it and then nothing in the app could touch it
/// again: no way to change the time (the setup had no picker, so everyone got
/// 09:00), and no way to stop it short of the phone's own notification settings.
/// This is the one place that owns it, so the setup, Settings and the re-arm at
/// every start all agree.
class DailyCheckIn {
  const DailyCheckIn._();

  /// The notification id — inside the legacy block `900001` that the onboarding
  /// used, and listed with the foreign ids the water sweep must never cancel.
  static const int notificationId = 900001;

  static const String title = 'Daily check-in';
  static const String body = 'A gentle nudge for your medicine, water and to-dos.';

  static const String enabledKey = 'dailyCheckInEnabled';

  // The keys the setup always used for the time, so what people chose there (or
  // were given by default) carries over.
  static const String hourKey = 'preferredReminderHour';
  static const String minuteKey = 'preferredReminderMinute';

  static const TimeOfDay defaultTime = TimeOfDay(hour: 9, minute: 0);

  /// The time it is set for.
  static TimeOfDay get time {
    final h = CleanStorageService.getAppPreference(hourKey, defaultTime.hour);
    final m = CleanStorageService.getAppPreference(minuteKey, defaultTime.minute);
    return TimeOfDay(
      hour: h is int && h >= 0 && h < 24 ? h : defaultTime.hour,
      minute: m is int && m >= 0 && m < 60 ? m : defaultTime.minute,
    );
  }

  /// Whether it is on.
  ///
  /// Installs from before there was a switch scheduled it without recording that,
  /// so a missing answer is read off what is actually armed — on Android the
  /// alarm's own record, elsewhere the OS's pending list — and remembered, once.
  ///
  /// Only a yes is remembered. A no is what an empty list says as readily when the
  /// notification plugin is not ready yet or the call failed as when nothing is
  /// armed, and written down it would be a decision nobody made: [rearm] would
  /// never arm it again. Not recording it costs one more look next time.
  static Future<bool> isEnabled() async {
    final recorded = CleanStorageService.getAppPreference(enabledKey, null);
    if (recorded is bool) return recorded;
    final armed = await _isArmed();
    if (armed) await CleanStorageService.setAppPreference(enabledKey, true);
    return armed;
  }

  static Future<bool> _isArmed() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.containsKey('alarm_$notificationId')) return true;
      final pending = await NotificationService().getPendingNotifications();
      return pending.any((p) => p.id == notificationId);
    } catch (e) {
      debugPrint('DailyCheckIn: could not tell whether it is armed: $e');
      return false;
    }
  }

  /// Turn it on or off, and set the time it fires at. [time] defaults to the one
  /// already chosen. Idempotent: arming it again replaces it.
  ///
  /// The notification is armed (or withdrawn) FIRST and the choice recorded after,
  /// and a refusal throws: a choice written before the notification was, and left
  /// there when arming failed, has Settings saying "on" and the next start arming
  /// a time the person was told could not be set — with nothing ever appearing.
  static Future<void> apply({required bool enabled, TimeOfDay? time}) async {
    final t = time ?? DailyCheckIn.time;
    if (enabled) {
      final wasOn = await isEnabled();
      final armed = await NotificationService().scheduleDailyNotification(
        id: notificationId,
        title: title,
        body: body,
        hour: t.hour,
        minute: t.minute,
      );
      if (!armed) {
        // On Android the alarm's record is written before the alarm is registered,
        // so a refusal leaves one behind — and [isEnabled] reads that as "armed".
        // Where nothing was on before, take it back; where it was, the check-in
        // that is already set is left as it was.
        if (!wasOn) {
          try {
            await NotificationService().cancelNotification(notificationId);
          } catch (e) {
            debugPrint('DailyCheckIn: could not clear a refused arm: $e');
          }
        }
        throw StateError('The daily check-in could not be scheduled.');
      }
    } else {
      await NotificationService().cancelNotification(notificationId);
    }
    await CleanStorageService.setAppPreference(hourKey, t.hour);
    await CleanStorageService.setAppPreference(minuteKey, t.minute);
    await CleanStorageService.setAppPreference(enabledKey, enabled);
  }

  /// Arm it again if it is on: at every start, after a restore, on a new phone.
  /// Returns how many were armed (0 or 1), the shape `ReminderFamily` wants — so
  /// one that could not be armed is not counted.
  static Future<int> rearm() async {
    if (!await isEnabled()) return 0;
    final t = time;
    final armed = await NotificationService().scheduleDailyNotification(
      id: notificationId,
      title: title,
      body: body,
      hour: t.hour,
      minute: t.minute,
    );
    return armed ? 1 : 0;
  }
}
