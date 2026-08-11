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

  group('averageActualSchedule', () {
    test('< 3 nights returns null (not enough data)', () async {
      await SleepService.logManualSession(
        bedtime: DateTime(2026, 6, 14, 23, 0),
        wakeTime: DateTime(2026, 6, 15, 7, 0),
      );
      await SleepService.logManualSession(
        bedtime: DateTime(2026, 6, 15, 23, 0),
        wakeTime: DateTime(2026, 6, 16, 7, 0),
      );
      expect(SleepService.averageActualSchedule(), isNull);
    });

    test('>= 3 nights of consistent data returns the correct average',
        () async {
      // Three identical nights: bedtime 23:00, wake 07:00.
      for (var i = 0; i < 3; i++) {
        final day = DateTime(2026, 6, 14 + i);
        await SleepService.logManualSession(
          bedtime: DateTime(day.year, day.month, day.day, 23, 0),
          wakeTime: day.add(const Duration(days: 1, hours: 7)),
        );
      }
      final avg = SleepService.averageActualSchedule();
      expect(avg, isNotNull);
      expect(avg!.bedHour, 23);
      expect(avg.bedMinute, 0);
      expect(avg.wakeHour, 7);
      expect(avg.wakeMinute, 0);
    });

    test('midnight-wrap case: bedtime just before midnight and just after '
        'is averaged correctly, not split across the 0/1440 boundary',
        () async {
      // Bedtimes straddling midnight: 23:30, 00:15, 23:45 -- a naive
      // raw-minutes average would land around midday, which is wrong.
      // Sessions are keyed by wake date, so each night uses a distinct wake
      // day to avoid one overwriting another in the in-memory map.
      await SleepService.logManualSession(
        bedtime: DateTime(2026, 6, 14, 23, 30),
        wakeTime: DateTime(2026, 6, 15, 7, 0),
      );
      await SleepService.logManualSession(
        bedtime: DateTime(2026, 6, 15, 0, 15),
        wakeTime: DateTime(2026, 6, 16, 7, 0),
      );
      await SleepService.logManualSession(
        bedtime: DateTime(2026, 6, 16, 23, 45),
        wakeTime: DateTime(2026, 6, 17, 7, 0),
      );
      final avg = SleepService.averageActualSchedule();
      expect(avg, isNotNull);
      // (23:30=1410, 00:15 shifted +24h=1455, 23:45=1425) / 3 = 1430 = 23:50.
      expect(avg!.bedHour, 23);
      expect(avg.bedMinute, 50);
      expect(avg.wakeHour, 7);
      expect(avg.wakeMinute, 0);
    });

    test('respects the minNights override', () async {
      await SleepService.logManualSession(
        bedtime: DateTime(2026, 6, 14, 23, 0),
        wakeTime: DateTime(2026, 6, 15, 7, 0),
      );
      expect(SleepService.averageActualSchedule(minNights: 1), isNotNull);
      expect(SleepService.averageActualSchedule(), isNull);
    });
  });
}
