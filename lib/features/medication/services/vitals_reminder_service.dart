import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show TimeOfDay;

import '../../../core/services/clean_storage_service.dart';
import '../../../core/services/notification_service.dart';

/// A vital that can carry a daily "time to measure" reminder.
class VitalsReminderSpec {
  final int id; // stable notification id
  final String prefKey; // persistence namespace, e.g. 'vitals_bp_reminder'
  final String title;
  final String body;
  final int defaultHour;
  const VitalsReminderSpec({
    required this.id,
    required this.prefKey,
    required this.title,
    required this.body,
    required this.defaultHour,
  });
}

/// One source of truth for the BP + blood-sugar "remind me to measure"
/// reminders, shared by the header button, the settings screen and the
/// Reminders hub. The ids, prefs keys, copy and scheduling are unchanged from
/// the original header button, so any reminder already set keeps working.
class VitalsReminderService {
  VitalsReminderService._();

  static const VitalsReminderSpec bp = VitalsReminderSpec(
    id: 900020,
    prefKey: 'vitals_bp_reminder',
    title: 'Blood pressure check',
    body: 'Time to measure and log your blood pressure.',
    defaultHour: 9,
  );

  /// The second blood-pressure slot of a morning-and-evening routine. Its own
  /// spec (id, prefs, time) so the two can be switched and timed separately,
  /// and so it is re-armed with the rest by [rescheduleAll].
  ///
  /// 900024 is inside the legacy water-reminder id block, so it MUST also be in
  /// `NotificationService._foreignIdsInLegacyWaterBlock` or a water sweep
  /// cancels it; `water_reminder_sweep_test.dart` derives that check from
  /// [all].
  static const VitalsReminderSpec bpEvening = VitalsReminderSpec(
    id: 900024,
    prefKey: 'vitals_bp_evening_reminder',
    title: 'Blood pressure check',
    body: 'Time for your evening blood pressure reading.',
    defaultHour: 19,
  );

  static const VitalsReminderSpec glucose = VitalsReminderSpec(
    id: 900021,
    prefKey: 'vitals_glucose_reminder',
    title: 'Blood sugar check',
    body: 'Time to measure and log your blood sugar.',
    defaultHour: 8,
  );

  static const VitalsReminderSpec weight = VitalsReminderSpec(
    id: 900022,
    prefKey: 'vitals_weight_reminder',
    title: 'Weight check-in',
    body: 'Time to weigh in and log it.',
    // Morning, before eating/drinking, is the standard advice for a
    // comparable day-to-day weight reading.
    defaultHour: 7,
  );

  static const VitalsReminderSpec mood = VitalsReminderSpec(
    id: 900023,
    prefKey: 'vitals_mood_reminder',
    title: 'How are you feeling?',
    body: 'Take a moment to log your mood today.',
    defaultHour: 20,
  );

  /// Every spec, in a fixed order — so a caller can iterate them without
  /// hardcoding a list that silently goes stale when a fifth vital is added.
  static const List<VitalsReminderSpec> all = [bp, bpEvening, glucose, weight, mood];

  /// Re-arm every enabled vitals reminder from persisted state.
  ///
  /// These are `zonedSchedule`/AlarmManager registrations, so they do not
  /// survive an id-scheme change, a restore, or an exact-alarm grant that
  /// arrives after they were armed inexactly. Nothing re-established them:
  /// `ReminderRescheduleService` covered medicines, water and appointments only,
  /// and vitals had no rearm path at all — so a reminder the user had switched
  /// on could quietly stop existing and the toggle would still read "On".
  static Future<int> rescheduleAll() async {
    var armed = 0;
    for (final spec in all) {
      if (!isEnabled(spec)) continue;
      final t = timeOf(spec);
      try {
        await apply(spec, enabled: true, hour: t.hour, minute: t.minute);
        armed++;
      } catch (e) {
        debugPrint('⚠️ Re-arming the ${spec.title} reminder failed: $e');
      }
    }
    return armed;
  }

  static bool isEnabled(VitalsReminderSpec s) =>
      CleanStorageService.getAppPreference('${s.prefKey}_on', false) == true;

  static TimeOfDay timeOf(VitalsReminderSpec s) {
    final h = CleanStorageService.getAppPreference('${s.prefKey}_h', s.defaultHour)
            as int? ??
        s.defaultHour;
    final m =
        CleanStorageService.getAppPreference('${s.prefKey}_m', 0) as int? ?? 0;
    return TimeOfDay(hour: h, minute: m);
  }

  /// Enables/disables the daily reminder for [s]. When enabling, schedules a
  /// daily notification at [hour]:[minute] (falling back to the saved/default
  /// time); when disabling, cancels it. Persists the state either way.
  static Future<void> apply(
    VitalsReminderSpec s, {
    required bool enabled,
    int? hour,
    int? minute,
  }) async {
    final ns = NotificationService();
    if (!enabled) {
      await ns.cancelNotification(s.id);
      await CleanStorageService.setAppPreference('${s.prefKey}_on', false);
      return;
    }
    final current = timeOf(s);
    final h = hour ?? current.hour;
    final m = minute ?? current.minute;
    await ns.scheduleDailyNotification(
      id: s.id,
      title: s.title,
      body: s.body,
      hour: h,
      minute: m,
    );
    await CleanStorageService.setAppPreference('${s.prefKey}_on', true);
    await CleanStorageService.setAppPreference('${s.prefKey}_h', h);
    await CleanStorageService.setAppPreference('${s.prefKey}_m', m);
  }
}
