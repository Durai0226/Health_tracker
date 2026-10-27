/// "Every 6 hours" is the same clock times on every day of the year.
///
/// The slots used to be `anchor + k × interval` added to a local `DateTime` —
/// elapsed time, so on the day the clocks changed every slot after the change
/// moved an hour: 00:30, 06:30, 12:30, 18:30 became 00:30, 07:30, 13:30, 19:30,
/// and because the reminders are armed from that day's list and then repeat at
/// those times, the shift stayed until the next re-arm.
///
/// The year-long scans only bite where the machine's clock has daylight saving.
/// They were run with `TZ=America/New_York` and `TZ=Europe/London` against the
/// old arithmetic and fail there; in a zone without it they hold trivially, and
/// the clock-time tests above them carry the rule.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:tablet_remainder/features/medication/models/medicine_enums.dart';
import 'package:tablet_remainder/features/medication/models/medicine_schedule.dart';

void main() {
  String hm(int h, int m) => '$h:${m.toString().padLeft(2, '0')}';

  List<String> clock(List<DateTime> slots) =>
      [for (final s in slots) hm(s.hour, s.minute)];

  MedicineSchedule every(int hours, {int hour = 6, int minute = 0}) =>
      MedicineSchedule(
        frequencyType: FrequencyType.everyXHours,
        times: [ScheduledTime(hour: hour, minute: minute)],
        intervalHours: hours,
      );

  group('the clock times of an interval schedule', () {
    List<String> slots(int hour, int minute, int every) => [
          for (final s in MedicineSchedule.intervalSlotTimes(hour, minute, every))
            hm(s.hour, s.minute)
        ];

    test('run from the anchor in whole intervals to the end of the day', () {
      expect(slots(8, 0, 8), ['8:00', '16:00']);
      expect(slots(6, 0, 4), ['6:00', '10:00', '14:00', '18:00', '22:00']);
      expect(slots(0, 30, 6), ['0:30', '6:30', '12:30', '18:30']);
    });

    test('keep the minutes of the anchor', () {
      expect(slots(7, 45, 5), ['7:45', '12:45', '17:45', '22:45']);
    });

    test('never wrap round into the small hours of the next day', () {
      expect(slots(14, 0, 6), ['14:00', '20:00'],
          reason: 'the 02:00 after that belongs to tomorrow\'s own list');
      expect(slots(23, 0, 1), ['23:00']);
    });

    test('an interval of a day or more is the anchor alone', () {
      expect(slots(9, 15, 24), ['9:15']);
      expect(slots(9, 15, 36), ['9:15']);
    });

    test('every hour from midnight is all twenty-four', () {
      expect(slots(0, 0, 1), hasLength(24));
      expect(slots(0, 0, 1).last, '23:00');
    });

    test('a zero or negative interval is no schedule, and cannot loop forever', () {
      expect(MedicineSchedule.intervalSlotTimes(8, 0, 0), isEmpty,
          reason: 'zero hours is not a schedule, and must not loop');
      expect(MedicineSchedule.intervalSlotTimes(8, 0, -3), isEmpty);
    });
  });

  group('on every day of the year', () {
    // Anchors in the hour the clocks skip (02:xx) cannot keep their clock time on
    // the day they do not exist, so they are left out; every other slot has to.
    final cases = <(int hour, int minute, int every)>[
      (0, 0, 4),
      (0, 30, 6),
      (1, 0, 2),
      (3, 30, 3),
      (6, 0, 8),
      (6, 0, 4),
      (9, 0, 12),
      (22, 0, 12),
    ];

    for (final (hour, minute, every_) in cases) {
      test('every $every_ h from ${hm(hour, minute)} reads the same on all 365', () {
        final schedule = every(every_, hour: hour, minute: minute);
        final first = clock(schedule.getScheduledTimesForDate(DateTime(2026, 1, 1)));
        expect(first, isNotEmpty);
        for (var d = DateTime(2026, 1, 1);
            d.year == 2026;
            d = DateTime(d.year, d.month, d.day + 1)) {
          expect(clock(schedule.getScheduledTimesForDate(d)), first,
              reason: '${d.year}-${d.month}-${d.day}: a day the clocks change must '
                  'keep the clock times the person set');
        }
      });
    }

    test('and agrees with the plain clock arithmetic', () {
      final schedule = every(6, hour: 0, minute: 30);
      for (var d = DateTime(2026, 1, 1);
          d.year == 2026;
          d = DateTime(d.year, d.month, d.day + 1)) {
        expect(clock(schedule.getScheduledTimesForDate(d)),
            ['0:30', '6:30', '12:30', '18:30']);
      }
    });
  });

  group('the list reminders are armed from', () {
    List<String> pairs(List<({int hour, int minute})> t) =>
        [for (final s in t) hm(s.hour, s.minute)];

    test('is the same clock times as the day\'s timeline, day by day', () {
      final schedule = MedicineSchedule(
        frequencyType: FrequencyType.everyXHours,
        times: [ScheduledTime(hour: 7, minute: 15)],
        intervalHours: 5,
        startDate: DateTime(2026, 3, 1),
        endDate: DateTime(2026, 11, 30),
      );
      for (var d = DateTime(2026, 2, 20);
          d.isBefore(DateTime(2026, 12, 10));
          d = DateTime(d.year, d.month, d.day + 1)) {
        expect(pairs(schedule.everyXHoursClockTimesOn(d)),
            clock(schedule.getScheduledTimesForDate(d)),
            reason: '${d.year}-${d.month}-${d.day}');
      }
    });

    test('is empty before the schedule starts and after it ends', () {
      final schedule = MedicineSchedule(
        frequencyType: FrequencyType.everyXHours,
        times: [ScheduledTime(hour: 8, minute: 0)],
        intervalHours: 8,
        startDate: DateTime(2026, 6, 10),
        endDate: DateTime(2026, 6, 20),
      );
      expect(schedule.everyXHoursClockTimesOn(DateTime(2026, 6, 9)), isEmpty);
      expect(pairs(schedule.everyXHoursClockTimesOn(DateTime(2026, 6, 10))),
          ['8:00', '16:00']);
      expect(pairs(schedule.everyXHoursClockTimesOn(DateTime(2026, 6, 20))),
          ['8:00', '16:00'],
          reason: 'the end date is inclusive');
      expect(schedule.everyXHoursClockTimesOn(DateTime(2026, 6, 21)), isEmpty);
    });

    test('has nothing for a schedule that is not "every X hours"', () {
      final daily = MedicineSchedule(
        frequencyType: FrequencyType.onceDaily,
        times: [ScheduledTime(hour: 9, minute: 0)],
        intervalHours: 6, // left over from an earlier choice
      );
      expect(daily.everyXHoursClockTimes, isEmpty);
      expect(daily.everyXHoursClockTimesOn(DateTime(2026, 6, 1)), isEmpty);
      expect(clock(daily.getScheduledTimesForDate(DateTime(2026, 6, 1))), ['9:00'],
          reason: 'and its own times are untouched');
    });
  });

  group('what an interval schedule still is', () {
    test('has no slots on a day it is not active', () {
      final ended = MedicineSchedule(
        frequencyType: FrequencyType.everyXHours,
        times: [ScheduledTime(hour: 8, minute: 0)],
        intervalHours: 8,
        endDate: DateTime(2026, 3, 1),
      );
      expect(ended.getScheduledTimesForDate(DateTime(2026, 3, 2)), isEmpty);
      expect(clock(ended.getScheduledTimesForDate(DateTime(2026, 2, 28))),
          ['8:00', '16:00']);
    });

    test('with no anchor time falls back to eight in the morning', () {
      final bare = MedicineSchedule(
          frequencyType: FrequencyType.everyXHours, times: const [], intervalHours: 12);
      expect(clock(bare.getScheduledTimesForDate(DateTime(2026, 6, 1))),
          ['8:00', '20:00']);
    });

    test('without an interval is an ordinary fixed-time schedule', () {
      final noInterval = MedicineSchedule(
          frequencyType: FrequencyType.everyXHours,
          times: [ScheduledTime(hour: 9, minute: 0)]);
      expect(clock(noInterval.getScheduledTimesForDate(DateTime(2026, 6, 1))), ['9:00']);
    });
  });
}
