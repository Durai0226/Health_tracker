import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tablet_remainder/core/database/app_database.dart' show AppDatabase;

/// The schema shipped with **no indexes at all** — every table declared only a
/// primary key. `MedicineLogs` is queried by `medicineId` and `scheduledTime`
/// on every adherence, streak, per-medicine-history and export path, and it
/// grows forever with no pruning, so those were full table scans that degrade
/// linearly with use.
///
/// This asserts the indexes exist in a real SQLite file and that the query
/// planner actually chooses them — a `CREATE INDEX` the planner ignores is
/// decoration.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async => db.close());

  Future<Set<String>> indexNames() async {
    final rows = await db
        .customSelect("SELECT name FROM sqlite_master WHERE type = 'index'")
        .get();
    return rows.map((r) => r.data['name'] as String).toSet();
  }

  test('every expected index exists on a fresh database', () async {
    final names = await indexNames();
    for (final expected in const [
      'idx_medicine_logs_medicine',
      'idx_medicine_logs_time',
      'idx_bp_taken_at',
      'idx_glucose_taken_at',
      'idx_weight_taken_at',
      'idx_mood_taken_at',
      'idx_water_day_date',
      'idx_water_logs_daily',
      'idx_sleep_wake',
      'idx_steps_date',
      'idx_diary_entry_at',
      'idx_period_days_date',
    ]) {
      expect(names, contains(expected), reason: '$expected is missing');
    }
  });

  test('the planner uses the index for a medicineId lookup', () async {
    final plan = await db
        .customSelect(
            'EXPLAIN QUERY PLAN SELECT * FROM medicine_logs WHERE medicine_id = ?',
            variables: [Variable.withString('m1')])
        .get();
    final text = plan.map((r) => r.data.values.join(' ')).join(' ');
    expect(
      text.toUpperCase(),
      contains('IDX_MEDICINE_LOGS_MEDICINE'),
      reason: 'A medicineId lookup must not be a full scan — this is the N+1 '
          'path used by exports and the medicine detail screen. Plan: $text',
    );
  });

  test('the planner uses the index for a scheduledTime range', () async {
    final plan = await db
        .customSelect(
            'EXPLAIN QUERY PLAN SELECT * FROM medicine_logs '
            'WHERE scheduled_time >= ? AND scheduled_time <= ?',
            variables: [Variable.withInt(0), Variable.withInt(1 << 40)])
        .get();
    final text = plan.map((r) => r.data.values.join(' ')).join(' ');
    expect(
      text.toUpperCase(),
      contains('IDX_MEDICINE_LOGS_TIME'),
      reason: 'The adherence/streak windows are scheduledTime ranges (up to 180 '
          'and 365 days). Plan: $text',
    );
  });

  test('the planner uses the index ordering vitals by takenAt', () async {
    final plan = await db
        .customSelect('EXPLAIN QUERY PLAN SELECT * FROM blood_pressure_readings '
            'ORDER BY taken_at DESC')
        .get();
    final text = plan.map((r) => r.data.values.join(' ')).join(' ');
    expect(
      text.toUpperCase(),
      contains('IDX_BP_TAKEN_AT'),
      reason: 'Every vitals screen orders by takenAt. Plan: $text',
    );
  });
}
