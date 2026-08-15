import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/services/active_profile_service.dart';
import '../../../core/services/clean_storage_service.dart';
import '../../../core/widgets/app/app_widgets.dart';
import '../../../core/widgets/app/vitals_theme.dart';
import '../../focus/screens/focus_screen.dart';
import '../../medication/screens/nunito_medication_dashboard.dart';
import '../../medication/screens/vitals/blood_pressure_screen.dart';
import '../../medication/screens/vitals/blood_sugar_screen.dart';
import '../../medication/screens/vitals/weight_screen.dart';
import '../../period/screens/period_calendar_screen.dart';
import '../../sleep/screens/sleep_dashboard_screen.dart';
import '../../steps/screens/steps_dashboard_screen.dart';
import '../../water/screens/aqua_water_dashboard.dart';
import '../../medication/services/medicine_storage_service.dart';
import '../services/trends_data_service.dart';
import '../widgets/trend_chart_card.dart';

/// The unified "Trends" dashboard — every feature charted in one place with a
/// 7 / 14 / 30-day range selector. One small-multiple card per feature (each in
/// its own fixed accent), always shown even with no data (in-card empty state),
/// so the page visibly "covers all features".
class TrendsDashboardScreen extends StatefulWidget {
  /// Range to open on (defaults to 7 days). Lets a caller deep-link a range and
  /// leaves room to restore the user's last-used range later.
  final TrendRange initialRange;

  /// True when this is a bottom-nav destination rather than a pushed screen.
  ///
  /// It matters: as a root tab there is nothing to pop, so the header's back
  /// arrow would render but do nothing when tapped. Same flag the deleted
  /// Insights hub used for the same reason.
  final bool isRoot;

  const TrendsDashboardScreen({
    super.key,
    this.initialRange = TrendRange.d7,
    this.isRoot = false,
  });

  @override
  State<TrendsDashboardScreen> createState() => _TrendsDashboardScreenState();
}

class _TrendsDashboardScreenState extends State<TrendsDashboardScreen> {
  static const _kRangeKey = 'trends.range';

  late TrendRange _range;
  late Future<TrendsBundle> _future;

  /// The last bundle that loaded successfully.
  ///
  /// Switching range assigns a fresh [_future], and the [FutureBuilder] below
  /// used to fall straight back to [_loading] — four solid grey blocks — while
  /// it resolved. So every tap on Week/Month/Year wiped the whole dashboard to
  /// placeholders and re-mounted every chart, each of which then re-animated
  /// from zero. That full-screen flash is the most visible thing that happens
  /// on a switch in this app. Keeping the previous bundle on screen makes the
  /// range change look like a data update instead of a screen teardown.
  TrendsBundle? _lastGood;

  @override
  void initState() {
    super.initState();
    // Restore the user's last-used range (falls back to the caller's default).
    final stored =
        CleanStorageService.getAppPreference(_kRangeKey, widget.initialRange.index);
    final idx = (stored is int && stored >= 0 && stored < TrendRange.values.length)
        ? stored
        : widget.initialRange.index;
    _range = TrendRange.values[idx];
    _future = TrendsDataService.build(_range);

    // As a root tab this screen stays alive in the shell's IndexedStack, so
    // without a listener the charts would keep showing whatever was true at
    // launch. Pull-to-refresh covers the manual case; this covers logging a dose
    // in another tab. ActiveProfileService is ALSO needed for the same reason
    // (see nunito_medication_dashboard.dart/home_dashboard.dart's identical
    // fix): without it, switching the active profile via Home's switcher and
    // tapping back to this tab kept showing the PREVIOUS profile's vitals/med
    // trends, since VitalsStorageService.getBpForRange/getGlucoseForRange are
    // scoped by ActiveProfileService but nothing here ever re-queried them.
    MedicineCleanStorageService.revision.addListener(_onDataChanged);
    ActiveProfileService().addListener(_onDataChanged);
  }

  void _onDataChanged() {
    if (mounted) _reload();
  }

  @override
  void dispose() {
    MedicineCleanStorageService.revision.removeListener(_onDataChanged);
    ActiveProfileService().removeListener(_onDataChanged);
    super.dispose();
  }

