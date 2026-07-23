import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/widgets/app/app_widgets.dart';
import '../services/trends_data_service.dart';

/// Whether a [TrendChartCard] renders its series as daily bars or as lines.
enum TrendChartKind { bar, line }

/// A faint horizontal reference zone painted BEHIND a line chart — e.g. the
/// blood-pressure healthy band or the glucose target range. The colour is a
/// reserved STATUS colour, always drawn low-opacity and paired with a label in
/// the surrounding UI (never colour-alone).
class TrendBand {
  final double lo;
  final double hi;
  final Color color;
  const TrendBand(this.lo, this.hi, this.color);
}

const List<FontFeature> _tabular = [FontFeature.tabularFigures()];
const List<String> _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];
const List<String> _weekdays = [
  'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun',
];

String _tooltipDate(DateTime d) =>
    '${_weekdays[d.weekday - 1]}, ${d.day} ${_months[d.month - 1]}';

/// A reusable small-multiple card: one feature, its FIXED accent, a header
/// (accent icon tile + title + tabular headline stat + optional trend arrow), a
/// chart body (bar or line, drawn with fl_chart), and an in-card empty state so
/// a feature with no data in the range still reads as "covered" rather than
/// broken.
class TrendChartCard extends StatelessWidget {
  /// The feature's fixed accent — never cycled or reused across cards.
  final AccentSwatch accent;
  final IconData icon;
  final String title;

  /// Tabular headline stat (e.g. "88% avg", "128/82"). Pass '—' when empty.
  final String headline;

  /// Optional trend arrow. Only supplied where "up = good" is unambiguous.
  final StatTrend? trend;

  final TrendSeries series;
  final TrendChartKind kind;
  final int rangeDays;

  /// Lower-case feature noun for the empty-state copy ("No {featureName}…").
  final String featureName;

  /// Formats a raw series value for the touch tooltip.
  final String Function(double value) formatValue;

  /// Optional caption under the title (e.g. "Goal 2.5 L").
  final String? goalLabel;

  /// For the single multi-series case (BP) — labels the two lines, in order
  /// [primary, secondary]. Null keeps the card single-series (no legend).
  final List<String>? seriesLabels;

  /// Optional fixed y-max (e.g. adherence = 100, period flow = 4).
  final double? maxY;

  /// Optional faint reference zones drawn behind a LINE chart (e.g. the BP
  /// healthy range). Ignored by bar charts.
  final List<TrendBand> bands;

  /// Optional drill-down — tapping the card opens the feature's own screen.
  final VoidCallback? onTap;

  const TrendChartCard({
    super.key,
    required this.accent,
    required this.icon,
    required this.title,
    required this.headline,
    required this.series,
    required this.kind,
    required this.rangeDays,
    required this.featureName,
    this.formatValue = _defaultFormat,
    this.trend,
    this.goalLabel,
    this.seriesLabels,
    this.maxY,
    this.bands = const [],
    this.onTap,
  });

  static String _defaultFormat(double v) => v.toStringAsFixed(0);

