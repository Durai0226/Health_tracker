import 'package:flutter_test/flutter_test.dart';
import 'package:tablet_remainder/features/steps/models/step_daily_data.dart';
import 'package:tablet_remainder/features/steps/models/step_manual_entry.dart';
import 'package:tablet_remainder/features/steps/services/step_service.dart';

/// Regression — manual step entries must never be discarded.
///
/// `StepService._recompute` used to compute the day's total as
/// `day.sensorSteps ?? manualTotal`, so on any day the sensor also reported,
/// every step the user typed was thrown away: the entry row was written, the UI
/// accepted it, and the number simply never moved. `StepSource.mixed` is
/// documented as "a sensor total the user has topped up with a manual
/// adjustment", so the correct merge is a SUM — manual entries are corrections
/// layered on top of the device reading (the phone-on-the-charger case).
StepManualEntry entry(int steps, {String id = 'e'}) => StepManualEntry(
      id: id,
      dailyDataId: '2026-01-01',
      time: DateTime(2026, 1, 1, 12),
      steps: steps,
    );

StepDailyData day({
  int? sensor,
  int manualStored = 0,
  List<int> entries = const [],
  int goal = 8000,
}) =>
    StepDailyData(
      id: '2026-01-01',
      date: DateTime(2026, 1, 1),
      goalSteps: goal,
      sensorSteps: sensor,
      manualSteps: manualStored,
      manualEntries: [
        for (var i = 0; i < entries.length; i++) entry(entries[i], id: 'e$i'),
      ],
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async => StepService.resetForTesting());

  group('manual + sensor merge', () {
    test('a manual entry is added to the sensor reading, not discarded', () {
      // A day already synced from the health store, then topped up by hand.
      final synced = day(sensor: 5000);
      final merged = StepService.recomputeForTesting(
        synced.copyWith(manualEntries: [entry(1200)]),
      );
      expect(merged.effectiveSteps, 6200);
      expect(merged.manualSteps, 1200);
    });

    test('the raw device reading stays recoverable after the merge', () {
      final merged = StepService.recomputeForTesting(
        day(sensor: 5000).copyWith(manualEntries: [entry(1200)]),
      );
      expect(merged.sensorSteps! - merged.manualSteps, 5000);
    });

    test('recomputing twice does not double-count the manual entry', () {
      final once = StepService.recomputeForTesting(
        day(sensor: 5000).copyWith(manualEntries: [entry(1200)]),
      );
      final twice = StepService.recomputeForTesting(once);
      expect(twice.effectiveSteps, 6200);
      expect(twice.manualSteps, 1200);
    });

    test('a later health sync keeps the manual top-up', () {
      final merged = StepService.recomputeForTesting(
        day(sensor: 5000).copyWith(manualEntries: [entry(1200)]),
      );
      // Next sync reports 8000 RAW steps for the same day.
      final resynced =
          StepService.recomputeForTesting(merged, rawSensorSteps: 8000);
      expect(resynced.effectiveSteps, 9200);
      expect(resynced.manualSteps, 1200);
    });

    test('several entries all count', () {
      final merged = StepService.recomputeForTesting(
        day(sensor: 4000).copyWith(manualEntries: [entry(500), entry(700, id: 'b')]),
      );
      expect(merged.effectiveSteps, 5200);
    });

    test('goal completion is judged on the merged total', () {
      // 5000 sensor + 1200 manual clears a 6000 goal; the sensor alone doesn't.
      final merged = StepService.recomputeForTesting(
        day(sensor: 5000, goal: 6000).copyWith(manualEntries: [entry(1200)]),
      );
      expect(merged.goalReached, isTrue);
    });
  });

  group('trims and manual-only days', () {
    test('a negative entry trims the sensor total', () {
      final merged = StepService.recomputeForTesting(
        day(sensor: 5000).copyWith(manualEntries: [entry(-800)]),
      );
      expect(merged.effectiveSteps, 4200);
    });

    test('a trim can never take the day below zero', () {
      final merged = StepService.recomputeForTesting(
        day(sensor: 500).copyWith(manualEntries: [entry(-900)]),
      );
      expect(merged.effectiveSteps, 0);
    });

    test('a manual-only day still totals its entries (no sensor)', () {
      final merged = StepService.recomputeForTesting(
        day(sensor: null).copyWith(manualEntries: [entry(3000)]),
      );
      expect(merged.effectiveSteps, 3000);
      expect(merged.sensorSteps, isNull);
    });

    test('a manual-only day floors a net-negative tally at zero', () {
      final merged = StepService.recomputeForTesting(
        day(sensor: null).copyWith(manualEntries: [entry(-500)]),
      );
      expect(merged.effectiveSteps, 0);
    });

    test('removing every entry drops the total back to the sensor reading', () {
      final merged = StepService.recomputeForTesting(
        day(sensor: 5000).copyWith(manualEntries: [entry(1200)]),
      );
      final cleared = StepService.recomputeForTesting(
        merged.copyWith(manualEntries: const []),
      );
      expect(cleared.effectiveSteps, 5000);
      expect(cleared.manualSteps, 0);
    });
  });
}
