import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/widgets/app/app_widgets.dart';
import '../../water/screens/aqua_water_dashboard.dart';
import '../../sleep/screens/sleep_dashboard_screen.dart';
import '../../steps/screens/steps_dashboard_screen.dart';
import '../../period/screens/period_dashboard.dart';
import '../../biometrics/screens/heart_dashboard_screen.dart';
import '../../biometrics/screens/workouts_screen.dart';
import '../../biometrics/screens/connected_devices_screen.dart';
import '../../medication/screens/vitals/blood_pressure_screen.dart';
import '../../medication/screens/vitals/blood_sugar_screen.dart';
import '../../medication/screens/vitals/weight_screen.dart';
import '../../medication/screens/vitals/mood_screen.dart';
import '../../medication/screens/conditions/condition_library_screen.dart';
import '../../diary/screens/diary_screen.dart';
import '../../../core/widgets/app/vitals_theme.dart';
import '../../insights/screens/trends_dashboard_screen.dart';
import '../../insights/screens/weekly_recap_screen.dart';

/// The "Health" tab — one browse hub that surfaces EVERY tracker as an equal
/// sibling. Fixes the old IA where Steps/Sleep/BP/Glucose were buried three taps
/// deep inside the Medicine screen's "Quick Access" grid. Each row opens the
/// tracker's full dashboard (wrapped in the right accent scope).
class HealthBrowseScreen extends StatelessWidget {
  /// Switches the shell to the Trends tab. Passed in rather than pushing a second
  /// TrendsDashboardScreen: two live copies disagreed about the persisted range.
  /// Null (e.g. in a screenshot harness) falls back to pushing.
  final VoidCallback? onOpenTrends;

  const HealthBrowseScreen({super.key, this.onOpenTrends});