  @override
  Widget build(BuildContext context) {
    final ext = AppColorsExt.of(context);
    final tt = Theme.of(context).textTheme;
    final hasData = series.hasData;

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _header(ext, tt),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            height: 128,
            child: hasData ? _chart(context, ext) : _empty(ext, tt),
          ),
          if (hasData && seriesLabels != null && seriesLabels!.length >= 2) ...[
            const SizedBox(height: AppSpacing.sm),
            _legend(ext, tt),
          ],
        ],
      ),
    );
  }

  // ------------------------------------------------------------------ HEADER

  Widget _header(AppColorsExt ext, TextTheme tt) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
              color: accent.container, borderRadius: AppRadius.brMd),
          child: Icon(icon, size: 20, color: accent.onContainer),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: tt.titleMedium
                      ?.copyWith(color: ext.textPrimary, fontWeight: FontWeight.w700)),
              if (goalLabel != null)
                Text(goalLabel!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: tt.bodySmall?.copyWith(color: ext.textTertiary)),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Text(headline,
            maxLines: 1,
            style: tt.headlineSmall?.copyWith(
                color: ext.textPrimary,
                fontWeight: FontWeight.w800,
                fontFeatures: _tabular,
                letterSpacing: -0.3)),
        if (trend != null) ...[
          const SizedBox(width: 4),
          Icon(_trendIcon(trend!), size: 18, color: _trendColor(ext, trend!)),
        ],
      ],
    );
  }

  Widget _legend(AppColorsExt ext, TextTheme tt) {
    final mark = ext.mark(accent);
    Widget item(Color c, String label) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
                width: 10,
                height: 3,
                decoration: BoxDecoration(
                    color: c, borderRadius: BorderRadius.circular(2))),
            const SizedBox(width: 6),
            Text(label, style: tt.labelSmall?.copyWith(color: ext.textTertiary)),
          ],
        );
    return Row(
      children: [
        item(mark, seriesLabels![0]),
        const SizedBox(width: AppSpacing.md),
        item(mark.withOpacity(0.5), seriesLabels![1]),
      ],
    );
  }

  // -------------------------------------------------------------- EMPTY STATE

  Widget _empty(AppColorsExt ext, TextTheme tt) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        child: Text(
          'No $featureName logged in the last $rangeDays days — log to see the trend',
          textAlign: TextAlign.center,
          style: tt.bodySmall?.copyWith(color: ext.textTertiary, height: 1.4),
        ),
      ),
    );
  }

  // -------------------------------------------------------------------- CHART

  Widget _chart(BuildContext context, AppColorsExt ext) {
    final animate = !MediaQuery.of(context).disableAnimations;
    if (kind == TrendChartKind.line) {
      return _TrendLineChart(
        series: series,
        ext: ext,
        primaryColor: ext.mark(accent),
        seriesLabels: seriesLabels,
        formatValue: formatValue,
        rangeDays: rangeDays,
        animate: animate,
        bands: bands,
      );
    }
    return _TrendBarChart(
      series: series,
      ext: ext,
      barColor: ext.mark(accent),
      maxY: maxY,
      formatValue: formatValue,
      rangeDays: rangeDays,
      animate: animate,
    );
  }

  static IconData _trendIcon(StatTrend t) => switch (t) {
        StatTrend.up => Symbols.trending_up_rounded,
        StatTrend.down => Symbols.trending_down_rounded,
        StatTrend.flat => Symbols.trending_flat_rounded,
      };

  static Color _trendColor(AppColorsExt ext, StatTrend t) => switch (t) {
        StatTrend.up => ext.success.base,
        StatTrend.down => ext.error.base,
        StatTrend.flat => ext.textTertiary,
      };
}

// ----------------------------------------------------------------- BAR CHART

class _TrendBarChart extends StatelessWidget {
  final TrendSeries series;
  final AppColorsExt ext;
  final Color barColor;
  final double? maxY;
  final String Function(double) formatValue;
  final int rangeDays;
  final bool animate;

  const _TrendBarChart({
    required this.series,
    required this.ext,
    required this.barColor,
    required this.maxY,
    required this.formatValue,
    required this.rangeDays,
    required this.animate,
  });

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final points = series.points;
    final n = points.length;
    final topY = maxY ?? _niceMax(series.maxValue, series.goal);
    final barWidth = rangeDays <= 7 ? 13.0 : (rangeDays <= 14 ? 8.0 : 5.0);
    final interval = topY / 3;

