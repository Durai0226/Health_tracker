// Not a `_test.dart` file on purpose: `flutter test` must NOT pick this up
// directly. It is a plain-Dart entrypoint that dst_date_arithmetic_test.dart
// re-executes in a child process with `TZ=America/New_York`, because a Dart
// process reads its timezone once at startup and cannot switch it at runtime.
//
// Everything it imports is pure Dart (no dart:ui / flutter_test), so it runs
// under a bare `dart run`.
//
// Regression scope: date arithmetic done with an absolute Duration on LOCAL
// DateTimes. Across a DST transition a civil day is 23 or 25 hours, so
// `add(Duration(days: 1))` steps onto the wrong calendar day and
// `a.difference(b).inDays` drifts by one. In this app that off-by-one decides
// how long an antibiotic course runs, which days an every-X-days medicine is
// reminded on, where a 21-on/7-off cycle sits, and what date a period is
// predicted for. 2026 US transitions: spring forward Mar 8, fall back Nov 1.

import 'dart:io';

import 'package:clock/clock.dart';
import 'package:tablet_remainder/core/health/streak_engine.dart';
import 'package:rrule/rrule.dart';
import 'package:tablet_remainder/features/reminders/models/reminder_model.dart';
import 'package:tablet_remainder/features/reminders/models/reminder_recurrence.dart';
import 'package:tablet_remainder/features/reminders/utils/reminder_helper.dart';
import 'package:tablet_remainder/features/medication/models/medicine_enums.dart';
import 'package:tablet_remainder/features/medication/models/medicine_schedule.dart';
import 'package:tablet_remainder/features/period/models/cycle_phase.dart';
import 'package:tablet_remainder/features/period/services/cycle_predictor.dart';

final List<String> _failures = <String>[];

void _expect(Object? actual, Object? expected, String what) {
  final ok = (actual is DateTime && expected is DateTime)
      ? actual.isAtSameMomentAs(expected)
      : actual == expected;
  if (!ok) _failures.add('$what\n    expected: $expected\n    actual:   $actual');
}

/// Calendar-day construction — safe in every zone.
DateTime _d(int y, int m, int day) => DateTime(y, m, day);

/// A wall-clock instant — the thing a reminder actually promises the user.
DateTime _at(int y, int m, int day, int h, [int min = 0]) =>
    DateTime(y, m, day, h, min);

Reminder _reminder(DateTime at, RepeatType repeat, {List<int>? customDays}) =>
    Reminder(
      id: 'probe',
      title: 'probe',
      body: '',
      scheduledTime: at,
      repeatType: repeat,
      customDays: customDays,
    );

