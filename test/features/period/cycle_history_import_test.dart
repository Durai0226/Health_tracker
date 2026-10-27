/// Past periods come in from a health app, so predictions start with history.
///
/// Reading the plugin and asking for permission is the platform's part; what is
/// worked out here — which days bled, how heavily, and which of them the person
/// has already logged for themselves — is plain logic.
library;

import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health/health.dart';
import 'package:tablet_remainder/features/period/models/flow_intensity.dart';
import 'package:tablet_remainder/features/period/models/period_day.dart';
import 'package:tablet_remainder/features/period/services/cycle_history_import.dart';

void main() {
  final now = DateTime(2026, 9, 30, 12);

  HealthDataPoint flow(DateTime at, MenstrualFlow? level,
          {HealthDataType type = HealthDataType.MENSTRUATION_FLOW, HealthValue? value}) =>
      HealthDataPoint(
        uuid: 'f-${at.millisecondsSinceEpoch}-${level?.name}',
        value: value ?? MenstruationFlowHealthValue(flow: level, dateTime: at),
        type: type,
        unit: HealthDataUnit.NO_UNIT,
        dateFrom: at,
        dateTo: at,
        sourcePlatform: HealthPlatformType.googleHealthConnect,
        sourceDeviceId: 'unknown',
        sourceId: 'com.cycle.app',
        sourceName: 'Cycle app',
        recordingMethod: RecordingMethod.manual,
      );

  DateTime d(int y, int m, int day) => DateTime(y, m, day);

  group('how a level reads here', () {
    test('each bleeding level has its own', () {
      expect(CycleHistoryImport.flowFor(MenstrualFlow.spotting), FlowIntensity.spotting);
      expect(CycleHistoryImport.flowFor(MenstrualFlow.light), FlowIntensity.light);
      expect(CycleHistoryImport.flowFor(MenstrualFlow.medium), FlowIntensity.medium);
      expect(CycleHistoryImport.flowFor(MenstrualFlow.heavy), FlowIntensity.heavy);
    });

    test('bleeding with no level recorded is Medium, not Light', () {
      expect(CycleHistoryImport.flowFor(MenstrualFlow.unspecified), FlowIntensity.medium,
          reason: 'the middle, rather than a Light that would under-report it');
    });

    test('no bleeding is not a day', () {
      expect(CycleHistoryImport.flowFor(MenstrualFlow.none), isNull);
      expect(CycleHistoryImport.flowFor(null), isNull);
    });
  });

  group('the days in a read', () {
    List<ImportedFlowDay> days(List<HealthDataPoint> s) =>
        CycleHistoryImport.daysFrom(s, now: now);

    test('come out oldest first, one a day', () {
      final got = days([
        flow(DateTime(2026, 9, 3, 8), MenstrualFlow.medium),
        flow(DateTime(2026, 9, 1, 8), MenstrualFlow.light),
        flow(DateTime(2026, 9, 2, 8), MenstrualFlow.heavy),
      ]);
      expect([for (final x in got) x.day], [d(2026, 9, 1), d(2026, 9, 2), d(2026, 9, 3)]);
      expect([for (final x in got) x.flow],
          [FlowIntensity.light, FlowIntensity.heavy, FlowIntensity.medium]);
    });

    test('a day with several samples keeps the strongest', () {
      final got = days([
        flow(DateTime(2026, 9, 2, 7), MenstrualFlow.light),
        flow(DateTime(2026, 9, 2, 13), MenstrualFlow.heavy),
        flow(DateTime(2026, 9, 2, 20), MenstrualFlow.spotting),
      ]);
      expect(got, hasLength(1));
      expect(got.single.flow, FlowIntensity.heavy);
    });

    test('a sample just before midnight belongs to that local day', () {
      final got = days([flow(DateTime(2026, 9, 2, 23, 59), MenstrualFlow.light)]);
      expect(got.single.day, d(2026, 9, 2));
    });

    test('samples that are not flow, or no bleeding, are left out', () {
      final got = days([
        flow(DateTime(2026, 9, 1, 8), MenstrualFlow.none),
        flow(DateTime(2026, 9, 2, 8), null),
        flow(DateTime(2026, 9, 3, 8), MenstrualFlow.light,
            type: HealthDataType.STEPS,
            value: NumericHealthValue(numericValue: 4000)),
        flow(DateTime(2026, 9, 4, 8), MenstrualFlow.medium),
      ]);
      expect([for (final x in got) x.day], [d(2026, 9, 4)]);
    });

    test('reaches back two years and no further', () {
      final got = days([
        flow(DateTime(2024, 9, 29, 8), MenstrualFlow.light), // just over
        flow(DateTime(2024, 10, 1, 8), MenstrualFlow.light), // inside
      ]);
      expect([for (final x in got) x.day], [d(2024, 10, 1)]);
    });

    test('a day not yet lived has not bled', () {
      final got = days([
        flow(DateTime(2026, 9, 30, 8), MenstrualFlow.light), // today: counts
        flow(DateTime(2026, 10, 1, 8), MenstrualFlow.light), // tomorrow: no
      ]);
      expect([for (final x in got) x.day], [d(2026, 9, 30)]);
    });

    test('uses the clock when no time is given', () {
      withClock(Clock.fixed(now), () {
        final got = CycleHistoryImport.daysFrom(
            [flow(DateTime(2026, 10, 5, 8), MenstrualFlow.light)]);
        expect(got, isEmpty);
      });
    });

    test('nothing at all is nothing', () {
      expect(days(const []), isEmpty);
    });
  });

  group('what an import would do', () {
    final read = [
      ImportedFlowDay(d(2026, 8, 1), FlowIntensity.medium),
      ImportedFlowDay(d(2026, 8, 2), FlowIntensity.heavy),
      ImportedFlowDay(d(2026, 8, 3), FlowIntensity.light),
      ImportedFlowDay(d(2026, 8, 29), FlowIntensity.medium),
      ImportedFlowDay(d(2026, 8, 30), FlowIntensity.medium),
    ];

    test('with nothing logged yet: every day, in two periods', () {
      final plan = CycleHistoryImport.plan(read, const {});
      expect(plan.toAdd, hasLength(5));
      expect(plan.alreadyLogged, 0);
      expect(plan.periods, 2, reason: 'a gap of weeks is a new period');
      expect(plan.isEmpty, isFalse);
    });

    test('a day the person already logged flow for is theirs and is left alone', () {
      final existing = {
        '2026-08-02': PeriodDay.empty(d(2026, 8, 2)).copyWith(flowIndex: 2),
      };
      final plan = CycleHistoryImport.plan(read, existing);
      expect(plan.toAdd.map((x) => x.id), isNot(contains('2026-08-02')));
      expect(plan.toAdd, hasLength(4));
      expect(plan.alreadyLogged, 1);
    });

    test('a day logged for something else (no flow) takes the flow and keeps the rest',
        () {
      final existing = {
        '2026-08-01': PeriodDay.empty(d(2026, 8, 1)).copyWith(note: 'cramps', mood: 2),
      };
      final plan = CycleHistoryImport.plan(read, existing);
      expect(plan.toAdd.map((x) => x.id), contains('2026-08-01'));

      final write = CycleHistoryImport.daysToWrite(plan, existing);
      final first = write.firstWhere((x) => x.id == '2026-08-01');
      expect(first.flowIndex, FlowIntensity.medium.flowIndex);
      expect(first.note, 'cramps');
      expect(first.mood, 2);
    });

    test('everything already logged: nothing to do', () {
      final existing = {
        for (final x in read)
          x.id: PeriodDay.empty(x.day).copyWith(flowIndex: x.flow.flowIndex)
      };
      final plan = CycleHistoryImport.plan(read, existing);
      expect(plan.isEmpty, isTrue);
      expect(plan.alreadyLogged, 5);
      expect(plan.periods, 0);
    });

    test('the days to write carry the imported level', () {
      final plan = CycleHistoryImport.plan(read, const {});
      final write = CycleHistoryImport.daysToWrite(plan, const {});
      expect([for (final w in write) w.flowIndex],
          [for (final x in read) x.flow.flowIndex]);
      expect([for (final w in write) w.id],
          ['2026-08-01', '2026-08-02', '2026-08-03', '2026-08-29', '2026-08-30']);
    });
  });
}