    final groups = <BarChartGroupData>[
      for (var i = 0; i < n; i++)
        BarChartGroupData(
          x: i,
          barRods: points[i].value == null
              ? const []
              : [
                  BarChartRodData(
                    toY: points[i].value!,
                    color: barColor,
                    width: barWidth,
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(4)),
                  ),
                ],
        ),
    ];

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceBetween,
        minY: 0,
        maxY: topY,
        barGroups: groups,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: interval <= 0 ? null : interval,
          getDrawingHorizontalLine: (_) =>
              FlLine(color: ext.outline, strokeWidth: 1),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          show: true,
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 22,
              interval: 1,
              getTitlesWidget: (value, meta) =>
                  _bottomDateLabel(value.toInt(), points, n, tt, ext),
            ),
          ),
        ),
        extraLinesData: series.goal == null
            ? const ExtraLinesData()
            : ExtraLinesData(horizontalLines: [
                HorizontalLine(
                  y: series.goal!,
                  color: barColor.withOpacity(0.45),
                  strokeWidth: 1,
                  dashArray: const [4, 4],
                ),
              ]),
        barTouchData: BarTouchData(
          enabled: true,
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => ext.surface,
            tooltipBorder: BorderSide(color: ext.outline),
            tooltipRoundedRadius: 10,
            fitInsideHorizontally: true,
            fitInsideVertically: true,
            getTooltipItem: (group, gi, rod, ri) => BarTooltipItem(
              formatValue(rod.toY),
              tt.labelLarge!.copyWith(
                  color: ext.textPrimary,
                  fontWeight: FontWeight.w800,
                  fontFeatures: _tabular),
              children: [
                TextSpan(
                  text: '\n${_tooltipDate(points[group.x.toInt()].date)}',
                  style:
                      tt.labelSmall!.copyWith(color: ext.textSecondary),
                ),
              ],
            ),
          ),
        ),
      ),
      duration: animate ? const Duration(milliseconds: 300) : Duration.zero,
    );
  }
}

// ---------------------------------------------------------------- LINE CHART

class _TrendLineChart extends StatelessWidget {
  final TrendSeries series;
  final AppColorsExt ext;
  final Color primaryColor;
  final List<String>? seriesLabels;
  final String Function(double) formatValue;
  final int rangeDays;
  final bool animate;
  final List<TrendBand> bands;

  const _TrendLineChart({
    required this.series,
    required this.ext,
    required this.primaryColor,
    required this.seriesLabels,
    required this.formatValue,
    required this.rangeDays,
    required this.animate,
    this.bands = const [],
  });

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final points = series.points;
    final n = points.length;
    final secondaryColor = primaryColor.withOpacity(0.5);

    final primarySpots = <FlSpot>[
      for (var i = 0; i < n; i++)
        if (points[i].value != null) FlSpot(i.toDouble(), points[i].value!),
    ];
    final secondarySpots = <FlSpot>[
      for (var i = 0; i < n; i++)
        if (points[i].value2 != null) FlSpot(i.toDouble(), points[i].value2!),
    ];

    // A clinical scale should breathe around the data, not start at zero.
    // Reference bands are pulled into view so the healthy zone is always a
    // visible frame for the readings, not clipped off-screen.
    final vals = <double>[
      for (final p in points) ...[
        if (p.value != null) p.value!,
        if (p.value2 != null) p.value2!,
      ],
      for (final b in bands) ...[b.lo, b.hi],
    ];
    var lo = vals.reduce((a, b) => a < b ? a : b);
    var hi = vals.reduce((a, b) => a > b ? a : b);
    final pad = ((hi - lo) * 0.2).clamp(8.0, double.infinity);
    final minY = (lo - pad).clamp(0.0, double.infinity);
    final maxY = hi + pad;
    final interval = ((maxY - minY) / 3).clamp(1.0, double.infinity);

    LineChartBarData lineOf(List<FlSpot> spots, Color color) => LineChartBarData(
          spots: spots,
          color: color,
          barWidth: 2,
          isCurved: false,
          dotData: FlDotData(
            show: true,
            getDotPainter: (spot, pct, bar, index) => FlDotCirclePainter(
                radius: 2.5, color: color, strokeWidth: 0),
          ),
        );

