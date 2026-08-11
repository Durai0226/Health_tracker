import 'package:flutter_test/flutter_test.dart';
import 'package:tablet_remainder/core/utils/quiet_hours.dart';

void main() {
  group('QuietHours.isAllowedMinute', () {
    test('disabled: everything allowed', () {
      expect(
          QuietHours.isAllowedMinute(3 * 60,
              respectQuietHours: false, wakeHour: 7, bedHour: 22),
          true);
    });

    test('normal window: inside wake..bed is allowed', () {
      expect(
          QuietHours.isAllowedMinute(12 * 60,
              respectQuietHours: true, wakeHour: 7, bedHour: 22),
          true);
    });

    test('normal window: before wake is disallowed', () {
      expect(
          QuietHours.isAllowedMinute(3 * 60,
              respectQuietHours: true, wakeHour: 7, bedHour: 22),
          false);
    });

    test('normal window: after bed is disallowed', () {
      expect(
          QuietHours.isAllowedMinute(23 * 60,
              respectQuietHours: true, wakeHour: 7, bedHour: 22),
          false);
    });

    test('normal window: boundaries are inclusive', () {
      expect(
          QuietHours.isAllowedMinute(7 * 60,
              respectQuietHours: true, wakeHour: 7, bedHour: 22),
          true);
      expect(
          QuietHours.isAllowedMinute(22 * 60,
              respectQuietHours: true, wakeHour: 7, bedHour: 22),
          true);
    });

    test('overnight window (night-shift profile) wraps past midnight', () {
      // wake 22:00, bed 06:00 -- awake overnight, asleep during the day.
      expect(
          QuietHours.isAllowedMinute(23 * 60,
              respectQuietHours: true, wakeHour: 22, bedHour: 6),
          true);
      expect(
          QuietHours.isAllowedMinute(2 * 60,
              respectQuietHours: true, wakeHour: 22, bedHour: 6),
          true);
      expect(
          QuietHours.isAllowedMinute(12 * 60,
              respectQuietHours: true, wakeHour: 22, bedHour: 6),
          false);
    });

    test('omitting wakeMinute/bedMinute behaves identically to the existing '
        'hour-only calls (no regression)', () {
      for (final m in [3 * 60, 7 * 60, 12 * 60, 22 * 60, 23 * 60]) {
        expect(
          QuietHours.isAllowedMinute(m,
              respectQuietHours: true, wakeHour: 7, bedHour: 22),
          QuietHours.isAllowedMinute(m,
              respectQuietHours: true,
              wakeHour: 7,
              bedHour: 22,
              wakeMinute: 0,
              bedMinute: 0),
        );
      }
    });

    test('non-zero-minute boundaries: minute-precision window', () {
      // wake 07:15 (435), bed 22:45 (1365).
      expect(
          QuietHours.isAllowedMinute(434,
              respectQuietHours: true,
              wakeHour: 7,
              bedHour: 22,
              wakeMinute: 15,
              bedMinute: 45),
          false,
          reason: 'one minute before the sleep-derived wake boundary');
      expect(
          QuietHours.isAllowedMinute(435,
              respectQuietHours: true,
              wakeHour: 7,
              bedHour: 22,
              wakeMinute: 15,
              bedMinute: 45),
          true,
          reason: 'exactly on the sleep-derived wake boundary');
      expect(
          QuietHours.isAllowedMinute(1365,
              respectQuietHours: true,
              wakeHour: 7,
              bedHour: 22,
              wakeMinute: 15,
              bedMinute: 45),
          true,
          reason: 'exactly on the sleep-derived bed boundary');
      expect(
          QuietHours.isAllowedMinute(1366,
              respectQuietHours: true,
              wakeHour: 7,
              bedHour: 22,
              wakeMinute: 15,
              bedMinute: 45),
          false,
          reason: 'one minute after the sleep-derived bed boundary');
    });

    test('non-zero-minute overnight window wraps past midnight', () {
      // wake 22:30 (1350), bed 06:15 (375).
      expect(
          QuietHours.isAllowedMinute(1349,
              respectQuietHours: true,
              wakeHour: 22,
              bedHour: 6,
              wakeMinute: 30,
              bedMinute: 15),
          false);
      expect(
          QuietHours.isAllowedMinute(1350,
              respectQuietHours: true,
              wakeHour: 22,
              bedHour: 6,
              wakeMinute: 30,
              bedMinute: 15),
          true);
      expect(
          QuietHours.isAllowedMinute(375,
              respectQuietHours: true,
              wakeHour: 22,
              bedHour: 6,
              wakeMinute: 30,
              bedMinute: 15),
          true);
      expect(
          QuietHours.isAllowedMinute(376,
              respectQuietHours: true,
              wakeHour: 22,
              bedHour: 6,
              wakeMinute: 30,
              bedMinute: 15),
          false);
    });
  });

  group('QuietHours.filterMinutes', () {
    test('sorts and drops disallowed candidates', () {
      final result = QuietHours.filterMinutes(
        [23 * 60, 8 * 60, 2 * 60, 14 * 60],
        respectQuietHours: true,
        wakeHour: 7,
        bedHour: 22,
      );
      expect(result, [8 * 60, 14 * 60]);
    });

    test('disabled: returns everything, sorted', () {
      final result = QuietHours.filterMinutes(
        [23 * 60, 2 * 60],
        respectQuietHours: false,
        wakeHour: 7,
        bedHour: 22,
      );
      expect(result, [2 * 60, 23 * 60]);
    });

    test('omitting wakeMinute/bedMinute behaves identically to the existing '
        'hour-only calls (no regression)', () {
      final candidates = [23 * 60, 8 * 60, 2 * 60, 14 * 60];
      final withoutMinutes = QuietHours.filterMinutes(
        candidates,
        respectQuietHours: true,
        wakeHour: 7,
        bedHour: 22,
      );
      final withZeroMinutes = QuietHours.filterMinutes(
        candidates,
        respectQuietHours: true,
        wakeHour: 7,
        bedHour: 22,
        wakeMinute: 0,
        bedMinute: 0,
      );
      expect(withZeroMinutes, withoutMinutes);
    });

    test('non-zero-minute boundaries narrow the window precisely', () {
      // wake 07:15 (435), bed 22:45 (1365).
      final result = QuietHours.filterMinutes(
        [434, 435, 1365, 1366],
        respectQuietHours: true,
        wakeHour: 7,
        bedHour: 22,
        wakeMinute: 15,
        bedMinute: 45,
      );
      expect(result, [435, 1365]);
    });
  });
}
