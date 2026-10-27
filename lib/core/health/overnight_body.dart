/// What the body did overnight, against the person's own usual: how many of the
/// night's signals sit outside their usual range, and how far the heart rate
/// dropped while they slept.
///
/// Pure Dart. Wellness context, not a diagnosis: it says "outside your usual
/// range" and never "abnormal", gives no score and no verdict, and says nothing
/// at all without enough history for a signal to have a usual.
library;

import 'usual_range.dart';

/// The overnight signals a wearable can give.
enum BodySignal {
  restingHr('Resting heart rate', 'bpm', 2.0),
  hrv('Heart-rate variability', 'ms', 3.0),
  breathing('Breathing rate', 'breaths/min', 0.5),
  bloodOxygen('Blood oxygen', '%', 1.0),

  /// An absolute temperature (HealthKit) and a change from the wearer's own
  /// baseline (Health Connect) are different statistics and are never put in one
  /// series, so each is its own signal.
  temperature('Skin temperature', '°C', 0.15),
  temperatureChange('Skin temperature vs your baseline', '°C', 0.15);

  const BodySignal(this.label, this.unit, this.minHalfWidth);

  final String label;
  final String unit;

  /// The least a usual range is allowed to be wide (each side), so a very steady
  /// series is not a hairline and a one-point change is not "outside".
  final double minHalfWidth;
}

/// One signal last night, against its usual range.
class SignalReading {
  const SignalReading({
    required this.signal,
    required this.value,
    required this.range,
    required this.status,
  });

  final BodySignal signal;
  final double value;
  final UsualRange range;
  final RangeStatus status;

  bool get isOutside => status != RangeStatus.within;

  /// "64 bpm" — one decimal where the unit needs it.
  String get valueText => '${_fmt(value, signal)} ${signal.unit}';

  /// "usual 52–60".
  String get usualText =>
      'usual ${_fmt(range.low, signal)}–${_fmt(range.high, signal)}';

  static String _fmt(double v, BodySignal s) {
    switch (s) {
      case BodySignal.breathing:
      case BodySignal.temperature:
        return v.toStringAsFixed(1);
      case BodySignal.temperatureChange:
        // A change reads with its sign: "+0.3".
        final t = v.toStringAsFixed(1);
        return v > 0 && t != '0.0' ? '+$t' : t;
      case BodySignal.restingHr:
      case BodySignal.hrv:
      case BodySignal.bloodOxygen:
        return v.round().toString();
    }
  }
}

class OvernightBodyCheck {
  const OvernightBodyCheck._(this.signals);

  /// The signals that had a value last night AND a usual range to be set against.
  final List<SignalReading> signals;

  /// Signals needed before "n of m" is worth saying.
  static const int minSignals = 2;

  int get checked => signals.length;
  int get outside => signals.where((s) => s.isOutside).length;
  List<SignalReading> get outsideSignals =>
      [for (final s in signals) if (s.isOutside) s];

  /// "2 of 5 overnight signals are outside your usual range." or "All 5 ... are
  /// within".
  String get headline => outside == 0
      ? 'All $checked overnight signals are within your usual range.'
      : '$outside of $checked overnight signals are outside your usual range.';

  /// Last night's [last] value for each signal against the [history] of the
  /// days before it (oldest first, last night NOT in it). Null when fewer than
  /// [minSignals] signals have both.
  static OvernightBodyCheck? evaluate({
    required Map<BodySignal, double?> last,
    required Map<BodySignal, List<double>> history,
  }) {
    final out = <SignalReading>[];
    for (final s in BodySignal.values) {
      final value = last[s];
      final past = history[s];
      if (value == null || past == null) continue;
      final range = UsualRangeCalc.compute(past, minHalfWidth: s.minHalfWidth);
      if (range == null) continue;
      out.add(SignalReading(
          signal: s, value: value, range: range, status: range.statusOf(value)));
    }
    return out.length < minSignals ? null : OvernightBodyCheck._(out);
  }
}

/// How far the heart rate dropped overnight.
class NightHeartDip {
  const NightHeartDip({
    required this.dayAvg,
    required this.nightAvg,
    required this.lowestBpm,
    required this.lowestHour,
  });