    return LineChart(
      LineChartData(
        minX: 0,
        maxX: (n - 1).toDouble(),
        minY: minY,
        maxY: maxY,
        rangeAnnotations: RangeAnnotations(
          horizontalRangeAnnotations: [
            for (final b in bands)
              HorizontalRangeAnnotation(y1: b.lo, y2: b.hi, color: b.color),
          ],
        ),
        lineBarsData: [
          lineOf(primarySpots, primaryColor),
          if (secondarySpots.isNotEmpty) lineOf(secondarySpots, secondaryColor),
        ],
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: interval,
          getDrawingHorizontalLine: (_) =>
              FlLine(color: ext.outline, strokeWidth: 1),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          show: true,
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              interval: interval,
              getTitlesWidget: (value, meta) {
                if (value <= meta.min || value >= meta.max) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Text(value.round().toString(),
                      style: tt.labelSmall
                          ?.copyWith(color: ext.textTertiary, fontFeatures: _tabular)),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 22,
              interval: 1,
              getTitlesWidget: (value, meta) =>
                  _bottomDateLabel(value.toInt(), points, n, tt, ext),
            ),
          ),
        ),
        lineTouchData: LineTouchData(
          enabled: true,
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => ext.surface,
            tooltipBorder: BorderSide(color: ext.outline),
            tooltipRoundedRadius: 10,
            fitInsideHorizontally: true,
            fitInsideVertically: true,
            getTooltipItems: (touchedSpots) {
              final labelled = seriesLabels != null;
              return touchedSpots.map((s) {
                final prefix = labelled && s.barIndex < seriesLabels!.length
                    ? '${seriesLabels![s.barIndex]} '
                    : '';
                return LineTooltipItem(
                  '$prefix${formatValue(s.y)}',
                  tt.labelLarge!.copyWith(
                      color: ext.textPrimary,
                      fontWeight: FontWeight.w800,
                      fontFeatures: _tabular),
                  children: labelled
                      ? null
                      : [
                          TextSpan(
                            text:
                                '\n${_tooltipDate(points[s.x.round()].date)}',
                            style: tt.labelSmall!
                                .copyWith(color: ext.textSecondary),
                          ),
                        ],
                );
              }).toList();
            },
          ),
        ),
      ),
      duration: animate ? const Duration(milliseconds: 300) : Duration.zero,
    );
  }
}

// ----------------------------------------------------------------- RING CARD

/// A goal-progress card (Apple Fitness / Oura grammar): a [ProgressRing] on the
/// LEFT whose fill is the range's average of daily value ÷ goal, its centre the
/// key figure; on the RIGHT the title, a one-line headline, and a COMPACT mini
/// bar chart of the daily pattern. Used for metrics that have a real goal
/// (Water, Steps, Sleep, Focus, Medicine adherence). Falls back to the plain
/// [TrendChartCard] bar chart at the call site when no goal is available.
class TrendRingCard extends StatelessWidget {
  /// The feature's fixed accent — the ring fill AND the mini bars.
  final AccentSwatch accent;
  final IconData icon;
  final String title;

  /// Ring fill 0..1 (already clamped by the caller).
  final double ringProgress;

  /// The big tabular figure in the ring centre (e.g. "83%", "7h20m").
  final String centerValue;

  /// Tiny caption under [centerValue] (e.g. "of goal", "avg/day"). Null hides.
  final String? centerCaption;

  /// One-line headline to the right (e.g. "avg 2.1 L · goal 2.5 L").
  final String headline;

  /// Trend arrow — only supplied where "up = good".
  final StatTrend? trend;

  /// The daily series behind the mini bar chart (and empty-state detection).
  final TrendSeries series;

  /// Optional fixed y-max for the mini bars (e.g. adherence = 100).
  final double? miniMaxY;

  /// Optional drill-down — tapping the card opens the feature's own screen.
  final VoidCallback? onTap;

  final int rangeDays;
  final String featureName;
  final String Function(double) formatValue;

