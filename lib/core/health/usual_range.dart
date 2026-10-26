/// A person's own usual range for a daily measurement, and where a value sits
/// against it.
///
/// "Normal" for resting heart rate, HRV, breathing rate or blood oxygen is not
/// one number: a 48 bpm resting rate is ordinary for a runner and worth noticing
/// for someone who sits at 70. So the band drawn behind a trend is the person's
/// OWN recent spread — mean ± one standard deviation of their previous days —
/// never a population figure.
///
/// This is wellness context, not a diagnosis. It says "outside your usual
/// range", never "abnormal", and says nothing at all until there is enough
/// history to stand behind it.
library;

import 'dart:math' as math;

import 'package:flutter/foundation.dart';

enum RangeStatus { below, within, above }

@immutable
class UsualRange {
  final double low;
  final double high;
  final double mean;

  /// How many values the range was worked out from.
  final int n;

  const UsualRange(
      {required this.low,
      required this.high,
      required this.mean,
      required this.n});

  RangeStatus statusOf(double value) {
    if (value < low) return RangeStatus.below;
    if (value > high) return RangeStatus.above;
    return RangeStatus.within;
  }
}

class UsualRangeCalc {
  const UsualRangeCalc._();

  /// Values needed before a range means anything. Fewer is a handful of days,
  /// not a pattern.
  static const int minValues = 7;

  /// Mean ± one sample standard deviation of [values], or null with fewer than
  /// [minValues].
  ///
  /// [minHalfWidth] stops a very steady series collapsing to a line: someone
  /// whose resting rate sat at exactly 58 for a month would otherwise find 59
  /// flagged as "above your usual". It is per metric because a sensible floor
  /// for bpm is not one for blood oxygen.
  static UsualRange? compute(List<double> values, {double minHalfWidth = 0}) {
    if (values.length < minValues) return null;
    final mean = values.reduce((a, b) => a + b) / values.length;
    final variance = values
            .map((v) => (v - mean) * (v - mean))
            .reduce((a, b) => a + b) /
        (values.length - 1);
    final half = math.max(math.sqrt(variance), minHalfWidth);
    return UsualRange(
        low: mean - half, high: mean + half, mean: mean, n: values.length);
  }
}

/// "HRV within your usual range (7-day avg 42 ms; usual 38–51)."
///
/// Compares the average of the LAST 7 days against the range of the 21 days
/// before them. Averaging a week smooths the night-to-night swing that makes a
/// single HRV reading mean little, and keeping the week out of its own
/// reference range stops a bad week from widening the range it is judged by.
@immutable
class HrvStatus {
  final double sevenDayAvgMs;
  final UsualRange range;
  final RangeStatus status;

  const HrvStatus(
      {required this.sevenDayAvgMs, required this.range, required this.status});

  /// Nights in the last seven needed before the average is trusted.
  static const int minRecentNights = 4;

  /// Floor on the half-width, in ms, so a very steady sleeper's range is not a
  /// hairline.
  static const double minHalfWidthMs = 3;

  static const int recentDays = 7;
  static const int referenceDays = 21;

  /// [points] are `(date, ms)` for ONE HRV metric — never mix RMSSD and SDNN,
  /// which are different statistics. [today] is the last day included.
  /// Null when either side lacks the history to say anything.
  static HrvStatus? evaluate(List<({DateTime date, double ms})> points,
      {required DateTime today}) {
    final end = DateTime(today.year, today.month, today.day);
    // Calendar-day arithmetic via the constructor, not Duration: a Duration of
    // N*24h across a DST change lands an hour off and shifts a day.
    DateTime back(int d) => DateTime(end.year, end.month, end.day - d);
    final recentStart = back(recentDays - 1);
    final referenceStart = back(recentDays + referenceDays - 1);

    bool inRange(DateTime d, DateTime from, DateTime to) =>
        !d.isBefore(from) && !d.isAfter(to);

    final recent = <double>[];
    final reference = <double>[];
    for (final p in points) {
      final d = DateTime(p.date.year, p.date.month, p.date.day);
      if (inRange(d, recentStart, end)) {
        recent.add(p.ms);
      } else if (inRange(d, referenceStart, back(recentDays))) {
        reference.add(p.ms);
      }
    }
    if (recent.length < minRecentNights) return null;
    final range =
        UsualRangeCalc.compute(reference, minHalfWidth: minHalfWidthMs);
    if (range == null) return null;
    final avg = recent.reduce((a, b) => a + b) / recent.length;
    return HrvStatus(
        sevenDayAvgMs: avg, range: range, status: range.statusOf(avg));
  }

  /// The line shown to the user.
  String get message {
    final where = switch (status) {
      RangeStatus.within => 'within',
      RangeStatus.above => 'above',
      RangeStatus.below => 'below',
    };
    return 'HRV $where your usual range '
        '(7-day avg ${sevenDayAvgMs.round()} ms; '
        'usual ${range.low.round()}–${range.high.round()}).';
  }
}
