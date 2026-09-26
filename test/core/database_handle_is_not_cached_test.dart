import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart';
import 'package:tablet_remainder/core/services/clean_storage_service.dart';

/// `CleanStorageService` kept its own `AppDatabase?` and `??=`-ed it on first
/// use. That bought nothing — `AppDatabase.instance` is itself a singleton —
/// and cost a real hazard: the cached handle survived
/// `AppDatabase.setInstanceForTesting`, so any test that closed its in-memory
/// database without ALSO calling `CleanStorageService.resetForTesting()` left
/// the service pointing at the closed one.
///
/// Every later read then threw "Can't re-open a database after closing it",
/// which the callers' try/catch swallowed — so the test still passed while the
/// service silently returned nothing. Three of those were visible in the
/// suite's own output before this fix, on a path (`rescheduleAllReminders`)
/// that other tests genuinely drive.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('positive: the service follows setInstanceForTesting immediately',
      () async {
    final first = AppDatabase.forTesting(NativeDatabase.memory());
    AppDatabase.setInstanceForTesting(first);
    expect(CleanStorageService.database, same(first));

    // A second test's database, with no resetForTesting() in between — the
    // exact sequence that used to strand the old handle.
    final second = AppDatabase.forTesting(NativeDatabase.memory());
    AppDatabase.setInstanceForTesting(second);
    expect(CleanStorageService.database, same(second),
        reason: 'a cached handle here points at the PREVIOUS test\'s database, '
            'which that test has already closed');

    await first.close();
    await second.close();
  });

  test('negative: reads still work after an earlier database was closed',
      () async {
    final first = AppDatabase.forTesting(NativeDatabase.memory());
    AppDatabase.setInstanceForTesting(first);
    await CleanStorageService.init();
    await first.close(); // the previous test's teardown

    final second = AppDatabase.forTesting(NativeDatabase.memory());
    AppDatabase.setInstanceForTesting(second);
    CleanStorageService.resetForTesting();
    await CleanStorageService.init();

    // Would have thrown "Can't re-open a database after closing it" into a
    // swallowing catch, leaving an empty list that reads as "no reminders".
    expect(await CleanStorageService.getAllReminders(), isEmpty);
    expect(CleanStorageService.database, same(second));

    await second.close();
  });

  test('the handle is not cached in a field at all', () {
    final src =
        File('lib/core/services/clean_storage_service.dart').readAsStringSync();
    expect(src, contains('static AppDatabase get database => AppDatabase.instance;'),
        reason: 'caching a second reference to a singleton can only go stale');
    expect(src, isNot(contains('static AppDatabase? _database;')),
        reason: 'the field is what went stale');
  });
}
