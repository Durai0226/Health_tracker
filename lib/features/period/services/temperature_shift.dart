/// A rise in resting temperature after ovulation, found in the person's own
/// basal body temperature (BBT) log.
///
/// Pure Dart. The "three over six" rule, the common fertility-awareness one:
/// three days in a row each warmer than the six before them, the third by at
/// least 0.2 °C. Ovulation is then estimated at the day before the first warmer
/// day, because the rise follows it.
///
/// What it is and is not. It looks BACK: a shift is only visible three days
/// after it began, so it confirms ovulation rather than forecasting it, and it
/// is an estimate that illness, alcohol, a short night or a changed alarm can
/// all move. It is never a basis for contraception, and says so wherever it is
/// shown. Nothing here changes the calendar-method prediction.
library;

import '../services/cycle_predictor.dart' show DerivedCycle;

/// One day's BBT.
class BbtReading {
  const BbtReading(this.date, this.celsius);

  final DateTime date;
  final double celsius;
}

/// A temperature shift found in one cycle.
class TemperatureShift {
  const TemperatureShift({
    required this.cycleStart,
    required this.firstHighDay,
    required this.coverline,
    required this.thirdDayRise,
  });

  final DateTime cycleStart;

  /// The first of the three warmer days.
  final DateTime firstHighDay;

  /// The highest of the six readings before it.
  final double coverline;

  /// How far above the coverline the third warmer day was.
  final double thirdDayRise;

  /// 1-based cycle day of [firstHighDay].
  int get riseCycleDay => _daysBetween(cycleStart, firstHighDay) + 1;

  /// The day before the rise: where ovulation most likely was.
  DateTime get ovulationDay =>
      DateTime(firstHighDay.year, firstHighDay.month, firstHighDay.day - 1);

  int get ovulationCycleDay => riseCycleDay - 1;
}

class TemperatureShiftCheck {
  const TemperatureShiftCheck._();

  /// Readings before the rise that set the coverline.
  static const int baselineReadings = 6;

  /// Warmer days in a row.
  static const int confirmDays = 3;

  /// The third warmer day must clear the coverline by this much (°C).
  static const double thirdDayMinRise = 0.2;

  /// The six readings must fall within this many days before the rise, so a
  /// patchy log (one reading a week) cannot make a baseline out of nothing.
  static const int baselineSpanDays = 8;

  /// Ovulation is not found before this cycle day: an early "rise" is a cold
  /// reading, not a shift.
  static const int earliestRiseCycleDay = 8;

  /// Readings outside this range are mistyped, not temperatures.
  static const double minPlausibleC = 35.0;
  static const double maxPlausibleC = 38.5;

  /// The shift in the cycle that began on [cycleStart] and ended [cycleEnd]
  /// (null while it is still open), or null.
  static TemperatureShift? detect({
    required DateTime cycleStart,
    DateTime? cycleEnd,
    required Iterable<BbtReading> readings,
  }) {
    final start = _dayOnly(cycleStart);
    final end = cycleEnd == null ? null : _dayOnly(cycleEnd);
    final byDay = <DateTime, double>{};
    for (final r in readings) {
      final d = _dayOnly(r.date);
      if (d.isBefore(start) || (end != null && d.isAfter(end))) continue;
      if (r.celsius < minPlausibleC || r.celsius > maxPlausibleC) continue;
      byDay[d] = r.celsius;
    }
    final days = byDay.keys.toList()..sort();
    if (days.length < baselineReadings + confirmDays) return null;

    for (var i = baselineReadings; i + confirmDays <= days.length; i++) {
      final first = days[i];
      if (_daysBetween(start, first) + 1 < earliestRiseCycleDay) continue;

      final baseline = days.sublist(i - baselineReadings, i);
      if (_daysBetween(baseline.first, first) > baselineSpanDays) continue;
      var coverline = byDay[baseline.first]!;
      for (final d in baseline) {
        if (byDay[d]! > coverline) coverline = byDay[d]!;
      }

      // Three consecutive calendar days, every one of them warmer.
      var ok = true;
      for (var k = 0; k < confirmDays; k++) {
        final want = DateTime(first.year, first.month, first.day + k);
        final t = byDay[want];
        if (t == null || t <= coverline) {
          ok = false;
          break;
        }
      }
      if (!ok) continue;
      final third = byDay[DateTime(first.year, first.month, first.day + 2)]!;
      // Compared in hundredths: 36.4 + 0.2 must count as 36.6, and in
      // floating point it is 36.599999999999994.
      if (((third - coverline) * 100).round() < (thirdDayMinRise * 100).round()) {
        continue;
      }
      return TemperatureShift(
        cycleStart: start,
        firstHighDay: first,
        coverline: coverline,
        thirdDayRise: third - coverline,
      );
    }
    return null;
  }

  /// The shifts worth showing now: none unless the newest one belongs to one of
  /// the last [cyclesBack] cycles (a shift from half a year ago is history, not
  /// news), and then it and up to [earlierShown] before it, oldest first.
  static List<TemperatureShift> recent(
    List<DerivedCycle> cycles,
    Iterable<BbtReading> readings, {
    int cyclesBack = 2,
    int earlierShown = 3,
  }) {
    final shifts = forCycles(cycles, readings);
    if (shifts.isEmpty || cycles.isEmpty) return const [];
    final from = cycles.length > cyclesBack
        ? cycles[cycles.length - cyclesBack].start
        : cycles.first.start;
    if (shifts.last.cycleStart.isBefore(from)) return const [];
    final keep = earlierShown + 1;
    return shifts.length > keep ? shifts.sublist(shifts.length - keep) : shifts;
  }

  /// The shift in each of [cycles] that has one, oldest first.
  static List<TemperatureShift> forCycles(
    List<DerivedCycle> cycles,
    Iterable<BbtReading> readings,
  ) {
    final all = readings.toList();
    return [
      for (final c in cycles)
        ?detect(cycleStart: c.start, cycleEnd: c.end, readings: all),
    ];
  }

}

DateTime _dayOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// Calendar days from [a] to [b], not elapsed hours: a day with a clock change
/// in it is 23 or 25 of them.
int _daysBetween(DateTime a, DateTime b) =>
    DateTime.utc(b.year, b.month, b.day)
        .difference(DateTime.utc(a.year, a.month, a.day))
        .inDays;
