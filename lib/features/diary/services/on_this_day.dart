/// "On this day": what you wrote on today's date in earlier years.
library;

import '../models/diary_entry.dart';

/// One entry from an earlier year, and how long ago that was.
class OnThisDayItem {
  const OnThisDayItem({required this.entry, required this.yearsAgo});

  final DiaryEntry entry;
  final int yearsAgo;

  /// "1 year ago", "3 years ago".
  String get label => yearsAgo == 1 ? '1 year ago' : '$yearsAgo years ago';
}

class OnThisDay {
  const OnThisDay._();

  /// The most that are shown at once.
  static const int maxItems = 3;

  /// Entries dated the same month and day as [today] in an EARLIER year, the
  /// most recent year first (and within a year, the latest entry first).
  ///
  /// This year's own entries are never "on this day" — they are just today.
  /// An entry from 29 February is shown on 28 February in a year with no 29th,
  /// so it comes round every year rather than every fourth.
  static List<OnThisDayItem> forDay(
    List<DiaryEntry> entries,
    DateTime today, {
    int max = maxItems,
  }) {
    final leapFallback = today.month == 2 && today.day == 28 && !_isLeap(today.year);
    final out = <OnThisDayItem>[];
    for (final e in entries) {
      final d = e.entryAt;
      if (d.year >= today.year) continue;
      final sameDay = d.month == today.month && d.day == today.day;
      final leapEntry = leapFallback && d.month == 2 && d.day == 29;
      if (sameDay || leapEntry) {
        out.add(OnThisDayItem(entry: e, yearsAgo: today.year - d.year));
      }
    }
    out.sort((a, b) {
      final byYear = a.yearsAgo.compareTo(b.yearsAgo);
      return byYear != 0 ? byYear : b.entry.entryAt.compareTo(a.entry.entryAt);
    });
    return out.take(max).toList();
  }

  static bool _isLeap(int y) => (y % 4 == 0 && y % 100 != 0) || y % 400 == 0;
}