  final int dayAvg;
  final int nightAvg;
  final int lowestBpm;

  /// The hour of the day (0 to 23) of the lowest hourly average overnight.
  final int lowestHour;

  /// How far below the daytime average the night's was, in percent (negative
  /// when it was higher).
  int get dipPercent => ((dayAvg - nightAvg) / dayAvg * 100).round();

  /// Hourly averages needed on each side.
  static const int minNightHours = 3;
  static const int minDayHours = 6;

  /// Daytime is these hours of the day before the night (09:00 to 20:59) — awake,
  /// before bed.
  static const int dayFromHour = 9;
  static const int dayToHour = 21;

  /// The dip for the night from [bedtime] to [wakeTime], from the hourly heart
  /// rates of the evening's day ([dayBefore]) and of the wake-up day ([wakeDay]):
  /// 24 slots each, null where the hour had no sample.
  ///
  /// Overnight is the whole hours inside the night; daytime is the previous
  /// day's 09:00–21:00 up to bedtime. Null when either side is too thin.
  static NightHeartDip? compute({
    required List<int?> dayBefore,
    required List<int?> wakeDay,
    required DateTime bedtime,
    required DateTime wakeTime,
  }) {
    int? at(List<int?> day, int hour) =>
        hour >= 0 && hour < day.length ? day[hour] : null;

    final wakeDate = DateTime(wakeTime.year, wakeTime.month, wakeTime.day);
    // Whole hours: from the first full hour after bedtime to the last full one
    // before waking.
    var t = DateTime(bedtime.year, bedtime.month, bedtime.day, bedtime.hour);
    if (t.isBefore(bedtime)) t = t.add(const Duration(hours: 1));
    final night = <({int hour, int bpm})>[];
    for (; !t.add(const Duration(hours: 1)).isAfter(wakeTime);
        t = t.add(const Duration(hours: 1))) {
      final onWakeDay = DateTime(t.year, t.month, t.day) == wakeDate;
      final bpm = at(onWakeDay ? wakeDay : dayBefore, t.hour);
      if (bpm != null) night.add((hour: t.hour, bpm: bpm));
    }
    if (night.length < minNightHours) return null;

    final day = <int>[];
    final before = DateTime(wakeDate.year, wakeDate.month, wakeDate.day - 1);
    for (var h = dayFromHour; h < dayToHour; h++) {
      // Not an hour already in bed (someone asleep by 20:00).
      if (!DateTime(before.year, before.month, before.day, h).isBefore(bedtime)) {
        continue;
      }
      final bpm = at(dayBefore, h);
      if (bpm != null) day.add(bpm);
    }
    if (day.length < minDayHours) return null;

    int mean(Iterable<int> v) =>
        (v.reduce((a, b) => a + b) / v.length).round();
    final lowest = night.reduce((a, b) => b.bpm < a.bpm ? b : a);
    return NightHeartDip(
      dayAvg: mean(day),
      nightAvg: mean(night.map((e) => e.bpm)),
      lowestBpm: lowest.bpm,
      lowestHour: lowest.hour,
    );
  }

  /// "Heart rate dropped 18% below daytime overnight (about 54 vs 66 bpm); lowest
  /// around 2 am."
  String get line {
    final pct = dipPercent;
    final lowest = 'lowest around ${_hourLabel(lowestHour)}';
    if (pct >= 1) {
      return 'Your heart rate was $pct% lower overnight than by day (about '
          '$nightAvg vs $dayAvg bpm); $lowest.';
    }
    if (pct <= -1) {
      return 'Your heart rate was ${-pct}% higher overnight than by day (about '
          '$nightAvg vs $dayAvg bpm); $lowest.';
    }
    return 'Your heart rate was about the same overnight as by day ($nightAvg vs '
        '$dayAvg bpm); $lowest.';
  }

  static String _hourLabel(int h) {
    if (h == 0) return '12 am';
    if (h < 12) return '$h am';
    if (h == 12) return '12 pm';
    return '${h - 12} pm';
  }
}
