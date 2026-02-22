import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import '../models/relaxation_game_models.dart';

/// Glassmorphism container widget
class GlassmorphicContainer extends StatelessWidget {
  final Widget child;
  final double blur;
  final double opacity;
  final Color? color;
  final BorderRadius? borderRadius;
  final EdgeInsets? padding;
  final Border? border;

  const GlassmorphicContainer({
    super.key,
    required this.child,
    this.blur = 10.0,
    this.opacity = 0.1,
    this.color,
    this.borderRadius,
    this.padding,
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: borderRadius ?? BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          padding: padding ?? const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: (color ?? Colors.white).withOpacity(opacity),
            borderRadius: borderRadius ?? BorderRadius.circular(20),
            border: border ?? Border.all(
              color: Colors.white.withOpacity(0.2),
              width: 1.5,
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Animated gradient background
class AnimatedGradientBackground extends StatefulWidget {
  final RelaxationTheme theme;
  final Duration duration;
  final Widget? child;

  const AnimatedGradientBackground({
    super.key,
    required this.theme,
    this.duration = const Duration(seconds: 5),
    this.child,
  });

  @override
  State<AnimatedGradientBackground> createState() => _AnimatedGradientBackgroundState();
}

class _AnimatedGradientBackgroundState extends State<AnimatedGradientBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    )..repeat(reverse: true);
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
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
        final colors = widget.theme.gradientColors;
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment(
                0.5 + _animation.value * 0.5,
                1.0 - _animation.value * 0.3,
              ),
              colors: colors,
            ),
          ),
          child: widget.child,
        );
      },
    );
  }
}

/// Particle system widget for visual effects
class ParticleSystemWidget extends StatefulWidget {
  final int particleCount;
  final Color primaryColor;
  final Color secondaryColor;
  final double speed;
  final Size size;

  const ParticleSystemWidget({
    super.key,
    this.particleCount = 50,
    required this.primaryColor,
    required this.secondaryColor,
    this.speed = 1.0,
    required this.size,
  });

  @override
  State<ParticleSystemWidget> createState() => _ParticleSystemWidgetState();
}

class _ParticleSystemWidgetState extends State<ParticleSystemWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<_FloatingParticle> _particles = [];
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _initParticles();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat();
  }

  void _initParticles() {
    _particles.clear();
    for (int i = 0; i < widget.particleCount; i++) {
      _particles.add(_createParticle());
    }
  }

  _FloatingParticle _createParticle() {
    return _FloatingParticle(
      x: _random.nextDouble() * widget.size.width,
      y: _random.nextDouble() * widget.size.height,
      size: 2 + _random.nextDouble() * 4,
      speedX: (_random.nextDouble() - 0.5) * widget.speed,
      speedY: (_random.nextDouble() - 0.5) * widget.speed,
      opacity: 0.3 + _random.nextDouble() * 0.7,
      color: _random.nextBool() ? widget.primaryColor : widget.secondaryColor,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        // Update particles
        for (var particle in _particles) {
          particle.x += particle.speedX;
          particle.y += particle.speedY;

          // Wrap around
          if (particle.x < 0) particle.x = widget.size.width;
          if (particle.x > widget.size.width) particle.x = 0;
          if (particle.y < 0) particle.y = widget.size.height;
          if (particle.y > widget.size.height) particle.y = 0;
        }

        return CustomPaint(
          size: widget.size,
          painter: _ParticlePainter(particles: _particles),
        );
      },
    );
  }
}

class _FloatingParticle {
  double x;
  double y;
  double size;
  double speedX;
  double speedY;
  double opacity;
  Color color;

  _FloatingParticle({
    required this.x,
    required this.y,
    required this.size,
    required this.speedX,
    required this.speedY,
    required this.opacity,
    required this.color,
  });
}

class _ParticlePainter extends CustomPainter {
  final List<_FloatingParticle> particles;

  _ParticlePainter({required this.particles});

