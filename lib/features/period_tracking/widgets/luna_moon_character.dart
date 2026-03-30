import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../theme/luna_theme.dart';

/// Animated moon character widget for Luna Cycle
/// Replaces the blob character with a moon-themed mascot
class LunaMoonCharacter extends StatefulWidget {
  final double size;
  final LunaCyclePhase phase;
  final LunaMoonMood mood;
  final bool animate;
  final bool showGlow;

  const LunaMoonCharacter({
    super.key,
    this.size = 120,
    required this.phase,
    this.mood = LunaMoonMood.happy,
    this.animate = true,
    this.showGlow = true,
  });

  @override
  State<LunaMoonCharacter> createState() => _LunaMoonCharacterState();
}

class _LunaMoonCharacterState extends State<LunaMoonCharacter>
    with TickerProviderStateMixin {
  late AnimationController _floatController;
  late AnimationController _glowController;
  late AnimationController _blinkController;
  late Animation<double> _floatAnimation;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();

    _floatController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    );

    _glowController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    _blinkController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );

    _floatAnimation = Tween<double>(begin: -5, end: 5).animate(
      CurvedAnimation(parent: _floatController, curve: Curves.easeInOut),
    );

    _glowAnimation = Tween<double>(begin: 0.3, end: 0.6).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );

    if (widget.animate) {
      _floatController.repeat(reverse: true);
      _glowController.repeat(reverse: true);
      _startBlinking();
    }
  }

  void _startBlinking() {
    Future.delayed(Duration(seconds: 2 + math.Random().nextInt(3)), () {
      if (mounted) {
        _blinkController.forward().then((_) {
          _blinkController.reverse().then((_) {
            _startBlinking();
          });
        });
      }
    });
  }

  @override
  void dispose() {
    _floatController.dispose();
    _glowController.dispose();
    _blinkController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_floatController, _glowController]),
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, widget.animate ? _floatAnimation.value : 0),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Glow effect
              if (widget.showGlow)
                Container(
                  width: widget.size * 1.4,
                  height: widget.size * 1.4,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: LunaTheme.getPhaseColor(widget.phase)
                            .withOpacity(_glowAnimation.value),
                        blurRadius: 40,
                        spreadRadius: 10,
                      ),
                    ],
                  ),
                ),
              // Moon body
              CustomPaint(
                size: Size(widget.size, widget.size),
                painter: _MoonPainter(
                  phase: widget.phase,
                  mood: widget.mood,
                  blinkProgress: _blinkController.value,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _MoonPainter extends CustomPainter {
  final LunaCyclePhase phase;
  final LunaMoonMood mood;
  final double blinkProgress;

  _MoonPainter({
    required this.phase,
    required this.mood,
    required this.blinkProgress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Moon phase determines fill
    final phaseColor = LunaTheme.getPhaseColor(phase);
    final lightColor = LunaTheme.getPhaseLightColor(phase);

    // Draw moon body
    final moonPaint = Paint()
      ..shader = RadialGradient(
        colors: [lightColor, phaseColor],
        stops: const [0.3, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius));

    canvas.drawCircle(center, radius * 0.9, moonPaint);

    // Draw craters (subtle)
    _drawCraters(canvas, center, radius);

    // Draw face
    _drawFace(canvas, center, radius);

    // Draw cheeks (blush)
    if (mood == LunaMoonMood.happy || mood == LunaMoonMood.love) {
      _drawCheeks(canvas, center, radius);
    }
  }

  void _drawCraters(Canvas canvas, Offset center, double radius) {
    final craterPaint = Paint()
      ..color = Colors.black.withOpacity(0.05)
      ..style = PaintingStyle.fill;

    // Small craters
    canvas.drawCircle(
      center + Offset(-radius * 0.3, -radius * 0.4),
      radius * 0.1,
      craterPaint,
    );
    canvas.drawCircle(
      center + Offset(radius * 0.4, radius * 0.2),
      radius * 0.08,
      craterPaint,
    );
    canvas.drawCircle(
      center + Offset(-radius * 0.2, radius * 0.5),
      radius * 0.06,
      craterPaint,
    );
  }

  void _drawFace(Canvas canvas, Offset center, double radius) {
    final eyeY = center.dy - radius * 0.15;
    final leftEyeX = center.dx - radius * 0.25;
    final rightEyeX = center.dx + radius * 0.25;

    final eyePaint = Paint()
      ..color = const Color(0xFF2D2D2D)
      ..style = PaintingStyle.fill;

    // Eyes (affected by blinking)
    final eyeHeight = radius * 0.12 * (1 - blinkProgress);
    
    if (mood == LunaMoonMood.sleepy) {
      // Half-closed eyes
      _drawSleepyEye(canvas, Offset(leftEyeX, eyeY), radius * 0.1);
      _drawSleepyEye(canvas, Offset(rightEyeX, eyeY), radius * 0.1);
    } else if (mood == LunaMoonMood.love) {
      // Heart eyes
      _drawHeartEye(canvas, Offset(leftEyeX, eyeY), radius * 0.12);
      _drawHeartEye(canvas, Offset(rightEyeX, eyeY), radius * 0.12);
    } else if (mood == LunaMoonMood.sad) {
      // Sad eyes
      _drawSadEye(canvas, Offset(leftEyeX, eyeY), radius * 0.1);
      _drawSadEye(canvas, Offset(rightEyeX, eyeY), radius * 0.1);
    } else {
      // Normal eyes
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(leftEyeX, eyeY),
          width: radius * 0.1,
          height: eyeHeight,
        ),
        eyePaint,
      );
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(rightEyeX, eyeY),
          width: radius * 0.1,
          height: eyeHeight,
        ),
        eyePaint,
      );

      // Eye shine
      final shinePaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill;
      canvas.drawCircle(
        Offset(leftEyeX - radius * 0.02, eyeY - radius * 0.03),
        radius * 0.025,
        shinePaint,
      );
      canvas.drawCircle(
        Offset(rightEyeX - radius * 0.02, eyeY - radius * 0.03),
        radius * 0.025,
        shinePaint,
      );
    }

    // Mouth
    _drawMouth(canvas, center, radius);
  }

  void _drawSleepyEye(Canvas canvas, Offset center, double size) {
    final paint = Paint()
      ..color = const Color(0xFF2D2D2D)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    final path = Path()
      ..moveTo(center.dx - size, center.dy)
      ..quadraticBezierTo(center.dx, center.dy + size * 0.5, center.dx + size, center.dy);

    canvas.drawPath(path, paint);
  }

  void _drawHeartEye(Canvas canvas, Offset center, double size) {
    final paint = Paint()
      ..color = const Color(0xFFFF6B8A)
      ..style = PaintingStyle.fill;

    final path = Path();
    path.moveTo(center.dx, center.dy + size * 0.3);
    path.cubicTo(
      center.dx - size, center.dy - size * 0.2,
      center.dx - size * 0.5, center.dy - size,
      center.dx, center.dy - size * 0.3,
    );
    path.cubicTo(
      center.dx + size * 0.5, center.dy - size,
      center.dx + size, center.dy - size * 0.2,
      center.dx, center.dy + size * 0.3,
    );

    canvas.drawPath(path, paint);
  }

  void _drawSadEye(Canvas canvas, Offset center, double size) {
    final paint = Paint()
      ..color = const Color(0xFF2D2D2D)
      ..style = PaintingStyle.fill;

    canvas.drawOval(
      Rect.fromCenter(center: center, width: size, height: size * 0.8),
      paint,
    );

    // Eyebrow
    final browPaint = Paint()
      ..color = const Color(0xFF2D2D2D)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    final browPath = Path()
      ..moveTo(center.dx - size * 0.8, center.dy - size * 1.2)
      ..lineTo(center.dx + size * 0.4, center.dy - size * 0.8);

    canvas.drawPath(browPath, browPaint);
  }

  void _drawMouth(Canvas canvas, Offset center, double radius) {
    final mouthY = center.dy + radius * 0.25;
    final mouthPaint = Paint()
      ..color = const Color(0xFF2D2D2D)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    final mouthPath = Path();

    switch (mood) {
      case LunaMoonMood.happy:
        mouthPath.moveTo(center.dx - radius * 0.2, mouthY);
        mouthPath.quadraticBezierTo(
          center.dx, mouthY + radius * 0.15,
          center.dx + radius * 0.2, mouthY,
        );
        break;
      case LunaMoonMood.love:
        mouthPath.moveTo(center.dx - radius * 0.15, mouthY);
        mouthPath.quadraticBezierTo(
          center.dx, mouthY + radius * 0.2,
          center.dx + radius * 0.15, mouthY,
        );
        // Fill for open smile
        final fillPaint = Paint()
          ..color = const Color(0xFFFF8A80)
          ..style = PaintingStyle.fill;
        canvas.drawPath(mouthPath, fillPaint);
        break;
      case LunaMoonMood.sleepy:
        mouthPath.moveTo(center.dx - radius * 0.1, mouthY);
        mouthPath.lineTo(center.dx + radius * 0.1, mouthY);
        break;
      case LunaMoonMood.sad:
        mouthPath.moveTo(center.dx - radius * 0.15, mouthY + radius * 0.05);
        mouthPath.quadraticBezierTo(
          center.dx, mouthY - radius * 0.1,
          center.dx + radius * 0.15, mouthY + radius * 0.05,
        );
        break;
      case LunaMoonMood.worried:
        mouthPath.moveTo(center.dx - radius * 0.12, mouthY);
        mouthPath.quadraticBezierTo(
          center.dx, mouthY - radius * 0.08,
          center.dx + radius * 0.12, mouthY + radius * 0.05,
        );
        break;
      case LunaMoonMood.neutral:
        mouthPath.moveTo(center.dx - radius * 0.12, mouthY);
        mouthPath.lineTo(center.dx + radius * 0.12, mouthY);
        break;
    }

    canvas.drawPath(mouthPath, mouthPaint);
  }

  void _drawCheeks(Canvas canvas, Offset center, double radius) {
    final blushPaint = Paint()
      ..color = const Color(0xFFFFB6C1).withOpacity(0.5)
      ..style = PaintingStyle.fill;

    // Left cheek
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(center.dx - radius * 0.45, center.dy + radius * 0.1),
        width: radius * 0.15,
        height: radius * 0.1,
      ),
      blushPaint,
    );

    // Right cheek
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(center.dx + radius * 0.45, center.dy + radius * 0.1),
        width: radius * 0.15,
        height: radius * 0.1,
      ),
      blushPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _MoonPainter oldDelegate) {
    return oldDelegate.phase != phase ||
        oldDelegate.mood != mood ||
        oldDelegate.blinkProgress != blinkProgress;
  }
}

/// Moon mood types
enum LunaMoonMood {
  happy,
  love,
  sleepy,
  sad,
  worried,
  neutral,
}

extension LunaMoonMoodExtension on LunaMoonMood {
  static LunaMoonMood fromPhase(LunaCyclePhase phase) {
    switch (phase) {
      case LunaCyclePhase.menstrual:
        return LunaMoonMood.sleepy;
      case LunaCyclePhase.follicular:
        return LunaMoonMood.happy;
      case LunaCyclePhase.ovulation:
        return LunaMoonMood.love;
      case LunaCyclePhase.luteal:
        return LunaMoonMood.neutral;
      case LunaCyclePhase.pms:
        return LunaMoonMood.worried;
    }
  }
}

/// Small moon icon for UI elements
class LunaMoonIcon extends StatelessWidget {
  final double size;
  final LunaCyclePhase phase;

  const LunaMoonIcon({
    super.key,
    this.size = 24,
    required this.phase,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LunaTheme.getPhaseGradient(phase),
        boxShadow: [
          BoxShadow(
            color: LunaTheme.getPhaseColor(phase).withOpacity(0.3),
            blurRadius: 4,
            spreadRadius: 1,
          ),
        ],
      ),
    );
  }
}
