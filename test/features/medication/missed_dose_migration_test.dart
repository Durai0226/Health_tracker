import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tablet_remainder/core/database/app_database.dart';

/// Simulates an EXISTING install that already holds the duplicate rows the old
/// reconciler could write, then upgrades it and checks nothing legitimate is lost.
void main() {
  test('schema-9 cleanup removes only SUPERSEDED missed rows', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final slotA = DateTime(2026, 8, 1, 8, 0);   // has both missed + taken
    final slotB = DateTime(2026, 8, 2, 8, 0);   // missed only  -> must survive
    final slotC = DateTime(2026, 8, 3, 8, 0);   // missed + skipped

    Future<void> ins(String id, DateTime slot,
        {bool taken = false, bool skipped = false, bool missed = false}) async {
      await db.into(db.medicineLogs).insert(MedicineLogsCompanion.insert(
            id: id,
            medicineId: 'med-1',
            scheduledTime: slot,
            isTaken: Value(taken),
            isSkipped: Value(skipped),
            isMissed: Value(missed),
          ));
    }

    // Legacy id shape, exactly what the old reconciler produced.
    await ins('med-1_missed_${slotA.millisecondsSinceEpoch}', slotA, missed: true);
    await ins('med-1_${slotA.millisecondsSinceEpoch}', slotA, taken: true);
    await ins('med-1_missed_${slotB.millisecondsSinceEpoch}', slotB, missed: true);
    await ins('med-1_missed_${slotC.millisecondsSinceEpoch}', slotC, missed: true);
    await ins('med-1_${slotC.millisecondsSinceEpoch}', slotC, skipped: true);

    expect((await db.select(db.medicineLogs).get()).length, 5);

    // Run the same statement the v9 migration runs.
    await db.customStatement(
      "DELETE FROM medicine_logs WHERE id LIKE '%\\_missed\\_%' ESCAPE '\\' "
      'AND EXISTS (SELECT 1 FROM medicine_logs m2 '
      '            WHERE m2.medicine_id = medicine_logs.medicine_id '
      '              AND m2.scheduled_time = medicine_logs.scheduled_time '
      '              AND m2.id <> medicine_logs.id '
      '              AND (m2.is_taken = 1 OR m2.is_skipped = 1))',
    );

    final rows = await db.select(db.medicineLogs).get();
    final ids = rows.map((r) => r.id).toSet();

    expect(rows.length, 3, reason: 'two superseded missed rows removed');
    expect(ids.contains('med-1_${slotA.millisecondsSinceEpoch}'), isTrue,
        reason: 'the taken row survives');
    expect(ids.contains('med-1_missed_${slotB.millisecondsSinceEpoch}'), isTrue,
        reason: 'a missed row with NO user action is real history — must survive');
    expect(ids.contains('med-1_${slotC.millisecondsSinceEpoch}'), isTrue,
        reason: 'the skipped row survives');
    expect(ids.any((i) => i.contains('_missed_') && i.contains('${slotA.millisecondsSinceEpoch}')),
        isFalse);

    await db.close();
  });
}
