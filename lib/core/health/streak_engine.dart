/// Pure-Dart streak logic with *forgiveness* — the behavior-change research is
/// blunt that a hard reset on one missed day is demoralizing and counter-
/// productive (especially for medication). This allows a small number of grace
/// days per rolling week before a streak breaks, plus an "at risk" signal for a
/// gentle nudge. Deterministic (inject [today]) so it's fully unit-testable.
class StreakResult {
  final int current;
  final int longest;

  /// A grace day was consumed to keep the current streak alive.
  final bool usedGrace;

  /// Today isn't completed yet and the streak will break if the day ends unmet.
  final bool atRisk;

  const StreakResult({
    required this.current,
    required this.longest,
    required this.usedGrace,
    required this.atRisk,
  });
}

class StreakEngine {
  const StreakEngine._();

  /// [completedDays] is the set of days the goal was met (time component
  /// ignored). [graceDaysPerWeek] misses are forgiven within any trailing
  /// 7-day span before the streak breaks.
  static StreakResult compute({
    required Set<DateTime> completedDays,
    required DateTime today,
    int graceDaysPerWeek = 1,
  }) {
    final done = completedDays.map(_d).toSet();
    final t = _d(today);

    // Current streak: walk backward from today (or yesterday if today's not yet
    // done), forgiving up to graceDaysPerWeek misses per trailing week. Never
    // walk past the earliest recorded day (so we don't "forgive" prehistory).
    final earliest = done.isEmpty ? t : _earliest(done);
    var cursor = done.contains(t) ? t : _prevDay(t);
    var current = 0;
    var usedGrace = false;
    var graceLeft = graceDaysPerWeek;
    var stepsInWeek = 0;

    while (!cursor.isBefore(earliest)) {
      if (stepsInWeek == 7) {
        stepsInWeek = 0;
        graceLeft = graceDaysPerWeek; // reset grace each trailing week
      }
      if (done.contains(cursor)) {
        current++;
      } else {
        if (graceLeft > 0) {
          graceLeft--;
          usedGrace = true;
        } else {
          break; // streak broken
        }
      }
      cursor = _prevDay(cursor);
      stepsInWeek++;
    }

    // Longest streak across history, applying the same weekly-grace rule.
    final longest = _longest(done, graceDaysPerWeek);

    final atRisk = !done.contains(t) && current > 0;

    return StreakResult(
      current: current,
      longest: longest < current ? current : longest,
      usedGrace: usedGrace,
      atRisk: atRisk,
    );
  }

  static int _longest(Set<DateTime> done, int gracePerWeek) {
    if (done.isEmpty) return 0;
    final sorted = done.toList()..sort();
    final first = sorted.first;
    final last = sorted.last;
    var best = 0, run = 0, graceLeft = gracePerWeek, stepsInWeek = 0;
    for (var day = first; !day.isAfter(last); day = _nextDay(day)) {
      if (stepsInWeek == 7) {
        stepsInWeek = 0;
        graceLeft = gracePerWeek;
      }
      if (done.contains(day)) {
        run++;
        if (run > best) best = run;
      } else if (graceLeft > 0) {
        graceLeft--; // forgiven, streak continues but the missed day adds nothing
      } else {
        run = 0;
        graceLeft = gracePerWeek;
        stepsInWeek = 0;
      }
      stepsInWeek++;
    }
    return best;
  }

  static DateTime _earliest(Set<DateTime> days) =>
      days.reduce((a, b) => a.isBefore(b) ? a : b);

  static DateTime _d(DateTime x) => DateTime(x.year, x.month, x.day);

  // Day stepping MUST be calendar-based, never `add/subtract(Duration(days:1))`.
  // A local day is 23 or 25 hours long across a DST transition, so an absolute
  // 24-hour Duration lands on the wrong civil day exactly once per transition —
  // the walk then misses a completed day and the streak silently resets or
  // halves. The DateTime constructor normalizes an out-of-range `day` field
  // against the local calendar, which is DST-safe.
  static DateTime _nextDay(DateTime d) => DateTime(d.year, d.month, d.day + 1);

  static DateTime _prevDay(DateTime d) => DateTime(d.year, d.month, d.day - 1);
}
