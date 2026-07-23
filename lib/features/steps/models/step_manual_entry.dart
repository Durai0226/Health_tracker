import 'package:drift/drift.dart' show Value;
import 'package:tablet_remainder/core/database/app_database.dart' as db;

/// A single manual step adjustment the user logged for a day. Positive [steps]
/// add to the day's total; a negative value trims an over-count. Many entries
/// can belong to one [dailyDataId].
class StepManualEntry {
  final String id;
  final String dailyDataId;
  final DateTime time;
  final int steps;
  final String? note;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const StepManualEntry({
    required this.id,
    required this.dailyDataId,
    required this.time,
    required this.steps,
    this.note,
    this.createdAt,
    this.updatedAt,
  });

  StepManualEntry copyWith({
    String? id,
    String? dailyDataId,
    DateTime? time,
    int? steps,
    String? note,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return StepManualEntry(
      id: id ?? this.id,
      dailyDataId: dailyDataId ?? this.dailyDataId,
      time: time ?? this.time,
      steps: steps ?? this.steps,
      note: note ?? this.note,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Build the model from a persisted Drift row.
  factory StepManualEntry.fromRow(db.StepManualEntryRow r) => StepManualEntry(
        id: r.id,
        dailyDataId: r.dailyDataId,
        time: r.time,
        steps: r.steps,
        note: r.note,
        createdAt: r.createdAt,
        updatedAt: r.updatedAt,
      );

  /// Drift companion for insert/update (sets sync bookkeeping).
  db.StepManualEntriesCompanion toCompanion() {
    final now = DateTime.now();
    return db.StepManualEntriesCompanion(
      id: Value(id),
      dailyDataId: Value(dailyDataId),
      time: Value(time),
      steps: Value(steps),
      note: Value(note),
      createdAt: Value(createdAt ?? now),
      updatedAt: Value(now),
      synced: const Value(false),
    );
  }
}