/// `ReminderHelper.getNextOccurrence` — "same time tomorrow" must mean the same
/// WALL-CLOCK time, not 24 absolute hours later.
///
/// `_calculateNext` used `add(const Duration(days: 1))`. A civil day across a
/// transition is 23 or 25 hours, so an 08:00 reminder became 09:00 (spring
/// forward) or 07:00 (fall back) — and since each occurrence is computed from the
/// previous one, the drift compounded. Unobservable in the default suite, which
/// runs in a zone chosen by whoever is running it.
void _reminderRecurrence() {
  void expectNext(
    String what, {
    required Reminder reminder,
    required DateTime now,
    required DateTime expected,
  }) {
    withClock(Clock.fixed(now), () {
      _expect(ReminderHelper.getNextOccurrence(reminder), expected, what);
    });
  }

  // 2026 US transitions: spring forward Mar 8 (23h day), fall back Nov 1 (25h).
  expectNext(
    'daily 08:00 across spring forward stays 08:00',
    reminder: _reminder(_at(2026, 3, 7, 8), RepeatType.daily),
    now: _at(2026, 3, 7, 9),
    expected: _at(2026, 3, 8, 8),
  );
  expectNext(
    'daily 08:00 across fall back stays 08:00',
    reminder: _reminder(_at(2026, 10, 31, 8), RepeatType.daily),
    now: _at(2026, 10, 31, 9),
    expected: _at(2026, 11, 1, 8),
  );
  expectNext(
    'weekly 08:00 spanning spring forward stays 08:00 on the same weekday',
    reminder: _reminder(_at(2026, 3, 1, 8), RepeatType.weekly),
    now: _at(2026, 3, 1, 9),
    expected: _at(2026, 3, 8, 8),
  );
  expectNext(
    'weekdays Fri -> Mon across spring forward stays 07:30',
    reminder: _reminder(_at(2026, 3, 6, 7, 30), RepeatType.weekdays),
    now: _at(2026, 3, 6, 8),
    expected: _at(2026, 3, 9, 7, 30),
  );
  expectNext(
    'weekends Sat -> Sun across fall back stays 21:00',
    reminder: _reminder(_at(2026, 10, 31, 21), RepeatType.weekends),
    now: _at(2026, 10, 31, 22),
    expected: _at(2026, 11, 1, 21),
  );
  expectNext(
    'custom Mondays across spring forward stays 08:00',
    reminder: _reminder(_at(2026, 3, 2, 8), RepeatType.custom,
        customDays: const [DateTime.monday]),
    now: _at(2026, 3, 2, 9),
    expected: _at(2026, 3, 9, 8),
  );
  // The compounding case: the catch-up loop steps a missed daily reminder
  // forward one day at a time, so it crosses the transition mid-loop. Every one
  // of those steps used to shed or gain an hour.
  expectNext(
    'a daily reminder missed for 10 days, caught up across spring forward',
    reminder: _reminder(_at(2026, 3, 1, 8), RepeatType.daily),
    now: _at(2026, 3, 10, 12),
    expected: _at(2026, 3, 11, 8),
  );
  // 09:30 on Nov 1 exists twice in a fall-back zone. The reminder must land on
  // the wall-clock time regardless of which offset DateTime resolves it to.
  expectNext(
    'a time inside the repeated hour still resolves to that wall clock',
    reminder: _reminder(_at(2026, 10, 31, 1, 30), RepeatType.daily),
    now: _at(2026, 10, 31, 2),
    expected: _at(2026, 11, 1, 1, 30),
  );
}

void main() {
  // Guard against a vacuous run: if the ambient zone has no DST, none of this
  // proves anything and the parent test is being lied to.
  final winter = DateTime(2026, 1, 1).timeZoneOffset;
  final summer = DateTime(2026, 7, 1).timeZoneOffset;
  if (winter == summer) {
    stderr.writeln(
        'PROBE ABORT: zone has no DST (offset $winter year-round). '
        'Run with TZ=America/New_York.');
    exit(2);
  }

  _streakEngine();
  _medicineSchedule();
  _cyclePredictor();
  _reminderRecurrence();
  _rruleFloatingTime();

  if (_failures.isEmpty) {
    stdout.writeln('DST probe OK (${DateTime(2026, 7, 1).timeZoneName}).');
    return;
  }
  stderr.writeln('DST probe FAILED (${_failures.length}):');
  for (final f in _failures) {
    stderr.writeln('  - $f');
  }
  exit(1);
}

// ---------------------------------------------------------------------------

void _streakEngine() {
  // Spring forward (Mar 8 is a 23-hour day). Every day Mar 1..Mar 15 completed.
  final spring = {for (var day = 1; day <= 15; day++) _d(2026, 3, day)};
  final rSpring =
      StreakEngine.compute(completedDays: spring, today: _d(2026, 3, 15));
  _expect(rSpring.current, 15, 'streak: unbroken run across spring-forward');
  _expect(rSpring.usedGrace, false,
      'streak: no grace day burned across spring-forward');
  _expect(rSpring.longest, 15, 'streak: longest across spring-forward');

  // Fall back (Nov 1 is a 25-hour day). Every day Oct 25..Nov 5 completed.
  final fall = <DateTime>{
    for (var day = 25; day <= 31; day++) _d(2026, 10, day),
    for (var day = 1; day <= 5; day++) _d(2026, 11, day),
  };
  final rFall =
      StreakEngine.compute(completedDays: fall, today: _d(2026, 11, 5));
  _expect(rFall.current, 12, 'streak: unbroken run across fall-back');
  _expect(rFall.usedGrace, false, 'streak: no grace day burned across fall-back');
  _expect(rFall.longest, 12, 'streak: longest across fall-back');

  // A real break must still break — the fix must not make the walk permissive.
  final broken = {_d(2026, 3, 15), _d(2026, 3, 14), _d(2026, 3, 10)};
  final rBroken =
      StreakEngine.compute(completedDays: broken, today: _d(2026, 3, 15));
  _expect(rBroken.current, 2, 'streak: two misses across DST still break it');
}

