import 'package:flutter/material.dart';
import '../../../core/utils/quiet_hours.dart';

/// Persisted configuration for interval-based water reminders.
///
/// Stored as JSON in `CleanStorageService` app preferences under the key
/// `waterReminderConfig` (no Drift table / schema change). Every field is
/// JSON-safe so it round-trips through the preferences cache untouched.
class WaterReminderConfig {
  final bool enabled;
  final int startHour;
  final int startMinute;
  final int endHour;
  final int endMinute;
  final int intervalMinutes;

  /// Scheduled reminder times as minutes-since-midnight (interval-generated
  /// plus any custom times), kept sorted.
  final List<int> reminderMinutes;

  final String sound;

  /// Adaptive: stop scheduling further reminders once today's hydration goal is
  /// reached (re-established next app start / next day).
  final bool pauseWhenGoalReached;

  /// Adaptive: suppress reminders that fall outside the hydration profile's
  /// wake → bedtime window.
  final bool respectQuietHours;

  /// Opt-in: derive the [respectQuietHours] window from the Sleep feature's
  /// real data instead of the hydration profile's fixed wake/bed hours.
  /// Resolution falls back silently — a real sleep average (when there's
  /// enough history) → the stated sleep schedule → the hydration profile's
  /// hours — see `ReminderRescheduleService.rescheduleWaterReminders`.
  final bool useSleepSchedule;

  const WaterReminderConfig({
    this.enabled = false,
    this.startHour = 8,
    this.startMinute = 0,
    this.endHour = 22,
    this.endMinute = 0,
    this.intervalMinutes = 120,
    this.reminderMinutes = const [],
    this.sound = 'default',
    this.pauseWhenGoalReached = true,
    this.respectQuietHours = true,
    this.useSleepSchedule = false,
  });

  TimeOfDay get startTime => TimeOfDay(hour: startHour, minute: startMinute);
  TimeOfDay get endTime => TimeOfDay(hour: endHour, minute: endMinute);

  /// Reminder times to actually schedule, filtered by the quiet-hours window
  /// when [respectQuietHours] is on. [wakeHour]/[bedHour] (and the optional
  /// [wakeMinute]/[bedMinute], default 0) come from the hydration profile or,
  /// when [useSleepSchedule] is on, a sleep-derived window resolved by the
  /// caller. Delegates to the shared [QuietHours] primitive so this filter
  /// isn't water's own private copy — see its doc for why no other reminder
  /// type in this app applies it today.
  List<int> effectiveReminderMinutes({
    int wakeHour = 7,
    int wakeMinute = 0,
    int bedHour = 22,
    int bedMinute = 0,
  }) =>
      QuietHours.filterMinutes(
        reminderMinutes,
        respectQuietHours: respectQuietHours,
        wakeHour: wakeHour,
        bedHour: bedHour,
        wakeMinute: wakeMinute,
        bedMinute: bedMinute,
      );

  WaterReminderConfig copyWith({
    bool? enabled,
    int? startHour,
    int? startMinute,
    int? endHour,
    int? endMinute,
    int? intervalMinutes,
    List<int>? reminderMinutes,
    String? sound,
    bool? pauseWhenGoalReached,
    bool? respectQuietHours,
    bool? useSleepSchedule,
  }) {
    return WaterReminderConfig(
      enabled: enabled ?? this.enabled,
      startHour: startHour ?? this.startHour,
      startMinute: startMinute ?? this.startMinute,
      endHour: endHour ?? this.endHour,
      endMinute: endMinute ?? this.endMinute,
      intervalMinutes: intervalMinutes ?? this.intervalMinutes,
      reminderMinutes: reminderMinutes ?? this.reminderMinutes,
      sound: sound ?? this.sound,
      pauseWhenGoalReached: pauseWhenGoalReached ?? this.pauseWhenGoalReached,
      respectQuietHours: respectQuietHours ?? this.respectQuietHours,
      useSleepSchedule: useSleepSchedule ?? this.useSleepSchedule,
    );
  }

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'startHour': startHour,
        'startMinute': startMinute,
        'endHour': endHour,
        'endMinute': endMinute,
        'intervalMinutes': intervalMinutes,
        'reminderMinutes': reminderMinutes,
        'sound': sound,
        'pauseWhenGoalReached': pauseWhenGoalReached,
        'respectQuietHours': respectQuietHours,
        'useSleepSchedule': useSleepSchedule,
      };

  factory WaterReminderConfig.fromJson(Map<String, dynamic> json) {
    return WaterReminderConfig(
      enabled: json['enabled'] as bool? ?? false,
      startHour: (json['startHour'] as num?)?.toInt() ?? 8,
      startMinute: (json['startMinute'] as num?)?.toInt() ?? 0,
      endHour: (json['endHour'] as num?)?.toInt() ?? 22,
      endMinute: (json['endMinute'] as num?)?.toInt() ?? 0,
      intervalMinutes: (json['intervalMinutes'] as num?)?.toInt() ?? 120,
      reminderMinutes: (json['reminderMinutes'] as List?)
              ?.map((e) => (e as num).toInt())
              .toList() ??
          const [],
      sound: json['sound'] as String? ?? 'default',
      pauseWhenGoalReached: json['pauseWhenGoalReached'] as bool? ?? true,
      respectQuietHours: json['respectQuietHours'] as bool? ?? true,
      useSleepSchedule: json['useSleepSchedule'] as bool? ?? false,
    );
  }
}
