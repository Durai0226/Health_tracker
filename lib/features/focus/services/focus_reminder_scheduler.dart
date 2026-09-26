import 'package:clock/clock.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/services/notification_service.dart';
import 'focus_service.dart';
import '../../../core/utils/calendar_day.dart';

/// The one place Focus reminders are scheduled from.
///
/// Extracted because two callers need it and they must not disagree: the
/// settings screen (on load and on every toggle) and [migrateOffAlarmManager]
/// (once per install, at startup). Duplicating the logic is how a feature ends
/// up with a switch that means one thing on one path and something else on the
/// other — and this feature has already shipped three focus timers and two
/// design systems for exactly that reason.
class FocusReminderScheduler {
  const FocusReminderScheduler._();

  static const _kDailyEnabled = 'focus_daily_reminder';
  static const _kDailyTime = 'focus_reminder_time';
  static const _kStreakEnabled = 'focus_streak_reminder';

  /// Set once the 918_4xx ids have been taken off AlarmManager.
  static const _kMigratedV2 = 'focus_reminders_migrated_v2';

  /// Read the persisted settings and make the OS match them.
  ///
  /// Safe to call repeatedly: `scheduleFocusReminder` cancels the id before
  /// scheduling, and cancels it outright when `enabled` is false — so this is
  /// idempotent in both directions and never accumulates duplicates.
  static Future<void> apply() async {
    final prefs = await SharedPreferences.getInstance();
    final notifications = NotificationService();

    final dailyEnabled = prefs.getBool(_kDailyEnabled) ?? true;
    final parts = (prefs.getString(_kDailyTime) ?? '9:0').split(':');
    final hour = int.tryParse(parts.first) ?? 9;
    final minute = parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;

    await notifications.scheduleFocusReminder(
      id: NotificationService.focusDailyReminderId,
      enabled: dailyEnabled,
      title: 'Time to focus',
      body: 'A short session is enough.',
      when: nextOccurrence(hour, minute),
      repeatDaily: true,
    );

    // "At risk" is a fact about today, so this is re-decided every time rather
    // than left standing from yesterday. It can only go stale while the app is
    // unopened, and the streak can only advance by opening the app.
    final streakEnabled = prefs.getBool(_kStreakEnabled) ?? true;
    final atRisk = FocusService().streakAtRisk;
    final streak = FocusService().stats.currentStreak;

    await notifications.scheduleFocusReminder(
      id: NotificationService.focusStreakReminderId,
      enabled: streakEnabled && atRisk && streak > 0,
      title: 'Your $streak-day streak',
      // Shame-free even here, and TRUE: the engine forgives one miss per rolling
      // week, so this is information rather than a threat.
      body: 'A session today keeps it going. One missed day is forgiven.',
      when: nextOccurrence(20, 0),
    );
  }

  /// Take the two Focus reminder ids off AlarmManager, once per install.
  ///
  /// Anyone who already had Focus reminders switched on has live
  /// `AlarmManager.setAlarmClock()` registrations under 918_401/918_402 from
  /// `scheduleGenericReminder`. Those fire as full-screen, alarm-audio, ongoing
  /// notifications with a `✓ Take` button — and **creating `focus_channel` does
  /// not touch them.** A channel is presentation for notifications posted in the
  /// future; it cannot reach back into a scheduled alarm. Nor does the settings
  /// screen help, because the fix only runs if the user happens to open it.
  ///
  /// So this runs from `FocusService.init()`, on the startup path, for everyone.
  /// [apply] does the actual teardown: `scheduleFocusReminder` calls
  /// `cancelNotification`, which is the only cancel that also tears down the
  /// AlarmManager registration.
  ///
  /// Fire-and-forget and failure-tolerant: a reminder that stays wrong for one
  /// more launch is much better than a cold start that blocks on notification
  /// I/O, and the flag is only set once the teardown has actually happened.
  ///
  /// The cancels below are deliberately made HERE and not left to [apply].
  /// `scheduleFocusReminder` swallows its own failures — correctly, since a
  /// settings toggle must not throw at the user — which means calling it could
  /// never fail, so the flag would be set even on a launch where the old alarms
  /// were not torn down at all. Recording a migration that did not happen is
  /// worse than not migrating, because nothing ever tries again. Cancelling
  /// explicitly puts the failure back inside this `try`, where an unset flag
  /// means "retry next launch".
  static Future<void> migrateOffAlarmManager() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(_kMigratedV2) ?? false) return;

      // `cancelNotification`, not `_notifications.cancel`: it is the only cancel
      // that also tears down the AlarmManager registration, which is the entire
      // point of this migration.
      final notifications = NotificationService();
      await notifications
          .cancelNotification(NotificationService.focusDailyReminderId);
      await notifications
          .cancelNotification(NotificationService.focusStreakReminderId);

      await apply();
      await prefs.setBool(_kMigratedV2, true);
    } catch (_) {
      // Deliberately silent and unflagged — it will be retried next launch.
    }
  }

  /// The next wall-clock instant matching [hour]:[minute], today or tomorrow.
  static DateTime nextOccurrence(int hour, int minute) {
    final now = clock.now();
    final today = DateTime(now.year, now.month, now.day, hour, minute);
    // shiftCalendarDays, not add(Duration(days: 1)): this is a promise about a
    // wall-clock time. Adding 24 hours to 08:00 the day before spring forward
    // arms the reminder for 09:00 — an hour late, on the one morning a user is
    // least likely to forgive it.
    return today.isAfter(now) ? today : shiftCalendarDays(today, 1);
  }
}
