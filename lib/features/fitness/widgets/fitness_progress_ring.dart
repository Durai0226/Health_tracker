import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../theme/fitness_theme.dart';

/// Circular progress ring with gradient and glow
class FitnessProgressRing extends StatelessWidget {
  final double progress;
  final double size;
  final double strokeWidth;
  final Color? progressColor;
  final Color? trackColor;
  final Widget? child;
  final bool showGlow;
  final bool animate;

  const FitnessProgressRing({
    super.key,
    required this.progress,
    this.size = 120,
    this.strokeWidth = 10,
    this.progressColor,
    this.trackColor,
    this.child,
    this.showGlow = true,
    this.animate = true,
  });

  @override
  Widget build(BuildContext context) {
    final color = progressColor ?? FitnessTheme.primary;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Glow effect
          if (showGlow && progress > 0)
            Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: color.withOpacity(0.3 * progress),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ],
              ),
            ),
          // Progress ring
          CustomPaint(
            size: Size(size, size),
            painter: _ProgressRingPainter(
              progress: progress.clamp(0.0, 1.0),
              strokeWidth: strokeWidth,
              progressColor: color,
              trackColor: trackColor ?? FitnessTheme.surface,
            ),
          ),
          // Child widget
          if (child != null) child!,
        ],
      ),
    );
  }
}

class _ProgressRingPainter extends CustomPainter {
  final double progress;
  final double strokeWidth;
  final Color progressColor;
  final Color trackColor;

  _ProgressRingPainter({
    required this.progress,
    required this.strokeWidth,
    required this.progressColor,
    required this.trackColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    // Draw track
    final trackPaint = Paint()
      ..color = trackColor
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, trackPaint);

    // Draw progress
    if (progress > 0) {
      final progressPaint = Paint()
        ..shader = SweepGradient(
          startAngle: -math.pi / 2,
          endAngle: 3 * math.pi / 2,
          colors: [
            progressColor,
            progressColor.withOpacity(0.8),
            progressColor,
          ],
          stops: const [0.0, 0.5, 1.0],
          transform: GradientRotation(-math.pi / 2),
        ).createShader(Rect.fromCircle(center: center, radius: radius))
        ..strokeWidth = strokeWidth
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2,
        2 * math.pi * progress,
        false,
        progressPaint,
      );

      // Draw end cap glow
      if (progress > 0.05) {
        final endAngle = -math.pi / 2 + 2 * math.pi * progress;
        final endX = center.dx + radius * math.cos(endAngle);
        final endY = center.dy + radius * math.sin(endAngle);

        final glowPaint = Paint()
          ..color = progressColor.withOpacity(0.6)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

        canvas.drawCircle(Offset(endX, endY), strokeWidth / 2, glowPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ProgressRingPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.progressColor != progressColor ||
        oldDelegate.trackColor != trackColor;
  }
}

/// Animated progress ring with controller
class AnimatedProgressRing extends StatefulWidget {
  final double progress;
  final double size;
  final double strokeWidth;
  final Color? progressColor;
  final Widget? child;
  final Duration duration;

  const AnimatedProgressRing({
    super.key,
    required this.progress,
    this.size = 120,
    this.strokeWidth = 10,
    this.progressColor,
    this.child,
    this.duration = const Duration(milliseconds: 500),
  });

  @override
  State<AnimatedProgressRing> createState() => _AnimatedProgressRingState();
}

class _AnimatedProgressRingState extends State<AnimatedProgressRing>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  double _previousProgress = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _animation = Tween<double>(begin: 0, end: widget.progress).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    _controller.forward();
  }

  @override
  void didUpdateWidget(AnimatedProgressRing oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.progress != widget.progress) {
      _previousProgress = _animation.value;
      _animation = Tween<double>(
        begin: _previousProgress,
        end: widget.progress,
      ).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
      );
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return FitnessProgressRing(
          progress: _animation.value,
          size: widget.size,
          strokeWidth: widget.strokeWidth,
          progressColor: widget.progressColor,
          child: widget.child,
        );
      },
    );
  }
}

/// Timer ring with countdown display
class TimerProgressRing extends StatelessWidget {
  final int totalSeconds;
  final int remainingSeconds;
  final double size;
  final bool showMinutes;
  final Color? color;

  const TimerProgressRing({
    super.key,
    required this.totalSeconds,
    required this.remainingSeconds,
    this.size = 200,
    this.showMinutes = true,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final progress = totalSeconds > 0 ? remainingSeconds / totalSeconds : 0.0;
    final minutes = remainingSeconds ~/ 60;
    final seconds = remainingSeconds % 60;

    return FitnessProgressRing(
      progress: progress,
      size: size,
      strokeWidth: size * 0.05,
      progressColor: color ?? FitnessTheme.primary,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            showMinutes
                ? '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}'
                : seconds.toString(),
            style: FitnessTheme.timerMedium.copyWith(
              fontSize: size * 0.25,
            ),
          ),
          if (showMinutes)
            Text(
              'remaining',
              style: FitnessTheme.bodySm,
            ),
        ],
      ),
    );
  }
}

/// Weekly progress bars
class WeeklyProgressBars extends StatelessWidget {
  final List<double> values;
  final double maxValue;
  final double height;
  final List<String>? labels;

  const WeeklyProgressBars({
    super.key,
    required this.values,
    this.maxValue = 100,
    this.height = 100,
    this.labels,
  });

  @override
  Widget build(BuildContext context) {
    final defaultLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    final dayLabels = labels ?? defaultLabels;
    final today = DateTime.now().weekday - 1;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: List.generate(values.length, (index) {
        final progress = maxValue > 0 ? (values[index] / maxValue).clamp(0.0, 1.0) : 0.0;
        final isToday = index == today;

        return Column(
          children: [
            Container(
              width: 8,
              height: height,
              decoration: BoxDecoration(
                color: FitnessTheme.surface,
                borderRadius: FitnessTheme.borderRadiusSm,
              ),
              child: Align(
                alignment: Alignment.bottomCenter,
                child: AnimatedContainer(
                  duration: FitnessTheme.animationNormal,
                  width: 8,
                  height: height * progress,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        FitnessTheme.primary,
                        FitnessTheme.primary.withOpacity(0.6),
                      ],
                    ),
                    borderRadius: FitnessTheme.borderRadiusSm,
                    boxShadow: progress > 0
                        ? [
                            BoxShadow(
                              color: FitnessTheme.primary.withOpacity(0.4),
                              blurRadius: 8,
                              offset: const Offset(0, -2),
                            ),
                          ]
                        : null,
                  ),
                ),
              ),
            ),
            const SizedBox(height: FitnessTheme.spacingSm),
            Text(
              dayLabels[index],
              style: FitnessTheme.caption.copyWith(
                color: isToday ? FitnessTheme.primary : FitnessTheme.textMuted,
                fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        );
      }),
    );
  }
}

/// Streak indicator
class StreakIndicator extends StatelessWidget {
  final int streak;
  final int maxStreak;

  const StreakIndicator({
    super.key,
    required this.streak,
    this.maxStreak = 7,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(maxStreak, (index) {
        final isActive = index < streak;
        return Container(
          width: 12,
          height: 12,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isActive ? FitnessTheme.primary : FitnessTheme.surface,
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: FitnessTheme.primary.withOpacity(0.5),
                      blurRadius: 6,
                    ),
                  ]
                : null,
          ),
        );
      }),
    );
  }
}
