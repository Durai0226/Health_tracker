import 'insight.dart';
import 'vitals_analyzer.dart';

/// A blood-pressure reading reduced to what pattern detection needs.
class BpPoint {
  final DateTime at;
  final int systolic;
  final int diastolic;
  const BpPoint({required this.at, required this.systolic, required this.diastolic});
}

/// A glucose reading reduced to what pattern detection needs.
class GlucosePoint {
  final DateTime at;
  final int mgdl;
  final GlucoseContext context;
  const GlucosePoint({required this.at, required this.mgdl, required this.context});
}

/// Pure-Dart pattern detection over the user's own BP/glucose logs — the
/// Contour "My Patterns" idea, deterministic and offline. Returns ranked
/// [Insight]s (highest rank = most important); the UI shows the top one.
class VitalsPatternDetector {
  const VitalsPatternDetector._();

  /// [points] newest-first or oldest-first — we sort internally.
  /// How far back "recent" reaches. Both entry points clip to this, because the
  /// call sites pass the user's ENTIRE reading history while the generated copy
  /// says "your recent readings" — so an unbounded count let two readings from a
  /// year ago latch an insight permanently.
  static const Duration recentWindow = Duration(days: 30);

  static List<Insight> analyzeBp(List<BpPoint> points, {DateTime? now}) {
    final cutoff = (now ?? DateTime.now()).subtract(recentWindow);
    points = points.where((p) => p.at.isAfter(cutoff)).toList();
    final out = <Insight>[];
    if (points.length < 3) return out;
    final pts = [...points]..sort((a, b) => a.at.compareTo(b.at)); // oldest→newest
    final sys = pts.map((p) => p.systolic).toList();

    // Trend on systolic.
    final change = _totalChange(sys.map((e) => e.toDouble()).toList());
    if (change.abs() >= 8) {
      final up = change > 0;
      out.add(Insight(
        id: 'bp_trend',
        feature: InsightFeature.bloodPressure,
        severity: up ? InsightSeverity.attention : InsightSeverity.good,
        title: up ? 'Blood pressure trending up' : 'Blood pressure trending down',
        detail: up
            ? 'Your systolic has drifted up about ${change.round()} mmHg across recent readings — worth keeping an eye on.'
            : 'Nice — your systolic has eased about ${change.abs().round()} mmHg across recent readings.',
        metric: '${change > 0 ? '+' : ''}${change.round()} mmHg',
        why: 'Linear trend of systolic across your last ${pts.length} readings.',
        rank: up ? 70 : 40,
      ));
    }

    // Morning vs evening.
    final morn = pts.where((p) => p.at.hour < 12).map((p) => p.systolic).toList();
    final eve = pts.where((p) => p.at.hour >= 12).map((p) => p.systolic).toList();
    final mAvg = VitalsAnalyzer.mean(morn);
    final eAvg = VitalsAnalyzer.mean(eve);
    if (morn.length >= 2 && eve.length >= 2 && mAvg != null && eAvg != null) {
      final diff = mAvg - eAvg;
      if (diff.abs() >= 8) {
        final morningsHigher = diff > 0;
        out.add(Insight(
          id: 'bp_ampm',
          feature: InsightFeature.bloodPressure,
          severity: InsightSeverity.info,
          title: morningsHigher ? 'Mornings run higher' : 'Evenings run higher',
          detail:
              'Your ${morningsHigher ? 'morning' : 'evening'} systolic averages about ${diff.abs().round()} mmHg above the other half of the day.',
          metric: '${mAvg.round()} AM · ${eAvg.round()} PM',
          why: 'Average systolic for AM readings vs PM readings.',
          rank: 45,
        ));
      }
    }

    // Out-of-range frequency.
    final outOfRange = pts
        .where((p) =>
            VitalsAnalyzer.classifyBp(p.systolic, p.diastolic).index >=
            BpCategory.stage1.index)
        .length;
    final frac = outOfRange / pts.length;
    if (pts.length >= 5 && frac >= 0.4) {
      out.add(Insight(
        id: 'bp_outofrange',
        feature: InsightFeature.bloodPressure,
        severity: frac >= 0.7 ? InsightSeverity.attention : InsightSeverity.info,
        title: 'Most readings above target',
        detail:
            '${(frac * 100).round()}% of your recent readings are Stage 1 or higher. Consistency + your doctor\'s plan help most.',
        metric: '${(frac * 100).round()}%',
        why: 'Share of your last ${pts.length} readings classified Stage 1+ (AHA/ACC).',
        rank: 60,
      ));
    }

    out.sort((a, b) => b.rank.compareTo(a.rank));
    return out;
  }

