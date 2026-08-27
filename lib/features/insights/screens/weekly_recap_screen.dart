import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/utils/date_formats.dart';
import '../../../core/widgets/app/app_widgets.dart';
import '../../../core/widgets/app/insight_kit.dart'
    show InsightCard, SafetyDisclaimerBar;
import '../services/insight_actions.dart';
import '../services/trends_data_service.dart';
import '../services/weekly_recap_service.dart';
import '../widgets/trend_chart_card.dart';

/// Your last seven days, as a scrollable report.
///
/// ## What this replaces
///
/// The previous version rendered **nine radial gauges** and no time series.
/// Four of those gauges had no denominator to be a fraction of:
///
/// | ring | expression | the problem |
/// |---|---|---|
/// | Avg BP | `s.bpAvg != null ? 1 : 0` | a **closed circle** meaning "a value exists", drawn beside "Avg BP 150/95" |
/// | Avg sugar | `s.glucoseAvg != null ? 1 : 0` | same |
/// | Focus | `s.focusMinutes / 150` | 150 minutes a week is a target nobody set |
/// | Readings | `s.readingsLogged / 14` | so is 14 readings |
///
/// The first two are worth dwelling on, because `ProgressRing`'s painter makes
/// them worse than they look: it subtracts a round-cap allowance, so only a
/// value of exactly `1.0` paints a **fully closed** circle. `? 1 : 0` therefore
/// renders the single most emphatic thing that widget can draw, to say nothing
/// more than "this field is not null".
///
/// A ring promises *this much of a limit*. Where there is no limit the honest
/// form is a bar, and that choice now lives in one place — [TrendGoalCard.build],
/// shared with Trends — so two screens cannot drift apart about when a ring is
/// earned. Water, steps, sleep and adherence keep theirs because
/// `TrendSeries.goal` is a real stored limit, and each falls back to a bar on its
/// own when that goal is unset.
///
/// ## Failure used to look like a new user
///
/// Every data block was wrapped in `catch (_) {}`. On a real database failure
/// `adherencePct` went null, which tripped the `primaryEmpty` branch, which
/// rendered *"Start logging and your recap fills in here"* — to somebody with
/// months of history. The retry panel existed and could not be reached.
///
/// Three smaller versions of the same fault, all removed by moving the gather
/// into [WeeklyRecapService]:
///
/// * `var regularity = 0.75` survived its swallowed exception, so a failed sleep
///   read rendered a plausible regularity index no data supported.
/// * `waterDays++` sat *inside* the loop it was wrapped in, so a throw partway
///   through silently reported a partial count as a whole week.
/// * `readings` accumulated with `+=` across two separate try blocks, so a
///   glucose failure yielded a blood-pressure-only count with nothing to say so.
///
/// The service separates the three facts the old screen collapsed: **null is "we
/// don't know", zero is "we measured zero", a throw is "ask again."**
class WeeklyRecapScreen extends StatefulWidget {
  const WeeklyRecapScreen({super.key});

  @override
  State<WeeklyRecapScreen> createState() => _WeeklyRecapScreenState();

  /// One card per measure, and only for trackers with data this week.
  ///
  /// A tracker never used gets no card at all, so somebody who does not
  /// menstruate never meets a permanently empty Cycle card on a page about
  /// their week. Every card here carries the chart table twin and the spoken
  /// summary from `trend_chart_card.dart`, so none of them is colour-only.
  ///
  /// **Static and `@visibleForTesting` on purpose.** Every card is gated on
  /// `series.hasData`, and this repo's widget tests run against an empty
  /// in-memory database — so pumping the screen renders NO cards and any
  /// assertion about them passes vacuously. That was not hypothetical: the
  /// first version of the "no ring without a limit" test stayed green while a
  /// deliberately fabricated focus ring was in the tree. Calling this directly
  /// with a hand-built bundle is what makes the assertion bite.
  @visibleForTesting
  static List<Widget> cardsFor(AppColorsExt ext, WeeklyRecap r) =>
      _cards(ext, r, r.bundle.range.days);

