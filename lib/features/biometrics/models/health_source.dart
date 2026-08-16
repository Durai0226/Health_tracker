import 'dart:convert';

import 'package:drift/drift.dart' show Value;

import '../../../core/database/app_database.dart' as db;
import 'biometric_metric.dart';

/// What one contributing app or device has supplied for one metric.
class SourceMetricStat {
  final DateTime lastSeenAt;
  final int points;

  const SourceMetricStat({required this.lastSeenAt, required this.points});
}

/// An app or wearable that actually writes data we read — the row behind the
/// Connected-devices screen.
///
/// Identity is `(platform, sourceId, sourceName)`, NOT `sourceDeviceId`: the
/// plugin fills that from `Health().deviceId`, which resolves to the literal
/// `'unknown'` since the singleton was removed, and even when populated names
/// *this phone* rather than the watch. See `biometrics_tables.dart`.
class HealthSource {
  final String id; // src_<sha1[0:16]>
  final String sourceId; // bundle id / package name
  final String sourceName; // "Galaxy Watch5", "Oura"
  final String? deviceModel; // iOS-only; always null on Android
  final int platformIndex;

  /// Per-metric contribution, keyed by [BiometricMetricKey].
  final Map<String, SourceMetricStat> metrics;

  final DateTime firstSeenAt;
  final DateTime lastSeenAt;

  /// User pin from the Connected-devices screen. 0 = no preference; higher
  /// wins, and beats every automatic signal.
  final int priority;

  /// User switched this source off — excluded from aggregation entirely.
  final bool enabled;

  final DateTime createdAt;
  final DateTime updatedAt;

  const HealthSource({
    required this.id,
    required this.sourceId,
    required this.sourceName,
    required this.platformIndex,
    required this.firstSeenAt,
    required this.lastSeenAt,
    required this.createdAt,
    required this.updatedAt,
    this.deviceModel,
    this.metrics = const {},
    this.priority = 0,
    this.enabled = true,
  });

  /// What the user sees. Falls back through the fields most likely to be
  /// meaningful; `sourceId` is a package name, so it is the last resort.
  String get displayName =>
      sourceName.trim().isNotEmpty ? sourceName.trim() : sourceId;

  /// Metric keys this source has ever supplied, in the canonical order so the
  /// chips don't reshuffle between rebuilds.
  List<String> get contributedMetrics => BiometricMetricKey.values
      .where((k) => (metrics[k]?.points ?? 0) > 0)
      .toList();

  factory HealthSource.fromRow(db.HealthSourceRow r) => HealthSource(
        id: r.id,
        sourceId: r.sourceId,
        sourceName: r.sourceName,
        deviceModel: r.deviceModel,
        platformIndex: r.platformIndex,
        metrics: decodeMetrics(r.metricsJson),
        firstSeenAt: r.firstSeenAt,
        lastSeenAt: r.lastSeenAt,
        priority: r.priority,
        enabled: r.enabled,
        createdAt: r.createdAt,
        updatedAt: r.updatedAt,
      );

  db.HealthSourcesCompanion toCompanion() => db.HealthSourcesCompanion(
        id: Value(id),
        sourceId: Value(sourceId),
        sourceName: Value(sourceName),
        deviceModel: Value(deviceModel),
        platformIndex: Value(platformIndex),
        metricsJson: Value(encodeMetrics(metrics)),
        firstSeenAt: Value(firstSeenAt),
        lastSeenAt: Value(lastSeenAt),
        priority: Value(priority),
        enabled: Value(enabled),
        createdAt: Value(createdAt),
        updatedAt: Value(updatedAt),
        synced: const Value(false),
      );

  HealthSource copyWith({
    Map<String, SourceMetricStat>? metrics,
    DateTime? lastSeenAt,
    DateTime? updatedAt,
    int? priority,
    bool? enabled,
    String? sourceName,
    String? deviceModel,
  }) =>
      HealthSource(
        id: id,
        sourceId: sourceId,
        sourceName: sourceName ?? this.sourceName,
        deviceModel: deviceModel ?? this.deviceModel,
        platformIndex: platformIndex,
        metrics: metrics ?? this.metrics,
        firstSeenAt: firstSeenAt,
        lastSeenAt: lastSeenAt ?? this.lastSeenAt,
        priority: priority ?? this.priority,
        enabled: enabled ?? this.enabled,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  static Map<String, SourceMetricStat> decodeMetrics(String? json) {
    if (json == null || json.isEmpty) return const {};
    try {
      final map = jsonDecode(json) as Map;
      final out = <String, SourceMetricStat>{};
      map.forEach((k, v) {
        if (v is! Map) return;
        final ms = v['lastSeenMs'];
        final pts = v['points'];
        if (ms is! num || pts is! num) return;
        out['$k'] = SourceMetricStat(
          lastSeenAt: DateTime.fromMillisecondsSinceEpoch(ms.toInt()),
          points: pts.toInt(),
        );
      });
      return out;
    } catch (_) {
      return const {};
    }
  }

  static String encodeMetrics(Map<String, SourceMetricStat> metrics) =>
      jsonEncode(metrics.map((k, v) => MapEntry(k, {
            'lastSeenMs': v.lastSeenAt.millisecondsSinceEpoch,
            'points': v.points,
          })));
}
