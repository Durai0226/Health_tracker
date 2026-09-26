/// `FocusService.init()` must not write to disk when nothing changed.
///
/// `_checkAndUpdateStreak` ran unconditionally from `init()` and ended with
/// `_saveData()`, which was 19 sequential `setAppPreference` calls — each its
/// own Drift write, each its own transaction with its own WAL fsync. `init()`
/// is awaited in main's pre-runApp `Future.wait`, so a user who had never
/// opened the Focus tab paid all 19 writes before the first frame of every cold
/// start, storing values byte-identical to what was already on disk.
///
/// Measured as WRITES, not elapsed time: wall-clock on a shared machine swings
/// far more than the thing being measured, and a write count is the same number
/// on every machine.
library;

import 'package:clock/clock.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' show AppDatabase;
import 'package:tablet_remainder/core/services/active_profile_service.dart';
import 'package:tablet_remainder/core/services/clean_storage_service.dart';
import 'package:tablet_remainder/features/focus/services/focus_service.dart';

import '../support/counting_executor.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late CountingExecutor counter;
  late AppDatabase db;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    counter = CountingExecutor(NativeDatabase.memory());
    db = AppDatabase.forTesting(counter);
    AppDatabase.setInstanceForTesting(db);
    ActiveProfileService().resetForTesting();
    CleanStorageService.resetForTesting();
    await CleanStorageService.init();
  });

  tearDown(() async => db.close());

  final at = DateTime(2026, 4, 15, 10);

  /// Writes against `app_preferences` during one cold `init()`.
  Future<int> coldInitPrefWrites() async {
    FocusService().resetForTesting();
    counter.reset();
    await withClock(Clock.fixed(at), () => FocusService().init());
    return counter.writeTally['app_preferences'] ?? 0;
  }

  test('the FIRST cold start persists its defaults', () async {
    // Nothing is stored yet, so writing is correct here — this is the control
    // that stops the assertion below passing because init() does nothing at all.
    final first = await coldInitPrefWrites();
    expect(first, greaterThan(0),
        reason: 'an empty database has nothing stored, so the defaults must '
            'land — otherwise the no-op assertion below proves nothing');
  });

  test('a SECOND cold start with unchanged state writes nothing', () async {
    await coldInitPrefWrites(); // populate
    final second = await coldInitPrefWrites();

    expect(second, 0,
        reason: 'every value already on disk is identical, so there is nothing '
            'to persist — this used to be 19 separate write transactions '
            'before the first frame, on every launch, for every user');
  });

  test('a real change still persists, in ONE transaction not nineteen',
      () async {
    await coldInitPrefWrites();
    final focus = FocusService();

    counter.reset();
    await withClock(Clock.fixed(at), () async {
      focus.setDuration(42);
    });
    // setDuration persists; give the write a turn to land.
    await Future<void>.delayed(const Duration(milliseconds: 50));

    final writes = counter.writeTally['app_preferences'] ?? 0;
    expect(writes, greaterThan(0), reason: 'a real change must be saved');
    expect(writes, lessThan(19),
        reason: 'only the keys that actually changed should be written; '
            'writing all 19 again is the defect');

    // And it round-trips.
    FocusService().resetForTesting();
    await withClock(Clock.fixed(at), () => FocusService().init());
    expect(FocusService().selectedMinutes, 42,
        reason: 'skipping unchanged keys must not skip changed ones');
  });
}