// ---------------------------------------------------------------------------

void _medicineSchedule() {
  // (a) A 10-day antibiotic course started Mar 4 must end after Mar 13.
  final course = MedicineSchedule(
    frequencyType: FrequencyType.onceDaily,
    times: [ScheduledTime(hour: 9, minute: 0)],
    startDate: _d(2026, 3, 4),
    durationDays: 10,
  );
  _expect(course.isActiveOnDate(_d(2026, 3, 4)), true, 'course: day 1 active');
  _expect(course.isActiveOnDate(_d(2026, 3, 13)), true,
      'course: day 10 (last) active');
  _expect(course.isActiveOnDate(_d(2026, 3, 14)), false,
      'course: day 11 must NOT be active (no 11th day of antibiotics)');
  // The alarm isolate passes a DateTime carrying a time-of-day.
  _expect(course.isActiveOnDate(DateTime(2026, 3, 14, 9, 0)), false,
      'course: day 11 inactive even with a time component');

  // (b) every-2-days parity must not flip at the transition.
  final everyTwo = MedicineSchedule(
    frequencyType: FrequencyType.everyXDays,
    times: [ScheduledTime(hour: 9, minute: 0)],
    intervalDays: 2,
    startDate: _d(2026, 3, 4),
  );
  for (var day = 4; day <= 20; day++) {
    final expectOn = (day - 4) % 2 == 0;
    _expect(everyTwo.isActiveOnDate(_d(2026, 3, day)), expectOn,
        'everyXDays: 2026-03-$day active?');
  }
  // A dose day must actually yield a slot (no slots => no reminder AND no
  // missed-dose record: a silently skipped medicine).
  _expect(everyTwo.getScheduledTimesForDate(_d(2026, 3, 10)).length, 1,
      'everyXDays: dose day 2026-03-10 yields a slot');
  _expect(everyTwo.getScheduledTimesForDate(_d(2026, 3, 11)).length, 0,
      'everyXDays: off day 2026-03-11 yields no slot');

  // (c) 21-on / 7-off cyclical (e.g. contraception) must not shift phase.
  final cyclical = MedicineSchedule(
    frequencyType: FrequencyType.cyclical,
    times: [ScheduledTime(hour: 9, minute: 0)],
    startDate: _d(2026, 3, 1),
    cycleDaysOn: 21,
    cycleDaysOff: 7,
  );
  _expect(cyclical.isActiveOnDate(_d(2026, 3, 21)), true,
      'cyclical: 2026-03-21 is the last ON day');
  _expect(cyclical.isActiveOnDate(_d(2026, 3, 22)), false,
      'cyclical: 2026-03-22 is the first OFF day');
  _expect(cyclical.isActiveOnDate(_d(2026, 3, 28)), false,
      'cyclical: 2026-03-28 is the last OFF day');
  _expect(cyclical.isActiveOnDate(_d(2026, 3, 29)), true,
      'cyclical: 2026-03-29 starts the next ON block');

  // (d) Titration steps must escalate on the right day, not a day late.
  final titrating = MedicineSchedule(
    frequencyType: FrequencyType.onceDaily,
    times: [ScheduledTime(hour: 9, minute: 0)],
    startDate: _d(2026, 3, 4),
    titrationSteps: [
      TitrationStep(startDayOffset: 0, dosageAmount: 25),
      TitrationStep(startDayOffset: 7, dosageAmount: 50),
      TitrationStep(startDayOffset: 14, dosageAmount: 100),
    ],
  );
  _expect(titrating.effectiveDosageAmount(_d(2026, 3, 10), 25.0), 25.0,
      'titration: day 6 still on step 1');
  _expect(titrating.effectiveDosageAmount(_d(2026, 3, 11), 25.0), 50.0,
      'titration: day 7 (2026-03-11) escalates to 50mg');
  _expect(titrating.effectiveDosageAmount(_d(2026, 3, 18), 25.0), 100.0,
      'titration: day 14 (2026-03-18) escalates to 100mg');
}

