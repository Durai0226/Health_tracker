import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tablet_remainder/core/health/streak_engine.dart';
import 'package:tablet_remainder/features/medication/models/medicine_enums.dart';
import 'package:tablet_remainder/features/medication/models/medicine_schedule.dart';
import 'package:tablet_remainder/features/period/models/cycle_phase.dart';
import 'package:tablet_remainder/features/period/services/cycle_predictor.dart';

/// Regression suite for DST-unsafe date arithmetic.
///
/// A local civil day is 23 or 25 hours long across a daylight-saving
/// transition, so `add(Duration(days: 1))` steps onto the wrong calendar day
/// and `a.difference(b).inDays` truncates by one. In this app that off-by-one
/// decided how many days an antibiotic course ran, which days an every-X-days
/// medicine was reminded on, where a 21-on/7-off cycle sat, which titration
/// dose applied, whether a streak survived, and what date a period was
/// predicted for.
///
/// Two layers:
///  1. The `group`s below assert the correct calendar-day semantics. They hold
///     in EVERY zone, so they run wherever CI happens to live.
///  2. `dst_date_arithmetic_probe.dart` re-runs the same assertions in a child
///     process pinned to `TZ=America/New_York`. A Dart process reads its
///     timezone once at startup, so a real DST zone can only be exercised out
///     of process. That is the test that actually fails on the unfixed code
///     (34 failures at the time of the fix).
void main() {
  DateTime d(int y, int m, int day) => DateTime(y, m, day);

  group('StreakEngine — calendar-day walking', () {
    test('an unbroken 15-day run counts 15', () {
      final done = {for (var i = 1; i <= 15; i++) d(2026, 3, i)};
      final r = StreakEngine.compute(completedDays: done, today: d(2026, 3, 15));
      expect(r.current, 15);
      expect(r.longest, 15);
      expect(r.usedGrace, isFalse);
    });

    test('an unbroken run spanning a month boundary counts every day', () {
      final done = <DateTime>{
        for (var i = 25; i <= 31; i++) d(2026, 10, i),
        for (var i = 1; i <= 5; i++) d(2026, 11, i),
      };
      final r =
          StreakEngine.compute(completedDays: done, today: d(2026, 11, 5));
      expect(r.current, 12);
      expect(r.longest, 12);
      expect(r.usedGrace, isFalse);
    });

    test('two misses in a week still break the streak', () {
      final done = {d(2026, 3, 15), d(2026, 3, 14), d(2026, 3, 10)};
      final r = StreakEngine.compute(completedDays: done, today: d(2026, 3, 15));
      expect(r.current, 2);
    });
  });

  group('MedicineSchedule.isActiveOnDate — calendar-day offsets', () {
    test('a 10-day course is active on exactly 10 days', () {
      final s = MedicineSchedule(
        frequencyType: FrequencyType.onceDaily,
        times: [ScheduledTime(hour: 9, minute: 0)],
        startDate: d(2026, 3, 4),
        durationDays: 10,
      );
      final active = [
        for (var i = 4; i <= 20; i++)
          if (s.isActiveOnDate(d(2026, 3, i))) i,
      ];
      expect(active, [4, 5, 6, 7, 8, 9, 10, 11, 12, 13]);
      // The alarm isolate passes a DateTime carrying a time-of-day.
      expect(s.isActiveOnDate(DateTime(2026, 3, 14, 9, 0)), isFalse);
    });

    test('every-2-days keeps its parity, and dose days yield slots', () {
      final s = MedicineSchedule(
        frequencyType: FrequencyType.everyXDays,
        times: [ScheduledTime(hour: 9, minute: 0)],
        intervalDays: 2,
        startDate: d(2026, 3, 4),
      );
      for (var i = 4; i <= 20; i++) {
        expect(s.isActiveOnDate(d(2026, 3, i)), (i - 4) % 2 == 0,
            reason: '2026-03-$i');
      }
      // No slots means no reminder AND no missed-dose record.
      expect(s.getScheduledTimesForDate(d(2026, 3, 10)), hasLength(1));
      expect(s.getScheduledTimesForDate(d(2026, 3, 11)), isEmpty);
    });

    test('21-on / 7-off cyclical keeps its phase', () {
      final s = MedicineSchedule(
        frequencyType: FrequencyType.cyclical,
        times: [ScheduledTime(hour: 9, minute: 0)],
        startDate: d(2026, 3, 1),
        cycleDaysOn: 21,
        cycleDaysOff: 7,
      );
      expect(s.isActiveOnDate(d(2026, 3, 21)), isTrue, reason: 'last ON day');
      expect(s.isActiveOnDate(d(2026, 3, 22)), isFalse, reason: 'first OFF day');
      expect(s.isActiveOnDate(d(2026, 3, 28)), isFalse, reason: 'last OFF day');
      expect(s.isActiveOnDate(d(2026, 3, 29)), isTrue, reason: 'next ON block');
    });

    test('titration escalates on the scheduled day, not a day late', () {
      final s = MedicineSchedule(
        frequencyType: FrequencyType.onceDaily,
        times: [ScheduledTime(hour: 9, minute: 0)],
        startDate: d(2026, 3, 4),
        titrationSteps: [
          TitrationStep(startDayOffset: 0, dosageAmount: 25),
          TitrationStep(startDayOffset: 7, dosageAmount: 50),
          TitrationStep(startDayOffset: 14, dosageAmount: 100),
        ],
      );
      expect(s.effectiveDosageAmount(d(2026, 3, 10), 25.0), 25.0);
      expect(s.effectiveDosageAmount(d(2026, 3, 11), 25.0), 50.0);
      expect(s.effectiveDosageAmount(d(2026, 3, 18), 25.0), 100.0);
    });
  });

  group('CyclePredictor — calendar-day cycles', () {
    List<FlowDay> bleed(DateTime start, int len) => [
          for (var i = 0; i < len; i++)
            FlowDay(DateTime(start.year, start.month, start.day + i), 2),
        ];

    test('a 5-day period run reads as 5 days', () {
      final cycles = CyclePredictor.deriveCycles(bleed(d(2026, 3, 5), 5));
      expect(cycles, hasLength(1));
      expect(cycles.first.periodLengthDays, 5);
      expect(cycles.first.isOpen, isTrue);
    });

    test('28-day cycles derive as 28 and predict the right calendar day', () {
      final days = <FlowDay>[
        ...bleed(d(2026, 1, 5), 5),
        ...bleed(d(2026, 2, 2), 5),
        ...bleed(d(2026, 3, 2), 5),
      ];
      final cycles = CyclePredictor.deriveCycles(days);
      expect(cycles.map((c) => c.cycleLengthDays), [28, 28, null]);
      expect(cycles[1].end, d(2026, 3, 1));

      final p = CyclePredictor.predict(days: days, on: d(2026, 3, 20));
      expect(p.lastPeriodStart, d(2026, 3, 2));
      expect(p.predictedStart, d(2026, 3, 30));
      expect(p.ovulationDay, d(2026, 3, 16));
      expect(p.fertileStart, d(2026, 3, 11));
      expect(p.fertileEnd, d(2026, 3, 17));
      expect(p.dayOfCycle, 19);
      expect(p.daysUntilNextPeriod, 10);
    });

    test('prediction across a month boundary lands on the right day', () {
      final days = <FlowDay>[
        ...bleed(d(2026, 8, 25), 5),
        ...bleed(d(2026, 9, 22), 5),
        ...bleed(d(2026, 10, 20), 5),
      ];
      final p = CyclePredictor.predict(days: days, on: d(2026, 11, 10));
      expect(p.predictedStart, d(2026, 11, 17));
      expect(p.ovulationDay, d(2026, 11, 3));
      expect(p.daysUntilNextPeriod, 7);
      expect(p.dayOfCycle, 22);
    });

    test('cycle day 17 is luteal, not ovulation', () {
      expect(
        CyclePredictor.phaseOn(
          d(2026, 3, 18),
          lastStart: d(2026, 3, 2),
          cycleLength: 28,
          periodLength: 5,
          lutealLength: 14,
        ),
        CyclePhase.luteal,
      );
    });

    test('gestational days are calendar days', () {
      final p = CyclePredictor.predict(
        days: const [],
        on: d(2026, 3, 20),
        pregnancyMode: true,
        pregnancyStartDate: d(2026, 3, 1),
      );
      expect(p.gestationalDays, 19);
    });
  });

  // The one test that can actually observe a DST transition. Everything above
  // passes in a no-DST zone even on the buggy code; this does not.
  test(
    'all of the above still hold under TZ=America/New_York (out of process)',
    () async {
      if (Platform.isWindows) {
        markTestSkipped('TZ env var is not honoured on Windows');
        return;
      }
      final dart = _dartExecutable();
      if (dart == null) {
        markTestSkipped('no dart executable found to spawn the DST probe');
        return;
      }
      final probe = File('test/core/dst_date_arithmetic_probe.dart');
      expect(probe.existsSync(), isTrue,
          reason: 'probe missing at ${probe.absolute.path}');

      final r = await Process.run(
        dart,
        ['run', probe.path],
        environment: const {'TZ': 'America/New_York'},
        workingDirectory: Directory.current.path,
      );
      // Exit 2 means the child somehow still had no DST — treat as a skip
      // rather than a false pass, so the suite never silently stops covering
      // this.
      if (r.exitCode == 2) {
        markTestSkipped('DST probe could not obtain a DST zone: ${r.stderr}');
        return;
      }
      expect(r.exitCode, 0, reason: '${r.stdout}\n${r.stderr}');
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}

/// The Dart VM binary, for re-running the probe with a different `TZ`.
/// `flutter test` runs suites inside `flutter_tester`, so
/// [Platform.resolvedExecutable] is not necessarily `dart`.
String? _dartExecutable() {
  final flutterRoot = Platform.environment['FLUTTER_ROOT'];
  if (flutterRoot != null && flutterRoot.isNotEmpty) {
    final candidate = File('$flutterRoot/bin/cache/dart-sdk/bin/dart');
    if (candidate.existsSync()) return candidate.path;
  }
  final resolved = Platform.resolvedExecutable;
  if (resolved.split(Platform.pathSeparator).last.startsWith('dart')) {
    return resolved;
  }
  return null;
}
