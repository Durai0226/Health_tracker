import 'package:clock/clock.dart';

import '../../../core/health/morning_report.dart';
import '../../../core/services/clean_storage_service.dart';
import '../../sleep/services/overnight_body_service.dart';
import '../../sleep/services/sleep_service.dart';

/// The morning report for today, from the sleep and biometrics the app holds.
class MorningReportService {
  const MorningReportService._();

  static const _dismissedKey = 'morning_report_dismissed_on';

  /// It is a morning thing: until noon.
  static const int untilHour = 12;

  /// Nights before last night that make "your usual".
  static const int usualNights = 14;

  static String _key(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  static bool dismissedToday({DateTime? now}) =>
      CleanStorageService.getAppPreference(_dismissedKey, '') ==
      _key(now ?? clock.now());

  static Future<void> dismissToday({DateTime? now}) =>
      CleanStorageService.setAppPreference(_dismissedKey, _key(now ?? clock.now()));

  /// Today's report, or null: past noon, put away, or no night that ended this
  /// morning to report on.
  static MorningReport? today({DateTime? now}) {
    final n = now ?? clock.now();
    if (n.hour >= untilHour || dismissedToday(now: n)) return null;

    final last = SleepService.getLastNight();
    if (last == null) return null;
    final today = DateTime(n.year, n.month, n.day);
    final wake = DateTime(last.wakeTime.year, last.wakeTime.month, last.wakeTime.day);
    if (wake != today) return null;

    final since = DateTime(today.year, today.month, today.day - usualNights);
    final earlier = [
      for (final s in SleepService.getAllSessions())
        if (s.asleepMinutes > 0 &&
            DateTime(s.wakeTime.year, s.wakeTime.month, s.wakeTime.day)
                .isAfter(since) &&
            DateTime(s.wakeTime.year, s.wakeTime.month, s.wakeTime.day)
                .isBefore(today))
          s.asleepMinutes,
    ];

    return MorningReport.build(
      lastNightMinutes: last.asleepMinutes,
      earlierNights: earlier,
      debt: SleepService.sleepDebt(),
      body: OvernightBody.checkFor(today),
    );
  }
}
