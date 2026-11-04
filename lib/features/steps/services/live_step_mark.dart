/// Where the phone's step counter stood the last time a day's count was written
/// down.
///
/// Android's step sensor reports steps cumulative since the phone started, and keeps
/// counting whether or not this app is running. Today's count is that reading minus
/// the reading at the start of tracking, so a session that starts later has nothing
/// to subtract from, and the steps taken while the app was closed were never
/// counted. The mark is that missing reading: written beside the day, read at the
/// first event of the next session.
class LiveStepMark {
  const LiveStepMark({required this.dayKey, required this.raw});

  /// The calendar day (yyyy-MM-dd) the reading was taken on.
  final String dayKey;

  /// The sensor's cumulative-since-boot reading.
  final int raw;

  String encode() => '$dayKey|$raw';

  /// The mark [encode] wrote, or null for anything else: a missing, hand-edited or
  /// half-written value counts nothing rather than guessing.
  static LiveStepMark? decode(Object? stored) {
    if (stored is! String) return null;
    final at = stored.lastIndexOf('|');
    if (at <= 0) return null;
    final raw = int.tryParse(stored.substring(at + 1));
    if (raw == null || raw < 0) return null;
    return LiveStepMark(dayKey: stored.substring(0, at), raw: raw);
  }

  /// The steps to add to [todayKey] for a session whose first reading is [reading].
  ///
  /// Never more than were taken, and zero when that cannot be said:
  ///  * another day: a gap that runs across midnight cannot be split between the two
  ///    days, and adding all of it to today would invent a day's worth of walking;
  ///  * a reading below the mark: the phone restarted and its counter began again.
  ///    The steps since then are real, but so are the ones before the restart, and
  ///    only the difference is known, so nothing is claimed.
  int stepsSince(String todayKey, int reading) {
    if (dayKey != todayKey) return 0;
    final gap = reading - raw;
    return gap > 0 ? gap : 0;
  }
}
