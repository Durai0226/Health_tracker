/// What an iPhone is asked to hold for a medicine.
///
/// An iPhone cannot decide at the moment a notification fires whether the
/// medicine is due today, so every medicine used to be armed as "this time, every
/// day": a once-a-week tablet reminded daily. The plan arms what is due, and only
/// that, wherever the OS allows it.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:tablet_remainder/features/medication/models/medicine_enums.dart';
import 'package:tablet_remainder/features/medication/models/medicine_schedule.dart';
import 'package:tablet_remainder/features/medication/services/ios_dose_plan.dart';

void main() {
  // Wednesday 28 October 2026, ten in the morning.
  final now = DateTime(2026, 10, 28, 10, 0);
  assert(now.weekday == DateTime.wednesday);

  ScheduledTime at(int h, [int m = 0]) => ScheduledTime(hour: h, minute: m);

  MedicineSchedule sched(
    FrequencyType type, {
    List<ScheduledTime>? times,
    int? intervalHours,
    int? intervalDays,
    List<int>? days,
    DateTime? start,
    DateTime? end,
    int? duration,
    int? on,
    int? off,
    List<ScheduledTime>? weekend,
    bool prn = false,
  }) =>
      MedicineSchedule(
        frequencyType: type,
        times: times ?? [at(8)],
        intervalHours: intervalHours,
        intervalDays: intervalDays,
        specificDays: days,
        startDate: start,
        endDate: end,
        durationDays: duration,
        cycleDaysOn: on,
        cycleDaysOff: off,
        weekendTimes: weekend,
        isPRN: prn,
      );

  List<PlannedDose> plan(MedicineSchedule s, {int max = 24}) =>
      IosDosePlan.plan(s, now: now, maxCount: max);

  group('every day, for ever: what it always was', () {
    test('once a day is one repeating daily reminder, at the next time it comes round',
        () {
      final p = plan(sched(FrequencyType.onceDaily, times: [at(8)]));
      expect(p.map((d) => d.repeat), [DoseRepeat.daily]);
      expect(p.single.at, DateTime(2026, 10, 29, 8),
          reason: '08:00 has passed today');
    });

    test('a time later today starts today', () {
      final p = plan(sched(FrequencyType.onceDaily, times: [at(21)]));
      expect(p.single.at, DateTime(2026, 10, 28, 21));
    });

    test('several times a day are one each, in the order the medicine lists them',
        () {
      final p = plan(sched(FrequencyType.thriceDaily,
          times: [at(8), at(14), at(21)]));
      expect(p.map((d) => (d.hour, d.minute)), [(8, 0), (14, 0), (21, 0)]);
      expect(p.every((d) => d.repeat == DoseRepeat.daily), isTrue);
    });

    test('every X hours is its clock times, repeating daily', () {
      final p = plan(sched(FrequencyType.everyXHours,
          times: [at(6)], intervalHours: 8));
      expect(p.map((d) => d.hour), [6, 14, 22]);
      expect(p.every((d) => d.repeat == DoseRepeat.daily), isTrue);
    });

    test('every X hours with no interval has no clock times, so nothing is armed', () {
      expect(plan(sched(FrequencyType.everyXHours, times: [at(6)])), isEmpty);
      expect(
          plan(sched(FrequencyType.everyXHours, times: [at(6)], intervalHours: 0)),
          isEmpty);
    });

    test('a start date that has arrived is still "every day"', () {
      final p = plan(sched(FrequencyType.onceDaily,
          start: DateTime(2026, 10, 1)));
      expect(p.single.repeat, DoseRepeat.daily);
    });

    test('is cut to the count it is allowed', () {
      final p = plan(
          sched(FrequencyType.thriceDaily, times: [at(8), at(14), at(21)]),
          max: 2);
      expect(p.map((d) => d.hour), [8, 14]);
    });
  });

  group('chosen weekdays: one repeating weekly reminder each', () {
    test('Monday and Thursday at 8 are two weekly reminders, soonest first', () {
      final p = plan(sched(FrequencyType.specificDays, days: [1, 4]));
      expect(p.map((d) => d.repeat), [DoseRepeat.weekly, DoseRepeat.weekly]);
      expect(p.map((d) => d.weekday), [DateTime.thursday, DateTime.monday]);
      expect(p.first.at, DateTime(2026, 10, 29, 8), reason: 'Thursday, tomorrow');
      expect(p.last.at, DateTime(2026, 11, 2, 8), reason: 'Monday, next week');
    });

    test('a once-a-week medicine is one reminder a week, not seven', () {
      final p = plan(sched(FrequencyType.specificDays, days: [7]));
      expect(p.length, 1);
      expect(p.single.weekday, DateTime.sunday);
      expect(p.single.at, DateTime(2026, 11, 1, 8));
    });

    test('each time on each day', () {
      final p = plan(sched(FrequencyType.specificDays,
          days: [2, 5], times: [at(8), at(20)]));
      expect(p.length, 4);
      expect({for (final d in p) (d.weekday, d.hour)}, {
        (DateTime.tuesday, 8),
        (DateTime.tuesday, 20),
        (DateTime.friday, 8),
        (DateTime.friday, 20),
      });
    });

    test('today\'s weekday: later today if the time has not come, else next week',
        () {
      final later = plan(sched(FrequencyType.specificDays,
          days: [3], times: [at(11)]));
      expect(later.single.at, DateTime(2026, 10, 28, 11));
      final earlier = plan(sched(FrequencyType.specificDays,
          days: [3], times: [at(9)]));
      expect(earlier.single.at, DateTime(2026, 11, 4, 9));
    });

    test('is cut to the count it is allowed, the soonest kept', () {
      final p = plan(
          sched(FrequencyType.specificDays,
              days: [1, 3, 5], times: [at(8), at(14), at(21)]),
          max: 4);
      expect(p.length, 4);
      // Wednesday 11:00-ish: today's 14:00 and 21:00 are still to come, then
      // Friday 8:00, then Friday 14:00.
      expect(p.map((d) => d.at), [
        DateTime(2026, 10, 28, 14),
        DateTime(2026, 10, 28, 21),
        DateTime(2026, 10, 30, 8),
        DateTime(2026, 10, 30, 14),
      ]);
    });

    test('more weekday-and-time pairs than there is room for are armed as the doses due next',
        () {
      // Monday to Saturday, five times a day: 30 pairs, room for 24. Armed as weekly
      // reminders, six pairs would be left out for good, and a different six on a
      // different day the app was opened.
      final p = plan(sched(FrequencyType.specificDays,
          days: [1, 2, 3, 4, 5, 6],
          times: [at(6), at(10), at(14), at(18), at(22)]));

      expect(p.length, 24);
      expect(p.every((d) => d.repeat == DoseRepeat.once), isTrue);
      expect(p.first.at, DateTime(2026, 10, 28, 14), reason: 'the next dose due');
    });

    test('exactly as many as there is room for stay weekly', () {
      final p = plan(
          sched(FrequencyType.specificDays,
              days: [1, 2, 3, 4], times: [at(6), at(8), at(10), at(12), at(14), at(16)]),
          max: 24);
      expect(p.length, 24);
      expect(p.every((d) => d.repeat == DoseRepeat.weekly), isTrue);
    });

    test('all seven days is every day', () {
      final p = plan(sched(FrequencyType.specificDays,
          days: [1, 2, 3, 4, 5, 6, 7]));
      expect(p.map((d) => d.repeat), [DoseRepeat.daily]);
    });

    test('a repeated or impossible day is ignored, and none left is nothing', () {
      expect(plan(sched(FrequencyType.specificDays, days: [4, 4])).length, 1);
      expect(plan(sched(FrequencyType.specificDays, days: [0, 9])), isEmpty);
    });

    test('no chosen days falls through to "when it is due", which is never',
        () {
      expect(plan(sched(FrequencyType.specificDays, days: const [])), isEmpty);
    });
  });

  group('anything that is not for ever: one reminder for each dose due', () {
    test('a course with an end date stops on it, inclusive, and not after', () {
      final p = plan(sched(FrequencyType.onceDaily,
          end: DateTime(2026, 10, 31)));
      expect(p.every((d) => d.repeat == DoseRepeat.once), isTrue);
      expect(p.map((d) => d.at), [
        DateTime(2026, 10, 29, 8),
        DateTime(2026, 10, 30, 8),
        DateTime(2026, 10, 31, 8),
      ]);
    });

    test('each one carries the dose\'s own clock time', () {
      final p = plan(sched(FrequencyType.onceDaily,
          times: [at(8, 15)], end: DateTime(2026, 10, 30)));
      expect(p.map((d) => (d.hour, d.minute)), [(8, 15), (8, 15)]);
    });

    test('a course that is over has nothing armed', () {
      expect(
          plan(sched(FrequencyType.onceDaily, end: DateTime(2026, 10, 27))),
          isEmpty,
          reason: 'it used to keep reminding every day after the last dose');
    });

    test('a course of N days counts N days from its start', () {
      final p = plan(sched(FrequencyType.onceDaily,
          start: DateTime(2026, 10, 26), duration: 5));
      // 26, 27, 28, 29, 30 — today\'s 08:00 has passed.
      expect(p.map((d) => d.at.day), [29, 30]);
    });

    test('a start in the future begins on that day, not today', () {
      final p = plan(sched(FrequencyType.onceDaily,
          start: DateTime(2026, 11, 3)));
      expect(p.first.at, DateTime(2026, 11, 3, 8));
      expect(p.first.repeat, DoseRepeat.once);
    });

    test('every 3 days is every third day from the start', () {
      final p = plan(
          sched(FrequencyType.everyXDays,
              intervalDays: 3, start: DateTime(2026, 10, 25)),
          max: 4);
      // 25, 28, 31, 3 Nov, 6 Nov — today\'s (28th) 08:00 has passed.
      expect(p.map((d) => d.at), [
        DateTime(2026, 10, 31, 8),
        DateTime(2026, 11, 3, 8),
        DateTime(2026, 11, 6, 8),
        DateTime(2026, 11, 9, 8),
      ]);
    });

    test('three weeks on and one off skips the week off', () {
      // On for 3 days, off for 2: 26,27,28 on; 29,30 off; 31,1,2 on.
      final p = plan(
          sched(FrequencyType.cyclical,
              on: 3, off: 2, start: DateTime(2026, 10, 26)),
          max: 4);
      expect(p.map((d) => d.at.day), [31, 1, 2, 5]);
    });

    test('a different time at the weekend is armed at that time, on those days',
        () {
      final p = plan(
          sched(FrequencyType.onceDaily,
              times: [at(7)], weekend: [at(10)]),
          max: 8);
      final byDay = {for (final d in p) d.at.day: d.at.hour};
      expect(byDay[29], 7, reason: 'Thursday');
      expect(byDay[31], 10, reason: 'Saturday');
      expect(byDay[1], 10, reason: 'Sunday');
      expect(byDay[2], 7, reason: 'Monday');
    });

    test('a weekly medicine with an end date is dated, so it stops', () {
      final p = plan(sched(FrequencyType.specificDays,
          days: [4], end: DateTime(2026, 11, 12)));
      expect(p.map((d) => d.at.day), [29, 5, 12]);
      expect(p.every((d) => d.repeat == DoseRepeat.once), isTrue);
    });

    test('only doses still to come are armed: today\'s earlier ones are not', () {
      final p = plan(
          sched(FrequencyType.twiceDaily,
              times: [at(8), at(20)], end: DateTime(2026, 10, 28)));
      expect(p.map((d) => d.at), [DateTime(2026, 10, 28, 20)]);
    });

    test('is cut to the count it is allowed, soonest kept', () {
      final p = plan(
          sched(FrequencyType.onceDaily, end: DateTime(2026, 12, 31)),
          max: 5);
      expect(p.length, 5);
      expect(p.first.at, DateTime(2026, 10, 29, 8));
      expect(p.last.at, DateTime(2026, 11, 2, 8));
    });

    test('a dose that is monthly is still found', () {
      final p = plan(
          sched(FrequencyType.everyXDays,
              intervalDays: 30, start: DateTime(2026, 10, 1)),
          max: 2);
      expect(p.map((d) => d.at), [
        DateTime(2026, 10, 31, 8),
        DateTime(2026, 11, 30, 8),
      ]);
    });
  });

  group('when the clocks skip an hour (run with TZ=America/New_York)', () {
    // 02:30 on Sunday 8 March 2026 does not exist in New York: Dart moves a DateTime
    // built for it to 03:30. On a machine whose zone has no such gap (this one is
    // IST) the group has nothing to check and says so.
    final gapDay = DateTime(2026, 3, 8, 2, 30);
    final skipped = gapDay.hour != 2;
    final saturday = DateTime(2026, 3, 7, 10, 0);

    List<PlannedDose> planAt(MedicineSchedule s) =>
        IosDosePlan.plan(s, now: saturday, maxCount: 24);

    test('a daily 02:30 dose is anchored on a day it exists, and stays 02:30', () {
      final p = planAt(sched(FrequencyType.onceDaily, times: [at(2, 30)]));

      expect(p.single.repeat, DoseRepeat.daily);
      expect((p.single.hour, p.single.minute), (2, 30),
          reason: 'read back from a DateTime built for the skipped time it would be '
              '03:30, and the reminder would repeat at 03:30 every day after');
      if (skipped) {
        expect(p.single.at, DateTime(2026, 3, 9, 2, 30),
            reason: 'the day the clocks skip it is passed over, not armed late');
      }
    }, skip: skipped ? false : 'this machine\'s zone has no spring-forward gap');

    test('a Sunday 02:30 weekly dose is anchored on the Sunday after', () {
      final p = planAt(
          sched(FrequencyType.specificDays, days: [7], times: [at(2, 30)]));

      expect(p.single.repeat, DoseRepeat.weekly);
      expect((p.single.hour, p.single.minute), (2, 30));
      expect(p.single.at, DateTime(2026, 3, 15, 2, 30));
    }, skip: skipped ? false : 'this machine\'s zone has no spring-forward gap');

    test('a one-off for the skipped time is armed for the moment it falls, and is still the 02:30 dose',
        () {
      final p = IosDosePlan.plan(
          sched(FrequencyType.onceDaily,
              times: [at(2, 30)], end: DateTime(2026, 3, 10)),
          now: saturday,
          maxCount: 24);

      final gapDose = p.firstWhere((d) => d.at.day == 8);
      expect(gapDose.repeat, DoseRepeat.once);
      expect((gapDose.hour, gapDose.minute), (2, 30),
          reason: 'a Take on it is logged against the 02:30 slot, not 03:30');
      expect(gapDose.at, DateTime(2026, 3, 8, 3, 30),
          reason: 'but it is armed for when 02:30 would have been');
    }, skip: skipped ? false : 'this machine\'s zone has no spring-forward gap');

    test('a time that exists is untouched, on any machine', () {
      final p = planAt(sched(FrequencyType.onceDaily, times: [at(8)]));
      expect(p.single.at, DateTime(2026, 3, 8, 8));
      expect((p.single.hour, p.single.minute), (8, 0));
    });
  });

  group('nothing to arm', () {
    test('as-needed medicine', () {
      expect(plan(sched(FrequencyType.asNeeded)), isEmpty);
      expect(plan(sched(FrequencyType.onceDaily, prn: true)), isEmpty);
    });

    test('no times', () {
      expect(plan(sched(FrequencyType.onceDaily, times: const [])), isEmpty);
    });

    test('no room', () {
      expect(plan(sched(FrequencyType.onceDaily), max: 0), isEmpty);
    });
  });
}
