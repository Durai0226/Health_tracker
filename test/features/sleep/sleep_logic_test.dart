import 'package:flutter_test/flutter_test.dart';
import 'package:tablet_remainder/features/sleep/models/sleep_schedule.dart';
import 'package:tablet_remainder/features/sleep/models/sleep_session.dart';
import 'package:tablet_remainder/features/sleep/models/sleep_stage.dart';

/// QA — Sleep pure helpers (F4). Duration formatting, schedule wrap math, and
/// the safe source-index mapping. (SleepConsistency.fromIndex is covered by
/// sleep_consistency_test.dart; these are the untested pieces.)
void main() {
  group('SleepSession.formatMinutes', () {
    test('hours + zero-padded minutes', () => expect(SleepSession.formatMinutes(452), '7h 32m'));
    test('under an hour → minutes only', () => expect(SleepSession.formatMinutes(45), '45m'));
    test('exact hour zero-pads the minutes', () => expect(SleepSession.formatMinutes(60), '1h 00m'));
    test('negative clamps to 0m', () => expect(SleepSession.formatMinutes(-10), '0m'));
    test('zero → 0m', () => expect(SleepSession.formatMinutes(0), '0m'));
  });

  group('SleepSchedule', () {
    test('targetLabel whole hours', () => expect(const SleepSchedule(targetMinutes: 480).targetLabel, '8h'));
    test('targetLabel with minutes', () => expect(const SleepSchedule(targetMinutes: 450).targetLabel, '7h 30m'));
    test('scheduledInBedMinutes wraps midnight (22:30→07:00 = 510)', () {
      expect(
          const SleepSchedule(bedtimeHour: 22, bedtimeMinute: 30, wakeHour: 7, wakeMinute: 0)
              .scheduledInBedMinutes,
          510);
    });
    test('scheduledInBedMinutes: equal bed/wake → 1440 (degenerate edge)', () {
      expect(
          const SleepSchedule(bedtimeHour: 8, bedtimeMinute: 0, wakeHour: 8, wakeMinute: 0)
              .scheduledInBedMinutes,
          1440);
    });
    test('reminderMinuteOfDay = bedtime − windDown', () {
      expect(
          const SleepSchedule(bedtimeHour: 22, bedtimeMinute: 30, windDownMinutes: 30)
              .reminderMinuteOfDay,
          1320);
    });
    test('reminderMinuteOfDay wraps before midnight (00:10 − 30m → 23:40)', () {
      expect(
          const SleepSchedule(bedtimeHour: 0, bedtimeMinute: 10, windDownMinutes: 30)
              .reminderMinuteOfDay,
          1420);
    });
  });

  group('SleepSourceX.fromIndex', () {
    test('valid index maps to a real source', () => expect(SleepSourceX.fromIndex(0), SleepSource.values[0]));
    test('out-of-range index → manual', () => expect(SleepSourceX.fromIndex(99), SleepSource.manual));
    test('negative index → manual', () => expect(SleepSourceX.fromIndex(-1), SleepSource.manual));
  });
}
