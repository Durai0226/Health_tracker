import 'dart:math';
import '../models/cycle_log.dart';
import '../models/symptom_log.dart';

class PeriodPredictionService {
  
  // Calculate predicted ovulation date (typically 14 days before next period)
  static DateTime predictOvulation(DateTime periodStart, int cycleLength) {
    return periodStart.add(Duration(days: cycleLength - 14));
  }

  // Calculate fertile window (5 days before ovulation + ovulation day + 1 day after)
  static Map<String, DateTime> predictFertileWindow(DateTime periodStart, int cycleLength) {
    final ovulation = predictOvulation(periodStart, cycleLength);
    return {
      'start': ovulation.subtract(const Duration(days: 5)),
      'end': ovulation.add(const Duration(days: 1)),
      'ovulation': ovulation,
    };
  }

  // Calculate next period date
  static DateTime predictNextPeriod(DateTime lastPeriodStart, int cycleLength) {
    return lastPeriodStart.add(Duration(days: cycleLength));
  }

  // Calculate PMS window (typically 5-7 days before period)
  static Map<String, DateTime> predictPMSWindow(DateTime nextPeriodStart, {int daysBefore = 7}) {
    return {
      'start': nextPeriodStart.subtract(Duration(days: daysBefore)),
      'end': nextPeriodStart.subtract(const Duration(days: 1)),
    };
  }

  // Calculate average cycle length from history
  static int calculateAverageCycleLength(List<CycleLog> cycles) {
    if (cycles.isEmpty) return 28;
    if (cycles.length == 1) return cycles.first.cycleLength;

    final completedCycles = cycles.where((c) => c.isComplete).toList();
    if (completedCycles.isEmpty) return 28;

    final totalDays = completedCycles.fold<int>(
      0,
      (sum, cycle) => sum + cycle.actualCycleLength,
    );
    return (totalDays / completedCycles.length).round();
  }

  // Calculate average period duration from history
  static int calculateAveragePeriodDuration(List<CycleLog> cycles) {
    if (cycles.isEmpty) return 5;

    final completedCycles = cycles.where((c) => c.isComplete).toList();
    if (completedCycles.isEmpty) return 5;

    final totalDays = completedCycles.fold<int>(
      0,
      (sum, cycle) => sum + cycle.periodDuration,
    );
    return (totalDays / completedCycles.length).round();
  }

  // Detect cycle irregularities
  static CycleIrregularityResult detectIrregularities(List<CycleLog> cycles) {
    if (cycles.length < 3) {
      return CycleIrregularityResult(
        isIrregular: false,
        message: 'Need at least 3 cycles for irregularity detection',
        confidence: 0,
      );
    }

    final completedCycles = cycles.where((c) => c.isComplete).toList();
    if (completedCycles.length < 3) {
      return CycleIrregularityResult(
        isIrregular: false,
        message: 'Need at least 3 completed cycles',
        confidence: 0,
      );
    }

    final lengths = completedCycles.map((c) => c.actualCycleLength).toList();
    final avgLength = lengths.reduce((a, b) => a + b) / lengths.length;
    
    // Calculate standard deviation
    final variance = lengths.fold<double>(
      0,
      (sum, length) => sum + pow(length - avgLength, 2),
    ) / lengths.length;
    final stdDev = sqrt(variance);

    // Irregularity thresholds
    final List<String> issues = [];
    double irregularityScore = 0;

    // Check cycle length variation (>7 days variation is concerning)
    if (stdDev > 7) {
      issues.add('High cycle length variation (${stdDev.toStringAsFixed(1)} days)');
      irregularityScore += 30;
    } else if (stdDev > 4) {
      issues.add('Moderate cycle length variation');
      irregularityScore += 15;
    }

    // Check for very short or long cycles
    final shortCycles = lengths.where((l) => l < 21).length;
    final longCycles = lengths.where((l) => l > 35).length;

    if (shortCycles > 0) {
      issues.add('$shortCycles cycle(s) shorter than 21 days');
      irregularityScore += shortCycles * 20;
    }
    if (longCycles > 0) {
      issues.add('$longCycles cycle(s) longer than 35 days');
      irregularityScore += longCycles * 15;
    }

    // Check period duration variation
    final durations = completedCycles.map((c) => c.periodDuration).toList();
    final avgDuration = durations.reduce((a, b) => a + b) / durations.length;
    final durationVariance = durations.fold<double>(
      0,
      (sum, d) => sum + pow(d - avgDuration, 2),
    ) / durations.length;
    final durationStdDev = sqrt(durationVariance);

    if (durationStdDev > 2) {
      issues.add('Period duration varies significantly');
      irregularityScore += 10;
    }

    // Determine overall irregularity
    final isIrregular = irregularityScore >= 25;
    final confidence = min(100, irregularityScore.round());

    String message;
    if (irregularityScore < 15) {
      message = 'Your cycles appear regular';
    } else if (irregularityScore < 30) {
      message = 'Some minor variations detected';
    } else if (irregularityScore < 50) {
      message = 'Moderate irregularities detected - consider consulting a doctor';
    } else {
      message = 'Significant irregularities detected - please consult a healthcare provider';
    }

    return CycleIrregularityResult(
      isIrregular: isIrregular,
      message: message,
      confidence: confidence,
      issues: issues,
      averageCycleLength: avgLength,
      cycleLengthStdDev: stdDev,
    );
  }