  static List<Widget> _cards(AppColorsExt ext, WeeklyRecap r, int days) {
    final b = r.bundle;
    // A reserved STATUS colour, always paired with the legend — never a series.
    final bandGreen =
        ext.mark(ext.success).withOpacity(ext.isDark ? 0.16 : 0.12);

    return [
      if (b.adherence.hasData)
        TrendGoalCard.build(
          ext: ext,
          accent: ext.medicine,
          icon: Symbols.medication_rounded,
          title: 'Medicine',
          series: b.adherence,
          days: days,
          featureName: 'doses',
          formatValue: (v) => '${v.round()}%',
          centerValue: (gp) => '${(gp * 100).round()}%',
          centerCaption: 'adherence',
          ringHeadline: (_) =>
              '${b.adherence.loggedDays} of $days days tracked',
          miniMaxY: 100,
          barHeadline: '${b.adherence.average!.round()}% avg',
          barMaxY: 100,
        ),

      if (b.water.hasData)
        TrendGoalCard.build(
          ext: ext,
          accent: ext.water,
          icon: Symbols.water_drop_rounded,
          title: 'Water',
          series: b.water,
          days: days,
          featureName: 'water',
          formatValue: (v) => '${v.round()} ml',
          centerValue: (_) => '${b.water.goalPercent!.round()}%',
          centerCaption: 'of goal',
          ringHeadline: (_) =>
              'avg ${(b.water.average! / 1000).toStringAsFixed(1)} L',
          barHeadline: '${(b.water.average! / 1000).toStringAsFixed(1)} L avg',
        ),

      if (b.steps.hasData)
        TrendGoalCard.build(
          ext: ext,
          accent: ext.steps,
          icon: Symbols.directions_walk_rounded,
          title: 'Steps',
          series: b.steps,
          days: days,
          featureName: 'steps',
          formatValue: (v) => '${v.round()} steps',
          centerValue: (_) => '${b.steps.goalPercent!.round()}%',
          centerCaption: 'of goal',
          ringHeadline: (_) => 'avg ${b.steps.average!.round()} a day',
          barHeadline: '${b.steps.average!.round()} avg',
        ),

      if (b.sleep.hasData)
        TrendGoalCard.build(
          ext: ext,
          accent: ext.sleep,
          icon: Symbols.bedtime_rounded,
          title: 'Sleep',
          series: b.sleep,
          days: days,
          featureName: 'sleep',
          formatValue: (v) => '${v.toStringAsFixed(1)}h',
          centerValue: (_) => '${b.sleep.goalPercent!.round()}%',
          centerCaption: 'of goal',
          ringHeadline: (_) =>
              'avg ${b.sleep.average!.toStringAsFixed(1)}h a night',
          barHeadline: '${b.sleep.average!.toStringAsFixed(1)}h avg',
        ),

      // A BAR, not a ring. The old screen drew focus against a hardcoded 150
      // minutes — a weekly target nobody set — and a ring against an invented
      // denominator is the most confident-looking way to be wrong.
      if (b.focus.hasData)
        TrendChartCard(
          accent: ext.focus,
          icon: Symbols.timer_rounded,
          title: 'Focus',
          headline: '${b.focus.total!.round()} min',
          trend: TrendGoalCard.goodTrend(b.focus),
          series: b.focus,
          kind: TrendChartKind.bar,
          rangeDays: days,
          featureName: 'focus',
          formatValue: (v) => '${v.round()} min',
        ),

      // Two series, ONE axis — both are mmHg, which is what makes this the only
      // legitimate multi-series card on the page. It is also the only form in
      // which "150/95" is legible at all; the old ring said only that it existed.
      if (b.bloodPressure.hasData)
        TrendChartCard(
          accent: ext.period,
          icon: Symbols.favorite_rounded,
          title: 'Blood pressure',
          headline: '${b.bloodPressure.latest!.round()}/'
              '${b.bloodPressure.latest2!.round()}',
          series: b.bloodPressure,
          kind: TrendChartKind.line,
          seriesLabels: const ['Sys', 'Dia'],
          bands: [TrendBand(60, 120, bandGreen)],
          rangeDays: days,
          featureName: 'blood pressure',
          formatValue: (v) => v.round().toString(),
        ),

      // Time-in-range: a share of readings that genuinely sums to 100, unlike a
      // ring meaning "a value exists".
      if (b.glucose.hasData)
        TrendTimeInRangeCard(
          accent: ext.medicine,
          icon: Symbols.glucose_rounded,
          title: 'Blood sugar',
          tir: b.glucoseTir,
          series: b.glucose,
          rangeDays: days,
          featureName: 'glucose',
          formatValue: (v) => '${v.round()} mg/dL',
        ),

      if (b.weight.hasData)
        TrendChartCard(
          accent: ext.brand,
          icon: Symbols.monitor_weight_rounded,
          title: 'Weight',
          // No trend arrow: weight has no universal good direction, which the
          // weight screen already argues in its own comment.
          headline: '${b.weight.latest!.toStringAsFixed(1)} kg',
          series: b.weight,
          kind: TrendChartKind.line,
          rangeDays: days,
          featureName: 'weight',
          formatValue: (v) => '${v.toStringAsFixed(1)} kg',
        ),
    ];
  }
}

