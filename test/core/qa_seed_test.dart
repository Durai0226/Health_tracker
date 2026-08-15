/// The seeder must actually populate every feature it claims to.
///
/// The previous seeder covered 3 of 30 tables — steps, sleep, and one
/// preference. Medicines, water, period, vitals and diary were empty, which is
/// every table behind the app's heaviest screens. Element budgets and query
/// counts measured against that are understatements, so a rating derived from
/// them measures the empty state rather than the app.
library;

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' show AppDatabase;
import 'package:tablet_remainder/core/dev/qa_seed.dart';
import 'package:tablet_remainder/core/services/active_profile_service.dart';
import 'package:tablet_remainder/core/services/clean_storage_service.dart';
import 'package:tablet_remainder/features/diary/services/diary_storage_service.dart';
import 'package:tablet_remainder/features/medication/services/medicine_storage_service.dart';
import 'package:tablet_remainder/features/medication/services/vitals_storage_service.dart';
import 'package:tablet_remainder/features/water/services/water_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    AppDatabase.setInstanceForTesting(db);
    ActiveProfileService().resetForTesting();
    CleanStorageService.resetForTesting();
    await CleanStorageService.init();
    await WaterService.init();
  });

  tearDown(() async => db.close());

  test('every rated feature gets data', () async {
    await seedQaData(force: true);

    final meds = await MedicineCleanStorageService.getAllMedicines();
    expect(meds, isNotEmpty, reason: 'medicines table left empty');

    final logs = await MedicineCleanStorageService.getAllLogs();
    expect(logs.length, greaterThan(20),
        reason: 'dose history must be deep enough for adherence and streaks '
            'to be non-trivial; got ${logs.length}');

    expect(await VitalsStorageService.getAllBp(), isNotEmpty,
        reason: 'blood pressure left empty');
    expect(await VitalsStorageService.getAllGlucose(), isNotEmpty,
        reason: 'glucose left empty');
    expect(await VitalsStorageService.getAllWeight(), isNotEmpty,
        reason: 'weight left empty');
    expect(await VitalsStorageService.getAllMood(), isNotEmpty,
        reason: 'mood left empty');
    expect(await DiaryStorageService.getAll(), isNotEmpty,
        reason: 'diary left empty');
  });

  test('adherence is realistic, not a flat 100%', () async {
    await seedQaData(force: true);
    final stats = await MedicineCleanStorageService.getAdherenceStats();
    final rate = stats['adherenceRate'] as int;

    expect(rate, greaterThan(50),
        reason: 'seeded adherence should look like real use, got $rate%');
    expect(rate, lessThan(100),
        reason: 'a flat 100% hides every bug in the adherence maths — the '
            'seed deliberately scatters missed and skipped doses. Got $rate%');
  });

  test('the heavy profile really is heavier', () async {
    await seedQaData(force: true);
    final typical = (await MedicineCleanStorageService.getAllLogs()).length;

    // Fresh database for the second profile.
    await db.close();
    db = AppDatabase.forTesting(NativeDatabase.memory());
    AppDatabase.setInstanceForTesting(db);
    CleanStorageService.resetForTesting();
    await CleanStorageService.init();
    await seedQaData(force: true, profile: SeedProfile.heavy);
    final heavy = (await MedicineCleanStorageService.getAllLogs()).length;

    expect(heavy, greaterThan(typical * 5),
        reason: 'the heavy profile exists to answer "does this feature cost '
            'more with a year of data?" — it must be materially bigger. '
            'typical=$typical heavy=$heavy');
  });
}