  const TrendRingCard({
    super.key,
    required this.accent,
    required this.icon,
    required this.title,
    required this.ringProgress,
    required this.centerValue,
    required this.headline,
    required this.series,
    required this.rangeDays,
    required this.featureName,
    required this.formatValue,
    this.centerCaption,
    this.trend,
    this.miniMaxY,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final ext = AppColorsExt.of(context);
    final tt = Theme.of(context).textTheme;
    final animate = !MediaQuery.of(context).disableAnimations;

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          ProgressRing(
            progress: ringProgress,
            size: 76,
            stroke: 9,
            accent: accent,
            animate: animate,
            center: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    centerValue,
                    maxLines: 1,
                    style: tt.titleMedium?.copyWith(
                      color: ext.textPrimary,
                      fontWeight: FontWeight.w800,
                      fontFeatures: _tabular,
                      letterSpacing: -0.3,
                    ),
                  ),
                ),
                if (centerCaption != null)
                  Text(
                    centerCaption!,
                    maxLines: 1,
                    style: tt.labelSmall?.copyWith(color: ext.textTertiary),
                  ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Icon(icon, size: 16, color: ext.mark(accent)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: tt.titleMedium?.copyWith(
                            color: ext.textPrimary,
                            fontWeight: FontWeight.w700),
                      ),
                    ),
                    if (trend != null) ...[
                      const SizedBox(width: 4),
                      Icon(_trendIconOf(trend!),
                          size: 18, color: _trendColorOf(ext, trend!)),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  headline,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: tt.bodyMedium?.copyWith(
                      color: ext.textSecondary, fontFeatures: _tabular),
                ),
                const SizedBox(height: AppSpacing.sm),
                SizedBox(
                  height: 44,
                  child: series.hasData
                      ? _MiniBarChart(
                          series: series,
                          ext: ext,
                          barColor: ext.mark(accent),
                          maxY: miniMaxY,
                          formatValue: formatValue,
                          rangeDays: rangeDays,
                          animate: animate,
                        )
                      : Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'No $featureName logged in the last $rangeDays days',
                            maxLines: 2,
                            style: tt.bodySmall?.copyWith(
                                color: ext.textTertiary, height: 1.3),
                          ),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------- MINI BAR CHART

/// A tiny (~44px) recessive bar chart of the daily pattern — thin rounded bars
/// in the accent over a faint baseline, gaps left empty (never zero bars),
/// touch tooltips retained. No axes: the ring + headline carry the numbers.
class _MiniBarChart extends StatelessWidget {
  final TrendSeries series;
  final AppColorsExt ext;
  final Color barColor;
  final double? maxY;
  final String Function(double) formatValue;
  final int rangeDays;
  final bool animate;

  const _MiniBarChart({
    required this.series,
    required this.ext,
    required this.barColor,
    required this.maxY,
    required this.formatValue,
    required this.rangeDays,
    required this.animate,
  });

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    // This is an axis-less sparkline (no date labels), so we plot ONLY the
    // logged days spread across the full width. Keeping an empty x-slot for
    // every un-logged day (as the full-size, date-labelled chart does) made
    // sparse recent-only data cluster into one corner and read as "collapsed".
    final logged = [
      for (final p in series.points)
        if (p.value != null) p
    ];
    final n = logged.length;
    final topY = maxY ?? _niceMax(series.maxValue, series.goal);
    final barWidth = rangeDays <= 7 ? 9.0 : (rangeDays <= 14 ? 6.0 : 4.0);

    final groups = <BarChartGroupData>[
      for (var i = 0; i < n; i++)
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: logged[i].value!,
              color: barColor,
              width: barWidth,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(4)),
            ),
          ],
        ),
    ];

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceBetween,
        minY: 0,
        maxY: topY,
        barGroups: groups,
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(
          show: true,
          border: Border(bottom: BorderSide(color: ext.outline, width: 1)),
        ),
        titlesData: const FlTitlesData(show: false),
        barTouchData: BarTouchData(
          enabled: true,
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => ext.surface,
            tooltipBorder: BorderSide(color: ext.outline),
            tooltipRoundedRadius: 10,
            fitInsideHorizontally: true,
            fitInsideVertically: true,
            getTooltipItem: (group, gi, rod, ri) => BarTooltipItem(
              formatValue(rod.toY),
              tt.labelLarge!.copyWith(
                  color: ext.textPrimary,
                  fontWeight: FontWeight.w800,
                  fontFeatures: _tabular),
              children: [
                TextSpan(
                  text: '\n${_tooltipDate(logged[group.x.toInt()].date)}',
                  style: tt.labelSmall!.copyWith(color: ext.textSecondary),
                ),
              ],
            ),
          ),
        ),
      ),
      duration: animate ? const Duration(milliseconds: 300) : Duration.zero,
    );
  }
}

