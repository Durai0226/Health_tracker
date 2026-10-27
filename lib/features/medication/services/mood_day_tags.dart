import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';

import '../../../core/health/mood_tags.dart';
import '../../../core/services/active_profile_service.dart';
import '../../period/services/period_service.dart';
import '../../sleep/services/sleep_service.dart';
import '../../steps/services/step_service.dart';
import 'medicine_storage_service.dart';

/// The tags a day has earned by itself, read from what the app already knows:
/// last night's sleep, the day's steps, a period, and the doses.
///
/// Each source is best-effort and independent: one that is empty, or fails,
/// simply adds no tag. The rules for each are in [MoodTags.forDay].
class MoodDayTags {
  const MoodDayTags._();

  static Future<List<String>> forDate(DateTime takenAt) async {
    final now = clock.now();
    final day = DateTime(takenAt.year, takenAt.month, takenAt.day);
    final today = DateTime(now.year, now.month, now.day);
    final over = day.isBefore(today) || (day == today && now.hour >= 21);

    int? sleep;
    try {
      sleep = SleepService.getForDate(day)?.asleepMinutes;
    } catch (_) {}

    int? steps;
    int? goal;
    try {
      final d = StepService.getDataForDate(day);
      steps = d?.effectiveSteps;
      goal = d?.goalSteps;
    } catch (_) {}

    // A period belongs to the account holder. A family member's mood must not be
    // tagged with the account holder's cycle.
    var bleeding = false;
    try {
      if (ActiveProfileService().isSelfActive) {
        bleeding = PeriodService.getDay(day)?.isBleeding ?? false;
      }
    } catch (_) {}

    var due = 0, taken = 0, missed = 0;
    try {
      final s = await MedicineCleanStorageService.getDailySummaryAsync(day);
      due = s.totalScheduled;
      taken = s.taken;
      missed = s.missed;
    } catch (e) {
      debugPrint('⚠️ Mood day tags: dose summary failed: $e');
    }

    return MoodTags.forDay(
      sleepMinutes: sleep,
      steps: steps,
      stepGoal: goal,
      dayIsOver: over,
      bleeding: bleeding,
      dosesDue: due,
      dosesTaken: taken,
      dosesMissed: missed,
    );
  }
}
