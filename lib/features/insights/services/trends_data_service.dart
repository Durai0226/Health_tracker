import 'dart:math' as math;

import '../../medication/services/medicine_storage_service.dart';
import '../../medication/services/vitals_storage_service.dart';
import '../../water/services/water_service.dart';
import '../../steps/services/step_service.dart';
import '../../sleep/services/sleep_service.dart';
import '../../focus/services/focus_service.dart';
import '../../period/services/period_service.dart';
import '../../period/models/cycle_phase.dart';

/// ADA Time-in-Range thresholds (mg/dL): <70 low, 70–180 in-range, >180 high.
const int kGlucoseLowThreshold = 70;
const int kGlucoseHighThreshold = 180;

/// A sensible default daily focus target (minutes) — the app stores no explicit
/// per-day focus goal, so this is the honest, documented fallback.
const double kFocusDailyGoalMinutes = 60;

/// Fallback nightly sleep target (minutes) when the schedule has none.
const int kSleepDefaultTargetMinutes = 480;

/// The selectable look-back window for the unified Trends dashboard.
enum TrendRange { d7, d14, d30 }

extension TrendRangeX on TrendRange {
  /// Number of calendar days the range covers (today included).
  int get days {
    switch (this) {
      case TrendRange.d7:
        return 7;
      case TrendRange.d14:
        return 14;
      case TrendRange.d30:
        return 30;
    }
  }

  /// Label for the range selector segment.
  String get label {
    switch (this) {
      case TrendRange.d7:
        return '7 days';
      case TrendRange.d14:
        return '14 days';
      case TrendRange.d30:
        return '30 days';
    }
  }
}

/// One calendar day's datum in a [TrendSeries].
///
/// [value] is `null` when nothing was logged that day — a genuine gap that the
/// charts render as empty space, never a misleading zero bar. [value2] carries
/// the single legitimate second series (blood-pressure diastolic).
class TrendPoint {
  final DateTime date;
  final double? value;
  final double? value2;
  const TrendPoint(this.date, this.value, [this.value2]);

  bool get hasData => value != null;
}

/// A single feature's daily series across the selected range, chronological
/// (oldest → newest, exactly one entry per calendar day). Derived aggregates
/// ignore gap days so an empty day never drags an average toward zero.
class TrendSeries {
  final List<TrendPoint> points;

  /// Optional reference line (e.g. the water / steps goal). Null = no line.
  final double? goal;

  const TrendSeries(this.points, {this.goal});

  Iterable<double> get _primary =>
      points.where((p) => p.value != null).map((p) => p.value!);

  bool get hasData => points.any((p) => p.value != null);

  int get loggedDays => points.where((p) => p.value != null).length;

  double? get average {
    final v = _primary.toList();
    if (v.isEmpty) return null;
    return v.reduce((a, b) => a + b) / v.length;
  }

  double? get total {
    final v = _primary.toList();
    if (v.isEmpty) return null;
    return v.reduce((a, b) => a + b);
  }

  /// Average of (daily value ÷ [goal]) across logged days, clamped 0..1 — the
  /// fill for a goal-progress ring. Null when there is no goal or no logged
  /// data, so the caller can fall back to a plain bar chart gracefully.
  double? get goalProgress {
    if (goal == null || goal! <= 0) return null;
    final v = _primary.toList();
    if (v.isEmpty) return null;
    final ratio = v.map((x) => x / goal!).reduce((a, b) => a + b) / v.length;
    return ratio.clamp(0.0, 1.0);
  }

  /// Uncapped average of (daily value ÷ [goal]) as a percentage — for the ring's
  /// CENTRE label, so beating a goal reads honestly (e.g. "128%") while the ring
  /// FILL stays clamped via [goalProgress]. Null when no goal or no logged data.
  double? get goalPercent {
    if (goal == null || goal! <= 0) return null;
    final v = _primary.toList();
    if (v.isEmpty) return null;
    return v.map((x) => x / goal!).reduce((a, b) => a + b) / v.length * 100;
  }

