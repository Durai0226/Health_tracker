import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tablet_remainder/core/database/app_database.dart';
import 'package:tablet_remainder/features/sleep/models/sleep_stage.dart';
import 'package:tablet_remainder/features/sleep/services/sleep_service.dart';

/// Regression — a hand-logged night must not be shadowed by an imported one.
///
/// One night can legitimately hold two rows: the user's manual entry (random
/// uuid id) and the Health import (`hk_<dateKey>`). `SleepService.init` used to
/// build the day map with `putIfAbsent` over a wake-time-DESC scan, so whichever
/// row happened to have the later wake time won. When that was the import, the
/// user's own night vanished from the dashboard — and because `syncFromHealth`'s
/// "never clobber a manual night" guard reads that same map, the manual night
/// stayed buried on every subsequent sync.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    AppDatabase.setInstanceForTesting(db);
    await SleepService.resetForTesting();
  });

  tearDown(() async => db.close());

  // The loader only reads the last ~35 nights, so anchor the fixtures to now.
  final today = DateTime.now();
  final night = DateTime(today.year, today.month, today.day)
      .subtract(const Duration(days: 3));
  final dateKey = '${night.year}-${night.month.toString().padLeft(2, '0')}'
      '-${night.day.toString().padLeft(2, '0')}';

  Future<void> insert({
    required String id,
    required SleepSource source,
    required DateTime wake,
    required DateTime updatedAt,
    int asleep = 420,
  }) =>
      db.sleepDao.upsert(SleepSessionsCompanion(
        id: Value(id),
        dateKey: Value(dateKey),
        bedtime: Value(wake.subtract(const Duration(hours: 8))),
        wakeTime: Value(wake),
        inBedMinutes: const Value(480),
        asleepMinutes: Value(asleep),
        sourceIndex: Value(source.index),
        createdAt: Value(updatedAt),
        updatedAt: Value(updatedAt),
      ));

  test('the manual night wins even when the import woke later', () async {
    await insert(
      id: 'hk_$dateKey',
      source: SleepSource.healthConnect,
      wake: DateTime(night.year, night.month, night.day, 8), // later wake
      updatedAt: DateTime(night.year, night.month, night.day, 9),
      asleep: 500,
    );
    await insert(
      id: 'manual-1',
      source: SleepSource.manual,
      wake: DateTime(night.year, night.month, night.day, 6), // earlier wake
      updatedAt: DateTime(night.year, night.month, night.day, 7),
      asleep: 420,
    );

    await SleepService.init();

    final loaded = SleepService.getForDate(night);
    expect(loaded, isNotNull);
    expect(loaded!.source, SleepSource.manual);
    expect(loaded.id, 'manual-1');
    expect(loaded.asleepMinutes, 420);
  });

  test('the manual night wins even when the import was written later', () async {
    await insert(
      id: 'manual-1',
      source: SleepSource.manual,
      wake: DateTime(night.year, night.month, night.day, 6),
      updatedAt: DateTime(night.year, night.month, night.day, 7),
    );
    await insert(
      id: 'hk_$dateKey',
      source: SleepSource.healthConnect,
      wake: DateTime(night.year, night.month, night.day, 8),
      updatedAt: DateTime(night.year, night.month, night.day, 23), // newer
      asleep: 500,
    );

    await SleepService.init();

    expect(SleepService.getForDate(night)!.source, SleepSource.manual);
  });

  test('between two imports the most recently updated wins', () async {
    await insert(
      id: 'hk_$dateKey',
      source: SleepSource.healthConnect,
      wake: DateTime(night.year, night.month, night.day, 8),
      updatedAt: DateTime(night.year, night.month, night.day, 9),
      asleep: 500,
    );
    await insert(
      id: 'hk_other',
      source: SleepSource.healthConnect,
      wake: DateTime(night.year, night.month, night.day, 7),
      updatedAt: DateTime(night.year, night.month, night.day, 20),
      asleep: 455,
    );

    await SleepService.init();

    expect(SleepService.getForDate(night)!.asleepMinutes, 455);
  });

  test('the surviving manual night is what a later health sync sees', () async {
    // The guard in syncFromHealth reads the in-memory map, so the map has to be
    // right for "never clobber a manual night" to hold across a restart.
    await insert(
      id: 'hk_$dateKey',
      source: SleepSource.healthConnect,
      wake: DateTime(night.year, night.month, night.day, 8),
      updatedAt: DateTime(night.year, night.month, night.day, 9),
    );
    await insert(
      id: 'manual-1',
      source: SleepSource.manual,
      wake: DateTime(night.year, night.month, night.day, 6),
      updatedAt: DateTime(night.year, night.month, night.day, 7),
    );

    await SleepService.init();

    final lastNight = SleepService.getAllSessions()
        .firstWhere((s) => s.dateKey == dateKey);
    expect(lastNight.source, SleepSource.manual);
  });
}
