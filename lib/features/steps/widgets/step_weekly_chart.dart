import 'package:flutter/material.dart';
import 'package:tablet_remainder/core/widgets/app/app_widgets.dart';

/// One bar's data in the weekly chart.
class StepDayBar {
  final String label; // "M", "T", ...
  final int steps;
  final bool isToday;
  final bool reached;

  const StepDayBar({
    required this.label,
    required this.steps,
    this.isToday = false,
    this.reached = false,
  });
}

/// Seven token-coloured bars against a dashed goal line. Reached days use the
/// success tone, others the steps accent; today is emphasised with a ring and a
/// bold label. Bars animate up gated on `!disableAnimations`.
class StepWeeklyChart extends StatelessWidget {
  final List<StepDayBar> data;
  final int goalSteps;
  final double height;

  const StepWeeklyChart({
    super.key,
    required this.data,
    required this.goalSteps,
    this.height = 148,
  });

  @override
  Widget build(BuildContext context) {
    final ext = AppColorsExt.of(context);
    final tt = Theme.of(context).textTheme;
    final animate = !MediaQuery.of(context).disableAnimations;

    final maxSteps = data.fold<int>(0, (m, d) => d.steps > m ? d.steps : m);
    // Headroom so the goal line + tallest bar both sit comfortably.
    final scaleMax =
        [maxSteps, goalSteps, 1].reduce((a, b) => a > b ? a : b) * 1.15;
    final goalFraction = goalSteps > 0 ? (goalSteps / scaleMax).clamp(0.0, 1.0) : 0.0;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('This week', style: tt.titleLarge),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: ext.steps.container,
                  borderRadius: AppRadius.brFull,
                ),
                child: Text(
                  'Goal ${_short(goalSteps)}',
                  style: tt.labelSmall?.copyWith(
                    color: ext.steps.onContainer,
                    fontWeight: FontWeight.w700,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            height: height,
            child: Stack(
              children: [
                // Goal line.
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: goalFraction * height,
                  child: _DashedLine(color: ext.outlineStrong),
                ),
                // Bars.
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (final d in data)
                      Expanded(
                        child: _Bar(
                          datum: d,
                          fraction:
                              scaleMax > 0 ? (d.steps / scaleMax).clamp(0.0, 1.0) : 0.0,
                          maxHeight: height,
                          animate: animate,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              for (final d in data)
                Expanded(
                  child: Text(
                    d.label,
                    textAlign: TextAlign.center,
                    style: tt.labelSmall?.copyWith(
                      color: d.isToday ? ext.mark(ext.steps) : ext.textTertiary,
                      fontWeight: d.isToday ? FontWeight.w800 : FontWeight.w500,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  static String _short(int n) {
    if (n >= 1000) {
      final k = n / 1000.0;
      return '${k.toStringAsFixed(k >= 10 ? 0 : 1)}k';
    }
    return '$n';
  }
}

class _Bar extends StatelessWidget {
  final StepDayBar datum;
  final double fraction;
  final double maxHeight;
  final bool animate;

  const _Bar({
    required this.datum,
    required this.fraction,
    required this.maxHeight,
    required this.animate,
  });

  @override
  Widget build(BuildContext context) {
    final ext = AppColorsExt.of(context);
    final color = datum.steps <= 0
        ? ext.outline
        : (datum.reached ? ext.mark(ext.success) : ext.mark(ext.steps));
    // Small floor so empty days still show a faint stub.
    final target = datum.steps <= 0 ? 3.0 : (fraction * maxHeight).clamp(4.0, maxHeight);

    final bar = Container(
      decoration: BoxDecoration(
        color: color,
        borderRadius: AppRadius.brSm,
        border: datum.isToday
            ? Border.all(color: ext.textPrimary.withValues(alpha: 0.35), width: 1.5)
            : null,
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 5),
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

class _DashedLine extends StatelessWidget {
  final Color color;
  const _DashedLine({required this.color});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 1,
      child: LayoutBuilder(
        builder: (context, constraints) {
          const dash = 5.0;
          const gap = 4.0;
          final count = (constraints.maxWidth / (dash + gap)).floor();
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(
              count < 0 ? 0 : count,
              (_) => Container(width: dash, height: 1, color: color),
            ),
          );
        },
      ),
    );
  }
}
