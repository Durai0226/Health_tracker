/// Which samples from the health store have already been brought in — or looked
/// at and left out.
///
/// An import that only asks "is this reading in the database?" brings back every
/// reading the person deleted, at the next start. Remembering the ids it has seen
/// is what lets a deletion stick. The list is bounded: it is only ever asked about
/// recent samples, so the oldest ids can go once the cap is reached.
///
/// "Recent" is the window the next run will read again, and that is not a fixed
/// number of ids: an app that writes a reading every few minutes puts thousands
/// into a week. An id still inside that window is the last to go ([appended]'s
/// `keep`), or a reading the person deleted comes back at the next run.
library;

import 'package:shared_preferences/shared_preferences.dart';

class ImportLedger {
  const ImportLedger(this.prefsKey, {this.cap = 1500, this.hardCap = 5000});

  /// The preference the ids are kept under.
  final String prefsKey;

  /// Ids kept, newest last; the oldest are dropped past this — unless they are
  /// still wanted ([appended]'s `keep`).
  final int cap;

  /// The most ever kept, wanted or not: the ids live in the app's preferences,
  /// which are read whole at every start, so they cannot be allowed to grow with
  /// whatever a health app writes.
  final int hardCap;

  /// The ids remembered, oldest first.
  List<String> load(SharedPreferences prefs) => [...?prefs.getStringList(prefsKey)];

  /// [existing] with [added] on the end, the oldest dropped past [cap].
  ///
  /// The ids in [keep] go last: they are still inside the window the next run will
  /// read, so forgetting one is the deleted reading coming back. If they alone are
  /// more than [cap], that many are kept — up to [hardCap], oldest first beyond it.
  List<String> appended(List<String> existing, Iterable<String> added,
      {Set<String> keep = const {}}) {
    final all = [...existing, ...added];
    if (all.length <= cap) return all;
    var drop = all.length - cap;
    final kept = <String>[];
    for (final id in all) {
      if (drop > 0 && !keep.contains(id)) {
        drop--;
        continue;
      }
      kept.add(id);
    }
    return kept.length <= hardCap ? kept : kept.sublist(kept.length - hardCap);
  }

  /// Remember [added] after [existing].
  Future<void> remember(
          SharedPreferences prefs, List<String> existing, Iterable<String> added,
          {Set<String> keep = const {}}) =>
      prefs.setStringList(prefsKey, appended(existing, added, keep: keep));
}
