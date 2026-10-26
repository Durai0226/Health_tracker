import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';

import '../../../core/services/clean_storage_service.dart';
import '../../../core/services/snooze_log.dart';
import '../models/reminder_model.dart';
import 'reminder_alarm.dart';
import 'reminder_tune_up.dart';

/// Gathers what [ReminderTuneUp] needs, applies what the user accepts, and
/// remembers what they waved away.
class ReminderTuneUpService {
  const ReminderTuneUpService._();

  static const _dismissedKey = 'reminder_tuneup_dismissed';

  /// How long "not now" lasts. Long enough that the same card is not asking
  /// again next week, short enough that a changed pattern gets a fresh look.
  static const Duration dismissFor = Duration(days: 30);

  static String _fmt(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// `reminderId|kind|yyyy-MM-dd` — the day it was dismissed.
  static List<String> _dismissals() {
    final v = CleanStorageService.getAppPreference(_dismissedKey, const <String>[]);
    return v is List ? v.map((e) => e.toString()).toList() : const [];
  }

  /// Whether this suggestion for this reminder is currently waved away.
  static bool isDismissed(String reminderId, TuneUpKind kind, {DateTime? now}) {
    final t = now ?? clock.now();
    final today = DateTime(t.year, t.month, t.day);
    for (final e in _dismissals()) {
      final parts = e.split('|');
      if (parts.length != 3 || parts[0] != reminderId || parts[1] != kind.name) {
        continue;
      }
      final on = DateTime.tryParse(parts[2]);
      if (on != null && today.difference(on) < dismissFor) return true;
    }
    return false;
  }

  static Future<void> dismiss(String reminderId, TuneUpKind kind,
      {DateTime? now}) async {
    final t = now ?? clock.now();
    final kept = [
      for (final e in _dismissals())
        if (!e.startsWith('$reminderId|${kind.name}|')) e,
      '$reminderId|${kind.name}|${_fmt(t)}',
    ];
    await CleanStorageService.setAppPreference(_dismissedKey, kept);
  }

  /// The notification ids a reminder's snoozes may be filed under: its own slot,
  /// and — for the weekday-style repeats that arm one id per day — `slot + 1..7`.
  static List<int> _snoozeIds(Reminder r) {
    final slot = r.notificationSlot & 0x7FFFFFFF;
    return [slot, for (var d = 1; d <= 7; d++) slot + d];
  }

  /// The suggestion for [reminder], or null — also null when it was dismissed.
  static Future<TuneUp?> forOne(Reminder reminder, {DateTime? now}) async {
    try {
      final occurrences =
          await CleanStorageService.getReminderOccurrences(reminder.id);
      final snoozes = await SnoozeLog.read(_snoozeIds(reminder));
      final tuneUp = ReminderTuneUp.suggest(
          reminder: reminder, occurrences: occurrences, snoozes: snoozes);
      if (tuneUp == null || isDismissed(reminder.id, tuneUp.kind, now: now)) {
        return null;
      }
      return tuneUp;
    } catch (e) {
      debugPrint('ReminderTuneUpService.forOne failed: $e');
      return null;
    }
  }

  /// Suggestions for every repeating reminder in [reminders], by reminder id.
  static Future<Map<String, TuneUp>> forAll(Iterable<Reminder> reminders,
      {DateTime? now}) async {
    final out = <String, TuneUp>{};
    for (final r in reminders) {
      final repeats =
          r.repeatType != RepeatType.none || r.recurrenceRule != null;
      if (!repeats || r.isPaused) continue;
      final t = await forOne(r, now: now);
      if (t != null) out[r.id] = t;
    }
    return out;
  }

  /// Save [changed] and put the OS in step with it: armed at its new time, or —
  /// for a paused reminder — taken off. The one place a reminder edit made
  /// outside the form is turned into an alarm.
  static Future<void> saveAndRearm(Reminder changed,
      {ReminderAlarm alarm = const NotificationReminderAlarm()}) async {
    await CleanStorageService.saveReminder(changed);
    try {
      final request = ReminderArmRequest.forNextOccurrence(changed);
      if (request == null) {
        await alarm.disarm(
          id: changed.notificationSlot,
          repeatType: changed.repeatType,
          customDays: changed.customDays,
        );
      } else {
        await alarm.arm(request);
      }
    } catch (e) {
      // Saved; the next launch's re-arm pass recovers anything the OS refused.
      debugPrint('⚠️ Re-arming "${changed.title}" after a tune-up failed: $e');
    }
  }

  /// Apply [tuneUp] to [reminder]; returns the changed reminder.
  static Future<Reminder> apply(Reminder reminder, TuneUp tuneUp,
      {ReminderAlarm alarm = const NotificationReminderAlarm()}) async {
    final changed = ReminderTuneUp.apply(reminder, tuneUp);
    await saveAndRearm(changed, alarm: alarm);
    return changed;
  }
}