  // Predict PMS symptoms based on historical data
  static PMSPrediction predictPMS(List<SymptomLog> symptomHistory, DateTime nextPeriod) {
    if (symptomHistory.isEmpty) {
      return PMSPrediction(
        predictedSymptoms: [],
        predictedMoods: [],
        confidence: 0,
      );
    }

    // Analyze symptoms that occurred in PMS window (5-7 days before period)
    final Map<SymptomType, int> symptomFrequency = {};
    final Map<MoodType, int> moodFrequency = {};

    for (final log in symptomHistory) {
      for (final symptom in log.symptoms) {
        symptomFrequency[symptom.type] = (symptomFrequency[symptom.type] ?? 0) + 1;
      }
      for (final mood in log.moods) {
        moodFrequency[mood] = (moodFrequency[mood] ?? 0) + 1;
      }
    }

    // Get most common symptoms (appearing in >30% of logs)
    final threshold = symptomHistory.length * 0.3;
    final predictedSymptoms = symptomFrequency.entries
        .where((e) => e.value >= threshold)
        .map((e) => e.key)
        .toList();

    final predictedMoods = moodFrequency.entries
        .where((e) => e.value >= threshold)
        .map((e) => e.key)
        .toList();

    final confidence = min(100, (symptomHistory.length * 10).round());

    return PMSPrediction(
      predictedSymptoms: predictedSymptoms,
      predictedMoods: predictedMoods,
      confidence: confidence,
      pmsWindowStart: nextPeriod.subtract(const Duration(days: 7)),
      pmsWindowEnd: nextPeriod.subtract(const Duration(days: 1)),
    );
  }

