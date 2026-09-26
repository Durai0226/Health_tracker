import 'package:flutter/material.dart';
import '../../../../core/design/app_design.dart';
import '../../../../core/design/app_colors_ext.dart';

/// One data series for the trend chart.
class VitalsSeries {
  final List<double> values; // oldest → newest

  /// When each of [values] was recorded, oldest → newest and the same length.
  ///
  /// Supplied on every series the chart draws, the points are laid out on a
  /// real time axis: a burst of readings an hour apart draws as a cluster and
  /// a month-long gap draws as a gap. Omitted (the default) — or omitted by
  /// any one series on a multi-series chart — points are spaced evenly by
  /// index, which is the honest layout only for a series that is already one
  /// point per bucket, e.g. a seven-day run of daily totals. So a two-series
  /// chart must stamp BOTH series or neither.
  final List<DateTime>? times;

  final Color color;
  final String label;
  const VitalsSeries({
    required this.values,
    required this.color,
    required this.label,
    this.times,
  });

  /// [times] only when it can actually carry an axis: present, non-empty and
  /// one stamp per value. A mismatched list is ignored rather than thrown on —
  /// a trend chart is not worth crashing a health screen over.
  List<DateTime>? get axisTimes {
    final t = times;
    if (t == null || values.isEmpty || t.length != values.length) return null;
    return t;
  }
}

/// A lightweight, dependency-free line trend chart with an optional shaded
/// target band. Handles 1–2 series (systolic/diastolic, or a single glucose
/// line). Empty/short data degrades gracefully.
///
/// Points are placed on a time axis when every drawn series carries
/// [VitalsSeries.times], and evenly by index otherwise — see that field's doc
/// for which is right for a given series.
class VitalsTrendChart extends StatelessWidget {
  final List<VitalsSeries> series;
  final double minY;
  final double maxY;
  final double? bandLow;
  final double? bandHigh;
  final Color bandColor;

  /// What the shaded band *means*, e.g. "Shaded band is the normal range
  /// (90–120 mmHg)". A band with no explanation is unreadable — the reader has
  /// no way to tell a target range from a danger zone. When supplied (and a
  /// band is actually drawn) it renders as a legend line directly under the
  /// chart, with a swatch matching the band fill. Omit it and the chart renders
  /// exactly as before.
  final String? bandLabel;

  final double height;

  const VitalsTrendChart({
    super.key,
    required this.series,
    required this.minY,
    required this.maxY,
    this.bandLow,
    this.bandHigh,
    required this.bandColor,
    this.bandLabel,
    this.height = 180,
  });