  @override
  Widget build(BuildContext context) {
    final ext = AppColorsExt.of(context);
    final tt = Theme.of(context).textTheme;

    void open(Widget screen, FeatureAccent accent) {
      Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => AccentScope(feature: accent, child: screen)),
      );
    }

    final tiles = <Widget>[
      _tile(ext, Symbols.water_drop_rounded, ext.water, 'Water',
          'Hydration & daily intake',
          () => open(const AquaWaterDashboard(), FeatureAccent.water)),
      _tile(ext, Symbols.directions_walk_rounded, ext.steps, 'Steps',
          'Activity, distance & calories',
          () => open(const StepsDashboardScreen(), FeatureAccent.steps)),
      _tile(ext, Symbols.bedtime_rounded, ext.sleep, 'Sleep',
          'Duration, quality & trends',
          () => open(const SleepDashboardScreen(), FeatureAccent.sleep)),
      _tile(ext, Symbols.ecg_heart_rounded, ext.medicine, 'Heart',
          'Resting rate, variability & oxygen',
          () => open(const HeartDashboardScreen(), FeatureAccent.medicine)),
      _tile(ext, Symbols.exercise_rounded, ext.steps, 'Workouts',
          'Sessions imported from your watch',
          () => open(const WorkoutsScreen(), FeatureAccent.steps)),
      _tile(ext, Symbols.favorite_rounded, ext.period, 'Period',
          'Cycle, phases & predictions',
          () => open(const PeriodDashboard(), FeatureAccent.period)),
      _tile(ext, Symbols.monitor_heart_rounded, ext.medicine, 'Blood pressure',
          'Systolic / diastolic readings',
          () => open(const BloodPressureScreen(), FeatureAccent.medicine)),
      _tile(ext, Symbols.bloodtype_rounded, ext.medicine, 'Blood sugar',
          'Readings, trends & time in range',
          () => open(const BloodSugarScreen(), FeatureAccent.medicine)),
      _tile(
          ext,
          Symbols.monitor_weight_rounded,
          VitalsColors.weightAccent(ext.isDark),
          'Weight',
          'Readings & trend',
          () => open(const WeightScreen(), FeatureAccent.medicine)),
      _tile(
          ext,
          Symbols.mood_rounded,
          VitalsColors.moodAccent(ext.isDark),
          'Mood',
          'Daily check-ins & trend',
          () => open(const MoodScreen(), FeatureAccent.medicine)),
      _tile(ext, Symbols.auto_stories_rounded, ext.brand, 'Diary',
          'Your notes & reflections',
          () => open(const DiaryScreen(), FeatureAccent.brand)),
    ];

    return AppScaffold(
      body: Column(
        children: [
          AppHeader(
            title: 'Health',
            bottom: Container(height: 1, color: ext.outline),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.fromLTRB(AppSpacing.gutter,
                  AppSpacing.lg, AppSpacing.gutter, AppInsets.pushed(context)),
              children: [
                _trendsCard(context, ext, tt),
                const SizedBox(height: AppSpacing.md),
                // Re-homed here: the Insights hub was its only entry point.
                AppListGroup(children: [
                    _tile(
                        ext,
                        Symbols.calendar_view_week_rounded,
                        ext.brand,
                        'Weekly recap',
                        'Your last 7 days across every tracker',
                        () => Navigator.push(
                              context,
                              MaterialPageRoute<void>(
                                  builder: (_) => const WeeklyRecapScreen()),
                            )),
                    _tile(
                        ext,
                        Symbols.watch_rounded,
                        ext.brand,
                        'Connected devices',
                        "What's feeding your health data",
                        () => Navigator.push(
                              context,
                              MaterialPageRoute<void>(
                                  builder: (_) =>
                                      const ConnectedDevicesScreen()),
                            )),
                    _tile(
                        ext,
                        Symbols.menu_book_rounded,
                        ext.brand,
                        'Condition library',
                        'General reference for common conditions',
                        () => Navigator.push(
                              context,
                              MaterialPageRoute<void>(
                                  builder: (_) => const ConditionLibraryScreen()),
                            )),
                ]),
                const SizedBox(height: AppSpacing.xl),
                Text('Your trackers',
                    style: tt.headlineSmall?.copyWith(color: ext.textPrimary)),
                const SizedBox(height: AppSpacing.xs),
                Text('Everything you track, in one place.',
                    style:
                        tt.bodyMedium?.copyWith(color: ext.textSecondary)),
                const SizedBox(height: AppSpacing.lg),
                AppListGroup(children: tiles),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Pointer to the Trends TAB (not a pushed copy).
  ///
  /// Trends became a bottom-nav destination, so pushing another instance created
  /// two live copies: the pushed one wrote the persisted range while the root tab
  /// kept its launch-time range, and the user's selection silently disagreed
  /// between them. Switching tabs is also what the user actually wants here.
  Widget _trendsCard(BuildContext context, AppColorsExt ext, TextTheme tt) {
    return AppCard(
      color: ext.brand.container,
      onTap: onOpenTrends ??
          () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                    builder: (_) => const TrendsDashboardScreen()),
              ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
                color: ext.brand.onContainer.withOpacity(0.14),
                borderRadius: AppRadius.brMd),
            child: Icon(Symbols.monitoring_rounded,
                size: 24, color: ext.brand.onContainer),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Trends dashboard',
                    style: tt.titleMedium?.copyWith(
                        color: ext.brand.onContainer,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text('Every tracker charted · 7 / 14 / 30 days',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: tt.bodySmall?.copyWith(
                        color: ext.brand.onContainer.withOpacity(0.8))),
              ],
            ),
          ),
          Icon(Symbols.chevron_right_rounded,
              size: 20, color: ext.brand.onContainer.withOpacity(0.7)),
        ],
      ),
    );
  }

  Widget _tile(AppColorsExt ext, IconData icon, AccentSwatch accent,
          String title, String subtitle, VoidCallback onTap) =>
      AppListTile(
        icon: icon,
        iconColor: ext.mark(accent),
        title: title,
        subtitle: subtitle,
        onTap: onTap,
      );

}
