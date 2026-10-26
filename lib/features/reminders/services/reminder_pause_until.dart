import 'package:clock/clock.dart';

import '../../../core/services/clean_storage_service.dart';

/// "Pause until…": a reminder paused with a date it comes back on.
///
/// `Reminder.isPaused` is just a flag, and adding a column for a resume date
/// would be a schema migration for one optional value, so the dates live in a
/// preference: `reminderId|yyyy-MM-dd` entries. The reminder itself stays
/// ordinary — paused, unarmed — and [resumeDue] flips it back on once its date
/// arrives.
///
/// [resumeDue] is called from the same re-arm pass that runs at every app start
/// and resume, so a reminder comes back the first time the app is opened on or
/// after its date and is armed in that very pass. There is no timer: a paused
/// reminder fires nothing, so nothing else has a reason to wake the app.
class ReminderPauseUntil {
  const ReminderPauseUntil._();

  static const _key = 'reminder_pause_until';

  static String _fmt(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static Map<String, DateTime> _all() {
    final raw = CleanStorageService.getAppPreference(_key, const <String>[]);
    final out = <String, DateTime>{};
    if (raw is List) {
      for (final e in raw) {
        final s = e.toString();
        final i = s.lastIndexOf('|');
        if (i <= 0) continue;
        final d = DateTime.tryParse(s.substring(i + 1));
        if (d != null) out[s.substring(0, i)] = DateTime(d.year, d.month, d.day);
      }
    }
    return out;
  }

  static Future<void> _save(Map<String, DateTime> m) =>
      CleanStorageService.setAppPreference(
          _key, [for (final e in m.entries) '${e.key}|${_fmt(e.value)}']);

  /// The date [reminderId] comes back on, or null when it is paused with no
  /// end date (or not paused).
  static DateTime? get(String reminderId) => _all()[reminderId];

  static Future<void> set(String reminderId, DateTime until) async {
    final m = _all();
    m[reminderId] = DateTime(until.year, until.month, until.day);
    await _save(m);
  }

  static Future<void> clear(String reminderId) async {
    final m = _all();
    if (m.remove(reminderId) != null) await _save(m);
  }

  /// Ids whose resume date has arrived by [now] (the whole day counts: a
  /// reminder paused until the 20th is back on the morning of the 20th).
  static List<String> due({DateTime? now}) {
    final t = now ?? clock.now();
    final today = DateTime(t.year, t.month, t.day);
    return [
      for (final e in _all().entries)
        if (!e.value.isAfter(today)) e.key,
    ];
  }

  /// Un-pause every reminder whose date has arrived, and forget the dates.
  /// Returns how many were resumed.
  ///
  /// An entry for a reminder that no longer exists, or was resumed by hand, is
  /// dropped too — it must not linger and re-pause nothing forever.
  static Future<int> resumeDue({DateTime? now}) async {
    final ids = due(now: now);
    if (ids.isEmpty) return 0;
    final reminders = await CleanStorageService.getAllReminders();
    final byId = {for (final r in reminders) r.id: r};
    var resumed = 0;
    for (final id in ids) {
      final r = byId[id];
      if (r != null && r.isPaused) {
        await CleanStorageService.saveReminder(r.copyWith(isPaused: false));
        resumed++;
      }
      await clear(id);
    }
    return resumed;
  }
}
