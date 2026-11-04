import '../../../core/health/quiet_window.dart';
import '../../../core/services/clean_storage_service.dart';
import '../models/reminder_model.dart';

/// "Quiet hours": the reminders you made wait until they end.
///
/// Off until switched on. What it holds, and what it deliberately does not:
///  * Reminders on the Normal tier are not delivered inside the window; they
///    arrive when it ends.
///  * Quiet reminders are left alone — they make no sound, so there is nothing
///    to hold back.
///  * Insistent and Critical reminders are never held: those tiers are the
///    person saying "reach me whatever the hour".
///  * **Medicines are never touched.** A dose reminder is not delayed by quiet
///    hours — the same rule [VacationMode] follows, for the same reason.
class QuietHours {
  const QuietHours._();

  static const _enabledKey = 'quiet_hours_enabled';
  static const _startKey = 'quiet_hours_start';
  static const _endKey = 'quiet_hours_end';

  /// 22:00 to 07:00, what a first switch-on offers.
  static const defaultStartMinute = 22 * 60;
  static const defaultEndMinute = 7 * 60;

  static bool get enabled =>
      CleanStorageService.getAppPreference(_enabledKey, false) == true;

  static int _minute(Object? raw, int fallback) =>
      raw is int && raw >= 0 && raw < 1440 ? raw : fallback;

  /// The stored window, whether or not it is switched on.
  static QuietWindow get window => QuietWindow(
        startMinute: _minute(
            CleanStorageService.getAppPreference(_startKey), defaultStartMinute),
        endMinute: _minute(
            CleanStorageService.getAppPreference(_endKey), defaultEndMinute),
      );

  /// The window to apply, or null when quiet hours are off or the window has no
  /// length.
  static QuietWindow? get active {
    final w = window;
    return enabled && !w.isEmpty ? w : null;
  }

  static Future<void> save({
    required bool enabled,
    required QuietWindow window,
  }) async {
    await CleanStorageService.setAppPreference(_enabledKey, enabled);
    await CleanStorageService.setAppPreference(_startKey, window.startMinute);
    await CleanStorageService.setAppPreference(_endKey, window.endMinute);
  }

  /// What [hold] decided: when to arm, and how it repeats.
  static ({DateTime time, RepeatType repeat, List<int>? days}) _same(
          DateTime time, RepeatType repeat, List<int>? days) =>
      (time: time, repeat: repeat, days: days);

  /// Move a reminder out of quiet hours, or return it as it was.
  ///
  /// [time] is the instant to arm — for a repeat armed natively it is a stored
  /// anchor whose time of day is what repeats, not a moment to wait for.
  ///
  /// Weekday-bound repeats need care at midnight. A Friday 23:00 reminder held
  /// until 07:00 arrives on Saturday, so "weekdays" would fire Monday to Friday
  /// at 07:00 — a day early. Those are armed on the days they now land on
  /// instead, as a custom repeat.
  static ({DateTime time, RepeatType repeat, List<int>? days}) hold({
    required QuietWindow? window,
    required ReminderEscalation escalation,
    required DateTime time,
    required RepeatType repeat,
    required List<int>? days,
    required DateTime now,
  }) {
    if (window == null || escalation != ReminderEscalation.standard) {
      return _same(time, repeat, days);
    }
    // A one-off already past is not waiting for anything.
    if (repeat == RepeatType.none && !time.isAfter(now)) {
      return _same(time, repeat, days);
    }
    final end = window.endAfter(time);
    if (end == null) return _same(time, repeat, days);

    final dayShift = DateTime(end.year, end.month, end.day)
        .difference(DateTime(time.year, time.month, time.day))
        .inDays;

    List<int> rotated(Iterable<int> d) =>
        [for (final x in d) (x - 1 + dayShift) % 7 + 1];

    switch (repeat) {
      case RepeatType.none:
      case RepeatType.daily:
      case RepeatType.weekly:
        // The date moves with the time, so a weekly one lands on the right day.
        return _same(end, repeat, days);
      case RepeatType.weekdays:
        return dayShift == 0
            ? _same(end, repeat, days)
            : _same(end, RepeatType.custom, rotated(const [1, 2, 3, 4, 5]));
      case RepeatType.weekends:
        return dayShift == 0
            ? _same(end, repeat, days)
            : _same(end, RepeatType.custom, rotated(const [6, 7]));
      case RepeatType.custom:
        if (days == null || days.isEmpty) return _same(time, repeat, days);
        return dayShift == 0
            ? _same(end, repeat, days)
            : _same(end, repeat, rotated(days));
    }
  }
}