  @override
  void paint(Canvas canvas, Size size) {
    for (var particle in particles) {
      final paint = Paint()
        ..color = particle.color.withOpacity(particle.opacity)
        ..style = PaintingStyle.fill;

      canvas.drawCircle(
        Offset(particle.x, particle.y),
        particle.size,
        paint,
      );

      // Add glow effect
      final glowPaint = Paint()
        ..color = particle.color.withOpacity(particle.opacity * 0.3)
        ..style = PaintingStyle.fill
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

      canvas.drawCircle(
        Offset(particle.x, particle.y),
        particle.size * 2,
        glowPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

/// Ripple effect widget
class RippleEffectWidget extends StatefulWidget {
  final List<RippleEffect> ripples;
  final Color defaultColor;

  const RippleEffectWidget({
    super.key,
    required this.ripples,
    required this.defaultColor,
  });

  @override
  State<RippleEffectWidget> createState() => _RippleEffectWidgetState();
}

class _RippleEffectWidgetState extends State<RippleEffectWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 16),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          size: Size.infinite,
          painter: _RipplePainter(
            ripples: widget.ripples,
            defaultColor: widget.defaultColor,
          ),
        );
      },
    );
  }
}

class _RipplePainter extends CustomPainter {
  final List<RippleEffect> ripples;
  final Color defaultColor;

  _RipplePainter({required this.ripples, required this.defaultColor});

