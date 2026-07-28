import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tablet_remainder/core/database/app_database.dart';
import 'package:tablet_remainder/features/sleep/services/sleep_service.dart';

/// QA — SleepService analytics (F4), via the in-memory Drift harness +
/// resetForTesting. Includes the regression for the degenerate-duration bug
/// (wake ≤ bedtime should become an overnight session, not a 1-minute night).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    AppDatabase.setInstanceForTesting(db);
    await SleepService.resetForTesting();
    await SleepService.init();
  });

  tearDown(() async {
    await db.close();
  });

  test('logManualSession: wake ≤ bedtime shifts to an overnight session (regression)',
      () async {
    final day = DateTime(2026, 6, 15);
    // wake 07:00 is earlier than bedtime 23:00 on the SAME day.
    final bed = DateTime(day.year, day.month, day.day, 23, 0);
    final wake = DateTime(day.year, day.month, day.day, 7, 0);
    final s = await SleepService.logManualSession(bedtime: bed, wakeTime: wake, quality: 4);
    expect(s.inBedMinutes, 480, reason: 'should be an 8h overnight, not 1 minute');
  });

  test('logManualSession: a normal 8h good-quality night scores sensibly', () async {
    final bed = DateTime(2026, 6, 14, 23, 0);
    final wake = DateTime(2026, 6, 15, 7, 0);
    final s = await SleepService.logManualSession(bedtime: bed, wakeTime: wake, quality: 5);
    expect(s.inBedMinutes, 480);
    expect(s.sleepScore, inInclusiveRange(0, 100));
    expect(s.sleepScore, greaterThan(60));
  });

  test('regularityIndex is the neutral 0.75 placeholder with < 3 nights', () {
    expect(SleepService.regularityIndex(), 0.75);
  });

  test('suggestedBedtimeMinuteOfDay = wake − (target + buffer), wrapped', () {
    // default schedule: wake 07:00 (420), target 480 → 420 − 495 = −75 → 1365 (22:45)
    expect(SleepService.suggestedBedtimeMinuteOfDay(), 1365);
  });
}