  void _setRange(int i) {
    final next = TrendRange.values[i];
    if (next == _range) return;
    CleanStorageService.setAppPreference(_kRangeKey, next.index);
    setState(() {
      _range = next;
      _future = TrendsDataService.build(_range);
    });
  }

  void _open(Widget screen) {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    final ext = AppColorsExt.of(context);

    return AppScaffold(
      safeTop: true,
      body: Column(
        children: [
          AppHeader(
            title: 'Trends',
            icon: Symbols.monitoring_rounded,
            accent: ext.brand,
            // No back arrow on the root tab — there would be nothing to pop.
            leading: widget.isRoot
                ? null
                : AppIconButton(
                    icon: Symbols.arrow_back_rounded,
                    filled: false,
                    accent: ext.brand,
                    onPressed: () {
                      if (Navigator.canPop(context)) Navigator.pop(context);
                    },
                  ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.gutter, 0, AppSpacing.gutter, AppSpacing.sm),
            child: SegmentedToggle(
              accent: ext.brand,
              index: _range.index,
              onChanged: _setRange,
              items: [
                for (final r in TrendRange.values) SegmentItem(label: r.label),
              ],
            ),
          ),
          Container(height: 1, color: ext.outline),
          Expanded(
            child: FutureBuilder<TrendsBundle>(
              future: _future,
              builder: (context, snap) {
                if (snap.hasData) _lastGood = snap.data;
                if (snap.connectionState != ConnectionState.done) {
                  // Stale-while-revalidate: only the genuinely-empty first
                  // load gets skeletons. An error still surfaces below.
                  return _lastGood != null
                      ? _dashboard(ext, _lastGood!)
                      : _loading(ext);
                }
                if (snap.hasError || !snap.hasData) {
                  return _error(ext);
                }
                return _dashboard(ext, snap.data!);
              },
            ),
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------------------- DASHBOARD

  Widget _dashboard(AppColorsExt ext, TrendsBundle b) {
    final days = b.range.days;
    // Faint green "healthy zone" fill — a reserved STATUS colour, always paired
    // with a labelled band, never used as a series colour.
    final bandGreen =
        ext.mark(ext.success).withOpacity(ext.isDark ? 0.16 : 0.12);

    final cards = <Widget>[
      // MEDICINE ADHERENCE — ring vs a fixed 100% goal.
      _goalCard(
        ext: ext,
        accent: ext.medicine,
        icon: Symbols.medication_rounded,
        title: 'Medicine adherence',
        series: b.adherence,
        days: days,
        featureName: 'doses',
        formatValue: (v) => '${v.round()}%',
        centerValue: (gp) => '${(gp * 100).round()}%',
        centerCaption: 'adherence',
        ringHeadline: (_) =>
            '${b.adherence.loggedDays} of $days days tracked',
        miniMaxY: 100,
        barHeadline:
            b.adherence.hasData ? '${b.adherence.average!.round()}% avg' : '—',
        barMaxY: 100,
        onTap: () => _open(const NunitoMedicationDashboard()),
      ),
      // WATER — ring vs the stored daily goal (falls back to bars if unset).
      _goalCard(
        ext: ext,
        accent: ext.water,
        icon: Symbols.water_drop_rounded,
        title: 'Water',
        series: b.water,
        days: days,
        featureName: 'water',
        formatValue: (v) => '${_fmtInt(v)} ml',
        centerValue: (_) => '${b.water.goalPercent!.round()}%',
        centerCaption: 'of goal',
        ringHeadline: (_) =>
            'avg ${(b.water.average! / 1000).toStringAsFixed(1)} L · goal ${(b.water.goal! / 1000).toStringAsFixed(1)} L',
        barHeadline: b.water.hasData
            ? '${(b.water.average! / 1000).toStringAsFixed(1)} L avg'
            : '—',
        barGoalLabel: b.water.goal != null
            ? 'Goal ${(b.water.goal! / 1000).toStringAsFixed(1)} L'
            : null,
        onTap: () => _open(const AquaWaterDashboard()),
      ),
      // STEPS — ring vs the stored/adaptive step goal.
      _goalCard(
        ext: ext,
        accent: ext.steps,
        icon: Symbols.directions_walk_rounded,
        title: 'Steps',
        series: b.steps,
        days: days,
        featureName: 'steps',
        formatValue: (v) => '${_fmtInt(v)} steps',
        centerValue: (_) => '${b.steps.goalPercent!.round()}%',
        centerCaption: 'of goal',
        ringHeadline: (_) =>
            '${_fmtInt(b.steps.average!)}/day · goal ${_fmtInt(b.steps.goal!)}',
        barHeadline: b.steps.hasData ? '${_fmtInt(b.steps.average!)} avg' : '—',
        barGoalLabel:
            b.steps.goal != null ? 'Goal ${_fmtInt(b.steps.goal!)}' : null,
        onTap: () => _open(const StepsDashboardScreen()),
      ),
      // SLEEP — ring vs the schedule's nightly target.
      _goalCard(
        ext: ext,
        accent: ext.sleep,
        icon: Symbols.bedtime_rounded,
        title: 'Sleep',
        series: b.sleep,
        days: days,
        featureName: 'sleep',
        formatValue: _fmtHours,
        centerValue: (_) => _fmtHours(b.sleep.average!),
        centerCaption: 'avg/night',
        ringHeadline: (gp) =>
            'target ${_goalHours(b.sleep.goal!)} · ${(gp * 100).round()}% of goal',
        barHeadline: b.sleep.hasData
            ? '${b.sleep.average!.toStringAsFixed(1)} h avg'
            : '—',
        onTap: () => _open(const SleepDashboardScreen()),
      ),
      // FOCUS — ring vs a sensible daily focus target.
      _goalCard(
        ext: ext,
        accent: ext.focus,
        icon: Symbols.self_improvement_rounded,
        title: 'Focus',
        series: b.focus,
        days: days,
        featureName: 'focus',
        formatValue: (v) => '${v.round()} min',
        centerValue: (_) => _fmtDuration(b.focus.average!),
        centerCaption: 'avg/day',
        ringHeadline: (_) =>
            'target ${kFocusDailyGoalMinutes.round()}m/day · ${_fmtDuration(b.focus.total!)} total',
        barHeadline: b.focus.hasData ? _fmtDuration(b.focus.total!) : '—',
        onTap: () => _open(const FocusScreen()),
      ),
      // BLOOD PRESSURE — 2-line chart with a healthy-range band behind it.
      TrendChartCard(
        accent: VitalsColors.bpAccent(ext.isDark),
        icon: Symbols.monitor_heart_rounded,
        title: 'Blood pressure',
        headline: (b.bloodPressure.latest != null &&
                b.bloodPressure.latest2 != null)
            ? '${b.bloodPressure.latest!.round()}/${b.bloodPressure.latest2!.round()}'
            : '—',
        series: b.bloodPressure,
        kind: TrendChartKind.line,
        seriesLabels: const ['Sys', 'Dia'],
        rangeDays: days,
        featureName: 'blood pressure',
        formatValue: (v) => v.round().toString(),
        bands: [
          TrendBand(90, 120, bandGreen), // systolic normal
          TrendBand(60, 80, bandGreen), // diastolic normal
        ],
        onTap: () => _open(const BloodPressureScreen()),
      ),
      // GLUCOSE — Time-in-Range card (ADA CGM standard).
      TrendTimeInRangeCard(
        accent: VitalsColors.glucoseAccent(ext.isDark),
        icon: Symbols.bloodtype_rounded,
        title: 'Blood sugar',
        tir: b.glucoseTir,
        series: b.glucose,
        rangeDays: days,
        featureName: 'glucose',
        formatValue: (v) => '${v.round()} mg/dL',
        onTap: () => _open(const BloodSugarScreen()),
      ),
      // WEIGHT — simple line chart, no target band (no universal good/bad).
      TrendChartCard(
        accent: VitalsColors.weightAccent(ext.isDark),
        icon: Symbols.monitor_weight_rounded,
        title: 'Weight',
        headline:
            b.weight.latest != null ? '${b.weight.latest!.toStringAsFixed(1)} kg' : '—',
        series: b.weight,
        kind: TrendChartKind.line,
        rangeDays: days,
        featureName: 'weight',
        formatValue: (v) => '${v.toStringAsFixed(1)} kg',
        onTap: () => _open(const WeightScreen()),
      ),
      // PERIOD — cycle ring when the day can be placed, else the flow strip.
      if (b.cycle != null)
        TrendRingCard(
          accent: ext.period,
          icon: Symbols.calendar_month_rounded,
          title: 'Cycle',
          ringProgress: b.cycle!.progress,
          centerValue: 'Day ${b.cycle!.dayOfCycle}',
          centerCaption: 'of ${b.cycle!.cycleLength}',
          headline: '${b.cycle!.phaseLabel} phase',
          series: b.period,
          miniMaxY: 4,
          rangeDays: days,
          featureName: 'flow',
          formatValue: _flowLabel,
          onTap: () => _open(const PeriodCalendarScreen()),
        )
      else
        TrendChartCard(
          accent: ext.period,
          icon: Symbols.calendar_month_rounded,
          title: 'Period',
          headline: b.period.hasData ? '${b.period.loggedDays} days' : '—',
          series: b.period,
          kind: TrendChartKind.bar,
          maxY: 4,
          rangeDays: days,
          featureName: 'flow',
          formatValue: _flowLabel,
          onTap: () => _open(const PeriodCalendarScreen()),
        ),
    ];

    // At-a-glance summary on top, then the per-feature small-multiples, and the
    // medical disclaimer last — this is the app's main interpretation surface, so
    // it carries the same "not a diagnosis" footnote the Insights hub did.
    cards.insert(0, _summaryCard(ext, b));
    cards.add(const SafetyDisclaimerBar());

    return RefreshIndicator(
      color: ext.brand.base,
      onRefresh: _reload,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(AppSpacing.gutter, AppSpacing.lg,
            AppSpacing.gutter, AppSpacing.huge),
        itemCount: cards.length,
        separatorBuilder: (_, i) => const SizedBox(height: AppSpacing.lg),
        itemBuilder: (_, i) => cards[i],
      ),
    );
  }

  /// Rebuild the bundle from storage. Used by pull-to-refresh and by the
  /// medicine-revision listener.
  Future<void> _reload() async {
    if (!mounted) return;
    setState(() => _future = TrendsDataService.build(_range));
    await _future;
  }

  /// A calm at-a-glance header: how many areas are tracked this range + the one
  /// goal-based feature most on track (positive framing, never a "worst" callout).
  Widget _summaryCard(AppColorsExt ext, TrendsBundle b) {
    final tt = Theme.of(context).textTheme;

    final allSeries = <TrendSeries>[
      b.adherence, b.water, b.steps, b.sleep, b.focus,
      b.bloodPressure, b.glucose, b.weight, b.period,
    ];
    final tracked = allSeries.where((s) => s.hasData).length;

    final goals = <MapEntry<String, double>>[];
    void addGoal(String name, double? gp) {
      if (gp != null) goals.add(MapEntry(name, gp));
    }
    addGoal('Medicine', b.adherence.goalProgress);
    addGoal('Water', b.water.goalProgress);
    addGoal('Steps', b.steps.goalProgress);
    addGoal('Sleep', b.sleep.goalProgress);
    addGoal('Focus', b.focus.goalProgress);
    goals.sort((a, c) => c.value.compareTo(a.value));
    final top = goals.isNotEmpty ? goals.first : null;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                    color: ext.brand.container, borderRadius: AppRadius.brMd),
                child: Icon(Symbols.monitoring_rounded,
                    size: 20, color: ext.brand.onContainer),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'LAST ${_range.label.toUpperCase()}',
                      style: tt.labelSmall?.copyWith(
                          color: ext.textTertiary, letterSpacing: 0.6),
                    ),
                    const SizedBox(height: 2),
                    Text('Tracking $tracked of ${allSeries.length} areas',
                        style: tt.titleLarge),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          if (tracked == 0)
            Text('Log a few days to see your trends build.',
                style: tt.bodyMedium?.copyWith(color: ext.textSecondary))
          else if (top != null)
            Row(
              children: [
                Icon(Symbols.check_circle_rounded,
                    size: 16, color: ext.mark(ext.success)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Best this period · ${top.key} at ${(top.value * 100).round()}% of goal',
                    style: tt.bodyMedium?.copyWith(color: ext.textSecondary),
                  ),
                ),
              ],
            )
          else
            Text('Keep logging to build your picture.',
                style: tt.bodyMedium?.copyWith(color: ext.textSecondary)),
        ],
      ),
    );
  }

  // ------------------------------------------------------------------ STATES

  Widget _loading(AppColorsExt ext) => ListView(
        padding: const EdgeInsets.fromLTRB(AppSpacing.gutter, AppSpacing.lg,
            AppSpacing.gutter, AppSpacing.huge),
        children: List.generate(
          4,
          (_) => Container(
            height: 208,
            margin: const EdgeInsets.only(bottom: AppSpacing.lg),
            decoration: BoxDecoration(
                color: ext.surfaceVariant, borderRadius: AppRadius.brCard),
          ),
        ),
      );

  Widget _error(AppColorsExt ext) {
    final tt = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Symbols.error_rounded, size: 32, color: ext.textTertiary),
            const SizedBox(height: AppSpacing.md),
            Text("Couldn't load your trends",
                textAlign: TextAlign.center,
                style: tt.headlineSmall?.copyWith(color: ext.textPrimary)),
            const SizedBox(height: 6),
            Text('Your data is safe — please try again.',
                textAlign: TextAlign.center,
                style: tt.bodyMedium?.copyWith(color: ext.textSecondary)),
            const SizedBox(height: AppSpacing.lg),
            AppButton(
              label: 'Try again',
              variant: AppButtonVariant.ghost,
              size: AppButtonSize.sm,
              leadingIcon: Symbols.refresh_rounded,
              accent: ext.brand,
              onPressed: () =>
                  setState(() => _future = TrendsDataService.build(_range)),
            ),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------------ HELPERS

  /// Builds a goal-progress card: a [TrendRingCard] when the series has a usable
  /// goal (so `goalProgress` resolves), otherwise the plain [TrendChartCard] bar
  /// chart — which also carries the shared empty state when there's no data.
  static Widget _goalCard({
    required AppColorsExt ext,
    required AccentSwatch accent,
    required IconData icon,
    required String title,
    required TrendSeries series,
    required int days,
    required String featureName,
    required String Function(double) formatValue,
    required String Function(double gp) centerValue,
    required String centerCaption,
    required String Function(double gp) ringHeadline,
    required String barHeadline,
    double? miniMaxY,
    double? barMaxY,
    String? barGoalLabel,
    VoidCallback? onTap,
  }) {
    final gp = series.goalProgress;
    if (gp != null) {
      return TrendRingCard(
        accent: accent,
        icon: icon,
        title: title,
        ringProgress: gp,
        centerValue: centerValue(gp),
        centerCaption: centerCaption,
        headline: ringHeadline(gp),
        trend: _goodTrend(series),
        series: series,
        miniMaxY: miniMaxY,
        rangeDays: days,
        featureName: featureName,
        formatValue: formatValue,
        onTap: onTap,
      );
    }
    return TrendChartCard(
      accent: accent,
      icon: icon,
      title: title,
      headline: barHeadline,
      trend: _goodTrend(series),
      series: series,
      kind: TrendChartKind.bar,
      maxY: barMaxY,
      goalLabel: barGoalLabel,
      rangeDays: days,
      featureName: featureName,
      formatValue: formatValue,
      onTap: onTap,
    );
  }

  /// Compact nightly-goal label ("8h" whole, "7.5h" otherwise).
  static String _goalHours(double h) =>
      h % 1 == 0 ? '${h.round()}h' : '${h.toStringAsFixed(1)}h';

  /// Trend arrow only for features where "up = good", and only when the series
  /// shows a real rise or fall (a flat/insufficient series shows no arrow).
  static StatTrend? _goodTrend(TrendSeries s) {
    switch (s.direction) {
      case 1:
        return StatTrend.up;
      case -1:
        return StatTrend.down;
      default:
        return null;
    }
  }

  static String _fmtInt(double v) {
    final s = v.round().toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return buf.toString();
  }

  static String _fmtHours(double hours) {
    final m = (hours * 60).round();
    return '${m ~/ 60}h ${m % 60}m';
  }

  static String _fmtDuration(double minutes) {
    final m = minutes.round();
    if (m < 60) return '${m}m';
    return '${m ~/ 60}h ${m % 60}m';
  }

  static String _flowLabel(double flowIndex) {
    switch (flowIndex.round()) {
      case 1:
        return 'Spotting';
      case 2:
        return 'Light';
      case 3:
        return 'Medium';
      case 4:
        return 'Heavy';
      default:
        return '—';
    }
  }
}