// ----------------------------------------------------------- TIME-IN-RANGE CARD

/// The glucose Time-in-Range card (ADA CGM standard): a stacked segmented bar
/// of Low / In-range / High time (reserved STATUS colours, each with its own %
/// label), a green "in range" headline, and below it the daily glucose line
/// with the 70–180 target band shaded faintly behind it.
class TrendTimeInRangeCard extends StatelessWidget {
  final AccentSwatch accent; // glucose accent — the LINE colour
  final IconData icon;
  final String title;
  final GlucoseTir tir;
  final TrendSeries series; // daily glucose means for the line
  final int rangeDays;
  final String featureName;
  final String Function(double) formatValue;

  /// Optional drill-down — tapping the card opens the feature's own screen.
  final VoidCallback? onTap;

  const TrendTimeInRangeCard({
    super.key,
    required this.accent,
    required this.icon,
    required this.title,
    required this.tir,
    required this.series,
    required this.rangeDays,
    required this.featureName,
    required this.formatValue,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final ext = AppColorsExt.of(context);
    final tt = Theme.of(context).textTheme;
    final animate = !MediaQuery.of(context).disableAnimations;
    final hasData = tir.hasData;

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header — icon tile + title + green "in range" headline.
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                    color: accent.container, borderRadius: AppRadius.brMd),
                child: Icon(icon, size: 20, color: accent.onContainer),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: tt.titleMedium?.copyWith(
                        color: ext.textPrimary, fontWeight: FontWeight.w700)),
              ),
              const SizedBox(width: 10),
              Text(
                hasData ? '${tir.inRangePct.round()}% in range' : '—',
                maxLines: 1,
                style: tt.titleMedium?.copyWith(
                    color: hasData ? ext.mark(ext.success) : ext.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontFeatures: _tabular),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          if (!hasData)
            SizedBox(
              height: 128,
              child: Center(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                  child: Text(
                    'No $featureName logged in the last $rangeDays days — log to see the trend',
                    textAlign: TextAlign.center,
                    style: tt.bodySmall
                        ?.copyWith(color: ext.textTertiary, height: 1.4),
                  ),
                ),
              ),
            )
          else ...[
            _segmentedBar(ext, tt),
            const SizedBox(height: AppSpacing.md),
            _breakdown(ext, tt),
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              height: 120,
              child: _TrendLineChart(
                series: series,
                ext: ext,
                primaryColor: ext.mark(accent),
                seriesLabels: null,
                formatValue: formatValue,
                rangeDays: rangeDays,
                animate: animate,
                bands: [
                  TrendBand(
                    kGlucoseLowThreshold.toDouble(),
                    kGlucoseHighThreshold.toDouble(),
                    ext.mark(ext.success).withOpacity(ext.isDark ? 0.16 : 0.12),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // Stacked segmented bar — proportional fills, 2px surface gaps between them,
  // % labels inside segments wide enough to read.
  Widget _segmentedBar(AppColorsExt ext, TextTheme tt) {
    final segments = <(int, Color, Color, double)>[
      if (tir.low > 0)
        (tir.low, ext.fillBg(ext.warning), ext.fillFg(ext.warning), tir.lowPct),
      if (tir.inRange > 0)
        (
          tir.inRange,
          ext.fillBg(ext.success),
          ext.fillFg(ext.success),
          tir.inRangePct
        ),
      if (tir.high > 0)
        (tir.high, ext.fillBg(ext.error), ext.fillFg(ext.error), tir.highPct),
    ];
    final children = <Widget>[];
    for (var i = 0; i < segments.length; i++) {
      final (count, bg, fg, pct) = segments[i];
      if (i > 0) children.add(const SizedBox(width: 2)); // surface gap
      children.add(Expanded(
        flex: count,
        child: Container(
          height: 18,
          alignment: Alignment.center,
          decoration:
              BoxDecoration(color: bg, borderRadius: AppRadius.brFull),
          child: pct >= 12
              ? Text('${pct.round()}%',
                  maxLines: 1,
                  style: tt.labelSmall?.copyWith(
                      color: fg,
                      fontWeight: FontWeight.w700,
                      fontFeatures: _tabular))
              : null,
        ),
      ));
    }
    return Row(children: children);
  }

  // Labelled breakdown so every segment's % is named (never colour-alone).
  Widget _breakdown(AppColorsExt ext, TextTheme tt) {
    Widget row(Color c, String label, String range, double pct) => Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration:
                    BoxDecoration(color: c, borderRadius: BorderRadius.circular(3)),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(label,
                  style: tt.bodySmall?.copyWith(
                      color: ext.textPrimary, fontWeight: FontWeight.w600)),
              const SizedBox(width: 6),
              Text(range,
                  style: tt.labelSmall?.copyWith(
                      color: ext.textTertiary, fontFeatures: _tabular)),
              const Spacer(),
              Text('${pct.round()}%',
                  style: tt.bodySmall?.copyWith(
                      color: ext.textSecondary,
                      fontWeight: FontWeight.w700,
                      fontFeatures: _tabular)),
            ],
          ),
        );
    return Column(
      children: [
        row(ext.fillBg(ext.error), 'High', '> $kGlucoseHighThreshold', tir.highPct),
        row(ext.fillBg(ext.success), 'In range',
            '$kGlucoseLowThreshold–$kGlucoseHighThreshold', tir.inRangePct),
        row(ext.fillBg(ext.warning), 'Low', '< $kGlucoseLowThreshold', tir.lowPct),
      ],
    );
  }
}

