import 'package:clock/clock.dart';

import '../../../core/health/home_bp_week.dart';
import '../../../core/health/vitals_analyzer.dart';
import '../../../core/services/active_profile_service.dart';
import '../../../core/services/clean_storage_service.dart';
import '../../../core/utils/date_formats.dart';
import '../models/blood_pressure_reading.dart';
import 'bp_sessions.dart';
import 'vitals_reminder_service.dart';

/// The home-BP week a person has started: when it began, whether its result has
/// been put away, and what the readings say about it.
///
/// Kept per person (the active profile), since a week is one person's readings.
class HomeBpWeekService {
  const HomeBpWeekService._();

  static String get _who => ActiveProfileService().activeDependentId ?? 'self';
  static String get _startKey => 'bp_home_week_start_$_who';
  static String get _closedKey => 'bp_home_week_closed_$_who';

  static String _key(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  /// The day the running (or just-finished) week began, or null.
  static DateTime? get start {
    final v = CleanStorageService.getAppPreference(_startKey, '');
    return v is String && v.isNotEmpty ? DateTime.tryParse(v) : null;
  }

  /// Where the week stands now, from [readings] (this person's, any order), or
  /// null when none is running — or the one that ended has been put away.
  static HomeBpProgress? current(Iterable<BloodPressureReading> readings,
      {DateTime? now}) {
    final began = start;
    if (began == null) return null;
    final p = HomeBpWeek.progress(
      start: began,
      sessions: [
        for (final s in BpSessions.group(readings))
          HomeBpSample(s.takenAt, s.systolic, s.diastolic),
      ],
      now: now ?? clock.now(),
    );
    final closed = CleanStorageService.getAppPreference(_closedKey, '');
    if (p.ended && closed == _key(began)) return null;
    return p;
  }

  /// Begin a week today. [morningReminder] and [eveningReminder] switch on the
  /// usual blood-pressure reminders — what the person chose in the start sheet,
  /// never something done for them.
  static Future<void> begin({
    required bool morningReminder,
    required bool eveningReminder,
    DateTime? day,
  }) async {
    final d = day ?? clock.now();
    // `closed` names the START of the week that was put away, so a new week
    // (a different start) is never hidden by an old one and needs no resetting.
    await CleanStorageService.setAppPreference(
        _startKey, _key(DateTime(d.year, d.month, d.day)));
    if (morningReminder) {
      await VitalsReminderService.apply(VitalsReminderService.bp, enabled: true);
    }
    if (eveningReminder) {
      await VitalsReminderService.apply(VitalsReminderService.bpEvening,
          enabled: true);
    }
  }

  /// Put a finished week's result away.
  static Future<void> close() async {
    final began = start;
    if (began == null) return;
    await CleanStorageService.setAppPreference(_closedKey, _key(began));
  }

  /// Stop a week that is running, or clear a finished one.
  static Future<void> stop() async {
    await CleanStorageService.setAppPreference(_startKey, '');
    await CleanStorageService.setAppPreference(_closedKey, '');
  }

  /// The result as text to paste into a message, saying what it is and is not.
  static String summaryText(HomeBpProgress p) {
    final s = p.summary;
    final last = DateTime(p.start.year, p.start.month, p.start.day + 6);
    final range = '${DateFormats.dayMonth.format(p.start)} to '
        '${DateFormats.dayMonthYear.format(last)}';
    final cat = s.category;
    final lines = <String>[
      'Home blood pressure, $range',
      if (s.average == null)
        'No average yet: only the first day, which is left out, has readings.'
      else
        '${s.enough ? 'Average' : 'So far'}: ${s.average} mmHg'
            '${cat == null ? '' : ' (${VitalsAnalyzer.bpLabel(cat)} range)'} from '
            '${s.sessions} session${s.sessions == 1 ? '' : 's'} on ${s.days} '
            'day${s.days == 1 ? '' : 's'}; the first day is left out.',
      if (s.morning != null || s.evening != null)
        [
          if (s.morning != null) 'Morning ${s.morning}',
          if (s.evening != null) 'Evening ${s.evening}',
        ].join(' · '),
      'Each session is the average of readings taken about a minute apart, '
          'morning and evening. This describes the readings; it is not a '
          'diagnosis.',
    ];
    return lines.join('\n');
  }
}