  /// The most recent non-null value in the range.
  double? get latest {
    for (final p in points.reversed) {
      if (p.value != null) return p.value;
    }
    return null;
  }

  /// The most recent non-null [TrendPoint.value2] (BP diastolic).
  double? get latest2 {
    for (final p in points.reversed) {
      if (p.value2 != null) return p.value2;
    }
    return null;
  }

  /// Largest value across both series — used to size the chart's y-axis.
  double get maxValue {
    var m = 0.0;
    for (final p in points) {
      if (p.value != null) m = math.max(m, p.value!);
      if (p.value2 != null) m = math.max(m, p.value2!);
    }
    return m;
  }

  /// Coarse direction of the series: compares the average of the most recent
  /// half of logged days against the older half. Returns `+1` rising, `-1`
  /// falling, `0` flat / not enough data. Callers decide whether "up" is good.
  int get direction {
    final logged = points.where((p) => p.value != null).toList();
    if (logged.length < 4) return 0;
    final mid = logged.length ~/ 2;
    final older = logged.sublist(0, mid);
    final recent = logged.sublist(mid);
    double avg(List<TrendPoint> l) =>
        l.map((p) => p.value!).reduce((a, b) => a + b) / l.length;
    final delta = avg(recent) - avg(older);
    final scale = math.max(avg(older).abs(), 1);
    if (delta.abs() / scale < 0.05) return 0; // < 5% change reads as flat
    return delta > 0 ? 1 : -1;
  }
}

/// Glucose Time-in-Range breakdown over the whole selected window (every
/// reading, not per-day averages) — the ADA CGM standard: how much time was
/// spent low / in-range / high. Percentages sum to 100 when [hasData].
class GlucoseTir {
  final int low; // readings < 70 mg/dL
  final int inRange; // 70–180 mg/dL
  final int high; // > 180 mg/dL

  const GlucoseTir({this.low = 0, this.inRange = 0, this.high = 0});

  int get total => low + inRange + high;
  bool get hasData => total > 0;

  double get lowPct => total == 0 ? 0 : low / total * 100;
  double get inRangePct => total == 0 ? 0 : inRange / total * 100;
  double get highPct => total == 0 ? 0 : high / total * 100;

  static const GlucoseTir empty = GlucoseTir();
}

/// Current cycle position for the Period ring — day N of the learned length,
/// plus the phase label. Null on the bundle when there isn't enough cycle data
/// to place "today" (the card then falls back to the flow strip).
class CycleRingInfo {
  final int dayOfCycle;
  final int cycleLength;
  final String phaseLabel;

  const CycleRingInfo({
    required this.dayOfCycle,
    required this.cycleLength,
    required this.phaseLabel,
  });

  /// Ring fill: how far through the average cycle "today" is (0..1).
  double get progress =>
      cycleLength <= 0 ? 0 : (dayOfCycle / cycleLength).clamp(0.0, 1.0);
}

/// Every feature's daily series for one range — the single payload the Trends
/// dashboard renders. Built by [TrendsDataService.build].
class TrendsBundle {
  final TrendRange range;
  final TrendSeries adherence; // value = daily adherence %; goal = 100
  final TrendSeries water; // value = effective hydration ml; goal = ml
  final TrendSeries steps; // value = effective steps; goal = steps
  final TrendSeries sleep; // value = hours asleep; goal = target hours
  final TrendSeries focus; // value = focused minutes; goal = target minutes
  final TrendSeries bloodPressure; // value = systolic, value2 = diastolic (mmHg)
  final TrendSeries glucose; // value = mg/dL (daily mean)
  final GlucoseTir glucoseTir; // whole-window low/in/high breakdown
  final TrendSeries period; // value = flow index 1..4 (bleeding days only)
  final CycleRingInfo? cycle; // current cycle position, if placeable

  const TrendsBundle({
    required this.range,
    required this.adherence,
    required this.water,
    required this.steps,
    required this.sleep,
    required this.focus,
    required this.bloodPressure,
    required this.glucose,
    required this.glucoseTir,
    required this.period,
    required this.cycle,
  });
}

