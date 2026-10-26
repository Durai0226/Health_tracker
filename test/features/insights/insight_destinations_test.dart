import 'package:flutter_test/flutter_test.dart';
import 'package:tablet_remainder/core/design/app_colors_ext.dart';
import 'package:tablet_remainder/core/health/insight.dart';
import 'package:tablet_remainder/features/insights/services/insight_destinations.dart';
import 'package:tablet_remainder/features/medication/screens/analytics/nunito_adherence_report_screen.dart';
import 'package:tablet_remainder/features/medication/screens/refill_overview_screen.dart';
import 'package:tablet_remainder/features/medication/screens/vitals/blood_pressure_screen.dart';
import 'package:tablet_remainder/features/medication/screens/vitals/blood_sugar_screen.dart';
import 'package:tablet_remainder/features/sleep/screens/sleep_dashboard_screen.dart';
import 'package:tablet_remainder/features/water/screens/aqua_water_dashboard.dart';

Insight _insight(String id, InsightFeature feature) => Insight(
      id: id,
      feature: feature,
      severity: InsightSeverity.attention,
      title: 't',
      detail: 'd',
      why: 'w',
    );

void main() {
  group('InsightDestinations — a nudge opens the screen that fixes it', () {
    test('refill opens Refills, not the adherence report', () {
      expect(
          InsightDestinations.screenFor(
              _insight('med_refill', InsightFeature.medicine)),
          isA<RefillOverviewScreen>());
    });

    test('other medicine insights open the adherence report', () {
      for (final id in ['med_adherence', 'med_missrisk']) {
        expect(InsightDestinations.screenFor(_insight(id, InsightFeature.medicine)),
            isA<NunitoAdherenceReportScreen>(),
            reason: id);
      }
    });

    test('each tracker insight opens its own tracker', () {
      expect(
          InsightDestinations.screenFor(
              _insight('water_behind', InsightFeature.water)),
          isA<AquaWaterDashboard>());
      expect(
          InsightDestinations.screenFor(
              _insight('sleep_short', InsightFeature.sleep)),
          isA<SleepDashboardScreen>());
      expect(
          InsightDestinations.screenFor(
              _insight('gl_lows', InsightFeature.bloodSugar)),
          isA<BloodSugarScreen>());
      expect(
          InsightDestinations.screenFor(
              _insight('bp_trend', InsightFeature.bloodPressure)),
          isA<BloodPressureScreen>());
    });

    test('the BP-vs-adherence correlation opens Blood pressure', () {
      expect(
          InsightDestinations.screenFor(_insight(
              'correlation_bp_adherence', InsightFeature.crossCutting)),
          isA<BloodPressureScreen>());
    });

    test('insights with no better place return null so Trends stays the fallback', () {
      expect(
          InsightDestinations.screenFor(
              _insight('correlation_focus_sleep', InsightFeature.crossCutting)),
          isNull);
      expect(
          InsightDestinations.screenFor(
              _insight('rem_x', InsightFeature.reminders)),
          isNull);
    });

    test('the pushed screen carries its feature accent, not the brand fallback',
        () {
      FeatureAccent a(String id, InsightFeature f) =>
          InsightDestinations.accentFor(_insight(id, f));
      expect(a('water_behind', InsightFeature.water), FeatureAccent.water);
      expect(a('sleep_short', InsightFeature.sleep), FeatureAccent.sleep);
      expect(a('period_soon', InsightFeature.period), FeatureAccent.period);
      expect(a('med_refill', InsightFeature.medicine), FeatureAccent.medicine);
      expect(a('gl_lows', InsightFeature.bloodSugar), FeatureAccent.medicine);
      expect(a('correlation_bp_adherence', InsightFeature.crossCutting),
          FeatureAccent.medicine);
    });

    test('every feature is covered by the switch', () {
      // The switch is exhaustive by the compiler; this just proves none of
      // them throws when built.
      for (final f in InsightFeature.values) {
        expect(() => InsightDestinations.screenFor(_insight('x', f)),
            returnsNormally,
            reason: f.name);
        expect(() => InsightDestinations.accentFor(_insight('x', f)),
            returnsNormally,
            reason: f.name);
      }
    });
  });
}