class _WeeklyRecapScreenState extends State<WeeklyRecapScreen> {
  late Future<WeeklyRecap> _future;

  @override
  void initState() {
    super.initState();
    _future = WeeklyRecapService.load();
  }

  void _reload() => setState(() => _future = WeeklyRecapService.load());

  @override
  Widget build(BuildContext context) {
    final ext = AppColorsExt.of(context);

    return AppScaffold(
      body: Column(
        children: [
          AppHeader(
            title: 'Weekly recap',
            leading: AppHeader.backButton(context),
            bottom: Container(height: 1, color: ext.outline),
          ),
          Expanded(
            child: FutureBuilder<WeeklyRecap>(
              future: _future,
              builder: (context, snap) {
                final loading = snap.connectionState != ConnectionState.done;
                return AsyncSection<WeeklyRecap>(
                  isLoading: loading,
                  data: snap.hasData ? snap.data : null,
                  error: snap.error,
                  onRetry: _reload,
                  // A skeleton at the report's own rhythm. The old screen showed
                  // a centred spinner, which says nothing about what is coming.
                  skeleton: const PageSkeleton.report(),
                  errorTitle: "Couldn't load your recap",
                  errorMessage:
                      'Your data is safe — please try again. Nothing has been '
                      'lost.',
                  loadingSemanticLabel: 'Building your weekly recap',
                  banner: snap.hasData ? _partialBanner(snap.data!) : null,
                  builder: (context, recap) => _report(context, recap),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------------ BANNER

  /// Names what is missing rather than letting a partial week read as a quiet one.
  Widget? _partialBanner(WeeklyRecap r) {
    if (r.failedSources.isEmpty) return null;
    final ext = AppColorsExt.of(context);
    final tt = Theme.of(context).textTheme;
    return AppCard(
      child: Row(
        children: [
          Icon(Symbols.info_rounded, size: 20, color: ext.mark(ext.warning)),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              "Some of this week couldn't be loaded: "
              '${r.failedSources.join(', ')}. Everything else is below.',
              style: tt.bodySmall?.copyWith(color: ext.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------------ REPORT

  Widget _report(BuildContext context, WeeklyRecap r) {
    final ext = AppColorsExt.of(context);
    final accent = ext.brand;
    final days = r.bundle.range.days;
    final cards = WeeklyRecapScreen._cards(ext, r, days);

    return RefreshIndicator(
      color: accent.base,
      onRefresh: () async => _reload(),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(AppSpacing.gutter, AppSpacing.lg,
            AppSpacing.gutter, AppSpacing.huge),
        children: [
          // ---- Tier 1 — one figure, no chart at all. ---------------------
          _cover(ext, r),

          // Only when something WAS logged but nothing is chartable. With a
          // truly empty week the cover already says it, and saying it twice in
          // two different phrasings reads as a bug.
          if (cards.isEmpty && r.hero.hasValue) ...[
            const SizedBox(height: AppSpacing.lg),
            _emptyWeek(ext),
          ] else if (cards.isNotEmpty) ...[
            // ---- Tier 2 — one measure per card, never a dual axis. ------
            const SizedBox(height: AppSpacing.xl),
            SectionHeader(
                title: 'Your week, day by day',
                icon: Symbols.calendar_view_week_rounded,
                accent: accent),
            const SizedBox(height: AppSpacing.sm),
            for (final card in cards)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                child: card,
              ),
          ],

          // ---- Tier 3 — highlights. ------------------------------------
          if (r.highlights.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            SectionHeader(
                title: 'Highlights',
                icon: Symbols.star_rounded,
                accent: accent),
            const SizedBox(height: AppSpacing.sm),
            for (final i in r.highlights.take(4))
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: InsightCard(
                  insight: i,
                  onAction: InsightActions.of(context, i),
                ),
              ),
          ],

          const SizedBox(height: AppSpacing.lg),
          const SafetyDisclaimerBar(),
        ],
      ),
    );
  }

  // ------------------------------------------------------------------- COVER

  /// One figure, its denominator, and an optional delta. No ring.
  ///
  /// `displayLarge` is 32px, and stays 32px. That is this app's established hero
  /// size — `water_hero_gauge` and `step_activity_ring` both use it — so making
  /// the recap's cover bigger would be a change to the house scale, not a fix.
  ///
  /// What did change is the figures. The old cover applied `kTabular`, and
  /// tabular figures give every digit the width of a `0`, so a large standalone
  /// number reads loose. Proportional here; tabular only where numbers align in
  /// columns, which is what the table view exists for.
  Widget _cover(AppColorsExt ext, WeeklyRecap r) {
    final tt = Theme.of(context).textTheme;
    final on = ext.brand.onContainer;
    final hero = r.hero;

    final range = '${DateFormats.dayMonth.format(r.from).toUpperCase()} – '
        '${DateFormats.dayMonth.format(r.to).toUpperCase()}';

    return AppCard(
      color: ext.brand.container,
      padding: const EdgeInsets.all(AppSpacing.gutter),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('THIS WEEK · $range',
              style: tt.labelSmall
                  ?.copyWith(color: on.withOpacity(0.7), letterSpacing: 0.6)),
          if (hero.hasValue) ...[
            const SizedBox(height: AppSpacing.md),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      switch (hero.kind) {
                        RecapHeroKind.adherence => '${hero.value}%',
                        RecapHeroKind.daysLogged => '${hero.value}',
                      },
                      maxLines: 1,
                      style: tt.displayLarge?.copyWith(
                          color: on, fontWeight: FontWeight.w800, height: 1.0),
                    ),
                  ),
                ),
                if (hero.deltaPct != null && hero.deltaPct != 0) ...[
                  const SizedBox(width: AppSpacing.sm),
                  _deltaChip(ext, hero.deltaPct!),
                ],
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            // The denominator, always. "86%" alone is magic; "86% of doses
            // taken, across 5 days with doses due" is checkable.
            Text(
              switch (hero.kind) {
                RecapHeroKind.adherence =>
                  'of doses taken, ${hero.denominator}',
                RecapHeroKind.daysLogged => 'days logged ${hero.denominator}',
              },
              style: tt.bodyMedium?.copyWith(color: on.withOpacity(0.85)),
            ),
          ] else
            // No value — and deliberately not an em dash. The old screen had
            // four reachable em-dash sites; a dash is what a screen shows when
            // it has given up.
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Nothing logged yet this week.',
                      style:
                          tt.headlineSmall?.copyWith(color: on, height: 1.3)),
                  const SizedBox(height: AppSpacing.xs),
                  // The reassurance belongs here rather than in a second card
                  // saying the same thing differently. Somebody returning after
                  // a gap wants to know their history survived.
                  Text('Your history is still here — log anything and this '
                      'week starts filling in.',
                      style: tt.bodyMedium
                          ?.copyWith(color: on.withOpacity(0.85))),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _deltaChip(AppColorsExt ext, int delta) {
    final tt = Theme.of(context).textTheme;
    final up = delta > 0;
    // Adherence is the one hero here where "up" is unambiguously good.
    final swatch = up ? ext.success : ext.warning;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration:
          BoxDecoration(color: swatch.container, borderRadius: AppRadius.brFull),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(up ? Symbols.trending_up_rounded : Symbols.trending_down_rounded,
              size: 14, color: swatch.onContainer),
          const SizedBox(width: 4),
          Text('${up ? '+' : ''}$delta pts',
              style: tt.labelSmall?.copyWith(
                  color: swatch.onContainer, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _emptyWeek(AppColorsExt ext) {
    final tt = Theme.of(context).textTheme;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Nothing logged this week',
              style: tt.titleMedium?.copyWith(
                  color: ext.textPrimary, fontWeight: FontWeight.w700)),
          const SizedBox(height: AppSpacing.sm),
          // "You stopped" and "you are new" are different messages, and the old
          // screen said the second to both. This one says the history is still
          // there, which is what somebody returning after a gap wants to know.
          Text(
            'Your history is still here. Log anything and this week starts '
            'filling in.',
            style: tt.bodyMedium?.copyWith(color: ext.textSecondary),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------------- CARDS
}
