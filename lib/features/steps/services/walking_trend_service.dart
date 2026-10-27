import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';

import '../../../core/database/app_database.dart';
import '../../../core/health/walking_trends.dart';
import '../../../core/services/rest_day_store.dart';
import 'step_service.dart';

/// The walking trend for the Steps screen.
///
/// Read from the database rather than from the days the dashboard keeps in
/// memory: that window is 35 days and the baseline is 90.
class WalkingTrendService {
  const WalkingTrendService._();

  /// The trend over the complete days before today, or null when there is not
  /// enough walking on record to say anything.
  ///
  /// Today is left out. At eight in the morning it holds a few hundred steps,
  /// and counting it would read as a slump that is only the clock.
  static Future<WalkingTrend?> load({DateTime? now}) async {
    final n = now ?? clock.now();
    final today = DateTime(n.year, n.month, n.day);
    final yesterday = DateTime(today.year, today.month, today.day - 1);
    final from = DateTime(
        yesterday.year, yesterday.month, yesterday.day - WalkingTrends.baselineWindow + 1);
    try {
      final rows = await AppDatabase.instance.stepsDao.getDayRange(from, yesterday);
      final daily = <DateTime, int>{
        for (final r in rows)
          // The same total the rest of the Steps screen shows for a day.
          DateTime(r.date.year, r.date.month, r.date.day):
              r.sensorSteps ?? r.manualSteps,
      };
      // The days the screen holds in memory have the last word on those days:
      // the service tells its listeners before it has finished writing, so a
      // read triggered by a change can reach the database ahead of the change.
      for (final d in StepService.getDataForRange(from, yesterday)) {
        daily[DateTime(d.date.year, d.date.month, d.date.day)] = d.effectiveSteps;
      }
      // A day marked rest or unwell says nothing about how this person walks.
      final resting = RestDayStore.frozenDays(now: n);
      daily.removeWhere((day, _) => resting.contains(day));
      return WalkingTrends.compute(daily, today: yesterday);
    } catch (e) {
      debugPrint('⚠️ Walking trend failed: $e');
      return null;
    }
  }
}
