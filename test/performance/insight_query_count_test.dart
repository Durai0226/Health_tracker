@Tags(['performance'])
library;

/// A month of daily summaries must cost a constant number of queries, not one
/// pair per day.
///
/// `InsightService.gatherAll()` awaited `getDailySummaryAsync(day)` in a
/// 30-iteration loop. Each call issues TWO reads — the day's logs, plus a full
/// `getAllMedicines()` that re-decodes every medicine's schedule JSON — so a
/// weekly-recap open cost ~60 serialized round trips on the UI isolate,
/// unconditionally, even for a user with almost no data.
/// `TrendsDataService._adherence` had the same shape at up to 365 days.
///
/// This counts real statements against an in-memory Drift database, so it fails
/// if anyone reintroduces a per-day query.
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' show AppDatabase;
import 'package:tablet_remainder/core/services/active_profile_service.dart';
import 'package:tablet_remainder/core/services/clean_storage_service.dart';
import 'package:tablet_remainder/features/medication/services/medicine_storage_service.dart';

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

  test('30 daily summaries cost a constant number of reads', () async {
    final today = DateTime.now();
    final start = DateTime(today.year, today.month, today.day)
        .subtract(const Duration(days: 29));

    counter.reset();
    final summaries = await MedicineCleanStorageService
        .getDailySummariesForRange(start, today);

    expect(summaries.length, 30,
        reason: 'both bounds are inclusive, so a 29-day span is 30 days');
    expect(
      counter.selects,
      lessThanOrEqualTo(6),
      reason: 'A 30-day range must not scale with the number of days. The old '
          'per-day loop issued ~60 reads here (2 per day). Allowing a small '
          'constant covers the logs read, the medicines read and any profile '
          'lookup they perform.',
    );
  });

  test('the read count does not grow with the range length', () async {
    final today = DateTime(2026, 6, 30);

    counter.reset();
    await MedicineCleanStorageService.getDailySummariesForRange(
        today.subtract(const Duration(days: 6)), today);
    final forOneWeek = counter.selects;

    counter.reset();
    await MedicineCleanStorageService.getDailySummariesForRange(
        today.subtract(const Duration(days: 364)), today);
    final forOneYear = counter.selects;

    expect(
      forOneYear,
      forOneWeek,
      reason: 'A year (365 days) must cost the same number of queries as a '
          'week (7). Anything else means a per-day read crept back in — this is '
          'the Year-mode trends path.',
    );
  });
}
