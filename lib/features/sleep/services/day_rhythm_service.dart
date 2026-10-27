import '../../../core/health/day_rhythm.dart';
import 'sleep_service.dart';

/// A typical day, fitted to this person.
class DayRhythmView {
  const DayRhythmView({
    required this.spans,
    required this.wakeMinute,
    required this.fromNights,
  });

  final List<RhythmSpan> spans;

  /// When they wake, as minutes since midnight.
  final int wakeMinute;

  /// Whether the wake time and bedtime are the averages of their recent nights
  /// (true) or the ones in their sleep schedule (false).
  final bool fromNights;
}

/// Lays the general pattern of a day on the person's own wake time and bedtime.
///
/// The nights they have actually slept are better evidence of when they wake than
/// the time they once set, so with enough of them ([SleepService
/// .averageActualSchedule] needs three) those are used, and the card says so.
/// Otherwise the schedule's.
class DayRhythmService {
  const DayRhythmService._();

  static DayRhythmView? current() {
    final actual = SleepService.averageActualSchedule();
    final schedule = SleepService.getSchedule();
    final wake = actual != null
        ? actual.wakeHour * 60 + actual.wakeMinute
        : schedule.wakeHour * 60 + schedule.wakeMinute;
    final bed = actual != null
        ? actual.bedHour * 60 + actual.bedMinute
        : schedule.bedtimeHour * 60 + schedule.bedtimeMinute;
    final spans = DayRhythm.of(wakeMinute: wake, bedMinute: bed);
    if (spans == null) return null;
    return DayRhythmView(spans: spans, wakeMinute: wake, fromNights: actual != null);
  }
}
