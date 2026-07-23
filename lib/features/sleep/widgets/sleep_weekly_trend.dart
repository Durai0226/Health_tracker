import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:tablet_remainder/core/widgets/app/app_widgets.dart';
import '../models/sleep_session.dart';

/// Seven nightly duration bars with a dashed target line. Missing nights render
/// as muted stubs (honest gaps). Bedtime consistency now lives in its own hero
/// card ([SleepConsistencyCard]), so this stays focused on duration-vs-target.
class SleepWeeklyTrend extends StatelessWidget {
  final List<SleepTrendDay> days;
  final int targetMinutes;

  const SleepWeeklyTrend({
    super.key,
    required this.days,
    required this.targetMinutes,
  });

  static const _chartHeight = 116.0;

  @override
  Widget build(BuildContext context) {
    final ext = AppColorsExt.of(context);
    final tt = Theme.of(context).textTheme;

    final maxAsleep = days.fold<int>(0, (a, d) => math.max(a, d.asleepMinutes));
    final maxVal = math.max(targetMinutes, math.max(maxAsleep, 1)).toDouble();
    final fractions =
        days.map((d) => (d.asleepMinutes / maxVal).clamp(0.0, 1.0)).toList();
    final targetFraction = (targetMinutes / maxVal).clamp(0.0, 1.0);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Symbols.bar_chart_rounded, size: 16, color: ext.mark(ext.sleep)),
              const SizedBox(width: 8),
              Expanded(child: Text('Last 7 nights', style: tt.titleMedium)),
              Text(
                'Target ${SleepSession.formatMinutes(targetMinutes)}',
                style: tt.labelSmall?.copyWith(color: ext.textTertiary),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            height: _chartHeight,
            child: LayoutBuilder(
              builder: (context, c) => CustomPaint(
                size: Size(c.maxWidth, _chartHeight),
                painter: _TrendPainter(
                  fractions: fractions,
                  targetFraction: targetFraction,
                  barColor: ext.mark(ext.sleep),
                  emptyColor: ext.outline,
                  lineColor: ext.textTertiary,
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              for (final d in days)
                Expanded(
                  child: Text(
                    _dayLetter(d.date),
                    textAlign: TextAlign.center,
                    style: tt.labelSmall?.copyWith(color: ext.textTertiary),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  static String _dayLetter(DateTime d) {
    const letters = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    return letters[(d.weekday - 1) % 7];
  }
}

class _TrendPainter extends CustomPainter {
  final List<double> fractions;
  final double targetFraction;
  final Color barColor;
  final Color emptyColor;
  final Color lineColor;

  _TrendPainter({
    required this.fractions,
    required this.targetFraction,
    required this.barColor,
    required this.emptyColor,
    required this.lineColor,
  });

  static const _topPad = 10.0;

  @override
  void paint(Canvas canvas, Size size) {
    final count = fractions.length;
    if (count == 0) return;
    final drawableH = size.height - _topPad;
    final slotW = size.width / count;
    final barW = math.min(16.0, slotW * 0.5);
    final radius = Radius.circular(barW / 2);
    final paint = Paint()..style = PaintingStyle.fill;

    for (var i = 0; i < count; i++) {
      final cx = slotW * i + slotW / 2;
      final frac = fractions[i];
      if (frac <= 0) {
        // Muted stub for a night with no data.
        paint.color = emptyColor;
        final stub = Rect.fromCenter(
          center: Offset(cx, size.height - 2),
          width: barW,
          height: 4,
        );
        canvas.drawRRect(
            RRect.fromRectAndRadius(stub, const Radius.circular(2)), paint);
        continue;
      }
      final h = frac * drawableH;
      paint.color = barColor;
      final rect = Rect.fromLTWH(cx - barW / 2, size.height - h, barW, h);
      canvas.drawRRect(
        RRect.fromRectAndCorners(rect, topLeft: radius, topRight: radius),
        paint,
      );
    }

    // Dashed target line.
    final y = size.height - targetFraction * drawableH;
    final linePaint = Paint()
      ..color = lineColor
      ..strokeWidth = 1.2;
    const dash = 5.0;
    const gap = 4.0;
    var x = 0.0;
    while (x < size.width) {
      canvas.drawLine(Offset(x, y), Offset(math.min(x + dash, size.width), y),
          linePaint);
      x += dash + gap;
    }
  }

  @override
  bool shouldRepaint(_TrendPainter old) =>
      old.fractions != fractions ||
      old.targetFraction != targetFraction ||
      old.barColor != barColor ||
      old.emptyColor != emptyColor ||
      old.lineColor != lineColor;
}
