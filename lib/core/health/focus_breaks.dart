/// How long someone has been focusing without a break — and when that is long
/// enough to ask before another round.
///
/// Pure Dart: no clock, no storage, no Flutter. `FocusService` hands over its
/// sessions and the time; the Focus screen shows the question.
///
/// ## What is offered, and what is not
///
/// A question with two honest answers, never a refusal. The evidence for breaks is
/// on how tired people *feel* — structured breaks cut subjective fatigue, and
/// trials find no objective advantage over breaks people take themselves — so
/// this asks at the moment the next round is about to start, offers a break whose
/// length is the Flowtime one, and starts the round the moment they say so.
///
/// ## What counts as a break
///
/// A gap of [realBreakMinutes] between one round ending and the next beginning.
/// A Pomodoro's five-minute rests are not that — a person who has done four
/// rounds with only those has not had a break — and its long one is. A stand-alone
/// rest break is not recorded anywhere, so it shows up as exactly what it is: time
/// with no round in it.
library;

/// One round of focus: when it began and ended, and how many minutes were focus.
class FocusSpan {
  const FocusSpan({required this.start, required this.end, required this.minutes});

  final DateTime start;
  final DateTime end;

  /// Minutes actually focused. Not `end - start`: that includes the time a round
  /// spent paused.
  final int minutes;
}

/// The run of rounds that has gone on up to now with no real break in it.
class FocusStretch {
  const FocusStretch(this.minutes, this.since);

  /// Minutes focused in the run.
  final int minutes;

  /// When the first round of the run began; null when there is no run.
  ///
  /// Identifies the run: a declined offer is about THIS run, and a real break
  /// starts another.
  final DateTime? since;

  static const FocusStretch none = FocusStretch(0, null);
}

abstract final class FocusBreaks {
  /// A gap this long between two rounds is a break.
  static const int realBreakMinutes = 10;

  /// Ask before another round once a run reaches this many minutes.
  static const int offerAfterMinutes = 90;

  /// After a "start anyway", ask again once the run has grown by this much.
  static const int askAgainAfterMinutes = 60;

  /// Only rounds this recent can be part of the run: a run with no ten-minute gap
  /// in twelve hours is not something to be precise about.
  static const int lookBackHours = 12;

  /// The run ending at [now].
  ///
  /// Empty if the last round ended [realBreakMinutes] or more ago: the break has
  /// already happened.
  static FocusStretch stretch(Iterable<FocusSpan> spans, {required DateTime now}) {
    final since = now.subtract(const Duration(hours: lookBackHours));
    final recent = [
      for (final s in spans)
        if (s.minutes > 0 && s.end.isAfter(since) && !s.start.isAfter(now)) s
    ]..sort((a, b) => b.end.compareTo(a.end));
    if (recent.isEmpty) return FocusStretch.none;

    const gap = Duration(minutes: realBreakMinutes);
    final newest = recent.first;
    if (now.difference(newest.end) >= gap) return FocusStretch.none;

    var minutes = newest.minutes;
    var begins = newest.start;
    for (final s in recent.skip(1)) {
      // Rounds that overlap (a clock that moved) have a negative gap, which is
      // under any break and keeps the run going.
      if (begins.difference(s.end) >= gap) break;
      minutes += s.minutes;
      if (s.start.isBefore(begins)) begins = s.start;
    }
    return FocusStretch(minutes, begins);
  }

  /// Whether to ask before another round.
  ///
  /// [declined] is the run as it stood when they last said "start anyway". The same
  /// run is asked about again only after it has grown by [askAgainAfterMinutes]; a
  /// different run (there was a real break since) is asked about afresh.
  static bool shouldOffer(FocusStretch current, {FocusStretch? declined}) {
    if (current.minutes < offerAfterMinutes) return false;
    if (declined == null || declined.since != current.since) return true;
    return current.minutes >= declined.minutes + askAgainAfterMinutes;
  }

  /// "45 min", "1 h 40 min", "2 h".
  static String duration(int minutes) {
    if (minutes < 60) return '$minutes min';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return m == 0 ? '$h h' : '$h h $m min';
  }

  /// What the question says.
  static String offerMessage(int focusedMinutes) =>
      'You have focused for ${duration(focusedMinutes)} without a break of '
      '$realBreakMinutes minutes or more. A short one before the next round can '
      'make it feel lighter.';
}