/// Builds a per-feature DAILY series over a date range from the app's EXISTING
/// storage services. Pure aggregation — no persistence, no side effects beyond
/// ensuring the in-memory stores are hydrated (their `init()`s are idempotent).
class TrendsDataService {
  const TrendsDataService._();

  static Future<TrendsBundle> build(TrendRange range) async {
    // Ensure the in-memory-backed stores are loaded. Each init() is guarded and
    // cheap when already warm (FocusService is a startup singleton, so it is
    // read as-is rather than re-initialised here).
    await Future.wait<void>([
      WaterService.init(),
      StepService.init(),
      SleepService.init(),
      PeriodService.init(),
    ]);

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final n = range.days;
    final start = today.subtract(Duration(days: n - 1));
    final days = List<DateTime>.generate(n, (i) => start.add(Duration(days: i)));

    // Kick all three async series off together, then await — keeps concurrency
    // while letting glucose return its extra Time-in-Range payload.
    final adherenceF = _adherence(days);
    final bpF = _bloodPressure(days, start, today);
    final glucoseF = _glucose(days, start, today);
    final adherence = await adherenceF;
    final bloodPressure = await bpF;
    final (glucose, glucoseTir) = await glucoseF;

    return TrendsBundle(
      range: range,
      adherence: adherence,
      bloodPressure: bloodPressure,
      glucose: glucose,
      glucoseTir: glucoseTir,
      water: _water(days),
      steps: _steps(days, start, today),
      sleep: _sleep(days),
      focus: _focus(days),
      period: _period(days),
      cycle: _cycle(),
    );
  }

  // --------------------------------------------------------------- ADHERENCE

  static Future<TrendSeries> _adherence(List<DateTime> days) async {
    final summaries = await Future.wait(
        days.map((d) => MedicineCleanStorageService.getDailySummaryAsync(d)));
    final points = <TrendPoint>[];
    for (var i = 0; i < days.length; i++) {
      final s = summaries[i];
      // A day with no scheduled (non-PRN) doses is a gap, not 100%.
      final v = s.totalScheduled > 0
          ? (s.adherenceRate * 100).clamp(0, 100).toDouble()
          : null;
      points.add(TrendPoint(days[i], v));
    }
    // Adherence is measured against a fixed 100% goal — the ring's denominator.
    return TrendSeries(points, goal: 100);
  }

  // -------------------------------------------------------------------- WATER

  static TrendSeries _water(List<DateTime> days) {
    final points = <TrendPoint>[];
    double? goal;
    for (final d in days) {
      final data = WaterService.getDataForDate(d);
      if (data != null && data.dailyGoalMl > 0) {
        goal = data.dailyGoalMl.toDouble();
      }
      final ml = data?.effectiveHydrationMl ?? 0;
      points.add(TrendPoint(d, (data != null && ml > 0) ? ml.toDouble() : null));
    }
    return TrendSeries(points, goal: goal);
  }

  // -------------------------------------------------------------------- STEPS

  static TrendSeries _steps(List<DateTime> days, DateTime start, DateTime end) {
    final list = StepService.getDataForRange(start, end);
    final byKey = {for (final s in list) _ymd(s.date): s};
    final points = <TrendPoint>[];
    double? goal;
    for (final d in days) {
      final s = byKey[_ymd(d)];
      if (s != null && s.goalSteps > 0) goal = s.goalSteps.toDouble();
      points.add(TrendPoint(
          d, (s != null && s.effectiveSteps > 0) ? s.effectiveSteps.toDouble() : null));
    }
    return TrendSeries(points, goal: goal);
  }

  // -------------------------------------------------------------------- SLEEP

