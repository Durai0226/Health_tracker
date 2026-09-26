import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

/// The seam between this app's scheduling decisions and the OS scheduler.
///
/// ## Why this exists
///
/// `FlutterLocalNotificationsPlugin` is a concrete class with a private
/// constructor and no interface, so nothing could stand in for it. The whole of
/// `NotificationService` therefore had **no behavioural coverage at all**, and
/// the tests that were written instead say so in their own doc comments:
///
///   > No behavioural test can catch this: `FlutterLocalNotificationsPlugin` is
///   > a concrete class with no injection seam […] So the invariant is asserted
///   > against the source.
///   — `test/notifications/exact_alarm_fallback_guard_test.dart`
///
///   > `FlutterLocalNotificationsPlugin` is a concrete class with no injection
///   > seam, so the cancelling itself cannot be observed headlessly.
///   — `NotificationService.staleWaterIdsIn`
///
/// A source grep passes on code that is spelled right and behaves wrong, and it
/// fails on a rename that changed nothing. Both happened here.
///
/// Modelled on `AudioEngine` and `ReminderAlarm`, which made the same argument
/// one layer up: *delivery* is an OS behaviour and is not where the defects
/// live. The defects live in which id is armed, which is cancelled, in what
/// order, and with which schedule mode — and every one of those is ordinary
/// logic this makes directly assertable.
///
/// Deliberately narrow: the five plugin calls that carry a decision, plus the
/// exact-alarm capability check that the decision depends on. `initialize` and
/// `resolvePlatformSpecificImplementation` are NOT here — they configure the
/// plugin rather than schedule anything, and faking them would mean
/// re-implementing the plugin's own setup rather than our behaviour.
abstract interface class NotificationScheduler {
  /// Arm a notification for [when]. Throws `PlatformException` with code
  /// `exact_alarms_not_permitted` when an exact mode is refused — the retry that
  /// handles that lives in `zonedScheduleGuarded`, not here.
  Future<void> zonedSchedule(
    int id,
    String? title,
    String? body,
    tz.TZDateTime when,
    NotificationDetails details, {
    required AndroidScheduleMode androidScheduleMode,
    DateTimeComponents? matchDateTimeComponents,
    String? payload,
  });

  /// Post a notification immediately.
  Future<void> show(
    int id,
    String? title,
    String? body,
    NotificationDetails? details, {
    String? payload,
  });

  /// Withdraw one pending notification. A no-op for an id that was never armed.
  Future<void> cancel(int id);

  /// Withdraw every pending notification this app owns.
  Future<void> cancelAll();

  /// What the OS currently holds for this app.
  Future<List<PendingNotificationRequest>> pendingNotificationRequests();

  /// Whether Android currently permits EXACT alarms.
  ///
  /// Any failure to find out is treated as "permitted", so behaviour is
  /// unchanged when the check itself is unavailable (e.g. a background isolate
  /// without the plugin attached).
  Future<bool> exactAlarmsAllowed();
}

/// The production implementation: a thin, mechanical forward to the plugin.
///
/// Keep it that way — logic in the adapter is logic the recording double cannot
/// reproduce, and that double is the only reason this interface exists.
class PluginNotificationScheduler implements NotificationScheduler {
  PluginNotificationScheduler([FlutterLocalNotificationsPlugin? plugin])
      : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;

  @override
  Future<void> zonedSchedule(
    int id,
    String? title,
    String? body,
    tz.TZDateTime when,
    NotificationDetails details, {
    required AndroidScheduleMode androidScheduleMode,
    DateTimeComponents? matchDateTimeComponents,
    String? payload,
  }) =>
      _plugin.zonedSchedule(
        id,
        title,
        body,
        when,
        details,
        androidScheduleMode: androidScheduleMode,
        // Hardcoded because every call site in the app passed it. A local time
        // interpretation would re-anchor the instant to the device's current
        // offset, which is wrong across a DST boundary.
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: matchDateTimeComponents,
        payload: payload,
      );

  @override
  Future<void> show(
    int id,
    String? title,
    String? body,
    NotificationDetails? details, {
    String? payload,
  }) =>
      _plugin.show(id, title, body, details, payload: payload);

  @override
  Future<void> cancel(int id) => _plugin.cancel(id);

  @override
  Future<void> cancelAll() => _plugin.cancelAll();

  @override
  Future<List<PendingNotificationRequest>> pendingNotificationRequests() =>
      _plugin.pendingNotificationRequests();

  @override
  Future<bool> exactAlarmsAllowed() async {
    if (!Platform.isAndroid) return true;
    try {
      final impl = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      return await impl?.canScheduleExactNotifications() ?? true;
    } catch (e) {
      debugPrint('⚠️ Exact-alarm capability check failed (assuming allowed): $e');
      return true;
    }
  }
}