// ---------------------------------------------------------------------------

void _cyclePredictor() {
  List<FlowDay> bleed(DateTime start, int len) =>
      [for (var i = 0; i < len; i++) FlowDay(_d(start.year, start.month, start.day + i), 2)];

  // A 5-day period run that straddles the transition (Mar 5..Mar 9) must still
  // read as 5 days — and the run must not lose its last day to a 23-hour gap.
  final straddling = CyclePredictor.deriveCycles(bleed(_d(2026, 3, 5), 5));
  _expect(straddling.length, 1, 'cycles: one open cycle from a single run');
  _expect(straddling.first.periodLengthDays, 5,
      'cycles: period run straddling spring-forward is 5 days');

  // Three period starts, 28 days apart, then predict from inside the open cycle.
  final days = <FlowDay>[
    ...bleed(_d(2026, 1, 5), 5),
    ...bleed(_d(2026, 2, 2), 5),
    ...bleed(_d(2026, 3, 2), 5),
  ];
  final cycles = CyclePredictor.deriveCycles(days);
  _expect(cycles.length, 3, 'cycles: three derived');
  _expect(cycles[0].cycleLengthDays, 28, 'cycles: Jan->Feb length');
  _expect(cycles[1].cycleLengthDays, 28, 'cycles: Feb->Mar length');
  _expect(cycles[1].end, _d(2026, 3, 1), 'cycles: Feb cycle ends Mar 1');

  final p = CyclePredictor.predict(days: days, on: _d(2026, 3, 20));
  _expect(p.lastPeriodStart, _d(2026, 3, 2), 'predict: last period start');
  _expect(p.predictedStart, _d(2026, 3, 30),
      'predict: next period lands on the right calendar day');
  _expect(p.ovulationDay, _d(2026, 3, 16), 'predict: ovulation day');
  _expect(p.fertileStart, _d(2026, 3, 11), 'predict: fertile window start');
  _expect(p.fertileEnd, _d(2026, 3, 17), 'predict: fertile window end');
  _expect(p.dayOfCycle, 19, 'predict: day of cycle on 2026-03-20');
  _expect(p.daysUntilNextPeriod, 10, 'predict: days until next period');

  // Fall-back direction: Oct 20 + 28 days must be Nov 17, not Nov 16. (Adding
  // an absolute 28*24h across a 25-hour day lands at 23:00 the previous day.)
  final autumn = <FlowDay>[
    ...bleed(_d(2026, 8, 25), 5),
    ...bleed(_d(2026, 9, 22), 5),
    ...bleed(_d(2026, 10, 20), 5),
  ];
  final pAutumn = CyclePredictor.predict(days: autumn, on: _d(2026, 11, 10));
  _expect(pAutumn.predictedStart, _d(2026, 11, 17),
      'predict: next period across fall-back lands on the right calendar day');
  _expect(pAutumn.ovulationDay, _d(2026, 11, 3),
      'predict: ovulation day across fall-back');
  _expect(pAutumn.daysUntilNextPeriod, 7,
      'predict: days until next period across fall-back');
  _expect(pAutumn.dayOfCycle, 22, 'predict: day of cycle across fall-back');

  // Phase boundary one day past ovulation, on the far side of the transition.
  _expect(
    CyclePredictor.phaseOn(
      _d(2026, 3, 18),
      lastStart: _d(2026, 3, 2),
      cycleLength: 28,
      periodLength: 5,
      lutealLength: 14,
    ),
    CyclePhase.luteal,
    'phaseOn: cycle day 17 across spring-forward is luteal, not ovulation',
  );

  // Gestational day count across the transition.
  final preg = CyclePredictor.predict(
    days: const [],
    on: _d(2026, 3, 20),
    pregnancyMode: true,
    pregnancyStartDate: _d(2026, 3, 1),
  );
  _expect(preg.gestationalDays, 19, 'predict: gestational days across DST');
}

