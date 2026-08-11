/// Pure-Dart clinical engine for the Blood Pressure & Blood Sugar trackers.
///
/// All classification, averages, estimated-A1C, in-range %, unit conversion and
/// red-flag detection live here — deterministic, offline, free, and fully
/// unit-testable (no Flutter import). The UI maps the returned enums/labels to
/// colors; this file never decides pixels.
///
/// Thresholds are the load-bearing clinical constants:
///  - Blood pressure: AHA/ACC 2017 categories (mm Hg).
///  - Blood glucose: ADA targets (canonical unit = integer mg/dL).
library;

// ---------------------------------------------------------------------------
// Blood pressure
// ---------------------------------------------------------------------------

/// AHA/ACC 2017 blood-pressure categories, least→most severe.
enum BpCategory { normal, elevated, stage1, stage2, crisis }

// ---------------------------------------------------------------------------
// Blood glucose
// ---------------------------------------------------------------------------

/// When a glucose reading was taken — drives the target used to classify it.
enum GlucoseContext { fasting, beforeMeal, afterMeal, bedtime, random }

/// Glucose classification band, low→high.
enum GlucoseClass { severeLow, low, inRange, high, veryHigh }

/// Display unit for glucose (canonical storage is always mg/dL).
enum GlucoseUnit { mgdl, mmoll }

class VitalsAnalyzer {
  const VitalsAnalyzer._();

  // ---- Blood pressure ------------------------------------------------------

  /// Classify a reading via the AHA/ACC cascade (most-severe wins, so a
  /// mismatched systolic/diastolic resolves to the higher category).
  static BpCategory classifyBp(int systolic, int diastolic) {
    if (systolic > 180 || diastolic > 120) return BpCategory.crisis;
    if (systolic >= 140 || diastolic >= 90) return BpCategory.stage2;
    if (systolic >= 130 || diastolic >= 80) return BpCategory.stage1;
    if (systolic >= 120) return BpCategory.elevated; // diastolic < 80 here
    return BpCategory.normal;
  }

  /// A BP reading in the hypertensive-crisis zone (≥180/≥120) → surface the
  /// emergency red-flag card.
  static bool isBpCrisis(int systolic, int diastolic) =>
      classifyBp(systolic, diastolic) == BpCategory.crisis;

  /// Valid clinical bounds + systolic must exceed diastolic.
  static bool isValidBp(int systolic, int diastolic) =>
      systolic >= 50 &&
      systolic <= 300 &&
      diastolic >= 30 &&
      diastolic <= 200 &&
      systolic > diastolic;

  static String bpLabel(BpCategory c) {
    switch (c) {
      case BpCategory.normal:
        return 'Normal';
      case BpCategory.elevated:
        return 'Elevated';
      case BpCategory.stage1:
        return 'Stage 1 High';
      case BpCategory.stage2:
        return 'Stage 2 High';
      case BpCategory.crisis:
        return 'Hypertensive Crisis';
    }
  }

  /// One-line plain-language meaning (the "user understanding" line).
  static String bpMeaning(BpCategory c) {
    switch (c) {
      case BpCategory.normal:
        return 'Your blood pressure is in the healthy range.';
      case BpCategory.elevated:
        return 'Slightly above normal — small lifestyle changes can help.';
      case BpCategory.stage1:
        return 'Stage 1 high — worth discussing with your doctor.';
      case BpCategory.stage2:
        return 'Stage 2 high — please talk to your doctor.';
      case BpCategory.crisis:
        return 'Very high — this may need urgent medical care.';
    }
  }

  // ---- Blood glucose -------------------------------------------------------

  /// Upper "high" threshold (mg/dL) per context (ADA-based). At/above → high.
  static int glucoseHighThreshold(GlucoseContext ctx) {
    switch (ctx) {
      case GlucoseContext.fasting:
      case GlucoseContext.beforeMeal:
        return 130;
      case GlucoseContext.bedtime:
        return 150;
      case GlucoseContext.afterMeal:
      case GlucoseContext.random:
        return 180;
    }
  }

