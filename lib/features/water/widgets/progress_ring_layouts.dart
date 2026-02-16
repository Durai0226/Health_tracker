import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../../../core/constants/app_colors.dart';

/// Different progress ring layout styles
enum ProgressRingStyle {
  classic,      // Simple circular progress
  wave,         // Water wave animation
  segments,     // Segmented ring
  gradient,     // Gradient ring
  minimalist,   // Thin minimal ring
  meter,        // Gauge/meter style
}

/// Main progress ring widget that supports multiple layouts
class HydrationProgressRing extends StatelessWidget {
  final double progress;
  final int currentMl;
  final int goalMl;
  final ProgressRingStyle style;
  final double size;
  final VoidCallback? onTap;

  const HydrationProgressRing({
    super.key,
    required this.progress,
    required this.currentMl,
    required this.goalMl,
    this.style = ProgressRingStyle.classic,
    this.size = 200,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    switch (style) {
      case ProgressRingStyle.classic:
        return _ClassicRing(
          progress: progress,
          currentMl: currentMl,
          goalMl: goalMl,
          size: size,
          onTap: onTap,
        );
      case ProgressRingStyle.wave:
        return _WaveRing(
          progress: progress,
          currentMl: currentMl,
          goalMl: goalMl,
          size: size,
          onTap: onTap,
        );
      case ProgressRingStyle.segments:
        return _SegmentedRing(
          progress: progress,
          currentMl: currentMl,
          goalMl: goalMl,
          size: size,
          onTap: onTap,
        );
      case ProgressRingStyle.gradient:
        return _GradientRing(
          progress: progress,
          currentMl: currentMl,
          goalMl: goalMl,
          size: size,
          onTap: onTap,
        );
      case ProgressRingStyle.minimalist:
        return _MinimalistRing(
          progress: progress,
          currentMl: currentMl,
          goalMl: goalMl,
          size: size,
          onTap: onTap,
        );
      case ProgressRingStyle.meter:
        return _MeterRing(
          progress: progress,
          currentMl: currentMl,
          goalMl: goalMl,
          size: size,
          onTap: onTap,
        );
    }
  }
}

/// Classic circular progress ring
class _ClassicRing extends StatelessWidget {
  final double progress;
  final int currentMl;
  final int goalMl;
  final double size;
  final VoidCallback? onTap;

