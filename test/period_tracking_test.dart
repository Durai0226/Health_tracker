import 'package:flutter_test/flutter_test.dart';
import 'package:tablet_remainder/features/period_tracking/models/cycle_log.dart';
import 'package:tablet_remainder/features/period_tracking/models/symptom_log.dart';
import 'package:tablet_remainder/features/period_tracking/services/period_prediction_service.dart';

void main() {
  group('Period Prediction Service Tests', () {
    test('predictOvulation returns correct date (14 days before next period)', () {
      final periodStart = DateTime(2025, 2, 1);
      const cycleLength = 28;
      
      final ovulation = PeriodPredictionService.predictOvulation(periodStart, cycleLength);
      
      // Ovulation should be on day 14 (28 - 14 = 14 days after period start)
      expect(ovulation, DateTime(2025, 2, 15));
    });

    test('predictFertileWindow returns correct window', () {
      final periodStart = DateTime(2025, 2, 1);
      const cycleLength = 28;
      
      final window = PeriodPredictionService.predictFertileWindow(periodStart, cycleLength);
      
      expect(window['ovulation'], DateTime(2025, 2, 15));
      expect(window['start'], DateTime(2025, 2, 10)); // 5 days before ovulation
      expect(window['end'], DateTime(2025, 2, 16)); // 1 day after ovulation
    });

    test('predictNextPeriod returns correct date', () {
      final lastPeriod = DateTime(2025, 2, 1);
      const cycleLength = 28;
      
      final nextPeriod = PeriodPredictionService.predictNextPeriod(lastPeriod, cycleLength);
      
      expect(nextPeriod, DateTime(2025, 3, 1));
    });

    test('predictPMSWindow returns correct window', () {
      final nextPeriod = DateTime(2025, 3, 1);
      
      final pmsWindow = PeriodPredictionService.predictPMSWindow(nextPeriod, daysBefore: 7);
      
      expect(pmsWindow['start'], DateTime(2025, 2, 22));
      expect(pmsWindow['end'], DateTime(2025, 2, 28));
    });

    test('calculateAverageCycleLength with multiple cycles', () {
      final cycles = [
        CycleLog(id: '1', startDate: DateTime(2025, 1, 1), cycleLength: 28, isComplete: true),
        CycleLog(id: '2', startDate: DateTime(2025, 1, 29), cycleLength: 30, isComplete: true),
        CycleLog(id: '3', startDate: DateTime(2025, 2, 28), cycleLength: 26, isComplete: true),
      ];
      
      final avg = PeriodPredictionService.calculateAverageCycleLength(cycles);
      
      expect(avg, 28); // (28 + 30 + 26) / 3 = 28
    });

    test('getCurrentCycleDay returns correct day', () {
      final periodStart = DateTime(2025, 2, 1);
      final today = DateTime(2025, 2, 10);
      
      final cycleDay = PeriodPredictionService.getCurrentCycleDay(periodStart, today);
      
      expect(cycleDay, 10);
    });

    test('getCurrentPhase returns menstrual during period', () {
      final periodStart = DateTime(2025, 2, 1);
      final today = DateTime(2025, 2, 3);
      
      final phase = PeriodPredictionService.getCurrentPhase(periodStart, 28, 5, today);
      
      expect(phase, CyclePhase.menstrual);
    });

    test('getCurrentPhase returns follicular after period', () {
      final periodStart = DateTime(2025, 2, 1);
      final today = DateTime(2025, 2, 8);
      
      final phase = PeriodPredictionService.getCurrentPhase(periodStart, 28, 5, today);
      
      expect(phase, CyclePhase.follicular);
    });

    test('getCurrentPhase returns ovulation around day 14', () {
      final periodStart = DateTime(2025, 2, 1);
      final today = DateTime(2025, 2, 14);
      
      final phase = PeriodPredictionService.getCurrentPhase(periodStart, 28, 5, today);
      
      expect(phase, CyclePhase.ovulation);
    });

    test('getCurrentPhase returns luteal after ovulation', () {
      final periodStart = DateTime(2025, 2, 1);
      final today = DateTime(2025, 2, 20);
      
      final phase = PeriodPredictionService.getCurrentPhase(periodStart, 28, 5, today);
      
      expect(phase, CyclePhase.luteal);
    });

    test('getCurrentPhase returns PMS before next period', () {
      final periodStart = DateTime(2025, 2, 1);
      final today = DateTime(2025, 2, 26);
      
      final phase = PeriodPredictionService.getCurrentPhase(periodStart, 28, 5, today);
      
      expect(phase, CyclePhase.pms);
    });

    test('isInFertileWindow returns true during fertile window', () {
      final periodStart = DateTime(2025, 2, 1);
      final testDate = DateTime(2025, 2, 12); // Within fertile window
      
      final isInWindow = PeriodPredictionService.isInFertileWindow(testDate, periodStart, 28);
      
      expect(isInWindow, true);
    });

    test('isInFertileWindow returns false outside fertile window', () {
      final periodStart = DateTime(2025, 2, 1);
      final testDate = DateTime(2025, 2, 5); // During period, not fertile
      
      final isInWindow = PeriodPredictionService.isInFertileWindow(testDate, periodStart, 28);
      
      expect(isInWindow, false);
    });

    test('isOvulationDay returns true on ovulation day', () {
      final periodStart = DateTime(2025, 2, 1);
      final testDate = DateTime(2025, 2, 15); // Ovulation day for 28-day cycle
      
      final isOvulation = PeriodPredictionService.isOvulationDay(testDate, periodStart, 28);
      
      expect(isOvulation, true);
    });

    test('detectIrregularities returns regular for consistent cycles', () {
      final cycles = [
        CycleLog(id: '1', startDate: DateTime(2025, 1, 1), cycleLength: 28, isComplete: true),
        CycleLog(id: '2', startDate: DateTime(2025, 1, 29), cycleLength: 28, isComplete: true),
        CycleLog(id: '3', startDate: DateTime(2025, 2, 26), cycleLength: 28, isComplete: true),
      ];
      
      final result = PeriodPredictionService.detectIrregularities(cycles);
      
      expect(result.isIrregular, false);
      expect(result.message, 'Your cycles appear regular');
    });

    test('detectIrregularities detects irregular cycles', () {
      final cycles = [
        CycleLog(id: '1', startDate: DateTime(2025, 1, 1), cycleLength: 20, isComplete: true),
        CycleLog(id: '2', startDate: DateTime(2025, 1, 21), cycleLength: 40, isComplete: true),
        CycleLog(id: '3', startDate: DateTime(2025, 3, 2), cycleLength: 25, isComplete: true),
      ];
      
      final result = PeriodPredictionService.detectIrregularities(cycles);
      
      expect(result.isIrregular, true);
      expect(result.issues.isNotEmpty, true);
    });
  });

  group('Cycle Log Model Tests', () {
    test('getPhaseForDate returns correct phase', () {
      final cycle = CycleLog(
        id: 'test',
        startDate: DateTime(2025, 2, 1),
        cycleLength: 28,
        periodDuration: 5,
      );
      
      expect(cycle.getPhaseForDate(DateTime(2025, 2, 3)), CyclePhase.menstrual);
      expect(cycle.getPhaseForDate(DateTime(2025, 2, 8)), CyclePhase.follicular);
      expect(cycle.getPhaseForDate(DateTime(2025, 2, 14)), CyclePhase.ovulation);
      expect(cycle.getPhaseForDate(DateTime(2025, 2, 20)), CyclePhase.luteal);
      expect(cycle.getPhaseForDate(DateTime(2025, 2, 26)), CyclePhase.pms);
    });

    test('actualCycleLength returns correct value', () {
      final completedCycle = CycleLog(
        id: 'test',
        startDate: DateTime(2025, 2, 1),
        endDate: DateTime(2025, 3, 1),
        cycleLength: 28,
        isComplete: true,
      );
      
      expect(completedCycle.actualCycleLength, 28);
    });

    test('copyWith creates new instance with updated values', () {
      final original = CycleLog(
        id: 'test',
        startDate: DateTime(2025, 2, 1),
        cycleLength: 28,
        periodDuration: 5,
      );
      
      final updated = original.copyWith(cycleLength: 30, isComplete: true);
      
      expect(updated.cycleLength, 30);
      expect(updated.isComplete, true);
      expect(updated.periodDuration, 5); // Unchanged
    });

    test('toJson and fromJson work correctly', () {
      final cycle = CycleLog(
        id: 'test',
        startDate: DateTime(2025, 2, 1),
        cycleLength: 28,
        periodDuration: 5,
        notes: 'Test notes',
      );
      
      final json = cycle.toJson();
      final restored = CycleLog.fromJson(json);
      
      expect(restored.id, cycle.id);
      expect(restored.startDate, cycle.startDate);
      expect(restored.cycleLength, cycle.cycleLength);
      expect(restored.notes, cycle.notes);
    });
  });

  group('Symptom Log Model Tests', () {
    test('SymptomLog creation with symptoms and moods', () {
      final log = SymptomLog(
        id: 'test',
        date: DateTime(2025, 2, 10),
        symptoms: [
          SymptomEntry(type: SymptomType.cramps, severity: SymptomSeverity.moderate),
          SymptomEntry(type: SymptomType.headache, severity: SymptomSeverity.mild),
        ],
        moods: [MoodType.tired, MoodType.irritable],
        energyLevel: EnergyLevel.low,
        sleepQuality: SleepQuality.fair,
        sleepHours: 6.5,
        stressLevel: 7,
      );
      
      expect(log.symptoms.length, 2);
      expect(log.moods.length, 2);
      expect(log.energyLevel, EnergyLevel.low);
      expect(log.stressLevel, 7);
    });

    test('SymptomLog toJson and fromJson work correctly', () {
      final log = SymptomLog(
        id: 'test',
        date: DateTime(2025, 2, 10),
        symptoms: [
          SymptomEntry(type: SymptomType.cramps, severity: SymptomSeverity.severe),
        ],
        moods: [MoodType.anxious],
        energyLevel: EnergyLevel.veryLow,
      );
      
      final json = log.toJson();
      final restored = SymptomLog.fromJson(json);
      
      expect(restored.id, log.id);
      expect(restored.symptoms.length, 1);
      expect(restored.symptoms.first.type, SymptomType.cramps);
      expect(restored.symptoms.first.severity, SymptomSeverity.severe);
      expect(restored.moods.first, MoodType.anxious);
    });

    test('SymptomLog copyWith creates updated instance', () {
      final original = SymptomLog(
        id: 'test',
        date: DateTime(2025, 2, 10),
        stressLevel: 5,
      );
      
      final updated = original.copyWith(stressLevel: 8, hadIntimacy: true);
      
      expect(updated.stressLevel, 8);
      expect(updated.hadIntimacy, true);
      expect(updated.date, original.date);
    });
  });

  group('Flow Intensity Tests', () {
    test('FlowIntensity enum has correct values', () {
      expect(FlowIntensity.values.length, 5);
      expect(FlowIntensity.spotting.index, 0);
      expect(FlowIntensity.light.index, 1);
      expect(FlowIntensity.medium.index, 2);
      expect(FlowIntensity.heavy.index, 3);
      expect(FlowIntensity.veryHeavy.index, 4);
    });
  });

  group('Symptom Type Tests', () {
    test('SymptomType enum has all expected symptoms', () {
      expect(SymptomType.values.contains(SymptomType.cramps), true);
      expect(SymptomType.values.contains(SymptomType.headache), true);
      expect(SymptomType.values.contains(SymptomType.backPain), true);
      expect(SymptomType.values.contains(SymptomType.bloating), true);
      expect(SymptomType.values.contains(SymptomType.fatigue), true);
      expect(SymptomType.values.contains(SymptomType.cravings), true);
    });
  });

  group('Mood Type Tests', () {
    test('MoodType enum has all expected moods', () {
      expect(MoodType.values.contains(MoodType.happy), true);
      expect(MoodType.values.contains(MoodType.calm), true);
      expect(MoodType.values.contains(MoodType.anxious), true);
      expect(MoodType.values.contains(MoodType.irritable), true);
      expect(MoodType.values.contains(MoodType.moodSwings), true);
    });
  });
}
