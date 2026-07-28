import 'package:flutter_test/flutter_test.dart';
import 'package:tablet_remainder/features/period/models/cycle_phase.dart';
import 'package:tablet_remainder/features/period/models/cycle_prediction.dart';
import 'package:tablet_remainder/features/period/services/cycle_predictor.dart';

/// QA — cycle prediction (F6). Pure: builds a FlowDay history and asserts the
/// prediction/phase math + onboarding/pregnancy edge cases. No DB.
final _base = DateTime(2026, 1, 1);

/// Period history: a [periodLen]-day bleed starting at each offset (days from base).
List<FlowDay> history(List<int> startOffsets, {int periodLen = 5}) {
  final days = <FlowDay>[];
  for (final off in startOffsets) {
    for (var d = 0; d < periodLen; d++) {
      days.add(FlowDay(_base.add(Duration(days: off + d)), 2));
    }
  }
  return days;
}

void main() {
  group('phaseOn — pure phase math', () {
    CyclePhase p(int dayOffset, {int cycleLength = 28}) => CyclePredictor.phaseOn(
          _base.add(Duration(days: dayOffset)),
          lastStart: _base,
          cycleLength: cycleLength,
          periodLength: 5,
          lutealLength: 14,
        );
    test('day 0 → menstrual', () => expect(p(0), CyclePhase.menstrual));
    test('day 3 → menstrual', () => expect(p(3), CyclePhase.menstrual));
    test('day 8 → follicular', () => expect(p(8), CyclePhase.follicular));
    test('ovulation index (day 14) → ovulation', () => expect(p(14), CyclePhase.ovulation));
    test('day 20 → luteal', () => expect(p(20), CyclePhase.luteal));
    test('cycleLength 0 is guarded (falls back to 28, no crash)', () {
      expect(p(3, cycleLength: 0), CyclePhase.menstrual);
    });
  });

  group('predict — regular 28-day history', () {
    late CyclePrediction pred;
    setUp(() {
      // 4 period starts 28 days apart → 3 completed cycles + 1 open.
      pred = CyclePredictor.predict(
        days: history([0, 28, 56, 84]),
        on: _base.add(const Duration(days: 87)), // day 4 of the current cycle
      );
    });
    test('learns a ~28-day cycle', () => expect(pred.cycleLengthEstimate, 28));
    test('counts 3 completed cycles', () => expect(pred.completedCycles, 3));
    test('predicts next start at lastStart + 28', () {
      expect(pred.predictedStart, _base.add(const Duration(days: 112)));
    });
    test('days until next period', () => expect(pred.daysUntilNextPeriod, 25));
    test('today (day 4) is menstrual', () => expect(pred.phaseToday, CyclePhase.menstrual));
    test('state is ready (regular, not late)', () => expect(pred.state, CycleState.ready));
  });

  group('predict — edge cases', () {
    test('no data → onboarding', () {
      final pred = CyclePredictor.predict(days: const []);
      expect(pred.state, CycleState.onboarding);
    });
    test('fewer than 3 cycles → learning', () {
      final pred = CyclePredictor.predict(
        days: history([0, 28]), // 1 completed cycle
        on: _base.add(const Duration(days: 30)),
      );
      expect(pred.state, CycleState.learning);
    });
    test('pregnancy mode → pregnancy state with gestational days', () {
      final pred = CyclePredictor.predict(
        days: const [],
        pregnancyMode: true,
        pregnancyStartDate: _base,
        on: _base.add(const Duration(days: 30)),
      );
      expect(pred.state, CycleState.pregnancy);
      expect(pred.gestationalDays, 30);
    });
  });
}
