/// A span of the clock, repeating every day, when reminders should not sound:
/// "22:00 to 07:00".
///
/// Plain data and arithmetic — no storage, no platform — so the one question
/// that matters ("when does this wait until?") can be answered and tested
/// without a phone. Minutes are after midnight, 0 to 1439.
library;

import 'package:flutter/foundation.dart';

@immutable
class QuietWindow {
  const QuietWindow({required this.startMinute, required this.endMinute})
      : assert(startMinute >= 0 && startMinute < 1440),
        assert(endMinute >= 0 && endMinute < 1440);

  /// When quiet begins, inclusive.
  final int startMinute;

  /// When it ends, exclusive: a reminder due at the very minute quiet ends is
  /// not held.
  final int endMinute;

  /// Start equal to end is a window of no length, not one that lasts all day: a
  /// person who sets both to the same time has not asked for 24 hours of silence.
  bool get isEmpty => startMinute == endMinute;

  /// 22:00 to 07:00 runs through midnight; 13:00 to 15:00 does not.
  bool get crossesMidnight => startMinute > endMinute;

  /// Whether the time of day of [t] is inside the window. The date does not
  /// matter — it repeats every day.
  bool covers(DateTime t) {
    // An empty window needs no case of its own: start equal to end is not "through
    // midnight", so the within-the-day test below asks for a minute that is both
    // at or after the start and before the same minute, which none is.
    final m = t.hour * 60 + t.minute;
    return crossesMidnight
        ? (m >= startMinute || m < endMinute)
        : (m >= startMinute && m < endMinute);
  }

  /// The moment the window ends after [t], or null when [t] is not inside it.
  ///
  /// For a window through midnight that is tomorrow when [t] is before midnight
  /// (23:00 waits until 07:00 the next day) and today when it is after (03:00
  /// waits until 07:00 the same day).
  DateTime? endAfter(DateTime t) {
    if (!covers(t)) return null;
    final m = t.hour * 60 + t.minute;
    final nextDay = crossesMidnight && m >= startMinute;
    return DateTime(
        t.year, t.month, t.day + (nextDay ? 1 : 0), endMinute ~/ 60, endMinute % 60);
  }

  @override
  bool operator ==(Object other) =>
      other is QuietWindow &&
      other.startMinute == startMinute &&
      other.endMinute == endMinute;

  @override
  int get hashCode => Object.hash(startMinute, endMinute);

  @override
  String toString() => 'QuietWindow($startMinute–$endMinute)';
}