  /// Lower bound of the ideal target band (mg/dL) — used for the chart's green
  /// zone; classification treats <70 as low regardless.
  static int glucoseTargetLow(GlucoseContext ctx) {
    switch (ctx) {
      case GlucoseContext.fasting:
      case GlucoseContext.beforeMeal:
        return 80;
      default:
        return 70;
    }
  }

  /// Classify a glucose value (mg/dL) for its context. Severity (severe-low /
  /// very-high) overrides the context band.
  static GlucoseClass classifyGlucose(int mgdl, GlucoseContext ctx) {
    if (mgdl < 54) return GlucoseClass.severeLow;
    if (mgdl < 70) return GlucoseClass.low;
    if (mgdl > 250) return GlucoseClass.veryHigh;
    if (mgdl >= glucoseHighThreshold(ctx)) return GlucoseClass.high;
    return GlucoseClass.inRange;
  }

  /// Severe low (<54) → non-dismissible emergency card.
  static bool isGlucoseEmergencyLow(int mgdl) => mgdl < 54;

  static bool isValidGlucoseMgdl(int mgdl) => mgdl >= 10 && mgdl <= 900;

  static String glucoseLabel(GlucoseClass c) {
    switch (c) {
      case GlucoseClass.severeLow:
        return 'Severe Low';
      case GlucoseClass.low:
        return 'Low';
      case GlucoseClass.inRange:
        return 'In Range';
      case GlucoseClass.high:
        return 'High';
      case GlucoseClass.veryHigh:
        return 'Very High';
    }
  }

  static String glucoseMeaning(GlucoseClass c) {
    switch (c) {
      case GlucoseClass.severeLow:
        return 'Dangerously low — treat immediately.';
      case GlucoseClass.low:
        return 'Below range — have some fast-acting carbs.';
      case GlucoseClass.inRange:
        return 'In your target range — nicely done.';
      case GlucoseClass.high:
        return 'Above range — follow your care plan.';
      case GlucoseClass.veryHigh:
        return 'Very high — follow your care plan and recheck.';
    }
  }

  static String glucoseContextLabel(GlucoseContext ctx) {
    switch (ctx) {
      case GlucoseContext.fasting:
        return 'Fasting';
      case GlucoseContext.beforeMeal:
        return 'Before meal';
      case GlucoseContext.afterMeal:
        return 'After meal';
      case GlucoseContext.bedtime:
        return 'Bedtime';
      case GlucoseContext.random:
        return 'Random';
    }
  }

  // ---- Unit conversion (canonical storage = mg/dL) -------------------------

  static const double _mgdlPerMmol = 18.0182;

  /// mg/dL → mmol/L, rounded to 1 decimal for display.
  static double mgdlToMmol(int mgdl) =>
      (mgdl / _mgdlPerMmol * 10).round() / 10;

  /// mmol/L → mg/dL (canonical integer).
  static int mmolToMgdl(double mmol) => (mmol * _mgdlPerMmol).round();

  // ---- Aggregates (pure) ---------------------------------------------------

  /// Mean of ints, or null when empty.
  static double? mean(List<int> values) {
    if (values.isEmpty) return null;
    var sum = 0;
    for (final v in values) {
      sum += v;
    }
    return sum / values.length;
  }

  /// Estimated A1C from a set of glucose values (mg/dL): (mean+46.7)/28.7.
  /// Gated on [minReadings] so a couple of points can't imply an A1C; null
  /// below the gate. Always label the result an *estimate* in the UI.
  static double? estimatedA1c(List<int> mgdlValues, {int minReadings = 14}) {
    if (mgdlValues.length < minReadings) return null;
    final m = mean(mgdlValues)!;
    return (m + 46.7) / 28.7;
  }

  /// Fraction (0..1) of glucose readings classified in-range, given each
  /// reading's own context. Null when empty.
  static double? inRangePercent(List<({int mgdl, GlucoseContext ctx})> readings) {
    if (readings.isEmpty) return null;
    final inRange = readings
        .where((r) => classifyGlucose(r.mgdl, r.ctx) == GlucoseClass.inRange)
        .length;
    return inRange / readings.length;
  }
}
