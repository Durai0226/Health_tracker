import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:tablet_remainder/core/widgets/app/app_widgets.dart';

/// 24 slim bars showing when steps happened across the day. Falls back to a calm
/// empty state when there's no hourly breakdown (e.g. manual-only days).
class StepHourlyChart extends StatelessWidget {
  final List<int> hourly; // length 24 (or empty)
  final double height;

  const StepHourlyChart({
    super.key,
    required this.hourly,
    this.height = 96,
  });

  @override
  Widget build(BuildContext context) {
    final ext = AppColorsExt.of(context);
    final tt = Theme.of(context).textTheme;
    final animate = !MediaQuery.of(context).disableAnimations;

    final hasData = hourly.length == 24 && hourly.any((v) => v > 0);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Symbols.schedule_rounded, size: 18, color: ext.mark(ext.steps)),
              const SizedBox(width: 8),
              Text('Active hours', style: tt.titleLarge),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          if (!hasData)
            SizedBox(
              height: height,
              child: Center(
                child: Text(
                  'No hourly breakdown yet',
                  style: tt.bodySmall?.copyWith(color: ext.textTertiary),
                ),
              ),
            )
          else ...[
            SizedBox(
              height: height,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (var h = 0; h < 24; h++)
                    Expanded(
                      child: _HourBar(
                        value: hourly[h],
                        max: hourly.reduce((a, b) => a > b ? a : b),
                        maxHeight: height,
                        animate: animate,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (final label in const ['12a', '6a', '12p', '6p', '11p'])
                  Text(label,
                      style:
                          tt.labelSmall?.copyWith(color: ext.textTertiary)),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _HourBar extends StatelessWidget {
  final int value;
  final int max;
  final double maxHeight;
  final bool animate;

  const _HourBar({
    required this.value,
    required this.max,
    required this.maxHeight,
    required this.animate,
  });

  @override
  Widget build(BuildContext context) {
    final ext = AppColorsExt.of(context);
    final fraction = max > 0 ? (value / max).clamp(0.0, 1.0) : 0.0;
    final target = value <= 0 ? 2.0 : (fraction * maxHeight).clamp(3.0, maxHeight);
    final color = value <= 0 ? ext.outline : ext.mark(ext.steps);

    final bar = Container(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(2),
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 1.5),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: animate
            ? TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: target),
                duration: AppMotion.fill,
                curve: AppMotion.emphasized,
                builder: (context, h, child) =>
                    SizedBox(height: h, width: double.infinity, child: child),
                child: bar,
              )
            : SizedBox(height: target, width: double.infinity, child: bar),
      ),
    );
  }
}
