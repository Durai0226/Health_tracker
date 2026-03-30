import 'package:flutter/material.dart';
import 'dart:math' as math;

/// Reusable animation controllers and curves for bottom navs
class NavAnimations {
  /// Bounce scale animation for selection
  static Animation<double> bounceScale(AnimationController controller) {
    return Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: controller, curve: Curves.elasticOut),
    );
  }

  /// Pulse glow animation (Medicine)
  static Animation<double> pulseGlow(AnimationController controller) {
    return Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: controller, curve: Curves.easeInOut),
    );
  }

  /// Breathing scale animation (Focus)
  static Animation<double> breathingScale(AnimationController controller) {
    return Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: controller, curve: Curves.easeInOut),
    );
  }

  /// Water drop fall animation
  static Animation<double> waterDrop(AnimationController controller) {
    return Tween<double>(begin: -20.0, end: 0.0).animate(
      CurvedAnimation(parent: controller, curve: Curves.bounceOut),
    );
  }

  /// Ripple expand animation
  static Animation<double> rippleExpand(AnimationController controller) {
    return Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: controller, curve: Curves.easeOut),
    );
  }

  /// Flame flicker animation (Habit)
  static Animation<double> flameFlicker(AnimationController controller) {
    return Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: controller, curve: Curves.easeInOut),
    );
  }

  /// Bell shake animation (Reminders)
  static Animation<double> bellShake(AnimationController controller) {
    return Tween<double>(begin: -0.05, end: 0.05).animate(
      CurvedAnimation(parent: controller, curve: Curves.elasticInOut),
    );
  }

  /// Page flip rotation (Notes/Exam)
  static Animation<double> pageFlip(AnimationController controller) {
    return Tween<double>(begin: 0.0, end: math.pi / 12).animate(
      CurvedAnimation(parent: controller, curve: Curves.easeOutBack),
    );
  }

  /// Coin flip rotation (Finance)
  static Animation<double> coinFlip(AnimationController controller) {
    return Tween<double>(begin: 0.0, end: math.pi * 2).animate(
      CurvedAnimation(parent: controller, curve: Curves.easeOutCubic),
    );
  }

  /// Moon phase glow (Luna)
  static Animation<double> moonGlow(AnimationController controller) {
    return Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: controller, curve: Curves.easeInOutSine),
    );
  }

  /// Power burst scale (Fitness)
  static Animation<double> powerBurst(AnimationController controller) {
    return TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.3), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 1.3, end: 0.9), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 0.9, end: 1.0), weight: 50),
    ]).animate(CurvedAnimation(parent: controller, curve: Curves.easeOut));
  }

  /// Emoji morph scale (Mood)
  static Animation<double> emojiMorph(AnimationController controller) {
    return TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.8), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 0.8, end: 1.15), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 1.15, end: 1.0), weight: 30),
    ]).animate(CurvedAnimation(parent: controller, curve: Curves.easeInOut));
  }
}

/// Animated glow effect painter
class GlowPainter extends CustomPainter {
  final Color color;
  final double glowRadius;
  final double opacity;

  GlowPainter({
    required this.color,
    this.glowRadius = 20,
    this.opacity = 0.3,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: opacity)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, glowRadius);

    canvas.drawCircle(
      Offset(size.width / 2, size.height / 2),
      size.width / 3,
      paint,
    );
  }

  @override
  bool shouldRepaint(GlowPainter oldDelegate) =>
      color != oldDelegate.color ||
      glowRadius != oldDelegate.glowRadius ||
      opacity != oldDelegate.opacity;
}

/// Ripple effect painter for Water nav
class RipplePainter extends CustomPainter {
  final Color color;
  final double progress;
  final Offset center;

  RipplePainter({
    required this.color,
    required this.progress,
    required this.center,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final maxRadius = size.width * 0.8;
    final currentRadius = maxRadius * progress;
    final opacity = (1.0 - progress) * 0.3;

    final paint = Paint()
      ..color = color.withValues(alpha: opacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    canvas.drawCircle(center, currentRadius, paint);
  }

  @override
  bool shouldRepaint(RipplePainter oldDelegate) =>
      progress != oldDelegate.progress || center != oldDelegate.center;
}

/// Heartbeat line painter for Medicine nav
class HeartbeatPainter extends CustomPainter {
  final Color color;
  final double phase;

  HeartbeatPainter({required this.color, required this.phase});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    final path = Path();
    final width = size.width;
    final height = size.height;
    final midY = height / 2;

    path.moveTo(0, midY);

    for (double x = 0; x < width; x += 1) {
      final normalizedX = (x / width + phase) % 1.0;
      double y = midY;

      // Create heartbeat pattern
      if (normalizedX > 0.4 && normalizedX < 0.45) {
        y = midY - 8;
      } else if (normalizedX > 0.45 && normalizedX < 0.5) {
        y = midY + 12;
      } else if (normalizedX > 0.5 && normalizedX < 0.55) {
        y = midY - 6;
      }

      path.lineTo(x, y);
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(HeartbeatPainter oldDelegate) => phase != oldDelegate.phase;
}

/// Flame effect painter for Habit nav
class FlamePainter extends CustomPainter {
  final Color color;
  final double flicker;

  FlamePainter({required this.color, required this.flicker});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = LinearGradient(
        colors: [
          color.withValues(alpha: 0.0),
          color.withValues(alpha: 0.3 * flicker),
          color.withValues(alpha: 0.1),
        ],
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    final path = Path();
    path.moveTo(0, size.height);
    path.quadraticBezierTo(
      size.width * 0.25,
      size.height * (0.3 + 0.1 * flicker),
      size.width * 0.5,
      0,
    );
    path.quadraticBezierTo(
      size.width * 0.75,
      size.height * (0.3 + 0.1 * flicker),
      size.width,
      size.height,
    );
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(FlamePainter oldDelegate) => flicker != oldDelegate.flicker;
}
