/// Shared date-key and aggregation-window rules for the health trackers.
///
/// Steps, Sleep and Biometrics each need "which day does this sample belong
/// to", and two of them need "which NIGHT does it belong to". Those rules were
/// private copies inside `SleepService` and `StepService`; a third copy in
/// BiometricsService would have made "last night" mean two different things in
/// two features, which is unfixable once the data is written.
library;

/// `yyyy-MM-dd`, the primary-key format for every day-keyed health table.
String dateKeyOf(DateTime date) =>
    '${date.year}-${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

/// Midnight on [date], discarding any time component.
DateTime dayOnly(DateTime date) => DateTime(date.year, date.month, date.day);

/// The night a timestamp belongs to, named by its **wake-up morning**.
///
/// A sample at or after 18:00 belongs to the NEXT morning's night. This is the
/// rule `SleepService.syncFromHealth` already buckets by, kept identical here
/// on purpose: HRV, skin temperature and a derived resting heart rate are all
/// nightly figures that have to line up with the sleep session they describe.
String nightDateKeyFor(DateTime t) {
  final base = dayOnly(t);
  return dateKeyOf(t.hour >= 18 ? nextDay(base) : base);
}

/// `[00:00, next 00:00)` on the day named by [dateKey].
({DateTime start, DateTime end}) dayWindowFor(String dateKey) {
  final start = parseDateKey(dateKey);
  return (start: start, end: nextDay(start));
}

/// `[previous day 18:00, 18:00)` for the night named by [dateKey] — i.e. the
/// span whose wake-up morning is [dateKey]. The window HRV, skin temperature
/// and derived resting HR are computed over.
({DateTime start, DateTime end}) nightWindowFor(String dateKey) {
  final morning = parseDateKey(dateKey);
  final prev = previousDay(morning);
  return (
    start: DateTime(prev.year, prev.month, prev.day, 18),
    end: DateTime(morning.year, morning.month, morning.day, 18),
  );
}

/// `[previous day 22:00, 08:00)` — the hours someone is plausibly asleep.
///
/// Distinct from [nightWindowFor], and the difference matters. That one spans
/// 18:00→18:00: a full 24 hours whose only job is to say WHICH night a reading
/// belongs to, which is right for attributing a device's own nightly HRV
/// summary. It is useless for *deriving* a resting heart rate, because it
/// contains the entire waking day — take the low percentile over it and a brisk
/// afternoon still counts as "resting".
///
/// This window is the one to use when inferring resting heart rate from raw
/// samples. It is a proxy, not a sleep session: the app does not require Sleep
/// to be connected for Heart to work.
({DateTime start, DateTime end}) sleepProxyWindowFor(String dateKey) {
  final morning = parseDateKey(dateKey);
  final prev = previousDay(morning);
  return (
    start: DateTime(prev.year, prev.month, prev.day, 22),
    end: DateTime(morning.year, morning.month, morning.day, 8),
  );
}

/// The day after [d], by CALENDAR arithmetic.
///
/// Deliberately `DateTime(y, m, d + 1)` and never `.add(Duration(days: 1))`:
/// Duration is elapsed time, so across a DST boundary it lands on 23:00 or
/// 01:00 of the wrong day. That exact confusion produced 34 assertion failures
/// under `TZ=America/New_York` — see `docs/bug-hunt.md`, "One root cause: DST".
DateTime nextDay(DateTime d) => DateTime(d.year, d.month, d.day + 1);

/// The day before [d]. Calendar arithmetic, for the same DST reason as
/// [nextDay]; `DateTime` normalises day 0 to the last day of the prior month.
DateTime previousDay(DateTime d) => DateTime(d.year, d.month, d.day - 1);

/// Inverse of [dateKeyOf]. Throws [FormatException] on a malformed key — these
/// are primary keys the app writes itself, so a bad one is a bug, not input.
DateTime parseDateKey(String dateKey) {
  final parts = dateKey.split('-');
  if (parts.length != 3) {
    throw FormatException('Not a yyyy-MM-dd date key', dateKey);
  }
  return DateTime(
    int.parse(parts[0]),
    int.parse(parts[1]),
    int.parse(parts[2]),
  );
}