  static List<Insight> analyzeGlucose(List<GlucosePoint> points, {DateTime? now}) {
    final cutoff = (now ?? DateTime.now()).subtract(recentWindow);
    points = points.where((p) => p.at.isAfter(cutoff)).toList();
    final out = <Insight>[];
    if (points.length < 3) return out;
    final pts = [...points]..sort((a, b) => a.at.compareTo(b.at));
    final vals = pts.map((p) => p.mgdl).toList();

    // Trend.
    final change = _totalChange(vals.map((e) => e.toDouble()).toList());
    if (change.abs() >= 15) {
      final up = change > 0;
      out.add(Insight(
        id: 'gl_trend',
        feature: InsightFeature.bloodSugar,
        severity: up ? InsightSeverity.attention : InsightSeverity.good,
        title: up ? 'Blood sugar trending up' : 'Blood sugar trending down',
        detail: up
            ? 'Your average glucose has drifted up about ${change.round()} mg/dL recently.'
            : 'Your average glucose has eased about ${change.abs().round()} mg/dL recently.',
        metric: '${change > 0 ? '+' : ''}${change.round()} mg/dL',
        why: 'Linear trend of glucose across your last ${pts.length} readings.',
        rank: up ? 68 : 40,
      ));
    }

    // Frequent lows — over the RECENT window only. Both call sites pass the
    // user's entire history, so an unbounded count let two lows from a year ago
    // latch this insight forever while the copy claimed they were "recent".
    final lows = pts
        .where((p) => VitalsAnalyzer.classifyGlucose(p.mgdl, p.context).index <=
            GlucoseClass.low.index)
        .length;
    if (lows >= 2) {
      out.add(Insight(
        id: 'gl_lows',
        feature: InsightFeature.bloodSugar,
        severity: InsightSeverity.attention,
        title: 'Frequent low readings',
        detail:
            '$lows of your recent readings were low (<70 mg/dL). Recurrent lows are worth discussing with your care team.',
        metric: '$lows lows',
        why: 'Count of readings classified Low/Severe-low (ADA) in this window.',
        rank: 75,
      ));
    }

    // Fasting often high.
    final fasting = pts
        .where((p) => p.context == GlucoseContext.fasting)
        .map((p) => p.mgdl)
        .toList();
    final fAvg = VitalsAnalyzer.mean(fasting);
    if (fasting.length >= 3 && fAvg != null && fAvg >= 130) {
      out.add(Insight(
        id: 'gl_fasting',
        feature: InsightFeature.bloodSugar,
        severity: InsightSeverity.info,
        title: 'Fasting readings often high',
        detail:
            'Your fasting average is about ${fAvg.round()} mg/dL — above the 80–130 target range.',
        metric: '${fAvg.round()} mg/dL',
        why: 'Average of your fasting-tagged readings vs the ADA 80–130 target.',
        rank: 55,
      ));
    }

    out.sort((a, b) => b.rank.compareTo(a.rank));
    return out;
  }

  /// Total change (last − first of the fitted line) via least-squares slope.
  static double _totalChange(List<double> y) {
    final n = y.length;
    if (n < 2) return 0;
    final xMean = (n - 1) / 2.0;
    final yMean = y.reduce((a, b) => a + b) / n;
    double num = 0, den = 0;
    for (var i = 0; i < n; i++) {
      num += (i - xMean) * (y[i] - yMean);
      den += (i - xMean) * (i - xMean);
    }
    if (den == 0) return 0;
    final slope = num / den;
    return slope * (n - 1);
  }
}

