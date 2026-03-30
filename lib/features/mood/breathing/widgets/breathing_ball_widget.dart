import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/breathing_exercise.dart';
import '../../theme/mood_theme.dart';

/// Animated fluffy ball widget for breathing exercises
/// Expands on inhale, contracts on exhale - matching Behance design
class BreathingBallWidget extends StatefulWidget {
  final BreathingPhase phase;
  final BreathingExerciseColor colorScheme;
  final double size;
  final double progress;

  const BreathingBallWidget({
    super.key,
    required this.phase,
    required this.colorScheme,
    this.size = 280,
    this.progress = 0.0,
  });

  @override
  State<BreathingBallWidget> createState() => _BreathingBallWidgetState();
}

class _BreathingBallWidgetState extends State<BreathingBallWidget>
    with TickerProviderStateMixin {
  late AnimationController _breathController;
  late AnimationController _glowController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _initAnimations();
  }

  void _initAnimations() {
    _breathController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4000),
    );

    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _breathController, curve: Curves.easeInOut),
    );

    _glowAnimation = Tween<double>(begin: 0.3, end: 0.6).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );
  }

  @override
  void didUpdateWidget(BreathingBallWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.phase != widget.phase) {
      _updateAnimation();
    }
  }

  void _updateAnimation() {
    switch (widget.phase) {
      case BreathingPhase.inhale:
        _breathController.forward();
        break;
      case BreathingPhase.exhale:
        _breathController.reverse();
        break;
      case BreathingPhase.hold:
      case BreathingPhase.idle:
        break;
    }
  }

  @override
  void dispose() {
    _breathController.dispose();
    _glowController.dispose();
    super.dispose();
  }

  Color get _primaryColor {
    switch (widget.colorScheme) {
      case BreathingExerciseColor.purple:
        return MoodTheme.purple400;
      case BreathingExerciseColor.beige:
        return MoodTheme.beige300;
      case BreathingExerciseColor.lavender:
        return MoodTheme.purple200;
      case BreathingExerciseColor.cream:
        return MoodTheme.beige100;
    }
  }

  Color get _secondaryColor {
    switch (widget.colorScheme) {
      case BreathingExerciseColor.purple:
        return MoodTheme.purple600;
      case BreathingExerciseColor.beige:
        return MoodTheme.beige500;
      case BreathingExerciseColor.lavender:
        return MoodTheme.purple400;
      case BreathingExerciseColor.cream:
        return MoodTheme.beige300;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_scaleAnimation, _glowAnimation]),
      builder: (context, child) {
        final scale = _scaleAnimation.value;
        final glow = _glowAnimation.value;

        return SizedBox(
          width: widget.size,
          height: widget.size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Outer glow
              Transform.scale(
                scale: scale * 1.15,
                child: Container(
                  width: widget.size,
                  height: widget.size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: _primaryColor.withOpacity(glow * 0.5),
                        blurRadius: 60,
                        spreadRadius: 20,
                      ),
                    ],
                  ),
                ),
              ),

              // Main fluffy ball
              Transform.scale(
                scale: scale,
                child: Container(
                  width: widget.size * 0.85,
                  height: widget.size * 0.85,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      center: const Alignment(-0.2, -0.3),
                      radius: 0.8,
                      colors: [
                        _primaryColor.withOpacity(0.9),
                        _secondaryColor.withOpacity(0.7),
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: _secondaryColor.withOpacity(0.3),
                        blurRadius: 30,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: CustomPaint(
                    painter: _FluffyTexturePainter(
                      color: _primaryColor,
                      progress: widget.progress,
                    ),
                  ),
                ),
              ),

              // Inner highlight
              Transform.scale(
                scale: scale * 0.6,
                child: Container(
                  width: widget.size * 0.4,
                  height: widget.size * 0.4,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        Colors.white.withOpacity(0.4),
                        Colors.white.withOpacity(0.0),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Custom painter for fluffy texture effect
class _FluffyTexturePainter extends CustomPainter {
  final Color color;
  final double progress;

  _FluffyTexturePainter({
    required this.color,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final random = math.Random(42);

    // Draw soft fuzzy dots for texture
    final paint = Paint()
      ..style = PaintingStyle.fill;

    for (int i = 0; i < 80; i++) {
      final angle = random.nextDouble() * 2 * math.pi;
      final dist = random.nextDouble() * radius * 0.9;
      final dotRadius = 2 + random.nextDouble() * 6;
      
      final x = center.dx + math.cos(angle) * dist;
      final y = center.dy + math.sin(angle) * dist;

      paint.color = Colors.white.withOpacity(0.1 + random.nextDouble() * 0.15);
      canvas.drawCircle(Offset(x, y), dotRadius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _FluffyTexturePainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

/// Breathing progress indicator
class BreathingProgressBar extends StatelessWidget {
  final double progress;
  final BreathingExerciseColor colorScheme;

  const BreathingProgressBar({
    super.key,
    required this.progress,
    required this.colorScheme,
  });

  Color get _color {
    switch (colorScheme) {
      case BreathingExerciseColor.purple:
        return MoodTheme.purple500;
      case BreathingExerciseColor.beige:
        return MoodTheme.beige400;
      case BreathingExerciseColor.lavender:
        return MoodTheme.purple300;
      case BreathingExerciseColor.cream:
        return MoodTheme.beige200;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 4,
      margin: const EdgeInsets.symmetric(horizontal: 48),
      decoration: BoxDecoration(
        color: _color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(2),
      ),
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: progress.clamp(0.0, 1.0),
        child: Container(
          decoration: BoxDecoration(
            color: _color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    );
  }
}
