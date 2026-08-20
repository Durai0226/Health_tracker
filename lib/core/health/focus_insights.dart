/// Pure-Dart focus analytics: an "energy curve" over the day from the user's own
/// completed sessions, so we can tell them their best focus window — the honest,
/// data-grounded version of what Rise/RescueTime market (no sleep biomath, no
/// unsupported "burnout index").
class FocusSessionRef {
  /// Hour the session started (0..23).
  final int startHour;

  /// Focused minutes in the session.
  final int minutes;

  /// Whether the session was completed (vs abandoned).
  final bool completed;

  const FocusSessionRef({
    required this.startHour,
    required this.minutes,
    this.completed = true,
  });
}

class FocusInsights {
  const FocusInsights._();

  /// Total focused minutes per hour-of-day (24 buckets).
  static List<int> hourlyMinutes(List<FocusSessionRef> sessions) {
    final buckets = List<int>.filled(24, 0);
    for (final s in sessions) {
      if (s.startHour >= 0 && s.startHour < 24) buckets[s.startHour] += s.minutes;
    }
    return buckets;
  }

  /// The hour with the most accumulated focus, or null with too little history.
  static int? bestFocusHour(List<FocusSessionRef> sessions, {int minSessions = 5}) {
    if (sessions.length < minSessions) return null;
    final buckets = hourlyMinutes(sessions);
    var best = -1, bestMin = 0;
    for (var h = 0; h < 24; h++) {
      if (buckets[h] > bestMin) {
        bestMin = buckets[h];
        best = h;
      }
    }
    return best >= 0 && bestMin > 0 ? best : null;
  }

  /// Session-completion rate (0..1) — a gentle signal for right-sizing session
  /// length (low completion → suggest shorter sessions).
  static double completionRate(List<FocusSessionRef> sessions) {
    if (sessions.isEmpty) return 0;
    final done = sessions.where((s) => s.completed).length;
    return done / sessions.length;
  }

  /// The session length this user actually FINISHES, or null if unknown yet.
  ///
  /// The duration someone picks and the duration they see through are different
  /// numbers. A user who repeatedly sets 45 minutes and gives up at 18 is being
  /// quietly told twice a day that they failed, when the honest reading is that
  /// their real session is twenty minutes and they have been choosing badly.
  ///
  /// Three deliberate choices:
  ///
  ///  * **Only completed sessions count.** Abandoned ones measure the ambition,
  ///    not the capacity, and feeding them back in would keep recommending the
  ///    length that is not working.
  ///  * **Median, not mean.** One 180-minute marathon should not drag the
  ///    suggestion up for weeks.
  ///  * **Returns null under [minSessions].** A confident recommendation from two
  ///    data points is worse than saying nothing, because the user cannot tell
  ///    which one they are being given. Silence is the correct output for
  ///    not-enough-evidence.
  ///
  /// Rounded to the nearest 5 minutes so the app suggests "20", not "19".
  static int? suggestedMinutes(
    List<FocusSessionRef> sessions, {
    int minSessions = 5,
  }) {
    final done = sessions.where((s) => s.completed).map((s) => s.minutes).toList()
      ..sort();
    if (done.length < minSessions) return null;

    final mid = done.length ~/ 2;
    final median = done.length.isOdd
        ? done[mid]
        : ((done[mid - 1] + done[mid]) / 2).round();

    final rounded = (median / 5).round() * 5;
    return rounded.clamp(5, 120);
  }

  /// Human 12-hour label for an hour ("2 PM", "9 AM").
  static String hourLabel(int hour) {
    final h12 = hour % 12 == 0 ? 12 : hour % 12;
    final ap = hour < 12 ? 'AM' : 'PM';
    return '$h12 $ap';
  }
}