  @override
  Widget build(BuildContext context) {
    final ext = AppColorsExt.of(context);
    final tt = Theme.of(context).textTheme;
    final hasData = series.any((s) => s.values.isNotEmpty);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: height,
          width: double.infinity,
          child: hasData
              ? CustomPaint(
                  painter: _TrendPainter(
                    series: series,
                    minY: minY,
                    maxY: maxY,
                    bandLow: bandLow,
                    bandHigh: bandHigh,
                    bandColor: bandColor,
                    gridColor: ext.outline,
                    // A CustomPainter has no BuildContext, so it cannot reach
                    // the theme or the text scaler on its own. Passing both in
                    // is what makes the axis labels the same 11pt as the legend
                    // beneath them and lets them grow with Dynamic Type — they
                    // were the only text on the screen that did not.
                    labelStyle: tt.labelSmall!.copyWith(color: ext.textTertiary),
                    textScaler: MediaQuery.textScalerOf(context),
                  ),
                )
              : Center(
                  child: Text('Not enough data yet',
                      style: tt.bodyMedium?.copyWith(color: ext.textTertiary)),
                ),
        ),
        if (series.length > 1) ...[
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.md,
            children: series
                .map((s) => Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                                color: s.color, shape: BoxShape.circle)),
                        const SizedBox(width: 6),
                        Text(s.label,
                            style: tt.bodySmall
                                ?.copyWith(color: ext.textSecondary)),
                      ],
                    ))
                .toList(),
          ),
        ],
        // Explains the shaded band. Only rendered when a caller supplies a
        // label AND a band is actually drawn, so charts that omit it are
        // pixel-identical to before. Laid out as its own full-width row (not a
        // Wrap chip) so a long sentence wraps onto more lines instead of
        // overflowing.
        if (bandLabel != null && bandLow != null && bandHigh != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 16,
                height: 10,
                margin: const EdgeInsets.only(top: 3),
                decoration: BoxDecoration(
                  color: bandColor.withOpacity(0.12),
                  borderRadius: AppRadius.brSm,
                  border: Border.all(
                      color: bandColor.withOpacity(0.45), width: 0.8),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(bandLabel!,
                    style: tt.bodySmall?.copyWith(color: ext.textSecondary)),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _TrendPainter extends CustomPainter {
  final List<VitalsSeries> series;
  final double minY, maxY;
  final double? bandLow, bandHigh;
  final Color bandColor, gridColor;
  final TextStyle labelStyle;
  final TextScaler textScaler;

  _TrendPainter({
    required this.series,
    required this.minY,
    required this.maxY,
    required this.bandLow,
    required this.bandHigh,
    required this.bandColor,
    required this.gridColor,
    required this.labelStyle,
    required this.textScaler,
  });

  /// Minimum y-axis gutter. The real one is measured — see [paint].
  static const double _minLeftPad = 34;
  static const double _topPad = 8;
  static const double _botPad = 6;

  /// Earliest and latest stamp across the drawn series, so two series on one
  /// chart share a single axis instead of each stretching to its own extremes.
  ///
  /// All-or-nothing: null unless EVERY series that will actually be drawn
  /// carries usable stamps. Mixing the two layouts would put systolic on a
  /// time axis and diastolic on ordinal in the same plot — same pixel column
  /// meaning two different moments, which is a worse lie than spacing both by
  /// index. Empty series are skipped by [paint], so they do not veto the axis.
  static (DateTime, DateTime)? _timeDomain(List<VitalsSeries> series) {
    DateTime? lo, hi;
    for (final s in series) {
      if (s.values.isEmpty) continue;
      final ts = s.axisTimes;
      if (ts == null) return null;
      for (final t in ts) {
        if (lo == null || t.isBefore(lo)) lo = t;
        if (hi == null || t.isAfter(hi)) hi = t;
      }
    }
    return (lo == null || hi == null) ? null : (lo, hi);
  }

  @override
  void paint(Canvas canvas, Size size) {
    // The three y labels are the only thing in the gutter, so the gutter has to
    // be as wide as the widest of them ONCE SCALED. At 1.0x "120" measures about
    // 19pt and the constant wins, so the chart is pixel-identical to before; at
    // 2.0x it doubles and would otherwise have been painted over the plot.
    final labels = [minY, (minY + maxY) / 2, maxY]
        .map((v) => v.round().toString())
        .toList();
    final labelW = labels.map(_measure).reduce((a, b) => a > b ? a : b);
    final chartLeft = labelW + 6 > _minLeftPad ? labelW + 6 : _minLeftPad;
    final chartRight = size.width;
    final chartTop = _topPad;
    final chartBottom = size.height - _botPad;
    final chartW = chartRight - chartLeft;
    final chartH = chartBottom - chartTop;
    final range = (maxY - minY).abs() < 1 ? 1 : (maxY - minY);

    double yOf(double v) => chartBottom - ((v - minY) / range) * chartH;

    // Target band.
    if (bandLow != null && bandHigh != null) {
      final top = yOf(bandHigh!.clamp(minY, maxY));
      final bot = yOf(bandLow!.clamp(minY, maxY));
      canvas.drawRect(
        Rect.fromLTRB(chartLeft, top, chartRight, bot),
        Paint()..color = bandColor.withOpacity(0.12),
      );
    }

    // Horizontal gridlines + y labels (min / mid / max).
    final grid = Paint()
      ..color = gridColor.withOpacity(0.5)
      ..strokeWidth = 0.6;
    for (final v in [minY, (minY + maxY) / 2, maxY]) {
      final y = yOf(v);
      canvas.drawLine(Offset(chartLeft, y), Offset(chartRight, y), grid);
      _label(canvas, v.round().toString(), Offset(0, y - 6));
    }

    // Shared x domain. Measured in microseconds because a span can be minutes
    // (a hypo being re-checked) or years, and inDays would floor the first to
    // zero and collapse the whole series onto one x.
    final domain = _timeDomain(series);
    final domainStart = domain?.$1;
    final spanUs =
        domain == null ? 0 : domain.$2.difference(domain.$1).inMicroseconds;

    // Series polylines + dots.
    for (final s in series) {
      if (s.values.isEmpty) continue;
      final n = s.values.length;
      final ts = s.axisTimes;
      // A real time axis when the whole chart is stamped (see [_timeDomain])
      // and the stamps actually span an interval; even index spacing
      // otherwise. The fallback covers the untimed callers and the degenerate
      // span — one reading, or several logged at the same instant — which
      // would divide by zero and pile every point on top of the first.
      double xOf(int i) {
        if (ts != null && domainStart != null && spanUs > 0) {
          final f = ts[i].difference(domainStart).inMicroseconds / spanUs;
          return chartLeft + f.clamp(0.0, 1.0) * chartW;
        }
        return n == 1
            ? chartLeft + chartW / 2
            : chartLeft + (i / (n - 1)) * chartW;
      }

      final line = Paint()
        ..color = s.color
        ..strokeWidth = 2.4
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      final path = Path();
      for (var i = 0; i < n; i++) {
        final o = Offset(xOf(i), yOf(s.values[i].clamp(minY, maxY)));
        if (i == 0) {
          path.moveTo(o.dx, o.dy);
        } else {
          path.lineTo(o.dx, o.dy);
        }
      }
      canvas.drawPath(path, line);

      final dot = Paint()..color = s.color;
      for (var i = 0; i < n; i++) {
        canvas.drawCircle(
            Offset(xOf(i), yOf(s.values[i].clamp(minY, maxY))), 2.6, dot);
      }
    }
  }

  TextPainter _paintFor(String text) => TextPainter(
        text: TextSpan(text: text, style: labelStyle),
        textDirection: TextDirection.ltr,
        textScaler: textScaler,
      )..layout();

  double _measure(String text) => _paintFor(text).width;

  void _label(Canvas canvas, String text, Offset at) {
    _paintFor(text).paint(canvas, at);
  }

  @override
  bool shouldRepaint(covariant _TrendPainter old) =>
      old.series != series ||
      old.minY != minY ||
      old.maxY != maxY ||
      // Without these the labels kept the size and colour of the first paint
      // across a Dynamic Type or light/dark change, which is the whole defect
      // this painter was fixed for.
      old.labelStyle != labelStyle ||
      old.textScaler != textScaler;
}
