import 'dart:math' as math;

import '../models/cycle_phase.dart';
import '../models/cycle_prediction.dart';

/// PURE Dart — NO Flutter imports. Fully unit-testable with `dart test`.
///
/// Derives menstrual cycles from logged flow days, computes robust statistics
/// (median / average / std with MAD-based outlier rejection over the most recent
/// ≤12 cycles), and predicts the next period + fertile window with an honest
/// confidence + lifecycle state.

/// Minimal pure input: one logged day's flow. The service maps [PeriodDay] →
/// [FlowDay] so this file never depends on Drift / Flutter.
class FlowDay {
  final DateTime date;
  final int flowIndex;
  const FlowDay(this.date, this.flowIndex);
}

/// One derived cycle span (period start → day before next period start). The
/// most recent cycle is "open": [end] / [cycleLengthDays] are null.
class DerivedCycle {
  final DateTime start;
  final DateTime? end;
  final int? cycleLengthDays;
  final int periodLengthDays;

  const DerivedCycle({
    required this.start,
    this.end,
    this.cycleLengthDays,
    required this.periodLengthDays,
  });

  bool get isOpen => cycleLengthDays == null;
}

class CyclePredictor {
  const CyclePredictor._();

  static const int _lookbackCycles = 12;

  // ---- Public API --------------------------------------------------------

  /// Group flow days into cycles. Consecutive bleeding days form one period run,
  /// tolerating a single skipped day (gap ≤ 2 days). A cycle runs from one
  /// run's start to the day before the next run's start.
  static List<DerivedCycle> deriveCycles(List<FlowDay> days) {
    final flow = <DateTime>[];
    for (final d in days) {
      if (d.flowIndex > 0) flow.add(_dayOnly(d.date));
    }
    flow.sort();
    if (flow.isEmpty) return const [];

    // Build period runs, tolerating a 1-day gap.
    final runs = <List<DateTime>>[];
    for (final d in flow) {
      if (runs.isEmpty) {
        runs.add([d]);
        continue;
      }
      final last = runs.last.last;
      final gap = d.difference(last).inDays;
      if (gap == 0) continue; // duplicate day
      if (gap <= 2) {
        runs.last.add(d);
      } else {
        runs.add([d]);
      }
    }

    final cycles = <DerivedCycle>[];
    for (var i = 0; i < runs.length; i++) {
      final start = runs[i].first;
      final periodEnd = runs[i].last;
      final periodLen = periodEnd.difference(start).inDays + 1;
      if (i < runs.length - 1) {
        final nextStart = runs[i + 1].first;
        final cycleLen = nextStart.difference(start).inDays;
        cycles.add(DerivedCycle(
          start: start,
          end: nextStart.subtract(const Duration(days: 1)),
          cycleLengthDays: cycleLen,
          periodLengthDays: periodLen,
        ));
      } else {
        cycles.add(DerivedCycle(start: start, periodLengthDays: periodLen));
      }
    }
    return cycles;
  }

  /// Robust stats over the most recent ≤12 cycles, with MAD outlier rejection.
  static CycleStats computeStats(List<DerivedCycle> cycles) {
    if (cycles.isEmpty) return CycleStats.empty;

    // Period lengths: use the most recent cycles (open cycle included).
    final recentAll = cycles.length <= _lookbackCycles
        ? cycles
        : cycles.sublist(cycles.length - _lookbackCycles);
    final periodLens = recentAll.map((c) => c.periodLengthDays).toList();

    final completed = cycles.where((c) => c.cycleLengthDays != null).toList();
    final recentCompleted = completed.length <= _lookbackCycles
        ? completed
        : completed.sublist(completed.length - _lookbackCycles);

    if (recentCompleted.isEmpty) {
      return CycleStats(
        totalCyclesDetected: cycles.length,
        avgPeriodLength: periodLens.isEmpty ? null : _mean(periodLens),
        medianPeriodLength: periodLens.isEmpty ? null : _medianInt(periodLens),
      );
    }

    final rawCycleLens = recentCompleted.map((c) => c.cycleLengthDays!).toList();
    final kept = _rejectOutliers(rawCycleLens);
    final std = _std(kept);
    final isIrregular = kept.length >= 3 && std > 5.0;

    return CycleStats(
      cycleCount: kept.length,
      totalCyclesDetected: cycles.length,
      avgCycleLength: _mean(kept),
      medianCycleLength: _medianInt(kept),
      cycleLengthStd: std,
      shortestCycle: kept.reduce(math.min),
      longestCycle: kept.reduce(math.max),
      avgPeriodLength: periodLens.isEmpty ? null : _mean(periodLens),
      medianPeriodLength: periodLens.isEmpty ? null : _medianInt(periodLens),
      isIrregular: isIrregular,
    );
  }