  // Predict mood patterns for the month
  static List<MoodPrediction> predictMoodPattern(DateTime periodStart, int cycleLength) {
    final predictions = <MoodPrediction>[];

    // Menstrual phase (days 1-5): Lower energy, need for rest
    for (int i = 0; i < 5; i++) {
      predictions.add(MoodPrediction(
        date: periodStart.add(Duration(days: i)),
        phase: CyclePhase.menstrual,
        predictedMoods: [MoodType.tired, MoodType.sensitive],
        energyLevel: EnergyLevel.low,
        tips: 'Rest and self-care day. Be gentle with yourself.',
      ));
    }

    // Follicular phase (days 6-13): Rising energy
    for (int i = 5; i < cycleLength ~/ 2 - 2; i++) {
      predictions.add(MoodPrediction(
        date: periodStart.add(Duration(days: i)),
        phase: CyclePhase.follicular,
        predictedMoods: [MoodType.energetic, MoodType.happy],
        energyLevel: EnergyLevel.high,
        tips: 'Great time for new projects and social activities!',
      ));
    }

    // Ovulation phase (days 14-16): Peak energy
    for (int i = cycleLength ~/ 2 - 2; i < cycleLength ~/ 2 + 2; i++) {
      predictions.add(MoodPrediction(
        date: periodStart.add(Duration(days: i)),
        phase: CyclePhase.ovulation,
        predictedMoods: [MoodType.energetic, MoodType.focused],
        energyLevel: EnergyLevel.veryHigh,
        tips: 'Peak creativity and communication. Best time for important conversations.',
      ));
    }

    // Luteal phase (days 17-23): Gradually decreasing energy
    for (int i = cycleLength ~/ 2 + 2; i < cycleLength - 5; i++) {
      predictions.add(MoodPrediction(
        date: periodStart.add(Duration(days: i)),
        phase: CyclePhase.luteal,
        predictedMoods: [MoodType.calm, MoodType.focused],
        energyLevel: EnergyLevel.medium,
        tips: 'Good for detail-oriented tasks and completing projects.',
      ));
    }

    // PMS phase (days 24-28): Energy dip
    for (int i = cycleLength - 5; i < cycleLength; i++) {
      predictions.add(MoodPrediction(
        date: periodStart.add(Duration(days: i)),
        phase: CyclePhase.pms,
        predictedMoods: [MoodType.moodSwings, MoodType.irritable],
        energyLevel: EnergyLevel.low,
        tips: 'Practice extra self-care. Magnesium-rich foods may help.',
      ));
    }

    return predictions;
  }

  // Get current cycle day
  static int getCurrentCycleDay(DateTime periodStart, DateTime today) {
    return today.difference(periodStart).inDays + 1;
  }

  // Get current phase
  static CyclePhase getCurrentPhase(DateTime periodStart, int cycleLength, int periodDuration, DateTime today) {
    final dayOfCycle = getCurrentCycleDay(periodStart, today);
    
    if (dayOfCycle <= periodDuration) {
      return CyclePhase.menstrual;
    } else if (dayOfCycle <= cycleLength ~/ 2 - 2) {
      return CyclePhase.follicular;
    } else if (dayOfCycle <= cycleLength ~/ 2 + 2) {
      return CyclePhase.ovulation;
    } else if (dayOfCycle <= cycleLength - 5) {
      return CyclePhase.luteal;
    } else {
      return CyclePhase.pms;
    }
  }

  // Check if date is in fertile window
  static bool isInFertileWindow(DateTime date, DateTime periodStart, int cycleLength) {
    final window = predictFertileWindow(periodStart, cycleLength);
    return date.isAfter(window['start']!.subtract(const Duration(days: 1))) &&
           date.isBefore(window['end']!.add(const Duration(days: 1)));
  }

  // Check if date is ovulation day
  static bool isOvulationDay(DateTime date, DateTime periodStart, int cycleLength) {
    final ovulation = predictOvulation(periodStart, cycleLength);
    return date.year == ovulation.year &&
           date.month == ovulation.month &&
           date.day == ovulation.day;
  }
}

class CycleIrregularityResult {
  final bool isIrregular;
  final String message;
  final int confidence;
  final List<String> issues;
  final double? averageCycleLength;
  final double? cycleLengthStdDev;

  CycleIrregularityResult({
    required this.isIrregular,
    required this.message,
    required this.confidence,
    this.issues = const [],
    this.averageCycleLength,
    this.cycleLengthStdDev,
  });
}

class PMSPrediction {
  final List<SymptomType> predictedSymptoms;
  final List<MoodType> predictedMoods;
  final int confidence;
  final DateTime? pmsWindowStart;
  final DateTime? pmsWindowEnd;

  PMSPrediction({
    required this.predictedSymptoms,
    required this.predictedMoods,
    required this.confidence,
    this.pmsWindowStart,
    this.pmsWindowEnd,
  });
}

class MoodPrediction {
  final DateTime date;
  final CyclePhase phase;
  final List<MoodType> predictedMoods;
  final EnergyLevel energyLevel;
  final String tips;

  MoodPrediction({
    required this.date,
    required this.phase,
    required this.predictedMoods,
    required this.energyLevel,
    required this.tips,
  });
}
