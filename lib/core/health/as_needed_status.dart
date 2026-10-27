/// Where an as-needed medicine stands right now: when it was last taken, how
/// many doses in the last 24 hours against the most it allows, and when the next
/// is allowed.
///
/// Pure Dart. It reports the limits the person (or their prescriber) set on the
/// medicine — a minimum gap between doses and a most per day — and does nothing
/// about them: nothing is blocked and nothing is advised beyond "follow the
/// label". A medicine with neither limit set simply shows when it was last taken.
library;

class AsNeededStatus {
  const AsNeededStatus({
    required this.takenIn24h,
    this.lastTakenAt,
    this.maxPer24h,
    this.minGap,
    this.okFrom,
  });

  /// Doses in the 24 hours up to now.
  final int takenIn24h;

  final DateTime? lastTakenAt;

  /// The most doses allowed in 24 hours, if one was set.
  final int? maxPer24h;

  /// The least time allowed between doses, if one was set.
  final Duration? minGap;

  /// When the next dose is allowed; null when it is allowed now.
  final DateTime? okFrom;

  bool get allowedNow => okFrom == null;

  /// The daily limit has been reached.
  bool get atLimit => maxPer24h != null && takenIn24h >= maxPer24h!;

  /// "3 h ago · 2 of 4 · OK after 2:30 PM": what it says on its chip.
  /// [formatTime] words a clock time the way the rest of the app does.
  String line({required DateTime now, required String Function(DateTime) formatTime}) {
    final last = lastTakenAt;
    final parts = <String>[
      last == null ? 'Not taken in 24 h' : '${_ago(now.difference(last))} ago',
      if (maxPer24h != null) '$takenIn24h of $maxPer24h',
      if (okFrom == null)
        'OK now'
      else if (atLimit)
        'Limit reached · OK from ${formatTime(okFrom!)}'
      else
        'OK after ${formatTime(okFrom!)}',
    ];
    return parts.join(' · ');
  }

  /// "40 min", "3 h", "3 h 20 min".
  static String _ago(Duration d) {
    final minutes = d.inMinutes < 1 ? 1 : d.inMinutes;
    if (minutes < 60) return '$minutes min';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return m == 0 ? '$h h' : '$h h $m min';
  }

  /// [takenAt] are the times of every logged dose (any age; those older than 24
  /// hours are ignored). [maxPer24h] and [minHours] are the medicine's own
  /// settings; null or zero means no limit.
  static AsNeededStatus of({
    required Iterable<DateTime> takenAt,
    required DateTime now,
    int? maxPer24h,
    int? minHours,
  }) {
    final since = now.subtract(const Duration(hours: 24));
    final recent = [
      for (final t in takenAt)
        if (t.isAfter(since) && !t.isAfter(now)) t,
    ]..sort();
    final last = recent.isEmpty ? null : recent.last;
    final max = (maxPer24h != null && maxPer24h > 0) ? maxPer24h : null;
    final gap = (minHours != null && minHours > 0) ? Duration(hours: minHours) : null;

    DateTime? ok;
    void need(DateTime t) {
      if (t.isAfter(now) && (ok == null || t.isAfter(ok!))) ok = t;
    }

    if (last != null && gap != null) need(last.add(gap));
    if (max != null && recent.length >= max) {
      // The limit lifts when enough of the earliest doses have aged out of the
      // 24-hour window.
      need(recent[recent.length - max].add(const Duration(hours: 24)));
    }

    return AsNeededStatus(
      takenIn24h: recent.length,
      lastTakenAt: last,
      maxPer24h: max,
      minGap: gap,
      okFrom: ok,
    );
  }
}
