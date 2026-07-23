import 'dart:convert';
import 'package:flutter/material.dart' show TimeOfDay;
import 'package:drift/drift.dart' show Value;
import 'package:tablet_remainder/core/database/app_database.dart' as db;

/// A typed wrapper over the sleep half of the shared single-row
/// [db.HealthProfiles] table (target + bedtime/wake). Wind-down and the bedtime
/// reminder toggle overflow into the profile's `extraJson` so they persist
/// without their own columns and without clobbering the steps-owned fields.
class SleepSchedule {
  /// Nightly sleep target, in minutes (default 8h = 480).
  final int targetMinutes;
  final int bedtimeHour;
  final int bedtimeMinute;
  final int wakeHour;
  final int wakeMinute;

  /// Wind-down lead time before bedtime, in minutes (placeholder for reminders).
  final int windDownMinutes;

  /// Bedtime reminder toggle (gentle wind-down nudge on sleep_channel).
  final bool reminderEnabled;

  /// Wake alarm toggle — a plain daily alarm at [wake] (full-screen, alarm sound).
  final bool alarmEnabled;

  const SleepSchedule({
    this.targetMinutes = 480,
    this.bedtimeHour = 22,
    this.bedtimeMinute = 30,
    this.wakeHour = 7,
    this.wakeMinute = 0,
    this.windDownMinutes = 30,
    this.reminderEnabled = false,
    this.alarmEnabled = false,
  });

  TimeOfDay get bedtime => TimeOfDay(hour: bedtimeHour, minute: bedtimeMinute);
  TimeOfDay get wake => TimeOfDay(hour: wakeHour, minute: wakeMinute);

  /// "8h", "7h 30m" — the target rendered for the schedule row.
  String get targetLabel {
    final h = targetMinutes ~/ 60;
    final m = targetMinutes % 60;
    return m == 0 ? '${h}h' : '${h}h ${m}m';
  }

  /// Scheduled time in bed for the window, handling the midnight wrap
  /// (22:30 → 07:00 = 510 min).
  int get scheduledInBedMinutes {
    final bed = bedtimeHour * 60 + bedtimeMinute;
    final wk = wakeHour * 60 + wakeMinute;
    final diff = wk - bed;
    return diff <= 0 ? diff + 24 * 60 : diff;
  }

  /// Daily wind-down reminder time (bedtime − wind-down lead), as minutes-of-day
  /// (0..1439), handling the pre-midnight wrap.
  int get reminderMinuteOfDay {
    var m = (bedtimeHour * 60 + bedtimeMinute) - windDownMinutes;
    m %= 24 * 60;
    if (m < 0) m += 24 * 60;
    return m;
  }

  factory SleepSchedule.fromRow(db.HealthProfileRow r) {
    var windDown = 30;
    var reminder = false;
    var alarm = false;
    final raw = r.extraJson;
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          windDown =
              (decoded['sleepWindDownMinutes'] as num?)?.toInt() ?? windDown;
          reminder = decoded['sleepReminderEnabled'] as bool? ?? reminder;
          alarm = decoded['sleepAlarmEnabled'] as bool? ?? alarm;
        }
      } catch (_) {}
    }
    return SleepSchedule(
      targetMinutes: r.targetSleepMinutes,
      bedtimeHour: r.bedtimeHour,
      bedtimeMinute: r.bedtimeMinute,
      wakeHour: r.wakeHour,
      wakeMinute: r.wakeMinute,
      windDownMinutes: windDown,
      reminderEnabled: reminder,
      alarmEnabled: alarm,
    );
  }

  /// Defaults when the profile row hasn't been created yet.
  static SleepSchedule fromProfile(db.HealthProfileRow? r) =>
      r == null ? const SleepSchedule() : SleepSchedule.fromRow(r);

  /// A companion that writes ONLY the sleep-owned columns (+ merged extraJson),
  /// leaving the steps-owned fields (weight, stride, step goal) untouched on
  /// update via drift's upsert semantics. Pass the [existing] row so the
  /// wind-down / reminder keys merge into any steps-written extraJson.
  db.HealthProfilesCompanion toCompanion(db.HealthProfileRow? existing) {
    var extra = <String, dynamic>{};
    final raw = existing?.extraJson;
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) extra = Map<String, dynamic>.from(decoded);
      } catch (_) {}
    }
    extra['sleepWindDownMinutes'] = windDownMinutes;
    extra['sleepReminderEnabled'] = reminderEnabled;
    extra['sleepAlarmEnabled'] = alarmEnabled;

    final now = DateTime.now();
    return db.HealthProfilesCompanion(
      id: const Value('profile'),
      targetSleepMinutes: Value(targetMinutes),
      bedtimeHour: Value(bedtimeHour),
      bedtimeMinute: Value(bedtimeMinute),
      wakeHour: Value(wakeHour),
      wakeMinute: Value(wakeMinute),
      extraJson: Value(jsonEncode(extra)),
      createdAt: Value(existing?.createdAt ?? now),
      updatedAt: Value(now),
      synced: const Value(false),
    );
  }

  SleepSchedule copyWith({
    int? targetMinutes,
    int? bedtimeHour,
    int? bedtimeMinute,
    int? wakeHour,
    int? wakeMinute,
    int? windDownMinutes,
    bool? reminderEnabled,
    bool? alarmEnabled,
  }) {
    return SleepSchedule(
      targetMinutes: targetMinutes ?? this.targetMinutes,
      bedtimeHour: bedtimeHour ?? this.bedtimeHour,
      bedtimeMinute: bedtimeMinute ?? this.bedtimeMinute,
      wakeHour: wakeHour ?? this.wakeHour,
      wakeMinute: wakeMinute ?? this.wakeMinute,
      windDownMinutes: windDownMinutes ?? this.windDownMinutes,
      reminderEnabled: reminderEnabled ?? this.reminderEnabled,
      alarmEnabled: alarmEnabled ?? this.alarmEnabled,
    );
  }
}
