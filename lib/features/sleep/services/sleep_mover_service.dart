import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';

import '../../../core/health/caffeine_cutoff.dart';
import '../../../core/health/insight.dart';
import '../../../core/health/sleep_movers.dart';
import '../../steps/services/step_service.dart';
import '../../water/services/water_service.dart';
import 'sleep_service.dart';

/// What goes with a person's longer and shorter nights, read from the logs the
/// app already keeps: the night's sleep, and what the day before it held.
class SleepMovers {
  const SleepMovers._();

  /// Nights looked back over. The in-memory sleep window is about 35 nights, so
  /// that is the most there is to read.
  static const int lookbackNights = 35;

  /// Caffeine counts as "late" from this hour of the day before; alcohol as an
  /// evening drink from [eveningFromHour].
  static const int lateCaffeineFromHour = 14;
  static const int eveningFromHour = 17;

  /// The nights with their factors, newest first.
  static List<NightFactors> nights({DateTime? now}) {
    final n = now ?? clock.now();
    final today = DateTime(n.year, n.month, n.day);
    final out = <NightFactors>[];
    for (var i = 0; i < lookbackNights; i++) {
      final wake = DateTime(today.year, today.month, today.day - i);
      final session = SleepService.getForDate(wake);
      if (session == null || session.asleepMinutes <= 0) continue;
      final before = DateTime(wake.year, wake.month, wake.day - 1);

      // Drinks and steps are "unknown" for a day with nothing logged, not "no":
      // a day nobody logged drinks on says nothing about caffeine.
      bool? caffeine;
      bool? alcohol;
      final water = WaterService.getDataForDate(before);
      if (water != null && water.logs.isNotEmpty) {
        final mg = water.logs
            .where((l) => l.time.hour >= lateCaffeineFromHour)
            .fold<int>(0, (sum, l) => sum + l.caffeineAmount);
        caffeine = mg >= CaffeineCutoff.meaningfulMg;
        alcohol = water.logs
            .any((l) => l.isAlcoholic && l.time.hour >= eveningFromHour);
      }

      bool? active;
      final steps = StepService.getDataForDate(before);
      if (steps != null && steps.effectiveSteps > 0) active = steps.goalReached;

      out.add(NightFactors(
        night: wake,
        asleepMinutes: session.asleepMinutes,
        lateCaffeine: caffeine,
        eveningAlcohol: alcohol,
        activeDay: active,
      ));
    }
    return out;
  }

  /// The patterns worth a word, largest gap first.
  static List<Insight> insights({DateTime? now}) {
    try {
      return SleepMoverInsights.insights(nights(now: now));
    } catch (e) {
      debugPrint('⚠️ Sleep movers failed: $e');
      return const [];
    }
  }
}
