import '../models/blood_pressure_reading.dart';

/// Readings taken back to back, treated as one measurement.
///
/// Home-monitoring guidance (AHA, ESC) is to take two readings a minute or so
/// apart and use their average, because a single reading is noisy. The app
/// stores every reading as the user entered it and never rewrites one: a
/// session is DERIVED here, at read time, so raw readings, backups and the
/// Health Connect write all stay exactly as logged and nothing needs migrating.
///
/// Every place that averages, classifies or charts BP should go through
/// [collapse] rather than touch raw rows. The two things that must NOT are the
/// History list (the user's own entries) and the crisis emergency card, which
/// looks at the latest raw reading: averaging must never be able to hide one
/// dangerously high value.
class BpSession {
  /// Oldest first. Never empty.
  final List<BloodPressureReading> readings;

  const BpSession(this.readings);

  BloodPressureReading get first => readings.first;
  bool get isAveraged => readings.length > 1;

  /// The session's time — that of its first reading, so a session that spans
  /// 07:58–08:03 stays a morning reading in the morning/evening split.
  DateTime get takenAt => first.takenAt;

  static int _avg(Iterable<int> v) {
    final list = v.toList();
    return (list.reduce((a, b) => a + b) / list.length).round();
  }

  int get systolic => _avg(readings.map((r) => r.systolic));
  int get diastolic => _avg(readings.map((r) => r.diastolic));

  /// Mean of the pulses that were entered, or null when none were.
  int? get pulse {
    final p = readings.where((r) => r.pulse != null).map((r) => r.pulse!);
    return p.isEmpty ? null : _avg(p);
  }

  /// This session as one reading, shaped like any other so existing code can
  /// consume it unchanged. A single-reading session is returned as is.
  ///
  /// The id is the first reading's: it is for aggregation only, and nothing
  /// that edits or deletes ever receives one of these.
  BloodPressureReading toReading() {
    if (!isAveraged) return first;
    return first.copyWith(
      systolic: systolic,
      diastolic: diastolic,
      pulse: pulse,
    );
  }
}

class BpSessions {
  const BpSessions._();

  /// How long after a session's FIRST reading another still joins it.
  ///
  /// Anchored on the first reading rather than chained from the previous one,
  /// so a reading every eight minutes all afternoon cannot grow one endless
  /// "session".
  static const Duration window = Duration(minutes: 10);

  /// Groups [readings] into sessions, oldest first.
  ///
  /// Readings only join when they belong to the same person
  /// ([BloodPressureReading.dependentId]), so a parent's reading and a child's
  /// logged a minute apart are never averaged together.
  static List<BpSession> group(Iterable<BloodPressureReading> readings,
      {Duration window = window}) {
    final byPerson = <String?, List<BloodPressureReading>>{};
    for (final r in readings) {
      (byPerson[r.dependentId] ??= []).add(r);
    }

    final sessions = <BpSession>[];
    for (final list in byPerson.values) {
      list.sort((a, b) => a.takenAt.compareTo(b.takenAt));
      var current = <BloodPressureReading>[];
      for (final r in list) {
        if (current.isNotEmpty &&
            r.takenAt.difference(current.first.takenAt) > window) {
          sessions.add(BpSession(current));
          current = <BloodPressureReading>[];
        }
        current.add(r);
      }
      if (current.isNotEmpty) sessions.add(BpSession(current));
    }
    sessions.sort((a, b) => a.takenAt.compareTo(b.takenAt));
    return sessions;
  }

  /// One reading per session, for code that averages or classifies.
  ///
  /// [newestFirst] matches the order the caller already holds its list in; the
  /// DAO returns newest first, charts want oldest first.
  static List<BloodPressureReading> collapse(
    Iterable<BloodPressureReading> readings, {
    bool newestFirst = true,
    Duration window = window,
  }) {
    final out = group(readings, window: window).map((s) => s.toReading()).toList();
    return newestFirst ? out.reversed.toList() : out;
  }

  /// The session that contains the reading with [id], or null.
  static BpSession? containing(Iterable<BloodPressureReading> readings, String id,
      {Duration window = window}) {
    for (final s in group(readings, window: window)) {
      if (s.readings.any((r) => r.id == id)) return s;
    }
    return null;
  }
}
