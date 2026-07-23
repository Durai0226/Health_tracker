import 'dart:convert';
import 'package:drift/drift.dart' show Value;
import 'package:tablet_remainder/core/database/app_database.dart' as db;
import 'flow_intensity.dart';

/// A single logged calendar day. The id is the `yyyy-MM-dd` date key so a day is
/// upserted idempotently.
class PeriodDay {
  final String id; // yyyy-MM-dd
  final DateTime date;
  final String? cycleId;
  final int flowIndex;
  final int? mood; // 1..5
  final int? energy; // 1..5
  final double? bbtCelsius;
  final bool? intercourse;
  final List<String> symptomIds;
  final String? note;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const PeriodDay({
    required this.id,
    required this.date,
    this.cycleId,
    this.flowIndex = 0,
    this.mood,
    this.energy,
    this.bbtCelsius,
    this.intercourse,
    this.symptomIds = const [],
    this.note,
    this.createdAt,
    this.updatedAt,
  });

  /// Build the canonical `yyyy-MM-dd` id for a date.
  static String keyFor(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  /// A fresh, empty day for [date].
  factory PeriodDay.empty(DateTime date) {
    final d = DateTime(date.year, date.month, date.day);
    return PeriodDay(id: keyFor(d), date: d);
  }

  FlowIntensity get flow => FlowIntensityX.fromIndex(flowIndex);

  bool get isBleeding => flowIndex > 0;

  /// True when the day carries anything worth persisting.
  bool get hasData =>
      flowIndex > 0 ||
      mood != null ||
      energy != null ||
      bbtCelsius != null ||
      intercourse == true ||
      symptomIds.isNotEmpty ||
      (note != null && note!.trim().isNotEmpty);

  PeriodDay copyWith({
    String? cycleId,
    int? flowIndex,
    int? mood,
    int? energy,
    double? bbtCelsius,
    bool? intercourse,
    List<String>? symptomIds,
    String? note,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool clearBbt = false,
    bool clearMood = false,
    bool clearEnergy = false,
  }) {
    return PeriodDay(
      id: id,
      date: date,
      cycleId: cycleId ?? this.cycleId,
      flowIndex: flowIndex ?? this.flowIndex,
      mood: clearMood ? null : (mood ?? this.mood),
      energy: clearEnergy ? null : (energy ?? this.energy),
      bbtCelsius: clearBbt ? null : (bbtCelsius ?? this.bbtCelsius),
      intercourse: intercourse ?? this.intercourse,
      symptomIds: symptomIds ?? this.symptomIds,
      note: note ?? this.note,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  static List<String> _decodeSymptoms(String? raw) {
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded.map((e) => e.toString()).toList();
      }
    } catch (_) {}
    return const [];
  }

  factory PeriodDay.fromRow(db.PeriodDayRow r) => PeriodDay(
        id: r.id,
        date: r.date,
        cycleId: r.cycleId,
        flowIndex: r.flowIndex,
        mood: r.mood,
        energy: r.energy,
        bbtCelsius: r.bbtCelsius,
        intercourse: r.intercourse,
        symptomIds: _decodeSymptoms(r.symptomIdsJson),
        note: r.note,
        createdAt: r.createdAt,
        updatedAt: r.updatedAt,
      );

  /// Companion for an upsert. Always stamps `updatedAt` and marks the row dirty
  /// (`synced: false`) per the sync contract.
  db.PeriodDaysCompanion toCompanion() {
    final now = DateTime.now();
    return db.PeriodDaysCompanion(
      id: Value(id),
      date: Value(DateTime(date.year, date.month, date.day)),
      cycleId: cycleId == null ? const Value.absent() : Value(cycleId),
      flowIndex: Value(flowIndex),
      mood: mood == null ? const Value.absent() : Value(mood),
      energy: energy == null ? const Value.absent() : Value(energy),
      bbtCelsius:
          bbtCelsius == null ? const Value.absent() : Value(bbtCelsius),
      intercourse:
          intercourse == null ? const Value.absent() : Value(intercourse),
      symptomIdsJson:
          symptomIds.isEmpty ? const Value(null) : Value(jsonEncode(symptomIds)),
      note: note == null ? const Value.absent() : Value(note),
      createdAt: Value(createdAt ?? now),
      updatedAt: Value(now),
      synced: const Value(false),
    );
  }
}
