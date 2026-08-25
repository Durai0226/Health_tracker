import 'package:clock/clock.dart';

import 'date_formats.dart';

/// "4 hours ago" — one implementation, replacing five that had drifted.
///
/// Before this there were five hand-rolled copies with different vocabularies:
/// `connected_devices_screen.dart` said "3 days ago" while `blood_sugar_screen`,
/// `mood_screen`, `weight_screen` and `blood_pressure_screen` all said "3d ago".
/// Same concept, four screens, two spellings, and none of them localisable or
/// testable.
///
/// Two behaviours worth stating because every one of those copies got them
/// wrong:
///
/// **The tail is bounded.** "Last seen 412 days ago" is not information. Past a
/// week this hands off to [DateFormats.dayLabel], which is already year-aware,
/// so an old timestamp reads as "Mar 14" or "Mar 14, 2024".
///
/// **A future timestamp clamps to "just now".** A wearable syncing with clock
/// skew genuinely produces a `lastSeenAt` in the future. The old code rendered
/// that as "0 min ago" by accident, and would have rendered negative values if
/// its branch order ever changed.
///
/// Returns the **bare** phrase, never a prefixed sentence, so callers compose:
/// `'Last seen ${RelativeTime.since(at)}'`. [now] is injectable; production
/// callers omit it and get `clock.now()`, which is this project's convention.
class RelativeTime {
  const RelativeTime._();

  /// Bare relative phrase for [at].
  static String since(DateTime at, {DateTime? now}) {
    final ref = now ?? clock.now();
    final delta = ref.difference(at);

    // Clock skew: a timestamp from the future is "just now", not a negative
    // duration rendered as if it were positive.
    if (delta.isNegative) return 'just now';

    if (delta.inMinutes < 1) return 'just now';
    if (delta.inMinutes < 60) {
      final m = delta.inMinutes;
      return '$m min ago';
    }
    if (delta.inHours < 24) {
      final h = delta.inHours;
      return h == 1 ? '1 hour ago' : '$h hours ago';
    }
    if (delta.inDays == 1) return 'yesterday';
    if (delta.inDays <= 6) return '${delta.inDays} days ago';

    // Past a week a relative phrase stops being useful — give the date.
    //
    // Bare, with no "on " lead-in, because the whole point of returning a bare
    // phrase is that callers compose it. "Last seen Mar 14" and "Last reading ·
    // Mar 14" both read naturally; "Last reading · on Mar 14" does not, and a
    // preposition baked in here is one the caller cannot remove.
    return DateFormats.dayLabel(at, reference: ref);
  }

  /// [since], prefixed. The common caller shape.
  static String lastSeen(DateTime at, {DateTime? now}) =>
      'Last seen ${since(at, now: now)}';

  /// Null in, null out — so a caller renders nothing rather than a placeholder.
  ///
  /// Same discipline as `ReminderAdherence.proportionOfDaysCovered` returning
  /// null instead of zero: "we have no timestamp" and "the timestamp is old"
  /// are different facts and must not share a rendering.
  static String? sinceOrNull(DateTime? at, {DateTime? now}) =>
      at == null ? null : since(at, now: now);
}
