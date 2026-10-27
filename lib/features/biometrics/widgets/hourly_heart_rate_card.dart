import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/widgets/app/app_widgets.dart';

/// Heart rate through the day, hour by hour: 24 slim bars of the hourly average,
/// with the lowest and highest hours named.
///
/// An hour with no sample is a gap, drawn as empty space — never as a short bar,
/// which would be a measured value no device recorded. Renders nothing when the
/// day has no hourly data at all.
///
/// The bars are painted, not built: twenty-four rows of padding, alignment and a
/// decorated box were a few hundred widgets on a screen that already holds
/// several charts, for something that never changes after it is drawn.
class HourlyHeartRateCard extends StatelessWidget {
  const HourlyHeartRateCard({
    super.key,
    required this.hourly,
    this.height = 96,
  });

  /// 24 hourly averages (bpm), null where the hour had no sample.
  final List<int?> hourly;
  final double height;

  /// The hours (0–23) with the lowest and the highest average, or null when no
  /// hour has one. A tie goes to the earlier hour.
  static ({int lowHour, int low, int highHour, int high})? extremes(
      List<int?> hourly) {
    int? lowHour, highHour;
    for (var h = 0; h < hourly.length && h < 24; h++) {
      final v = hourly[h];
      if (v == null) continue;
      if (lowHour == null || v < hourly[lowHour]!) lowHour = h;
      if (highHour == null || v > hourly[highHour]!) highHour = h;
    }
    if (lowHour == null || highHour == null) return null;
    return (
      lowHour: lowHour,
      low: hourly[lowHour]!,
      highHour: highHour,
      high: hourly[highHour]!,
    );
  }

  static const List<String> _axis = ['12a', '6a', '12p', '6p', '11p'];

  /// The painted bars, for a test to find and look inside.
  static const Key barsKey = ValueKey('hourly-heart-rate-bars');

  /// Room left between one bar and the next, shared by the two of them.
  static const double barGap = 3;

  /// The shortest a bar is drawn: a value is never rounded away to nothing.
  static const double minBarHeight = 3;

  /// Where each hour's bar sits in an area of [size], null for an hour with no
  /// sample. Empty when [hourly] is not a day or has nothing in it.
  ///
  /// The axis starts a little below the lowest hour, so the bars show the spread
  /// rather than all standing tall on a zero that heart rate never has.
  static List<Rect?> barRects(List<int?> hourly, Size size) {
    final e = hourly.length == 24 ? extremes(hourly) : null;
    if (e == null) return const [];
    final floor = (e.low - 10).clamp(0, 300);
    final span = (e.high - floor).clamp(1, 300);
    final slot = size.width / 24;
    final width = math.max(slot - barGap, 1.0);
    return [
      for (var h = 0; h < 24; h++)
        if (hourly[h] == null)
          null
        else
          () {
            final fraction = ((hourly[h]! - floor) / span).clamp(0.0, 1.0);
            // `clamp` throws when its bounds cross, which a sliver of an area
            // (shorter than the minimum bar) would otherwise make it do.
            final barHeight = (fraction * math.max(size.height - 4, 0))
                .clamp(math.min(minBarHeight, size.height), size.height)
                .toDouble();
            return Rect.fromLTWH(
                h * slot + barGap / 2, size.height - barHeight, width, barHeight);
          }(),
    ];
  }

  /// "3 am", "12 pm".
  static String hourLabel(int h) {
    final n = h % 12 == 0 ? 12 : h % 12;
    return '$n ${h < 12 ? 'am' : 'pm'}';
  }

  @override
  Widget build(BuildContext context) {
    if (hourly.length != 24) return const SizedBox.shrink();
    final e = extremes(hourly);
    if (e == null) return const SizedBox.shrink();

    final ext = AppColorsExt.of(context);
    final tt = Theme.of(context).textTheme;
    final accent = ext.medicine;

    return Semantics(
      container: true,
      label: 'Heart rate by hour. Lowest ${e.low} beats per minute around '
          '${hourLabel(e.lowHour)}, highest ${e.high} around ${hourLabel(e.highHour)}.',
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Symbols.schedule_rounded, size: 18, color: ext.mark(accent)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Heart rate by hour',
                      style: tt.titleMedium?.copyWith(color: ext.textPrimary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            ExcludeSemantics(
              child: SizedBox(
                height: height,
                width: double.infinity,
                child: CustomPaint(
                  key: barsKey,
                  painter: HourlyBarsPainter(
                      hourly: hourly, color: ext.mark(accent)),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            // Five labels share the width equally and shrink to their slot: at a
            // large text size they get smaller before they would overlap.
            ExcludeSemantics(
              child: Row(
                children: [
                  for (var i = 0; i < _axis.length; i++)
                    Expanded(
                      child: Align(
                        alignment: i == 0
                            ? Alignment.centerLeft
                            : i == _axis.length - 1
                                ? Alignment.centerRight
                                : Alignment.center,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(_axis[i],
                              style: tt.labelSmall
                                  ?.copyWith(color: ext.textTertiary)),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Lowest ${e.low} bpm around ${hourLabel(e.lowHour)} · '
              'highest ${e.high} bpm around ${hourLabel(e.highHour)}. '
              'Each bar is an hour\'s average.',
              style: tt.bodySmall?.copyWith(color: ext.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

/// Draws [HourlyHeartRateCard.barRects], one rounded bar for each hour that has
/// a value.
class HourlyBarsPainter extends CustomPainter {
  const HourlyBarsPainter({required this.hourly, required this.color});

  final List<int?> hourly;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    for (final bar in HourlyHeartRateCard.barRects(hourly, size)) {
      if (bar == null) continue;
      // A third of the bar's own short side: round enough to read as a bar, never
      // so round that a three-pixel bar turns into a dot.
      canvas.drawRRect(
          RRect.fromRectAndRadius(bar, Radius.circular(bar.shortestSide / 3)),
          paint);
    }
  }

  @override
  bool shouldRepaint(HourlyBarsPainter old) =>
      old.color != color || !listEquals(old.hourly, hourly);
}
