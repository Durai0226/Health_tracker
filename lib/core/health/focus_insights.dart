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

  /// Human 12-hour label for an hour ("2 PM", "9 AM").
  static String hourLabel(int hour) {
    final h12 = hour % 12 == 0 ? 12 : hour % 12;
    final ap = hour < 12 ? 'AM' : 'PM';
    return '$h12 $ap';
  }
}
