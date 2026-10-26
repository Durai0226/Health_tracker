import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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
import '../widgets/patterns_section.dart';
import 'weekly_recap_screen.dart';

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

  /// A data change arrived while this screen was a HIDDEN tab; [_onPainted]
  /// flushes it the moment the tab is actually shown.
  bool _staleWhileHidden = false;

  void _onDataChanged() {
    if (!mounted) return;
    // As a root tab this screen is a permanent `IndexedStack` child: it stays
    // BUILT and LAID OUT while another tab is on screen. So logging a dose on
    // Today re-ran the entire bundle — four service `init()`s, four async
    // series, nine aggregations — for a screen nobody was looking at, on the
    // critical path of the tap that triggered it. Defer instead. The user sees
    // no difference: what they see is decided at the moment the tab appears,
    // and that is exactly when this reloads.
    if (!_isShowing) {
      _staleWhileHidden = true;
      return;
    }
    _reload();
  }

  /// Whether this screen is the SHOWN child of the shell's [IndexedStack].
  ///
  /// `IndexedStack` wraps every child in a [Visibility] and paints only the
  /// selected one — hidden children still build and still lay out, so neither
  /// `build` nor `didChangeDependencies` can tell the difference. That wrapper
  /// widget is the one signal there is.
  ///
  /// Pushed as a route, or in a widget test, there is no such ancestor and this
  /// reports visible — which is the behaviour this screen has always had.
  bool get _isShowing =>
      context.findAncestorWidgetOfExactType<Visibility>()?.visible ?? true;

  /// Called every time this screen's subtree is actually painted.
  ///
  /// Coming to the front does not rebuild this widget: the shell hands
  /// `IndexedStack` the same `const TrendsDashboardScreen(isRoot: true)` every
  /// time, so `Element.updateChild` short-circuits and `build` never runs. A
  /// paint, though, only happens for the child on top — which makes it the
  /// arrival signal.
  void _onPainted() {
    if (!_staleWhileHidden) return;
    _staleWhileHidden = false;
    // We are inside the paint phase; setState here would be illegal.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _reload();
    });
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

  /// Whether the Patterns section has anything to show right now.
  bool _hasPatterns = false;

  void _open(Widget screen) {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    final ext = AppColorsExt.of(context);

    final scaffold = AppScaffold(
      body: Column(
        children: [
          AppHeader(
            title: 'Trends',
            // No back arrow on the root tab — there would be nothing to pop.
            leading: widget.isRoot
                ? null
                : AppHeader.backButton(context),
            // The recap was reachable only from the Health tab's list, a screen
            // away from where people go to look at how the week went.
            actions: [
              AppIconButton(
                icon: Symbols.calendar_view_week_rounded,
                filled: false,
                accent: ext.brand,
                tooltip: 'Weekly recap',
                onPressed: () => _open(const WeeklyRecapScreen()),
              ),
            ],
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
                final loading = snap.connectionState != ConnectionState.done;
                return AsyncSection<TrendsBundle>(
                  isLoading: loading,
                  // Stale-while-revalidate, expressed as data rather than as a
                  // branch: while a new range loads, the previous bundle IS the
                  // data. An error still resolves to null and surfaces the
                  // retry panel, which is the behaviour this screen already had
                  // and the one Connected Devices was missing.
                  data: snap.hasData
                      ? snap.data
                      : (loading ? _lastGood : null),
                  error: snap.error,
                  onRetry: _retry,
                  // No onRefresh here: _dashboard owns its own RefreshIndicator
                  // around the ListView, and nesting two of them gives the
                  // gesture two competing owners.
                  skeleton: const PageSkeleton.report(),
                  errorTitle: "Couldn't load your trends",
                  builder: (context, b) => _dashboard(ext, b),
                );
              },
            ),
          ),
        ],
      ),
    );

    // The probe is a paint listener, nothing more — it adds no box, no layer
    // and no layout. See [_onPainted].
    return _PaintProbe(onPaint: _onPainted, child: scaffold);
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
      TrendGoalCard.build(
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
      TrendGoalCard.build(
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
      TrendGoalCard.build(
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
      TrendGoalCard.build(
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
        // `goalPercent`, not the clamped `gp` the ring FILL is drawn from.
        // With a 7h target and eight-hour nights the centre printed "8.0 h"
        // and the line beneath it "100% of goal" — the card disagreeing with
        // itself about a number it prints twice.
        ringHeadline: (_) => 'target ${_goalHours(b.sleep.goal!)} · '
            '${b.sleep.goalPercent!.round()}% of goal',
        barHeadline: b.sleep.hasData
            ? '${b.sleep.average!.toStringAsFixed(1)} h avg'
            : '—',
        onTap: () => _open(const SleepDashboardScreen()),
      ),
      // FOCUS — a BAR, never a ring. This card used to draw a ring against
      // "target 60m/day" and report progress towards it; no such target exists
      // anywhere in the app, so it was this screen's own number presented as
      // the user's. A ring implies a denominator, and inventing one is the most
      // confident-looking way to be wrong. The Weekly Recap made the same call
      // for the same reason.
      TrendChartCard(
        accent: ext.focus,
        icon: Symbols.self_improvement_rounded,
        title: 'Focus',
        headline: b.focus.hasData ? _fmtDuration(b.focus.total!) : '—',
        trend: TrendGoalCard.goodTrend(b.focus),
        series: b.focus,
        kind: TrendChartKind.bar,
        rangeDays: days,
        featureName: 'focus',
        formatValue: (v) => '${v.round()} min',
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
    // Right under the summary: what the logs say across days. Reloads with the
    // bundle (same identity changes on every rebuild) and renders nothing when
    // there is nothing to say.
    cards.insert(
        1,
        PatternsSection(
          reloadKey: b,
          onResolved: (has) {
            if (has != _hasPatterns) setState(() => _hasPatterns = has);
          },
        ));
    cards.add(const SafetyDisclaimerBar());

    return RefreshIndicator(
      color: ext.brand.base,
      onRefresh: _reload,
      child: ListView.separated(
        padding: EdgeInsets.fromLTRB(AppSpacing.gutter, AppSpacing.lg,
            AppSpacing.gutter, AppInsets.pushed(context)),
        itemCount: cards.length,
        // The gap after the Patterns item is dropped while that section is
        // empty, so an empty section leaves no doubled gap behind it.
        separatorBuilder: (_, i) =>
            SizedBox(height: i == 1 && !_hasPatterns ? 0 : AppSpacing.lg),
        itemBuilder: (_, i) => cards[i],
      ),
    );
  }

  /// Rebuild the bundle from storage. Used by pull-to-refresh and by the
  /// medicine-revision listener.
  ///
  /// The body is a BLOCK, not `setState(() => _future = …)`. An arrow closure
  /// returns the value it assigns, `setState` asserts in debug that its
  /// callback returned nothing, and `TrendsDataService.build` returns a Future
  /// — so in a debug build every refresh threw "setState() callback argument
  /// returned a Future" before it had refreshed anything. Release builds skip
  /// the assert, which is why it went unnoticed.
  Future<void> _reload() async {
    if (!mounted) return;
    final next = TrendsDataService.build(_range);
    setState(() {
      _future = next;
    });
    await next;
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

    // `goalPercent`, not `goalProgress`.
    //
    // `goalProgress` is `.clamp(0.0, 1.0)` and exists for a ring's FILL;
    // `goalPercent` is the uncapped one, documented on `TrendSeries` as being
    // "for the ring's CENTRE label, so beating a goal reads honestly (e.g.
    // 128%)". This line is a label, and the feature cards below it already
    // print `goalPercent` — so one screen showed "Steps · 128%" on a card and
    // "Best this period · Steps at 100% of goal" in the summary above it.
    //
    // It also decides WHICH feature is named: sorted on the clamped value,
    // anything at or above goal ties at 1.0, so "best" was whichever happened
    // to be added first rather than the one actually furthest ahead.
    final goals = <MapEntry<String, double>>[];
    void addGoal(String name, double? gp) {
      if (gp != null) goals.add(MapEntry(name, gp));
    }
    addGoal('Medicine', b.adherence.goalPercent);
    addGoal('Water', b.water.goalPercent);
    addGoal('Steps', b.steps.goalPercent);
    addGoal('Sleep', b.sleep.goalPercent);
    // Focus is absent on purpose: it has no stored goal, so it can never be
    // "most on track" against one.
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
                    AppEyebrow('LAST ${_range.label.toUpperCase()}'),
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
                    'Best this period · ${top.key} at ${top.value.round()}% of goal',
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

  /// Block body for the same reason as [_reload].
  void _retry() {
    final next = TrendsDataService.build(_range);
    setState(() {
      _future = next;
    });
  }

  // ------------------------------------------------------------------ HELPERS

  /// Compact nightly-goal label ("8h" whole, "7.5h" otherwise).
  static String _goalHours(double h) =>
      h % 1 == 0 ? '${h.round()}h' : '${h.toStringAsFixed(1)}h';

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

/// Calls [onPaint] whenever its subtree is painted.
///
/// A hidden `IndexedStack` child is built and laid out like any other, but it
/// is never painted — `RenderIndexedStack` paints only the child at `index`,
/// and the `Visibility` wrapper around it returns early as well. So "my paint
/// ran" is the one thing a tab can observe that means *I am on screen now*.
///
/// [RenderProxyBox] with nothing but a `paint` override: no extra box, no
/// layer, no effect on layout or hit testing.
class _PaintProbe extends SingleChildRenderObjectWidget {
  const _PaintProbe({required this.onPaint, required Widget super.child});

  final VoidCallback onPaint;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderPaintProbe(onPaint);

  @override
  void updateRenderObject(BuildContext context, _RenderPaintProbe renderObject) {
    renderObject.onPaint = onPaint;
  }
}

class _RenderPaintProbe extends RenderProxyBox {
  _RenderPaintProbe(this.onPaint);

  VoidCallback onPaint;

  @override
  void paint(PaintingContext context, Offset offset) {
    onPaint();
    super.paint(context, offset);
  }
}