  const _ClassicRing({
    required this.progress,
    required this.currentMl,
    required this.goalMl,
    required this.size,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = progress >= 1 ? AppColors.success : AppColors.info;
    
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: size,
              height: size,
              child: CircularProgressIndicator(
                value: progress.clamp(0.0, 1.0),
                strokeWidth: 12,
                backgroundColor: Colors.grey.shade200,
                valueColor: AlwaysStoppedAnimation(color),
              ),
            ),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (progress >= 1)
                  const Text('🎉', style: TextStyle(fontSize: 24)),
                Text(
                  '${currentMl}ml',
                  style: TextStyle(
                    fontSize: size * 0.14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'of ${goalMl}ml',
                  style: TextStyle(
                    fontSize: size * 0.06,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${(progress * 100).toInt()}%',
                    style: TextStyle(
                      fontSize: size * 0.07,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Wave animated ring (animated version needs StatefulWidget wrapper)
class _WaveRing extends StatefulWidget {
  final double progress;
  final int currentMl;
  final int goalMl;
  final double size;
  final VoidCallback? onTap;

  const _WaveRing({
    required this.progress,
    required this.currentMl,
    required this.goalMl,
    required this.size,
    this.onTap,
  });

  @override
  State<_WaveRing> createState() => _WaveRingState();
}

class _WaveRingState extends State<_WaveRing> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.progress >= 1 ? AppColors.success : AppColors.info;
    
    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.grey.shade300, width: 3),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.2),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipOval(
          child: Stack(
            children: [
              // Background
              Container(color: Colors.grey.shade100),
              // Water fill
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 500),
                  height: widget.size * widget.progress.clamp(0.0, 1.0),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        color.withOpacity(0.7),
                        color,
                      ],
                    ),
                  ),
                ),
              ),
              // Wave
              if (widget.progress > 0.05)
                AnimatedBuilder(
                  animation: _controller,
                  builder: (context, child) {
                    return Positioned(
                      bottom: widget.size * widget.progress.clamp(0.0, 1.0) - 10,
                      left: 0,
                      right: 0,
                      child: CustomPaint(
                        size: Size(widget.size, 20),
                        painter: WavePainter(
                          animationValue: _controller.value,
                          color: color.withOpacity(0.5),
                        ),
                      ),
                    );
                  },
                ),
              // Content
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (widget.progress >= 1)
                      const Text('🎉', style: TextStyle(fontSize: 28)),
                    Text(
                      '${widget.currentMl}ml',
                      style: TextStyle(
                        fontSize: widget.size * 0.12,
                        fontWeight: FontWeight.bold,
                        color: widget.progress > 0.5 ? Colors.white : AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      '${(widget.progress * 100).toInt()}%',
                      style: TextStyle(
                        fontSize: widget.size * 0.08,
                        fontWeight: FontWeight.w600,
                        color: widget.progress > 0.5 ? Colors.white70 : color,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Segmented ring with 8 segments
class _SegmentedRing extends StatelessWidget {
  final double progress;
  final int currentMl;
  final int goalMl;
  final double size;
  final VoidCallback? onTap;

  const _SegmentedRing({
    required this.progress,
    required this.currentMl,
    required this.goalMl,
    required this.size,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = progress >= 1 ? AppColors.success : AppColors.info;
    const segments = 8;
    final filledSegments = (progress * segments).ceil().clamp(0, segments);

    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            CustomPaint(
              size: Size(size, size),
              painter: SegmentedRingPainter(
                segments: segments,
                filledSegments: filledSegments,
                color: color,
                backgroundColor: Colors.grey.shade200,
              ),
            ),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '💧',
                  style: TextStyle(fontSize: size * 0.15),
                ),
                Text(
                  '${currentMl}ml',
                  style: TextStyle(
                    fontSize: size * 0.12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '$filledSegments/$segments',
                  style: TextStyle(
                    fontSize: size * 0.06,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Gradient ring with smooth color transition
class _GradientRing extends StatelessWidget {
  final double progress;
  final int currentMl;
  final int goalMl;
  final double size;
  final VoidCallback? onTap;

  const _GradientRing({
    required this.progress,
    required this.currentMl,
    required this.goalMl,
    required this.size,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            CustomPaint(
              size: Size(size, size),
              painter: GradientRingPainter(
                progress: progress.clamp(0.0, 1.0),
                strokeWidth: 14,
              ),
            ),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ShaderMask(
                  shaderCallback: (bounds) => const LinearGradient(
                    colors: [Colors.cyan, Colors.blue, Colors.purple],
                  ).createShader(bounds),
                  child: Text(
                    '${(progress * 100).toInt()}%',
                    style: TextStyle(
                      fontSize: size * 0.18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                Text(
                  '$currentMl/${goalMl}ml',
                  style: TextStyle(
                    fontSize: size * 0.06,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Minimalist thin ring
class _MinimalistRing extends StatelessWidget {
  final double progress;
  final int currentMl;
  final int goalMl;
  final double size;
  final VoidCallback? onTap;

  const _MinimalistRing({
    required this.progress,
    required this.currentMl,
    required this.goalMl,
    required this.size,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = progress >= 1 ? AppColors.success : AppColors.info;
    
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: size * 0.9,
              height: size * 0.9,
              child: CircularProgressIndicator(
                value: progress.clamp(0.0, 1.0),
                strokeWidth: 4,
                backgroundColor: Colors.grey.shade200,
                valueColor: AlwaysStoppedAnimation(color),
              ),
            ),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${(progress * 100).toInt()}',
                  style: TextStyle(
                    fontSize: size * 0.25,
                    fontWeight: FontWeight.w200,
                  ),
                ),
                Text(
                  'percent',
                  style: TextStyle(
                    fontSize: size * 0.05,
                    color: AppColors.textSecondary,
                    letterSpacing: 2,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Meter/gauge style ring
class _MeterRing extends StatelessWidget {
  final double progress;
  final int currentMl;
  final int goalMl;
  final double size;
  final VoidCallback? onTap;

  const _MeterRing({
    required this.progress,
    required this.currentMl,
    required this.goalMl,
    required this.size,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: size,
        height: size * 0.7,
        child: Stack(
          alignment: Alignment.center,
          children: [
            CustomPaint(
              size: Size(size, size * 0.7),
              painter: MeterPainter(
                progress: progress.clamp(0.0, 1.0),
              ),
            ),
            Positioned(
              bottom: 10,
              child: Column(
                children: [
                  Text(
                    '${currentMl}ml',
                    style: TextStyle(
                      fontSize: size * 0.12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Goal: ${goalMl}ml',
                    style: TextStyle(
                      fontSize: size * 0.05,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Custom painters

class WavePainter extends CustomPainter {
  final double animationValue;
  final Color color;

  WavePainter({required this.animationValue, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path();
    path.moveTo(0, size.height);

    for (double i = 0; i <= size.width; i++) {
      path.lineTo(
        i,
        size.height / 2 +
            math.sin((i / size.width * 2 * math.pi) + (animationValue * 2 * math.pi)) * 6,
      );
    }

    path.lineTo(size.width, size.height);
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant WavePainter oldDelegate) {
    return oldDelegate.animationValue != animationValue;
  }
}

class SegmentedRingPainter extends CustomPainter {
  final int segments;
  final int filledSegments;
  final Color color;
  final Color backgroundColor;

  SegmentedRingPainter({
    required this.segments,
    required this.filledSegments,
    required this.color,
    required this.backgroundColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 15;
    const strokeWidth = 12.0;
    const gap = 0.08; // Gap between segments in radians
    final segmentAngle = (2 * math.pi - gap * segments) / segments;

    for (int i = 0; i < segments; i++) {
      final startAngle = -math.pi / 2 + i * (segmentAngle + gap);
      final paint = Paint()
        ..color = i < filledSegments ? color : backgroundColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        segmentAngle,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant SegmentedRingPainter oldDelegate) {
    return oldDelegate.filledSegments != filledSegments;
  }
}

class GradientRingPainter extends CustomPainter {
  final double progress;
  final double strokeWidth;

  GradientRingPainter({required this.progress, required this.strokeWidth});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - strokeWidth;

    // Background
    final bgPaint = Paint()
      ..color = Colors.grey.shade200
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, bgPaint);

    // Gradient arc
    const gradient = SweepGradient(
      startAngle: -math.pi / 2,
      endAngle: 3 * math.pi / 2,
      colors: [
        Colors.cyan,
        Colors.blue,
        Colors.purple,
        Colors.pink,
      ],
    );

    final rect = Rect.fromCircle(center: center, radius: radius);
    final paint = Paint()
      ..shader = gradient.createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      rect,
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant GradientRingPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

class MeterPainter extends CustomPainter {
  final double progress;

  MeterPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height);
    final radius = size.width / 2 - 20;
    const strokeWidth = 16.0;

    // Background arc
    final bgPaint = Paint()
      ..color = Colors.grey.shade200
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      math.pi,
      math.pi,
      false,
      bgPaint,
    );

    // Progress arc with color gradient based on progress
    Color progressColor;
    if (progress >= 1) {
      progressColor = AppColors.success;
    } else if (progress >= 0.7) {
      progressColor = Colors.lightGreen;
    } else if (progress >= 0.4) {
      progressColor = Colors.orange;
    } else {
      progressColor = Colors.red;
    }

    final progressPaint = Paint()
      ..color = progressColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      math.pi,
      math.pi * progress,
      false,
      progressPaint,
    );

    // Tick marks
    for (int i = 0; i <= 10; i++) {
      final angle = math.pi + (math.pi * i / 10);
      final outerPoint = Offset(
        center.dx + (radius + 10) * math.cos(angle),
        center.dy + (radius + 10) * math.sin(angle),
      );
      final innerPoint = Offset(
        center.dx + (radius - 10) * math.cos(angle),
        center.dy + (radius - 10) * math.sin(angle),
      );

      final tickPaint = Paint()
        ..color = Colors.grey.shade400
        ..strokeWidth = i % 5 == 0 ? 2 : 1;

      canvas.drawLine(innerPoint, outerPoint, tickPaint);
    }
  }

  @override
  bool shouldRepaint(covariant MeterPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
