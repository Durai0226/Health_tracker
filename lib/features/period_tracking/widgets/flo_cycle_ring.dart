import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../theme/flo_theme.dart';
import 'flo_blob_character.dart';

/// Circular progress ring showing cycle day and phase
/// Inspired by Flo app's main dashboard visualization
class FloCycleRing extends StatefulWidget {
  final int cycleDay;
  final int cycleLength;
  final CyclePhaseType phase;
  final bool isOnPeriod;
  final int periodDuration;
  final VoidCallback? onTap;

  const FloCycleRing({
    super.key,
    required this.cycleDay,
    required this.cycleLength,
    required this.phase,
    this.isOnPeriod = false,
    this.periodDuration = 5,
    this.onTap,
  });

  @override
  State<FloCycleRing> createState() => _FloCycleRingState();
}

class _FloCycleRingState extends State<FloCycleRing>
    with TickerProviderStateMixin {
  late AnimationController _progressController;
  late AnimationController _pulseController;
  late Animation<double> _progressAnimation;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    
    _progressController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);

    _progressAnimation = Tween<double>(
      begin: 0,
      end: widget.cycleDay / widget.cycleLength,
    ).animate(CurvedAnimation(
      parent: _progressController,
      curve: Curves.easeOutCubic,
    ));

    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.03,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    _progressController.forward();
  }

  @override
  void didUpdateWidget(FloCycleRing oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.cycleDay != widget.cycleDay ||
        oldWidget.cycleLength != widget.cycleLength) {
      _progressAnimation = Tween<double>(
        begin: _progressAnimation.value,
        end: widget.cycleDay / widget.cycleLength,
      ).animate(CurvedAnimation(
        parent: _progressController,
        curve: Curves.easeOutCubic,
      ));
      _progressController.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _progressController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final phaseColor = FloTheme.getPhaseColor(widget.phase);
    final size = MediaQuery.of(context).size.width * 0.65;

    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (context, child) => Transform.scale(
          scale: _pulseAnimation.value,
          child: SizedBox(
            width: size,
            height: size,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Outer glow
                Container(
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: phaseColor.withOpacity(0.3),
                        blurRadius: 40,
                        spreadRadius: 10,
                      ),
                    ],
                  ),
                ),
                
                // Background ring
                AnimatedBuilder(
                  animation: _progressAnimation,
                  builder: (context, _) => CustomPaint(
                    size: Size(size, size),
                    painter: _CycleRingPainter(
                      progress: _progressAnimation.value,
                      phaseColor: phaseColor,
                      periodProgress: widget.isOnPeriod
                          ? widget.cycleDay / widget.periodDuration
                          : 0,
                      cycleLength: widget.cycleLength,
                      periodDuration: widget.periodDuration,
                      isDark: FloTheme.isDark(context),
                    ),
                  ),
                ),
                
                // Inner content
                Container(
                  width: size * 0.75,
                  height: size * 0.75,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: FloTheme.getSurface(context),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 20,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Day number
                      Text(
                        'Day ${widget.cycleDay}',
                        style: FloTheme.displayMedium.copyWith(
                          color: phaseColor,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      
                      // Phase name
                      Text(
                        FloTheme.getPhaseName(widget.phase),
                        style: FloTheme.bodyMedium.copyWith(
                          color: phaseColor.withOpacity(0.8),
                        ),
                      ),
                      
                      const SizedBox(height: FloTheme.spacingMd),
                      
                      // Blob character
                      FloBlobCharacter(
                        phase: widget.phase,
                        size: 50,
                        animate: true,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Custom painter for the cycle ring
class _CycleRingPainter extends CustomPainter {
  final double progress;
  final Color phaseColor;
  final double periodProgress;
  final int cycleLength;
  final int periodDuration;
  final bool isDark;

  _CycleRingPainter({
    required this.progress,
    required this.phaseColor,
    required this.periodProgress,
    required this.cycleLength,
    required this.periodDuration,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 15;
    final strokeWidth = 12.0;

    // Background ring
    final bgPaint = Paint()
      ..color = isDark ? Colors.white.withOpacity(0.1) : Colors.grey.withOpacity(0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, bgPaint);

    // Period phase arc (red/pink)
    if (periodDuration > 0) {
      final periodAngle = (periodDuration / cycleLength) * 2 * math.pi;
      final periodPaint = Paint()
        ..color = FloTheme.periodPink.withOpacity(0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2,
        periodAngle,
        false,
        periodPaint,
      );
    }

    // Fertile window arc (blue)
    final ovulationDay = cycleLength - 14;
    final fertileStart = (ovulationDay - 5) / cycleLength;
    final fertileEnd = (ovulationDay + 1) / cycleLength;
    
    final fertilePaint = Paint()
      ..color = FloTheme.ovulationBlue.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2 + fertileStart * 2 * math.pi,
      (fertileEnd - fertileStart) * 2 * math.pi,
      false,
      fertilePaint,
    );

    // Progress arc with gradient
    final progressAngle = progress * 2 * math.pi;
    final progressPaint = Paint()
      ..shader = SweepGradient(
        startAngle: -math.pi / 2,
        endAngle: -math.pi / 2 + progressAngle,
        colors: [
          phaseColor.withOpacity(0.5),
          phaseColor,
        ],
        stops: const [0.0, 1.0],
        transform: GradientRotation(-math.pi / 2),
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      progressAngle,
      false,
      progressPaint,
    );

    // Current position dot
    final dotAngle = -math.pi / 2 + progressAngle;
    final dotX = center.dx + radius * math.cos(dotAngle);
    final dotY = center.dy + radius * math.sin(dotAngle);

    // Dot shadow
    canvas.drawCircle(
      Offset(dotX, dotY + 2),
      10,
      Paint()..color = Colors.black.withOpacity(0.1),
    );

    // Dot
    canvas.drawCircle(
      Offset(dotX, dotY),
      10,
      Paint()..color = phaseColor,
    );

    // Dot inner
    canvas.drawCircle(
      Offset(dotX, dotY),
      5,
      Paint()..color = Colors.white,
    );
  }

  @override
  bool shouldRepaint(covariant _CycleRingPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.phaseColor != phaseColor ||
        oldDelegate.isDark != isDark;
  }
}

/// Pregnancy ring showing weeks progress
class FloPregnancyRing extends StatefulWidget {
  final int currentWeek;
  final int totalWeeks;
  final String fetusEmoji;
  final String sizeComparison;
  final VoidCallback? onTap;

  const FloPregnancyRing({
    super.key,
    required this.currentWeek,
    this.totalWeeks = 40,
    required this.fetusEmoji,
    required this.sizeComparison,
    this.onTap,
  });

  @override
  State<FloPregnancyRing> createState() => _FloPregnancyRingState();
}

class _FloPregnancyRingState extends State<FloPregnancyRing>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _animation = Tween<double>(
      begin: 0,
      end: widget.currentWeek / widget.totalWeeks,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    ));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size.width * 0.65;
    final trimester = widget.currentWeek <= 12
        ? 1
        : widget.currentWeek <= 27
            ? 2
            : 3;
    final trimesterColor = FloTheme.getPregnancyTrimesterColor(trimester);

    return GestureDetector(
      onTap: widget.onTap,
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Ring
            AnimatedBuilder(
              animation: _animation,
              builder: (context, _) => CustomPaint(
                size: Size(size, size),
                painter: _PregnancyRingPainter(
                  progress: _animation.value,
                  color: trimesterColor,
                  isDark: FloTheme.isDark(context),
                ),
              ),
            ),
            
            // Inner content
            Container(
              width: size * 0.75,
              height: size * 0.75,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: FloTheme.getSurface(context),
                boxShadow: FloTheme.shadowMd,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    widget.fetusEmoji,
                    style: const TextStyle(fontSize: 48),
                  ),
                  const SizedBox(height: FloTheme.spacingSm),
                  Text(
                    '${widget.currentWeek} weeks',
                    style: FloTheme.displaySmall.copyWith(
                      color: trimesterColor,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    widget.sizeComparison,
                    style: FloTheme.bodyMedium.copyWith(
                      color: FloTheme.getTextSecondary(context),
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

class _PregnancyRingPainter extends CustomPainter {
  final double progress;
  final Color color;
  final bool isDark;

  _PregnancyRingPainter({
    required this.progress,
    required this.color,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 15;
    final strokeWidth = 12.0;

    // Background
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = isDark ? Colors.white.withOpacity(0.1) : Colors.grey.withOpacity(0.15)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth,
    );

    // Progress
    final progressAngle = progress * 2 * math.pi;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      progressAngle,
      false,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _PregnancyRingPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}