  static TrendSeries _sleep(List<DateTime> days) {
    final byKey = {for (final s in SleepService.getAllSessions()) s.dateKey: s};
    final points = days.map((d) {
      final s = byKey[_ymd(d)];
      return TrendPoint(
          d, (s != null && s.asleepMinutes > 0) ? s.asleepMinutes / 60.0 : null);
    }).toList();
    final target = SleepService.getSchedule().targetMinutes;
    final goalMin = target > 0 ? target : kSleepDefaultTargetMinutes;
    return TrendSeries(points, goal: goalMin / 60.0);
  }

  // -------------------------------------------------------------------- FOCUS

  static TrendSeries _focus(List<DateTime> days) {
    final byDay = <String, double>{};
    for (final s in FocusService().sessions) {
      final k = _ymd(s.startedAt);
      byDay[k] = (byDay[k] ?? 0) + s.actualMinutes;
    }
    final points = days.map((d) {
      final m = byDay[_ymd(d)];
      return TrendPoint(d, (m != null && m > 0) ? m : null);
    }).toList();
    return TrendSeries(points, goal: kFocusDailyGoalMinutes);
  }

  // ----------------------------------------------------------- BLOOD PRESSURE

  static Future<TrendSeries> _bloodPressure(
      List<DateTime> days, DateTime start, DateTime today) async {
    final to = today.add(const Duration(days: 1));
    final readings = await VitalsStorageService.getBpForRange(start, to);
    final sys = <String, List<int>>{};
    final dia = <String, List<int>>{};
    for (final r in readings) {
      final k = _ymd(r.takenAt);
      (sys[k] ??= []).add(r.systolic);
      (dia[k] ??= []).add(r.diastolic);
    }
    final points = days.map((d) {
      final k = _ymd(d);
      final s = sys[k];
      if (s == null || s.isEmpty) return TrendPoint(d, null);
      final di = dia[k]!;
      return TrendPoint(d, _avg(s), _avg(di));
    }).toList();
    return TrendSeries(points);
  }

  // ------------------------------------------------------------------ GLUCOSE

  static Future<(TrendSeries, GlucoseTir)> _glucose(
      List<DateTime> days, DateTime start, DateTime today) async {
    final to = today.add(const Duration(days: 1));
    final readings = await VitalsStorageService.getGlucoseForRange(start, to);
    final byDay = <String, List<int>>{};
    var low = 0, inRange = 0, high = 0;
    for (final r in readings) {
      (byDay[_ymd(r.takenAt)] ??= []).add(r.valueMgdl);
      // Time-in-Range counts every reading, not the daily mean (ADA standard).
      if (r.valueMgdl < kGlucoseLowThreshold) {
        low++;
      } else if (r.valueMgdl > kGlucoseHighThreshold) {
        high++;
      } else {
        inRange++;
      }
    }
    final points = days.map((d) {
      final v = byDay[_ymd(d)];
      return TrendPoint(d, (v == null || v.isEmpty) ? null : _avg(v));
    }).toList();
    return (
      TrendSeries(points),
      GlucoseTir(low: low, inRange: inRange, high: high),
    );
  }

  // ------------------------------------------------------------------- PERIOD

  static TrendSeries _period(List<DateTime> days) {
    final points = days.map((d) {
      final day = PeriodService.getDay(d);
      final f = day?.flowIndex ?? 0;
      return TrendPoint(d, f > 0 ? f.toDouble() : null);
    }).toList();
    return TrendSeries(points);
  }

  /// Where "today" sits in the current cycle — the Period ring's fill + label.
  /// Null unless the predictor can place the day against a learned length.
  static CycleRingInfo? _cycle() {
    final p = PeriodService.getPrediction();
    final day = p.dayOfCycle;
    final len = p.cycleLengthEstimate;
    final phase = p.phaseToday;
    if (day == null || day <= 0 || len == null || len <= 0 || phase == null) {
      return null;
    }
    return CycleRingInfo(
      dayOfCycle: day,
      cycleLength: len,
      phaseLabel: phase.label,
    );
  }

  // ------------------------------------------------------------------ HELPERS

  static double _avg(List<int> v) =>
      v.reduce((a, b) => a + b) / v.length;

  static String _ymd(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