  /// The full prediction for a query date [on] (defaults to now).
  static CyclePrediction predict({
    required List<FlowDay> days,
    DateTime? on,
    int typicalCycleLength = 28,
    int typicalPeriodLength = 5,
    int lutealPhaseLength = 14,
    bool pregnancyMode = false,
    DateTime? pregnancyStartDate,
  }) {
    final today = _dayOnly(on ?? DateTime.now());

    if (pregnancyMode) {
      final start =
          pregnancyStartDate == null ? null : _dayOnly(pregnancyStartDate);
      final gestDays = start == null ? null : today.difference(start).inDays;
      return CyclePrediction(
        state: CycleState.pregnancy,
        confidence: PredictionConfidence.low,
        gestationalDays: (gestDays == null || gestDays < 0) ? null : gestDays,
        lastPeriodStart: start,
      );
    }

    final cycles = deriveCycles(days);
    if (cycles.isEmpty) return CyclePrediction.onboarding;

    final stats = computeStats(cycles);
    final lastStart = cycles.last.start;
    final completedCount = cycles.where((c) => c.cycleLengthDays != null).length;

    final learnedCycle =
        _learnedCycleLength(stats, typicalCycleLength, completedCount);
    final periodLen = stats.medianPeriodLength ?? typicalPeriodLength;

    final predictedStart = lastStart.add(Duration(days: learnedCycle));
    final half = _windowHalfWidth(stats.cycleLengthStd);
    final windowStart = predictedStart.subtract(Duration(days: half));
    final windowEnd = predictedStart.add(Duration(days: half));
    final ovulation = predictedStart.subtract(Duration(days: lutealPhaseLength));
    final fertileStart = ovulation.subtract(const Duration(days: 5));
    final fertileEnd = ovulation.add(const Duration(days: 1));

    final dayOfCycle = today.difference(lastStart).inDays + 1;
    final daysUntil = predictedStart.difference(today).inDays;
    final phase = phaseOn(
      today,
      lastStart: lastStart,
      cycleLength: learnedCycle,
      periodLength: periodLen,
      lutealLength: lutealPhaseLength,
    );

    final confidence =
        _confidence(completedCount, stats.cycleLengthStd, stats.isIrregular);

    final CycleState state;
    if (completedCount < 3) {
      state = CycleState.learning;
    } else if (stats.isIrregular) {
      state = CycleState.irregular;
    } else if (today.isAfter(windowEnd)) {
      state = CycleState.late;
    } else {
      state = CycleState.ready;
    }

    return CyclePrediction(
      predictedStart: predictedStart,
      windowStart: windowStart,
      windowEnd: windowEnd,
      ovulationDay: ovulation,
      fertileStart: fertileStart,
      fertileEnd: fertileEnd,
      dayOfCycle: dayOfCycle < 1 ? 1 : dayOfCycle,
      cycleLengthEstimate: learnedCycle,
      phaseToday: phase,
      confidence: confidence,
      state: state,
      daysUntilNextPeriod: daysUntil,
      completedCycles: completedCount,
      lastPeriodStart: lastStart,
    );
  }

  /// The phase of [date] relative to a known cycle anchor.
  static CyclePhase phaseOn(
    DateTime date, {
    required DateTime lastStart,
    required int cycleLength,
    required int periodLength,
    required int lutealLength,
  }) {
    final len = cycleLength <= 0 ? 28 : cycleLength;
    final offset = _dayOnly(date).difference(_dayOnly(lastStart)).inDays;
    var cd = offset % len;
    if (cd < 0) cd += len;

    final ovulationIndex = (len - lutealLength).clamp(0, len - 1);
    if (cd < periodLength) return CyclePhase.menstrual;
    if ((cd - ovulationIndex).abs() <= 1) return CyclePhase.ovulation;
    if (cd < ovulationIndex) return CyclePhase.follicular;
    return CyclePhase.luteal;
  }