/// RFC 5545 recurrence under a real DST zone.
///
/// `rrule` requires every DateTime to have `isUtc: true` and states it "doesn't
/// care about any time-zone-related stuff". A reminder, however, is a WALL-CLOCK
/// promise: 08:00 means 08:00 whatever the offset is that day.
///
/// The naive treatment — convert local→UTC, generate, convert back — reproduces
/// exactly the bug `_calculateNext` was just fixed for, because the offset
/// changes across a transition. [ReminderRecurrence] instead RELABELS the local
/// wall clock as UTC, so the arithmetic never touches a zone and cannot gain or
/// lose an hour.
///
/// This is the check that convention is actually holding. It cannot live in the
/// ordinary suite: a Dart process reads its zone once at startup.
void _rruleFloatingTime() {
  ReminderRecurrence r(String s) =>
      ReminderRecurrence.rrule(RecurrenceRule.fromString(s));

  void expectAllAt(String what, List<DateTime> got, int hour, int minute) {
    for (final d in got) {
      if (d.hour != hour || d.minute != minute) {
        _failures.add('$what\n    expected: every instance at '
            '$hour:${minute.toString().padLeft(2, '0')}'
            '\n    actual:   $d');
        return;
      }
    }
  }

  // 2026 US transitions: spring forward Mar 8, fall back Nov 1.
  expectAllAt(
    'daily RRULE across spring forward holds 08:00',
    r('RRULE:FREQ=DAILY').preview(start: DateTime(2026, 3, 5, 8), limit: 8),
    8,
    0,
  );
  expectAllAt(
    'daily RRULE across fall back holds 21:30',
    r('RRULE:FREQ=DAILY').preview(start: DateTime(2026, 10, 29, 21, 30), limit: 8),
    21,
    30,
  );
  expectAllAt(
    'every-other-week RRULE holds 07:15 across both transitions',
    r('RRULE:FREQ=WEEKLY;INTERVAL=2')
        .preview(start: DateTime(2026, 2, 3, 7, 15), limit: 26),
    7,
    15,
  );
  expectAllAt(
    'monthly BYSETPOS holds 17:45 all year',
    r('RRULE:FREQ=MONTHLY;BYDAY=FR;BYSETPOS=-1')
        .preview(start: DateTime(2026, 1, 30, 17, 45), limit: 12),
    17,
    45,
  );

  // The precise instant, not just the time of day: the day after spring forward.
  _expect(
    r('RRULE:FREQ=DAILY')
        .nextAfter(start: DateTime(2026, 3, 7, 8), after: DateTime(2026, 3, 7, 9)),
    DateTime(2026, 3, 8, 8),
    'daily RRULE lands on Mar 8 08:00, not 07:00 or 09:00',
  );
  _expect(
    r('RRULE:FREQ=DAILY').nextAfter(
        start: DateTime(2026, 10, 31, 8), after: DateTime(2026, 10, 31, 9)),
    DateTime(2026, 11, 1, 8),
    'daily RRULE lands on Nov 1 08:00 across fall back',
  );

  // Instances must come back LOCAL. A leaked UTC DateTime compares wrongly
  // against clock.now() and would be off by the whole zone offset.
  for (final d in r('RRULE:FREQ=DAILY')
      .preview(start: DateTime(2026, 6, 1, 8), limit: 3)) {
    if (d.isUtc) {
      _failures.add('RRULE instances must be reinterpreted as local'
          '\n    expected: isUtc == false\n    actual:   $d');
      break;
    }
  }
}
