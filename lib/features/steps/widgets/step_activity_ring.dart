import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:tablet_remainder/core/widgets/app/app_widgets.dart';
import '../theme/steps_theme.dart';
import '../utils/step_format.dart';

/// Bespoke activity ring for the steps hero: a bold progress arc around a big
/// tabular step count. When [progress] exceeds 1 a lighter "second lap" arc is
/// drawn over the full ring to show over-achievement. Animates on value change
/// only, gated on `!disableAnimations`.
class StepActivityRing extends StatelessWidget {
  final double progress; // 0..(>1)
  final int steps;
  final int goalSteps;
  final double size;
  final VoidCallback? onTap;

  const StepActivityRing({
    super.key,
    required this.progress,
    required this.steps,
    required this.goalSteps,
    this.size = 236,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final ext = AppColorsExt.of(context);
    final s = ext.steps;
    final tt = Theme.of(context).textTheme;
    final animate = !MediaQuery.of(context).disableAnimations;
    final reached = goalSteps > 0 && steps >= goalSteps;
    final pct = (progress.clamp(0.0, 9.99) * 100).round();
    final ringColor = StepsTheme.bandColor(ext, progress);

    Widget ringFor(double v) => CustomPaint(
          size: Size.square(size),
          painter: _ActivityRingPainter(
            value: v,
            ring: ringColor,
            overflow: StepsTheme.overflowColor(ext),
            track: StepsTheme.trackColor(ext),
          ),
        );

    final ring = animate
        ? TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: progress.clamp(0.0, 9.99)),
            duration: AppMotion.fill,
            curve: AppMotion.emphasized,
            builder: (context, v, _) => ringFor(v),
          )
        : ringFor(progress.clamp(0.0, 9.99));

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            ring,
            // The centre stack has to fit INSIDE the ring's fixed box, and at
            // 2.0x Dynamic Type it does not: icon + 32px figure + caption +
            // pill overflowed the 236pt square vertically. The responsive sweep
            // could not even report it as an overflow — it surfaced as an
            // uncaught framework exception, which is why it went unseen while
            // that sweep ran against an empty database and this ring showed no
            // numbers at all.
            //
            // scaleDown never enlarges, so at ordinary text sizes this renders
            // exactly as before; only the cases that would clip are shrunk. The
            // horizontal padding keeps it off the ring stroke.
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Symbols.directions_walk_rounded,
                    size: 22, color: ext.mark(s)),
                const SizedBox(height: 4),
                Text(
                  formatThousands(steps),
                  style: tt.displayLarge?.copyWith(
                    color: ext.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontFeatures: const [FontFeature.tabularFigures()],
                    height: 1.0,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'of ${formatThousands(goalSteps)} steps',
                  style: tt.bodyMedium?.copyWith(color: ext.textSecondary),
                ),
                const SizedBox(height: 10),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: reached ? ext.success.container : s.container,
                    borderRadius: AppRadius.brFull,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        reached
                            ? Symbols.check_rounded
                            : Symbols.local_fire_department_rounded,
                        size: 13,
                        color:
                            reached ? ext.success.onContainer : s.onContainer,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        reached ? 'Goal reached' : '$pct%',
                        style: tt.labelSmall?.copyWith(
                          color: reached
                              ? ext.success.onContainer
                              : s.onContainer,
                          fontWeight: FontWeight.w700,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActivityRingPainter extends CustomPainter {
  final double value; // may exceed 1
  final Color ring;
  final Color overflow;
  final Color track;

  _ActivityRingPainter({
    required this.value,
    required this.ring,
    required this.overflow,
    required this.track,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    const stroke = 16.0;
    final radius = (size.width - stroke) / 2;
    const startAngle = -math.pi / 2;

    // Track.
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = track,
    );

    // First lap (0..1).
    final firstLap = value.clamp(0.0, 1.0);
    if (firstLap > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        2 * math.pi * firstLap,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = stroke
          ..color = ring,
      );
    }

    // Second lap (over-achievement) drawn lighter, on top.
    if (value > 1.0) {
      final secondLap = (value - 1.0).clamp(0.0, 1.0);
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        2 * math.pi * secondLap,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = stroke
          ..color = overflow,
      );
    }
  }

  @override
  bool shouldRepaint(_ActivityRingPainter old) =>
      old.value != value ||
      old.ring != ring ||
      old.overflow != overflow ||
      old.track != track;
}
