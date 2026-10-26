import 'package:flutter/material.dart';

import '../../../core/design/app_colors_ext.dart';
import '../../../core/health/usual_range.dart';
import '../../../core/widgets/app/app_widgets.dart';
import '../../medication/screens/vitals/vitals_trend_chart.dart';

/// A 30-day line chart of one daily measurement with a shaded band for the
/// person's OWN usual range, taken from the days before today.
///
/// Today is deliberately left out of the range it is judged against, and the
/// band appears only with [UsualRangeCalc.minValues] earlier days. Before that
/// the card says what it is waiting for rather than drawing a band it cannot
/// stand behind.
class UsualRangeChartCard extends StatelessWidget {
  const UsualRangeChartCard({
    super.key,
    required this.title,
    required this.unit,
    required this.points,
    required this.today,
    this.minHalfWidth = 0,
    this.decimals = 0,
    this.lines = const [],
  });

  final String title;

  /// "bpm", "ms", "%" — printed after the range in the legend.
  final String unit;

  /// `(date, value)`, oldest first.
  final List<({DateTime date, double value})> points;

  /// The last day of the window. Its value is not part of its own range.
  final DateTime today;
  final double minHalfWidth;
  final int decimals;

  /// Extra lines under the chart (an average, a status, a caveat).
  final List<Widget> lines;

  /// Values strictly before [today]'s date.
  List<double> get _earlier {
    final t = DateTime(today.year, today.month, today.day);
    return [
      for (final p in points)
        if (DateTime(p.date.year, p.date.month, p.date.day).isBefore(t)) p.value
    ];
  }

  UsualRange? get range =>
      UsualRangeCalc.compute(_earlier, minHalfWidth: minHalfWidth);

  String _fmt(double v) => v.toStringAsFixed(decimals);

  @override
  Widget build(BuildContext context) {
    final ext = AppColorsExt.of(context);
    final tt = Theme.of(context).textTheme;
    final accent = ext.medicine;
    final r = range;

    final values = [for (final p in points) p.value];
    var lo = values.reduce((a, b) => a < b ? a : b);
    var hi = values.reduce((a, b) => a > b ? a : b);
    if (r != null) {
      if (r.low < lo) lo = r.low;
      if (r.high > hi) hi = r.high;
    }
    final pad = ((hi - lo) * 0.15).clamp(1.0, double.infinity);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: tt.titleMedium?.copyWith(color: ext.textPrimary)),
          const SizedBox(height: AppSpacing.sm),
          VitalsTrendChart(
            series: [
              VitalsSeries(
                values: values,
                times: [for (final p in points) p.date],
                color: ext.chartMark(accent),
                label: title,
              ),
            ],
            minY: lo - pad,
            maxY: hi + pad,
            bandLow: r?.low,
            bandHigh: r?.high,
            bandColor: ext.mark(accent),
            bandLabel: r == null
                ? null
                : 'Shaded band = your usual range (${_fmt(r.low)}–${_fmt(r.high)} '
                    '$unit), from your previous ${r.n} days',
          ),
          if (r == null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Your usual range appears after ${UsualRangeCalc.minValues} days of data.',
              style: tt.bodySmall?.copyWith(color: ext.textTertiary),
            ),
          ],
          for (final l in lines) ...[
            const SizedBox(height: AppSpacing.xs),
            l,
          ],
        ],
      ),
    );
  }
}
