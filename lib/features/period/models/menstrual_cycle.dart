import 'package:drift/drift.dart' show Value;
import 'package:tablet_remainder/core/database/app_database.dart' as db;

/// One detected/derived menstrual cycle: from a period start to the day before
/// the next period start. [cycleLengthDays] / [endDate] are null for the open
/// (most recent, still-running) cycle.
class MenstrualCycle {
  final String id;
  final DateTime startDate;
  final DateTime? endDate;
  final int? cycleLengthDays;
  final int? periodLengthDays;
  final bool isPredicted;
  final String? note;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const MenstrualCycle({
    required this.id,
    required this.startDate,
    this.endDate,
    this.cycleLengthDays,
    this.periodLengthDays,
    this.isPredicted = false,
    this.note,
    this.createdAt,
    this.updatedAt,
  });

  /// True for the current, not-yet-completed cycle (no next start observed).
  bool get isOpen => endDate == null || cycleLengthDays == null;

  MenstrualCycle copyWith({
    DateTime? startDate,
    DateTime? endDate,
    int? cycleLengthDays,
    int? periodLengthDays,
    bool? isPredicted,
    String? note,
  }) {
    return MenstrualCycle(
      id: id,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      cycleLengthDays: cycleLengthDays ?? this.cycleLengthDays,
      periodLengthDays: periodLengthDays ?? this.periodLengthDays,
      isPredicted: isPredicted ?? this.isPredicted,
      note: note ?? this.note,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  factory MenstrualCycle.fromRow(db.MenstrualCycleRow r) => MenstrualCycle(
        id: r.id,
        startDate: r.startDate,
        endDate: r.endDate,
        cycleLengthDays: r.cycleLengthDays,
        periodLengthDays: r.periodLengthDays,
        isPredicted: r.isPredicted,
        note: r.note,
        createdAt: r.createdAt,
        updatedAt: r.updatedAt,
      );

  db.MenstrualCyclesCompanion toCompanion() {
    final now = DateTime.now();
    return db.MenstrualCyclesCompanion(
      id: Value(id),
      startDate: Value(startDate),
      endDate: endDate == null ? const Value.absent() : Value(endDate),
      cycleLengthDays: cycleLengthDays == null
          ? const Value.absent()
          : Value(cycleLengthDays),
      periodLengthDays: periodLengthDays == null
          ? const Value.absent()
          : Value(periodLengthDays),
      isPredicted: Value(isPredicted),
      note: note == null ? const Value.absent() : Value(note),
      createdAt: Value(createdAt ?? now),
      updatedAt: Value(now),
      synced: const Value(false),
    );
  }
}
