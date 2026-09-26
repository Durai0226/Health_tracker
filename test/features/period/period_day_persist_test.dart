import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart';
import 'package:tablet_remainder/features/period/models/period_day.dart';

/// `PeriodDay.toCompanion` used `Value.absent()` for every nullable field that
/// was null. `PeriodDao.upsertDay` is an `insertOnConflictUpdate`, and ON
/// CONFLICT DO UPDATE writes only the columns the companion sets — so an
/// absent value means "keep what is stored" and a cleared field could never
/// reach SQLite.
///
/// The user-visible failure: the Log sheet clears mood/energy by tapping the
/// selected face again and clears BBT by emptying the field. `PeriodService`
/// updates its in-memory map optimistically, so the sheet closed and the
/// dashboard showed the value gone. After a restart it was back. A BBT typo
/// (36.7 for 36.1) could not be removed at all, and it feeds the TTC chart and
/// every downstream prediction.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    AppDatabase.setInstanceForTesting(db);
  });

  tearDown(() async => db.close());

  final date = DateTime(2026, 3, 12);
  PeriodDay full() => PeriodDay(
        id: '2026-03-12',
        date: date,
        flowIndex: 2,
        mood: 4,
        energy: 3,
        bbtCelsius: 36.7,
        intercourse: true,
        symptomIds: const ['cramps'],
        note: 'heavy morning',
        createdAt: date,
      );

  test('positive: every logged field round-trips', () async {
    await db.periodDao.upsertDay(full().toCompanion());

    final row = await db.periodDao.getDay('2026-03-12');
    expect(row, isNotNull);
    expect(row!.flowIndex, 2);
    expect(row.mood, 4);
    expect(row.energy, 3);
    expect(row.bbtCelsius, closeTo(36.7, 0.001));
    expect(row.intercourse, isTrue);
    expect(row.note, 'heavy morning');
    expect(row.symptomIdsJson, contains('cramps'));
  });

  test('negative: clearing mood, energy, BBT, intercourse and note persists',
      () async {
    await db.periodDao.upsertDay(full().toCompanion());

    // What the Log sheet does: tap the selected mood/energy again to clear,
    // empty the BBT field, clear the note.
    final cleared = full().copyWith(
      clearMood: true,
      clearBbt: true,
      note: null,
    );
    // `copyWith` has no clear flags for these two, so build the cleared day
    // directly — this is the shape PeriodService persists.
    final blanked = PeriodDay(
      id: cleared.id,
      date: cleared.date,
      flowIndex: cleared.flowIndex,
      symptomIds: const [],
      createdAt: cleared.createdAt,
    );
    await db.periodDao.upsertDay(blanked.toCompanion());

    final row = await db.periodDao.getDay('2026-03-12');
    expect(row, isNotNull, reason: 'the day itself must survive');
    expect(row!.flowIndex, 2, reason: 'flow was not cleared');
    expect(row.mood, isNull, reason: 'a cleared mood must not come back');
    expect(row.energy, isNull, reason: 'a cleared energy must not come back');
    expect(row.bbtCelsius, isNull,
        reason: 'a mistyped BBT must be removable, not merely overwritable');
    expect(row.intercourse, isNull);
    expect(row.note, isNull, reason: 'a cleared note must not come back');
    expect(row.symptomIdsJson, isNull);
  });

  test('negative: clearing does not resurrect a tombstone', () async {
    await db.periodDao.upsertDay(full().toCompanion());
    await db.periodDao.deleteDay('2026-03-12');
    expect((await db.periodDao.getAllDays()).map((r) => r.id),
        isNot(contains('2026-03-12')));

    // Re-logging the same date must clear the tombstone (upsertDay's contract).
    await db.periodDao.upsertDay(full().toCompanion());
    expect((await db.periodDao.getAllDays()).map((r) => r.id),
        contains('2026-03-12'));
  });
}
