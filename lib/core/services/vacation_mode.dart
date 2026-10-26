import 'package:clock/clock.dart';

import '../health/vacation_periods.dart';
import 'clean_storage_service.dart';

/// "I'm away": pauses everyday reminders and freezes streaks until a date.
///
/// What it touches, and what it deliberately does not:
///  * Generic reminders (the Reminders feature) are not armed on vacation days,
///    and their missed occurrences are not counted against the user.
///  * Streaks for water, steps, focus and reminders skip the days.
///  * **Medicines are never touched.** A dose reminder is not paused by going
///    away, and a medicine streak is not frozen: forgiving a missed dose by
///    mistake is the wrong direction to be generous in.
class VacationMode {
  const VacationMode._();

  static const _key = 'vacation_periods';

  static List<VacationPeriod> periods() =>
      VacationPeriods.decodeAll(CleanStorageService.getAppPreference(_key, const <String>[]));

  static VacationPeriod? active({DateTime? now}) =>
      VacationPeriods.active(periods(), now ?? clock.now());

  static bool isActive({DateTime? now}) => active(now: now) != null;

  /// The days streaks must skip, up to and including [now].
  static Set<DateTime> frozenDays({DateTime? now}) =>
      VacationPeriods.frozenDays(periods(), now ?? clock.now());

  /// Whether [instant] is on a vacation day.
  static bool covers(DateTime instant) =>
      VacationPeriods.coversInstant(periods(), instant);

  /// Start a vacation today, ending on [until] inclusive.
  static Future<void> start({required DateTime until, DateTime? now}) async {
    final today = now ?? clock.now();
    await CleanStorageService.setAppPreference(
      _key,
      VacationPeriods.encodeAll(
          VacationPeriods.add(periods(), from: today, until: until)),
    );
  }

  /// End the current vacation now; the days already spent away stay frozen.
  static Future<void> endNow({DateTime? now}) async {
    await CleanStorageService.setAppPreference(
      _key,
      VacationPeriods.encodeAll(
          VacationPeriods.endEarly(periods(), now ?? clock.now())),
    );
  }
}
