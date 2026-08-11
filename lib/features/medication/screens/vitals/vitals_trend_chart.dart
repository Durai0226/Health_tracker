import 'package:flutter/material.dart';
import '../../../../core/design/app_design.dart';
import '../../../../core/design/app_colors_ext.dart';

/// One data series for the trend chart.
class VitalsSeries {
  final List<double> values; // oldest → newest
  final Color color;
  final String label;
  const VitalsSeries({required this.values, required this.color, required this.label});
}

/// A lightweight, dependency-free line trend chart with an optional shaded
/// target band. Handles 1–2 series (systolic/diastolic, or a single glucose
/// line). Empty/short data degrades gracefully.
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
                    labelColor: ext.textTertiary,
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
                  borderRadius: const BorderRadius.all(Radius.circular(3)),
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
  final Color bandColor, gridColor, labelColor;

  _TrendPainter({
    required this.series,
    required this.minY,
    required this.maxY,
    required this.bandLow,
    required this.bandHigh,
    required this.bandColor,
    required this.gridColor,
    required this.labelColor,
  });

  static const double _leftPad = 34;
  static const double _topPad = 8;
  static const double _botPad = 6;

  @override
  void paint(Canvas canvas, Size size) {
    final chartLeft = _leftPad;
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
      _label(canvas, v.round().toString(), Offset(0, y - 6), labelColor);
    }

    // Series polylines + dots.
    for (final s in series) {
      if (s.values.isEmpty) continue;
      final n = s.values.length;
      double xOf(int i) => n == 1 ? chartLeft + chartW / 2 : chartLeft + (i / (n - 1)) * chartW;

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

  void _label(Canvas canvas, String text, Offset at, Color color) {
    final tp = TextPainter(
      text: TextSpan(
          text: text, style: TextStyle(color: color, fontSize: 10)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, at);
  }

  @override
  bool shouldRepaint(covariant _TrendPainter old) =>
      old.series != series || old.minY != minY || old.maxY != maxY;
}
