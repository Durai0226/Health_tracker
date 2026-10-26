import 'package:shared_preferences/shared_preferences.dart';

/// When each reminder was snoozed.
///
/// The occurrence log has a `snoozeCount` column that nothing ever wrote: a
/// snooze is counted in a preference keyed by notification id and reset at the
/// next fire, so "this reminder is snoozed a lot" was not knowable. This keeps
/// the timestamps instead.
///
/// SharedPreferences only, on purpose. A snooze usually happens from a
/// notification button, in a background isolate that has no database
/// connection, so anything richer than a preference could not be written from
/// where the event actually occurs. The main isolate reads it back (after a
/// `reload`, to see what the other isolate wrote) and matches each snooze to
/// the occurrence it followed.
class SnoozeLog {
  const SnoozeLog._();

  /// Newest snoozes kept per notification id. Enough for a few weeks of a
  /// daily reminder, small enough that a never-pruned preference stays tiny.
  static const int maxKept = 40;

  static String keyFor(int baseId) => 'reminder_snooze_log_$baseId';

  /// Record a snooze of notification [baseId] at [at]. Never throws: losing a
  /// data point is nothing, and a snooze must not fail because of it.
  static Future<void> record(
      SharedPreferences prefs, int baseId, DateTime at) async {
    try {
      final key = keyFor(baseId);
      final list = [...(prefs.getStringList(key) ?? const <String>[])]
        ..add(at.toIso8601String());
      final kept =
          list.length > maxKept ? list.sublist(list.length - maxKept) : list;
      await prefs.setStringList(key, kept);
    } catch (_) {}
  }

  /// Every recorded snooze for the notification ids in [baseIds], oldest first.
  ///
  /// A weekday, weekend or custom repeat arms a separate id per day
  /// (`slot + 1..7`), so one reminder's snoozes can sit under several ids and
  /// the caller passes all of them.
  static Future<List<DateTime>> read(Iterable<int> baseIds) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // Another isolate wrote these; without a reload this isolate's cached
      // copy would not have them.
      await prefs.reload();
      final out = <DateTime>[];
      for (final id in baseIds) {
        for (final s in prefs.getStringList(keyFor(id)) ?? const <String>[]) {
          final t = DateTime.tryParse(s);
          if (t != null) out.add(t);
        }
      }
      out.sort();
      return out;
    } catch (_) {
      return const [];
    }
  }
}
