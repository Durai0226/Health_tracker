/// Shared "respect quiet hours" math, promoted out of `WaterReminderConfig`
/// (which used to own a private copy of this exact filter) so any OTHER
/// auto-generated reminder type in this app can reuse the same rule instead
/// of reimplementing it.
///
/// Pure and parameterized on purpose — it doesn't fetch the wake/bed hours
/// itself, so it stays dependency-free and isolate-safe, matching
/// `reminder_window_nudges.dart`'s pattern.
///
/// Deliberately NOT applied anywhere a user explicitly picked a time (a
/// medicine dose, a vitals reminder, a custom/generic reminder, a focus
/// reminder) — every reminder type in this app besides water's interval
/// reminders is user-time-picked (confirmed by reading every scheduling call
/// site: medicine doses, vitals, generic/custom reminders, and focus
/// reminders all carry an explicit hour/minute the user chose). Silently
/// overriding that choice would be a regression, not an improvement, and for
/// a medicine dose specifically could suppress a clinically-timed reminder —
/// see AGENTS.md's "windows as a per-medicine OPTION, exact times stay
/// default" principle. This only makes sense for auto-generated candidate
/// times, like water's interval reminders, where the app (not the user)
/// picked the exact minute.
class QuietHours {
  QuietHours._();

  /// Whether [minuteOfDay] (0-1439) falls inside the wake→bedtime window.
  ///
  /// [wakeMinute]/[bedMinute] default to 0 so existing hour-only callers are
  /// unaffected; pass them when the window boundary isn't on the hour (e.g.
  /// derived from a real sleep average).
  static bool isAllowedMinute(
    int minuteOfDay, {
    required bool respectQuietHours,
    required int wakeHour,
    required int bedHour,
    int wakeMinute = 0,
    int bedMinute = 0,
  }) {
    if (!respectQuietHours) return true;
    final lo = wakeHour * 60 + wakeMinute;
    final hi = bedHour * 60 + bedMinute;
    if (lo <= hi) return minuteOfDay >= lo && minuteOfDay <= hi;
    // Overnight awake window (e.g. a night-shift profile: wake 22:00, bed
    // 06:00) wraps past midnight, so a single lo..hi range would filter out
    // everything.
    return minuteOfDay >= lo || minuteOfDay <= hi;
  }

  /// [candidateMinutes], sorted and filtered down to the allowed window.
  static List<int> filterMinutes(
    List<int> candidateMinutes, {
    required bool respectQuietHours,
    required int wakeHour,
    required int bedHour,
    int wakeMinute = 0,
    int bedMinute = 0,
  }) {
    final sorted = [...candidateMinutes]..sort();
    if (!respectQuietHours) return sorted;
    return sorted
        .where((m) => isAllowedMinute(m,
            respectQuietHours: respectQuietHours,
            wakeHour: wakeHour,
            bedHour: bedHour,
            wakeMinute: wakeMinute,
            bedMinute: bedMinute))
        .toList();
  }
}
