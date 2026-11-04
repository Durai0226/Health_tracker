/// Things found by when they happened, so "is there one within two minutes of
/// this?" looks at the few near it instead of every one there is.
///
/// The import asks that of every reading it has not seen, against every reading
/// already kept. As a scan of the whole list that is the two lengths multiplied:
/// harmless for a cuff, but a glucose sensor writes one every five minutes. On a
/// phone restored from a backup the kept list holds months of them while the
/// ledger of what was seen is empty (it is not in the backup), so the first run
/// compares tens of thousands with tens of thousands — hundreds of millions of
/// comparisons on the UI isolate, with the app frozen while it does.
class TimeIndex<T> {
  TimeIndex(Iterable<T> items, {required DateTime Function(T item) at}) : _at = at {
    items.forEach(add);
  }

  final DateTime Function(T item) _at;
  final Map<int, List<T>> _byMinute = {};

  /// File one more item, so a later question sees it too.
  void add(T item) => (_byMinute[_minuteOf(_at(item))] ??= <T>[]).add(item);

  static int _minuteOf(DateTime t) =>
      (t.millisecondsSinceEpoch / Duration.millisecondsPerMinute).floor();

  /// Whether some item that [matches] happened within [within] of [at], either
  /// side, the limit included.
  bool anyNear(DateTime at, Duration within, bool Function(T item) matches) {
    // Two moments within [within] of each other are at most this many minute
    // buckets apart, so these are the only buckets that can hold one.
    final reach = (within.inMilliseconds / Duration.millisecondsPerMinute).ceil();
    final minute = _minuteOf(at);
    for (var m = minute - reach; m <= minute + reach; m++) {
      final bucket = _byMinute[m];
      if (bucket == null) continue;
      for (final item in bucket) {
        if (_at(item).difference(at).abs() <= within && matches(item)) return true;
      }
    }
    return false;
  }
}
