import 'package:flutter_test/flutter_test.dart';
import 'package:tablet_remainder/features/steps/models/health_profile.dart';
import 'package:tablet_remainder/features/steps/models/step_daily_data.dart';
import 'package:tablet_remainder/features/steps/models/step_source.dart';

/// QA — Steps pure logic (F5). Progress/goal math, distance/calorie estimates,
/// and the safe source-index mapping. (All well-guarded — no bugs found; these
/// lock the behavior in.)
StepDailyData day({int? sensor, int manual = 0, int goal = 8000, double dist = 0}) =>
    StepDailyData(
      id: 'd',
      date: DateTime(2026, 1, 1),
      goalSteps: goal,
      sensorSteps: sensor,
      manualSteps: manual,
      distanceMeters: dist,
    );

void main() {
  group('StepDailyData', () {
    test('effectiveSteps prefers the sensor count', () {
      expect(day(sensor: 5000, manual: 100).effectiveSteps, 5000);
    });
    test('effectiveSteps falls back to manual when no sensor', () {
      expect(day(sensor: null, manual: 3000).effectiveSteps, 3000);
    });
    test('progress = steps / goal', () {
      expect(day(sensor: 4000, goal: 8000).progress, 0.5);
    });
    test('progress guards divide-by-zero (goal 0)', () {
      expect(day(sensor: 4000, goal: 0).progress, 0.0);
    });
    test('progress can exceed 1 (over-achievement)', () {
      expect(day(sensor: 12000, goal: 8000).progress, greaterThan(1.0));
    });
    test('clampedProgress caps at 1.0', () {
      expect(day(sensor: 12000, goal: 8000).clampedProgress, 1.0);
    });
    test('distanceKm / distanceKmWhole convert metres', () {
      expect(day(dist: 3500).distanceKm, 3.5);
      expect(day(dist: 3500).distanceKmWhole, 3);
    });
  });

  group('HealthProfile estimates', () {
    test('strideMeters from explicit stride', () {
      expect(const HealthProfile(strideLengthCm: 75).strideMeters, 0.75);
    });
    test('strideMeters derived from height (~0.415)', () {
      expect(const HealthProfile(heightCm: 170).strideMeters, closeTo(0.7055, 0.001));
    });
    test('strideMeters default (~0.72) when unknown', () {
      expect(const HealthProfile().strideMeters, 0.72);
    });
    test('deriveDistanceMeters = steps × stride', () {
      expect(const HealthProfile(strideLengthCm: 75).deriveDistanceMeters(1000), 750.0);
    });
    test('deriveDistanceMeters is 0 for non-positive steps', () {
      expect(const HealthProfile().deriveDistanceMeters(0), 0);
    });
    test('deriveActiveCalories scales with steps × weight', () {
      expect(const HealthProfile(weightKg: 70).deriveActiveCalories(8000), 280.0);
    });
    test('deriveActiveCalories is 0 for non-positive steps', () {
      expect(const HealthProfile().deriveActiveCalories(-5), 0);
    });
  });

  group('StepSourceX.fromIndex', () {
    test('valid index maps to a real source', () => expect(StepSourceX.fromIndex(0), StepSource.values[0]));
    test('null → manual', () => expect(StepSourceX.fromIndex(null), StepSource.manual));
    test('out-of-range → manual', () => expect(StepSourceX.fromIndex(99), StepSource.manual));
  });
}
