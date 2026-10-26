import 'package:flutter/material.dart';

import '../../../core/design/accent_scope.dart';
import '../../../core/design/app_colors_ext.dart';
import '../../../core/health/insight.dart';
import '../../focus/screens/focus_screen.dart';
import '../../medication/screens/analytics/nunito_adherence_report_screen.dart';
import '../../medication/screens/refill_overview_screen.dart';
import '../../medication/screens/vitals/blood_pressure_screen.dart';
import '../../medication/screens/vitals/blood_sugar_screen.dart';
import '../../period/screens/period_dashboard.dart';
import '../../sleep/screens/sleep_dashboard_screen.dart';
import '../../steps/screens/steps_dashboard_screen.dart';
import '../../water/screens/aqua_water_dashboard.dart';

/// Where tapping an insight should take the user: the screen that acts on it,
/// not the screen that charts it.
///
/// The Today nudge used to open Trends for every insight, so "Refill soon" put
/// the user on a chart page one more tap away from the refill button.
///
/// Keyed on [InsightFeature] rather than a list of ids so a new insight in an
/// existing feature lands somewhere sensible without anyone remembering to add
/// it here. The two id overrides are the cases where the feature's main screen
/// is the wrong fix. A null result means "no better place than Trends", and the
/// caller keeps its own fallback.
class InsightDestinations {
  const InsightDestinations._();

  /// The screen for [insight], or null when Trends is the right place.
  static Widget? screenFor(Insight insight) {
    switch (insight.id) {
      case 'med_refill':
        return const RefillOverviewScreen();
      case 'correlation_bp_adherence':
        return const BloodPressureScreen();
    }
    switch (insight.feature) {
      case InsightFeature.medicine:
        return const NunitoAdherenceReportScreen();
      case InsightFeature.water:
        return const AquaWaterDashboard();
      case InsightFeature.focus:
        return const FocusScreen();
      case InsightFeature.bloodPressure:
        return const BloodPressureScreen();
      case InsightFeature.bloodSugar:
        return const BloodSugarScreen();
      case InsightFeature.period:
        return const PeriodDashboard();
      case InsightFeature.steps:
        return const StepsDashboardScreen();
      case InsightFeature.sleep:
        return const SleepDashboardScreen();
      case InsightFeature.reminders:
      case InsightFeature.crossCutting:
        return null;
    }
  }

  /// The accent the destination should render in. A pushed route sits outside
  /// the tab it was opened from, so without a scope its sheets and cards fall
  /// back to the brand colour; the Health tab wraps every push the same way.
  static FeatureAccent accentFor(Insight insight) {
    if (insight.id == 'med_refill' ||
        insight.id == 'correlation_bp_adherence') {
      return FeatureAccent.medicine;
    }
    switch (insight.feature) {
      case InsightFeature.water:
        return FeatureAccent.water;
      case InsightFeature.focus:
        return FeatureAccent.focus;
      case InsightFeature.period:
        return FeatureAccent.period;
      case InsightFeature.steps:
        return FeatureAccent.steps;
      case InsightFeature.sleep:
        return FeatureAccent.sleep;
      case InsightFeature.medicine:
      case InsightFeature.bloodPressure:
      case InsightFeature.bloodSugar:
        return FeatureAccent.medicine;
      case InsightFeature.reminders:
        return FeatureAccent.reminders;
      case InsightFeature.crossCutting:
        return FeatureAccent.brand;
    }
  }

  /// A push of [screenFor], or null when there is no better destination.
  static VoidCallback? of(BuildContext context, Insight insight) {
    final screen = screenFor(insight);
    if (screen == null) return null;
    final accent = accentFor(insight);
    return () => Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => AccentScope(feature: accent, child: screen)));
  }
}