  /// Phase for an arbitrary [date], resolving the cycle that actually contains
  /// it (falls back to modulo-from-last-start for out-of-range dates). Null when
  /// there is no flow data at all.
  static CyclePhase? phaseForDate(
    DateTime date, {
    required List<FlowDay> days,
    int typicalCycleLength = 28,
    int typicalPeriodLength = 5,
    int lutealPhaseLength = 14,
  }) {
    final cycles = deriveCycles(days);
    if (cycles.isEmpty) return null;

    final d0 = _dayOnly(date);
    final stats = computeStats(cycles);
    final completedCount = cycles.where((c) => c.cycleLengthDays != null).length;
    final fallbackLen =
        _learnedCycleLength(stats, typicalCycleLength, completedCount);

    DerivedCycle? containing;
    for (final c in cycles) {
      final startsBefore = !c.start.isAfter(d0);
      final endsAfter = c.end == null || !d0.isAfter(c.end!);
      if (startsBefore && endsAfter) {
        containing = c;
        break;
      }
    }

    final anchor = containing ?? cycles.last;
    final len = anchor.cycleLengthDays ?? fallbackLen;
    return phaseOn(
      d0,
      lastStart: anchor.start,
      cycleLength: len,
      periodLength: anchor.periodLengthDays,
      lutealLength: lutealPhaseLength,
    );
  }

  // ---- Internals ---------------------------------------------------------

  static int _learnedCycleLength(
      CycleStats stats, int typical, int completedCount) {
    final median = stats.medianCycleLength;
    if (median == null || completedCount == 0) return typical;
    if (completedCount >= 3) return median;
    // Blend learned median with the typical default while data is thin.
    final w = completedCount / 3.0;
    return (w * median + (1 - w) * typical).round();
  }

  static int _windowHalfWidth(double std) {
    final s = std < 1.5 ? 1.5 : std;
    return (1.15 * s).round().clamp(1, 7);
  }

  static PredictionConfidence _confidence(
      int completedCount, double std, bool irregular) {
    if (completedCount < 3 || irregular) return PredictionConfidence.low;
    if (completedCount >= 6 && std <= 2.5) return PredictionConfidence.high;
    if (std <= 4.0) return PredictionConfidence.medium;
    return PredictionConfidence.low;
  }

  /// Modified z-score (0.6745·|x−median|/MAD) rejection at 3.5. Returns the
  /// input unchanged when too few points or MAD is degenerate.
  static List<int> _rejectOutliers(List<int> xs) {
    if (xs.length < 4) return xs;
    final med = _medianD(xs.map((e) => e.toDouble()).toList());
    final absDev = xs.map((e) => (e - med).abs()).toList();
    final mad = _medianD(absDev);
    if (mad == 0) return xs;
    const threshold = 3.5;
    final kept = <int>[];
    for (final e in xs) {
      final mz = 0.6745 * (e - med).abs() / mad;
      if (mz <= threshold) kept.add(e);
    }
    return kept.isEmpty ? xs : kept;
  }

  static DateTime _dayOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  static double _mean(List<int> xs) =>
      xs.isEmpty ? 0 : xs.reduce((a, b) => a + b) / xs.length;

  static int _medianInt(List<int> xs) => _medianD(
        xs.map((e) => e.toDouble()).toList(),
      ).round();

  static double _medianD(List<double> input) {
    if (input.isEmpty) return 0;
    final xs = [...input]..sort();
    final mid = xs.length ~/ 2;
    if (xs.length.isOdd) return xs[mid];
    return (xs[mid - 1] + xs[mid]) / 2.0;
  }

  static double _std(List<int> xs) {
    if (xs.length < 2) return 0;
    final m = _mean(xs);
    var sumSq = 0.0;
    for (final x in xs) {
      final d = x - m;
      sumSq += d * d;
    }
    return math.sqrt(sumSq / (xs.length - 1));
  }
}