  @override
  void paint(Canvas canvas, Size size) {
    for (var ripple in ripples) {
      if (ripple.isComplete) continue;

      final progress = ripple.progress;
      final radius = ripple.maxRadius * progress;
      final opacity = (1.0 - progress) * 0.6;

      final paint = Paint()
        ..color = ripple.color.withOpacity(opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0 * (1.0 - progress * 0.5);

      canvas.drawCircle(ripple.center, radius, paint);

      // Inner glow
      final glowPaint = Paint()
        ..color = ripple.color.withOpacity(opacity * 0.3)
        ..style = PaintingStyle.fill
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 15);

      canvas.drawCircle(ripple.center, radius * 0.3, glowPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

/// Light trail widget for Zen Flow mode
class LightTrailWidget extends StatelessWidget {
  final List<TouchPoint> points;
  final Color color;
  final double width;
  final double glowIntensity;

  const LightTrailWidget({
    super.key,
    required this.points,
    required this.color,
    this.width = 8.0,
    this.glowIntensity = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.infinite,
      painter: _LightTrailPainter(
        points: points,
        color: color,
        width: width,
        glowIntensity: glowIntensity,
      ),
    );
  }
}

class _LightTrailPainter extends CustomPainter {
  final List<TouchPoint> points;
  final Color color;
  final double width;
  final double glowIntensity;

  _LightTrailPainter({
    required this.points,
    required this.color,
    required this.width,
    required this.glowIntensity,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;

    final path = Path();
    path.moveTo(points.first.position.dx, points.first.position.dy);

    for (int i = 1; i < points.length; i++) {
      final p0 = points[i - 1].position;
      final p1 = points[i].position;
      final mid = Offset((p0.dx + p1.dx) / 2, (p0.dy + p1.dy) / 2);
      path.quadraticBezierTo(p0.dx, p0.dy, mid.dx, mid.dy);
    }

    // Draw glow
    for (int i = 3; i >= 1; i--) {
      final glowPaint = Paint()
        ..color = color.withOpacity(0.1 * glowIntensity / i)
        ..style = PaintingStyle.stroke
        ..strokeWidth = width * (1 + i * 1.5)
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 10.0 * i);

      canvas.drawPath(path, glowPaint);
    }

    // Draw main trail
    final paint = Paint()
      ..shader = LinearGradient(
        colors: [
          color.withOpacity(0.1),
          color.withOpacity(0.8),
          color,
        ],
      ).createShader(Rect.fromPoints(
        points.first.position,
        points.last.position,
      ))
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

/// Energy orb widget
class EnergyOrbWidget extends StatefulWidget {
  final Offset position;
  final OrbElement element;
  final double size;
  final double pulseIntensity;

  const EnergyOrbWidget({
    super.key,
    required this.position,
    required this.element,
    this.size = 80.0,
    this.pulseIntensity = 1.0,
  });

  @override
  State<EnergyOrbWidget> createState() => _EnergyOrbWidgetState();
}

class _EnergyOrbWidgetState extends State<EnergyOrbWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.9, end: 1.1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        final scale = _pulseAnimation.value * widget.pulseIntensity;
        final color = widget.element.color;

        return Positioned(
          left: widget.position.dx - widget.size / 2,
          top: widget.position.dy - widget.size / 2,
          child: Transform.scale(
            scale: scale,
            child: Container(
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    color.withOpacity(0.9),
                    color.withOpacity(0.6),
                    color.withOpacity(0.2),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.3, 0.6, 1.0],
                ),
                boxShadow: [
                  BoxShadow(
                    color: color.withOpacity(0.5),
                    blurRadius: 30 * widget.pulseIntensity,
                    spreadRadius: 10 * widget.pulseIntensity,
                  ),
                  BoxShadow(
                    color: color.withOpacity(0.3),
                    blurRadius: 60 * widget.pulseIntensity,
                    spreadRadius: 20 * widget.pulseIntensity,
                  ),
                ],
              ),
              child: Center(
                child: Container(
                  width: widget.size * 0.4,
                  height: widget.size * 0.4,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.white.withOpacity(0.5),
                        blurRadius: 15,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Bubble widget for bubble pop mode
class BubbleWidget extends StatefulWidget {
  final Offset position;
  final double size;
  final Color color;
  final VoidCallback onPop;
  final bool isPopped;

  const BubbleWidget({
    super.key,
    required this.position,
    required this.size,
    required this.color,
    required this.onPop,
    this.isPopped = false,
  });

  @override
  State<BubbleWidget> createState() => _BubbleWidgetState();
}

class _BubbleWidgetState extends State<BubbleWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _wobbleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);

    _wobbleAnimation = Tween<double>(begin: -0.02, end: 0.02).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isPopped) {
      return const SizedBox.shrink();
    }

    return AnimatedBuilder(
      animation: _wobbleAnimation,
      builder: (context, child) {
        return Positioned(
          left: widget.position.dx - widget.size / 2,
          top: widget.position.dy - widget.size / 2,
          child: GestureDetector(
            onTap: widget.onPop,
            child: Transform.rotate(
              angle: _wobbleAnimation.value,
              child: Container(
                width: widget.size,
                height: widget.size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    center: const Alignment(-0.3, -0.3),
                    colors: [
                      Colors.white.withOpacity(0.8),
                      widget.color.withOpacity(0.4),
                      widget.color.withOpacity(0.2),
                    ],
                    stops: const [0.0, 0.3, 1.0],
                  ),
                  border: Border.all(
                    color: widget.color.withOpacity(0.5),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: widget.color.withOpacity(0.2),
                      blurRadius: 10,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    // Highlight
                    Positioned(
                      top: widget.size * 0.15,
                      left: widget.size * 0.2,
                      child: Container(
                        width: widget.size * 0.25,
                        height: widget.size * 0.15,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.6),
                          borderRadius: BorderRadius.circular(widget.size * 0.1),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Zen garden rake pattern widget
class ZenGardenPatternWidget extends StatelessWidget {
  final List<List<Offset>> rakeLines;
  final Color sandColor;
  final Color lineColor;

  const ZenGardenPatternWidget({
    super.key,
    required this.rakeLines,
    required this.sandColor,
    required this.lineColor,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.infinite,
      painter: _ZenGardenPainter(
        rakeLines: rakeLines,
        sandColor: sandColor,
        lineColor: lineColor,
      ),
    );
  }
}

class _ZenGardenPainter extends CustomPainter {
  final List<List<Offset>> rakeLines;
  final Color sandColor;
  final Color lineColor;

  _ZenGardenPainter({
    required this.rakeLines,
    required this.sandColor,
    required this.lineColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Draw sand background texture
    final sandPaint = Paint()
      ..color = sandColor
      ..style = PaintingStyle.fill;

    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), sandPaint);

    // Draw rake lines
    for (var line in rakeLines) {
      if (line.length < 2) continue;

      final path = Path();
      path.moveTo(line.first.dx, line.first.dy);

      for (int i = 1; i < line.length; i++) {
        path.lineTo(line[i].dx, line[i].dy);
      }

      // Shadow
      final shadowPaint = Paint()
        ..color = lineColor.withOpacity(0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;

      canvas.drawPath(path.shift(const Offset(2, 2)), shadowPaint);

      // Main line
      final linePaint = Paint()
        ..color = lineColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;

      canvas.drawPath(path, linePaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

/// Breathing circle widget for guided breathing
class BreathingCircleWidget extends StatefulWidget {
  final double size;
  final Color color;
  final Duration inhaleTime;
  final Duration holdTime;
  final Duration exhaleTime;
  final VoidCallback? onPhaseChange;

  const BreathingCircleWidget({
    super.key,
    this.size = 200,
    required this.color,
    this.inhaleTime = const Duration(seconds: 4),
    this.holdTime = const Duration(seconds: 4),
    this.exhaleTime = const Duration(seconds: 4),
    this.onPhaseChange,
  });

  @override
  State<BreathingCircleWidget> createState() => _BreathingCircleWidgetState();
}

class _BreathingCircleWidgetState extends State<BreathingCircleWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  String _phase = 'Inhale';
  int _cyclePhase = 0;

  @override
  void initState() {
    super.initState();
    final totalDuration = widget.inhaleTime + widget.holdTime + widget.exhaleTime;
    _controller = AnimationController(
      duration: totalDuration,
      vsync: this,
    )..repeat();

    _controller.addListener(_updatePhase);
  }

  void _updatePhase() {
    final total = widget.inhaleTime.inMilliseconds +
        widget.holdTime.inMilliseconds +
        widget.exhaleTime.inMilliseconds;
    final current = (_controller.value * total).round();

    int newPhase;
    String newPhaseName;

    if (current < widget.inhaleTime.inMilliseconds) {
      newPhase = 0;
      newPhaseName = 'Inhale';
    } else if (current < widget.inhaleTime.inMilliseconds + widget.holdTime.inMilliseconds) {
      newPhase = 1;
      newPhaseName = 'Hold';
    } else {
      newPhase = 2;
      newPhaseName = 'Exhale';
    }

    if (newPhase != _cyclePhase) {
      _cyclePhase = newPhase;
      setState(() => _phase = newPhaseName);
      widget.onPhaseChange?.call();
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_updatePhase);
    _controller.dispose();
    super.dispose();
  }

  double _calculateScale() {
    final total = widget.inhaleTime.inMilliseconds +
        widget.holdTime.inMilliseconds +
        widget.exhaleTime.inMilliseconds;
    final current = (_controller.value * total).round();

    if (current < widget.inhaleTime.inMilliseconds) {
      // Inhale - grow
      final progress = current / widget.inhaleTime.inMilliseconds;
      return 0.6 + 0.4 * progress;
    } else if (current < widget.inhaleTime.inMilliseconds + widget.holdTime.inMilliseconds) {
      // Hold
      return 1.0;
    } else {
      // Exhale - shrink
      final exhaleStart = widget.inhaleTime.inMilliseconds + widget.holdTime.inMilliseconds;
      final progress = (current - exhaleStart) / widget.exhaleTime.inMilliseconds;
      return 1.0 - 0.4 * progress;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final scale = _calculateScale();

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Transform.scale(
              scale: scale,
              child: Container(
                width: widget.size,
                height: widget.size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      widget.color.withOpacity(0.8),
                      widget.color.withOpacity(0.4),
                      widget.color.withOpacity(0.1),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: widget.color.withOpacity(0.4),
                      blurRadius: 30 * scale,
                      spreadRadius: 10 * scale,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              _phase,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w500,
                color: widget.color,
                letterSpacing: 2,
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Hypnotic spiral widget
class HypnoticSpiralWidget extends StatefulWidget {
  final Color primaryColor;
  final Color secondaryColor;
  final double speed;

  const HypnoticSpiralWidget({
    super.key,
    required this.primaryColor,
    required this.secondaryColor,
    this.speed = 1.0,
  });

  @override
  State<HypnoticSpiralWidget> createState() => _HypnoticSpiralWidgetState();
}

class _HypnoticSpiralWidgetState extends State<HypnoticSpiralWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: Duration(milliseconds: (5000 / widget.speed).round()),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          size: Size.infinite,
          painter: _HypnoticSpiralPainter(
            rotation: _controller.value * 2 * pi,
            primaryColor: widget.primaryColor,
            secondaryColor: widget.secondaryColor,
          ),
        );
      },
    );
  }
}

class _HypnoticSpiralPainter extends CustomPainter {
  final double rotation;
  final Color primaryColor;
  final Color secondaryColor;

  _HypnoticSpiralPainter({
    required this.rotation,
    required this.primaryColor,
    required this.secondaryColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = min(size.width, size.height) / 2;

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(rotation);

    for (int i = 0; i < 12; i++) {
      final angle = i * pi / 6;
      final color = i.isEven ? primaryColor : secondaryColor;

      final path = Path();
      path.moveTo(0, 0);

      for (double r = 0; r < maxRadius; r += 2) {
        final spiralAngle = angle + r * 0.02;
        path.lineTo(
          r * cos(spiralAngle),
          r * sin(spiralAngle),
        );
      }

      final paint = Paint()
        ..color = color.withOpacity(0.6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3;

      canvas.drawPath(path, paint);
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

/// Mode selection card
class ModeSelectionCard extends StatelessWidget {
  final String title;
  final String emoji;
  final String description;
  final Color color;
  final bool isSelected;
  final bool isLocked;
  final int? minutesToUnlock;
  final VoidCallback onTap;

  const ModeSelectionCard({
    super.key,
    required this.title,
    required this.emoji,
    required this.description,
    required this.color,
    required this.isSelected,
    this.isLocked = false,
    this.minutesToUnlock,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isLocked ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: isSelected
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [color, color.withOpacity(0.7)],
                )
              : null,
          color: isSelected ? null : Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? color : Colors.white.withOpacity(0.2),
            width: isSelected ? 0 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: color.withOpacity(0.4),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                ]
              : null,
        ),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(emoji, style: const TextStyle(fontSize: 32)),
                const SizedBox(height: 12),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? Colors.white : Colors.white.withOpacity(0.9),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 11,
                    color: isSelected
                        ? Colors.white.withOpacity(0.8)
                        : Colors.white.withOpacity(0.6),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
            if (isLocked)
              Positioned(
                top: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.lock, color: Colors.white70, size: 12),
                      if (minutesToUnlock != null) ...[
                        const SizedBox(width: 4),
                        Text(
                          '${minutesToUnlock}m',
                          style: const TextStyle(
                            fontSize: 10,
                            color: Colors.white70,
                          ),
                        ),
                      ],
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

/// Settings slider widget
class SettingsSlider extends StatelessWidget {
  final String label;
  final IconData icon;
  final double value;
  final Color color;
  final ValueChanged<double> onChanged;
  final String? suffix;

  const SettingsSlider({
    super.key,
    required this.label,
    required this.icon,
    required this.value,
    required this.color,
    required this.onChanged,
    this.suffix,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.white.withOpacity(0.9),
              ),
            ),
            const Spacer(),
            Text(
              '${(value * 100).round()}${suffix ?? '%'}',
              style: TextStyle(
                fontSize: 12,
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SliderTheme(
          data: SliderThemeData(
            activeTrackColor: color,
            inactiveTrackColor: color.withOpacity(0.2),
            thumbColor: color,
            overlayColor: color.withOpacity(0.1),
            trackHeight: 4,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
          ),
          child: Slider(
            value: value,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}
