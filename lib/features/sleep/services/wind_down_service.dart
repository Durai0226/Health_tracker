import '../../../core/services/notification_service.dart';
import 'sleep_service.dart';

/// The daily wind-down reminder: when it rings, and keeping it armed there.
class WindDownService {
  const WindDownService._();

  /// When the reminder belongs, as minutes of the day: the lead time before the
  /// schedule's bedtime or — for someone who has asked it to follow tonight's
  /// plan — before the plan's.
  static int minuteOfDay() {
    final s = SleepService.getSchedule();
    return s.followPlan
        ? SleepService.bedtimePlan().windDownMinuteOfDay(s.windDownMinutes)
        : s.reminderMinuteOfDay;
  }

  /// Arm the reminder where it belongs, if it is switched on. Returns how many
  /// reminders are armed (0 or 1), for the start-up pass that counts them.
  ///
  /// Never asks for the notification permission by itself: only a reminder the
  /// person already switched on is touched.
  static Future<int> rearm() async {
    if (!SleepService.getSchedule().reminderEnabled) return 0;
    final armed = await NotificationService()
        .scheduleBedtimeReminder(enabled: true, minuteOfDay: minuteOfDay());
    return armed ? 1 : 0;
  }
}