// -------------------------------------------------------------------- SHARED

IconData _trendIconOf(StatTrend t) => switch (t) {
      StatTrend.up => Symbols.trending_up_rounded,
      StatTrend.down => Symbols.trending_down_rounded,
      StatTrend.flat => Symbols.trending_flat_rounded,
    };

Color _trendColorOf(AppColorsExt ext, StatTrend t) => switch (t) {
      StatTrend.up => ext.success.base,
      StatTrend.down => ext.error.base,
      StatTrend.flat => ext.textTertiary,
    };

/// A sparse bottom date axis: ~4 evenly-spaced 'M/d' labels, never one per day.
Widget _bottomDateLabel(
    int i, List<TrendPoint> points, int n, TextTheme tt, AppColorsExt ext) {
  if (i < 0 || i >= n) return const SizedBox.shrink();
  final step = (n / 4).ceil();
  if (i % step != 0) return const SizedBox.shrink();
  final d = points[i].date;
  return Padding(
    padding: const EdgeInsets.only(top: 6),
    child: Text('${d.month}/${d.day}',
        style: tt.labelSmall?.copyWith(color: ext.textTertiary, fontFeatures: _tabular)),
  );
}

/// Rounds a raw max (respecting an optional goal) up to a calm axis ceiling
/// with a little headroom above the tallest bar / the goal line.
double _niceMax(double dataMax, double? goal) {
  var m = dataMax;
  if (goal != null && goal > m) m = goal;
  if (m <= 0) return 1;
  m *= 1.15; // headroom
  // Snap to a readable step so gridlines land on round-ish numbers.
  final magnitude =
      _pow10((m).floor().toString().length - 1).toDouble();
  final step = magnitude <= 0 ? 1.0 : magnitude / 2;
  return (m / step).ceil() * step;
}

int _pow10(int e) {
  var r = 1;
  for (var i = 0; i < e; i++) {
    r *= 10;
  }
  return r;
}
