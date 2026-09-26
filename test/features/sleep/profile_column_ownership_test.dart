import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart';
import 'package:tablet_remainder/features/sleep/models/sleep_schedule.dart';
import 'package:tablet_remainder/features/steps/models/health_profile.dart';

/// `health_profiles` is a single row shared by two features, and both wrote it
/// with `insertOnConflictUpdate`.
///
/// `SleepSchedule.toCompanion` sets only the sleep columns and relies on absent
/// columns being preserved. `HealthProfile.toCompanion` set the sleep columns
/// too — from `StepService._profile`, a copy loaded once in `init()` and never
/// refreshed. So editing the sleep schedule and then tapping Save on
/// Steps → Goal & profile wrote the pre-edit bedtime/wake/target back over it.
/// `SleepService` kept its own in-memory copy, so the revert was invisible
/// until the next restart — after which the schedule, the suggested bedtime,
/// the bedtime reminder minute and the wake alarm had all moved back.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    AppDatabase.setInstanceForTesting(db);
  });

  tearDown(() async => db.close());

  test('positive: a step-goal save keeps a newer sleep schedule', () async {
    // 1. Steps writes the row first (the app-start state both services cached).
    const stale = HealthProfile(
      weightKg: 70,
      heightCm: 175,
      targetSleepMinutes: 480, // 8h
      bedtimeHour: 23,
      wakeHour: 7,
    );
    await db.stepsDao.saveProfile(stale.toCompanion());

    // 2. The user edits the sleep schedule: 7h target, wake 06:00.
    const edited = SleepSchedule(
      targetMinutes: 420,
      bedtimeHour: 22,
      bedtimeMinute: 30,
      wakeHour: 6,
      wakeMinute: 0,
    );
    await db.stepsDao
        .saveProfile(edited.toCompanion(await db.stepsDao.getProfile()));

    // 3. The user then saves a step goal. StepService still holds the STALE
    //    profile, so this is the exact write that used to revert the schedule.
    await db.stepsDao
        .saveProfile(stale.copyWith(customStepGoal: 9000).toCompanion());

    final row = await db.stepsDao.getProfile();
    expect(row, isNotNull);
    expect(row!.customStepGoal, 9000, reason: 'the step goal must be saved');
    expect(row.targetSleepMinutes, 420,
        reason: 'the newer sleep target must survive a step-goal save');
    expect(row.wakeHour, 6, reason: 'the newer wake hour must survive');
    expect(row.bedtimeHour, 22);
    expect(row.bedtimeMinute, 30);
  });

  test('negative: on a fresh row the profile still creates sleep defaults',
      () async {
    const p = HealthProfile(weightKg: 68, heightCm: 170);
    await db.stepsDao.saveProfile(p.toCompanion());

    final row = await db.stepsDao.getProfile();
    expect(row, isNotNull, reason: 'the row must be created');
    expect(row!.weightKg, 68);
    // The sleep columns come from the table defaults, not from steps.
    expect(row.targetSleepMinutes, isNotNull);
  });

  test('negative: saving a sleep schedule does not disturb steps columns',
      () async {
    const p = HealthProfile(weightKg: 82, heightCm: 180, customStepGoal: 12000);
    await db.stepsDao.saveProfile(p.toCompanion());

    const s = SleepSchedule(targetMinutes: 450, bedtimeHour: 23, wakeHour: 6);
    await db.stepsDao
        .saveProfile(s.toCompanion(await db.stepsDao.getProfile()));

    final row = await db.stepsDao.getProfile();
    expect(row!.weightKg, 82);
    expect(row.customStepGoal, 12000);
    expect(row.targetSleepMinutes, 450);
  });
}
