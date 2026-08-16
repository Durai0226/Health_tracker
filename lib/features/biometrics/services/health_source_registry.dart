import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:health/health.dart' show HealthDataPoint;

import '../models/health_source.dart';

/// One source's claim on one metric for one day.
class SourceCandidate {
  final String id;
  final String sourceId;
  final String sourceName;
  final int platformIndex;
  final String? deviceModel;

  /// How many samples this source contributed for the metric being resolved.
  final int sampleCount;
  final DateTime lastSeenAt;

  /// User pin from the Connected-devices screen; 0 = no preference.
  final int priority;

  const SourceCandidate({
    required this.id,
    required this.sourceId,
    required this.sourceName,
    required this.platformIndex,
    required this.sampleCount,
    required this.lastSeenAt,
    this.deviceModel,
    this.priority = 0,
  });

  SourceCandidate withCount(int count) => SourceCandidate(
        id: id,
        sourceId: sourceId,
        sourceName: sourceName,
        platformIndex: platformIndex,
        deviceModel: deviceModel,
        sampleCount: count,
        lastSeenAt: lastSeenAt,
        priority: priority,
      );
}

/// Identity and precedence for the apps/devices that write health data.
///
/// Pure functions only — everything here is driven by injected points and
/// preferences so it is testable without a plugin channel, matching the seam
/// `VitalsStorageService.importFromHealthConnect({samples})` established.
abstract final class HealthSourceRegistry {
  /// Stable primary key for a contributing source.
  ///
  /// Hashed rather than concatenated because `sourceName` is user-supplied on
  /// both platforms and routinely contains a person's name ("Durai's Apple
  /// Watch"). The name still lives in a field, but the KEY becomes a Firestore
  /// document id, and personal data does not belong in one.
  ///
  /// Keyed on `(platform, sourceId, sourceName)` and deliberately NOT on
  /// `sourceDeviceId` — see `biometrics_tables.dart` for why that field is
  /// unusable.
  static String keyFor(HealthDataPoint p) =>
      keyForParts(p.sourcePlatform.name, p.sourceId, p.sourceName);

  static String keyForParts(String platform, String sourceId, String name) {
    final raw = '$platform:$sourceId:$name';
    return 'src_${sha1.convert(utf8.encode(raw)).toString().substring(0, 16)}';
  }

  /// Which of two sources supplies a metric for a given day.
  ///
  /// A deterministic TOTAL order, mirroring `SleepService._winsOver`. Every
  /// tier exists for a reason:
  ///
  /// 1. **User pin** beats every automatic signal — someone naming their watch
  ///    is the strongest evidence available.
  /// 2. **More samples** for that metric that day. Objective and needs no
  ///    configuration: a device worn all day contributes more than one that
  ///    logged three spot readings.
  /// 3. **Later last-seen** — the device still in use.
  /// 4. **Lexicographic id.** Never reached in practice, and that is the point:
  ///    without it two equally-ranked devices could alternate between syncs,
  ///    and the trend line would jump between two calibrations, fabricating
  ///    day-to-day variation that is really just a coin flip.
  static bool wins(SourceCandidate a, SourceCandidate b) {
    if (a.priority != b.priority) return a.priority > b.priority;
    if (a.sampleCount != b.sampleCount) return a.sampleCount > b.sampleCount;
    if (a.lastSeenAt != b.lastSeenAt) return a.lastSeenAt.isAfter(b.lastSeenAt);
    return a.id.compareTo(b.id) < 0;
  }

  /// The single source a metric's numbers must come from.
  ///
  /// Returns null when [candidates] is empty. Callers MUST then use only that
  /// source's samples: blending an Oura ring's heart rate with a Galaxy Watch's
  /// for the same day produces a min/max range no device ever measured, which
  /// is the same class of fabrication as a zero-filled chart gap.
  static SourceCandidate? pickWinner(Iterable<SourceCandidate> candidates) {
    SourceCandidate? best;
    for (final c in candidates) {
      if (best == null || wins(c, best)) best = c;
    }
    return best;
  }

  /// Group [points] by contributing source, counting samples.
  static Map<String, SourceCandidate> candidatesFrom(
    Iterable<HealthDataPoint> points, {
    Map<String, HealthSource> known = const {},
  }) {
    final counts = <String, int>{};
    final seen = <String, DateTime>{};
    final proto = <String, HealthDataPoint>{};

    for (final p in points) {
      final key = keyFor(p);
      counts[key] = (counts[key] ?? 0) + 1;
      final at = p.dateTo;
      final prev = seen[key];
      if (prev == null || at.isAfter(prev)) seen[key] = at;
      proto.putIfAbsent(key, () => p);
    }

    return {
      for (final key in counts.keys)
        key: SourceCandidate(
          id: key,
          sourceId: proto[key]!.sourceId,
          sourceName: proto[key]!.sourceName,
          platformIndex: proto[key]!.sourcePlatform.index,
          deviceModel: proto[key]!.deviceModel,
          sampleCount: counts[key]!,
          lastSeenAt: seen[key]!,
          priority: known[key]?.priority ?? 0,
        ),
    };
  }

  /// Merge this pass's observations into the stored registry.
  ///
  /// `points` accumulate rather than overwrite, so the screen can say how much
  /// a device has ever contributed. `priority` and `enabled` are NEVER touched
  /// here — a sync refreshing `lastSeenAt` must not clobber a user preference.
  static HealthSource merge({
    required SourceCandidate candidate,
    required String metricKey,
    required DateTime now,
    HealthSource? existing,
  }) {
    final metrics = Map<String, SourceMetricStat>.from(existing?.metrics ?? {});
    final prior = metrics[metricKey];
    metrics[metricKey] = SourceMetricStat(
      lastSeenAt: candidate.lastSeenAt,
      points: (prior?.points ?? 0) + candidate.sampleCount,
    );

    if (existing == null) {
      return HealthSource(
        id: candidate.id,
        sourceId: candidate.sourceId,
        sourceName: candidate.sourceName,
        deviceModel: candidate.deviceModel,
        platformIndex: candidate.platformIndex,
        metrics: metrics,
        firstSeenAt: candidate.lastSeenAt,
        lastSeenAt: candidate.lastSeenAt,
        createdAt: now,
        updatedAt: now,
      );
    }

    return existing.copyWith(
      metrics: metrics,
      lastSeenAt: candidate.lastSeenAt.isAfter(existing.lastSeenAt)
          ? candidate.lastSeenAt
          : existing.lastSeenAt,
      updatedAt: now,
      // A device can be renamed; keep the freshest label the platform gave us.
      sourceName: candidate.sourceName.isNotEmpty
          ? candidate.sourceName
          : existing.sourceName,
      deviceModel: candidate.deviceModel ?? existing.deviceModel,
    );
  }
}
