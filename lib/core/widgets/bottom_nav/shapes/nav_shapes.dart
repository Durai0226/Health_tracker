import 'dart:ui';
import 'package:flutter/material.dart';
import 'dart:math' as math;

/// Pill-shaped nav (Medicine) - Rounded capsule ends
class PillNavPainter extends CustomPainter {
  final Color color;
  final bool isDark;

  PillNavPainter({required this.color, required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = isDark ? Colors.black.withValues(alpha: 0.7) : Colors.white.withValues(alpha: 0.9)
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = color.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Radius.circular(size.height / 2),
    );

    canvas.drawRRect(rect, paint);
    canvas.drawRRect(rect, borderPaint);
  }

  @override
  bool shouldRepaint(PillNavPainter oldDelegate) => 
      color != oldDelegate.color || isDark != oldDelegate.isDark;
}

/// Wave-top nav (Water) - Sinusoidal wave at top edge
class WaveNavPainter extends CustomPainter {
  final Color color;
  final bool isDark;
  final double wavePhase;

  WaveNavPainter({required this.color, required this.isDark, this.wavePhase = 0});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = isDark ? Colors.black.withValues(alpha: 0.7) : Colors.white.withValues(alpha: 0.9)
      ..style = PaintingStyle.fill;

    final path = Path();
    final waveHeight = 8.0;
    final waveCount = 3;

    path.moveTo(0, size.height);
    path.lineTo(0, waveHeight + 10);

    // Draw wave at top
    for (int i = 0; i <= size.width.toInt(); i++) {
      final x = i.toDouble();
      final y = waveHeight + math.sin((x / size.width * waveCount * math.pi * 2) + wavePhase) * waveHeight + 10;
      path.lineTo(x, y);
    }

    path.lineTo(size.width, size.height);
    path.close();

    canvas.drawPath(path, paint);

    // Border
    final borderPaint = Paint()
      ..color = color.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawPath(path, borderPaint);
  }

  @override
  bool shouldRepaint(WaveNavPainter oldDelegate) => 
      wavePhase != oldDelegate.wavePhase || color != oldDelegate.color;
}

/// Zen circle notch nav (Focus) - Smooth circular indent in center
class ZenNavPainter extends CustomPainter {
  final Color color;
  final bool isDark;
  final double breathScale;

  ZenNavPainter({required this.color, required this.isDark, this.breathScale = 1.0});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = isDark ? Colors.black.withValues(alpha: 0.7) : Colors.white.withValues(alpha: 0.9)
      ..style = PaintingStyle.fill;

    final notchRadius = 28.0 * breathScale;
    final centerX = size.width / 2;

    final path = Path();
    path.moveTo(0, 0);
    path.lineTo(centerX - notchRadius - 20, 0);
    
    // Smooth curve into notch
    path.quadraticBezierTo(
      centerX - notchRadius,
      0,
      centerX - notchRadius,
      notchRadius * 0.5,
    );
    
    // Arc for the notch
    path.arcToPoint(
      Offset(centerX + notchRadius, notchRadius * 0.5),
      radius: Radius.circular(notchRadius),
      clockwise: false,
    );
    
    // Smooth curve out of notch
    path.quadraticBezierTo(
      centerX + notchRadius,
      0,
      centerX + notchRadius + 20,
      0,
    );
    
    path.lineTo(size.width, 0);
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();

    canvas.drawPath(path, paint);

    final borderPaint = Paint()
      ..color = color.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawPath(path, borderPaint);
  }

  @override
  bool shouldRepaint(ZenNavPainter oldDelegate) => 
      breathScale != oldDelegate.breathScale || color != oldDelegate.color;
}

/// Angular athletic nav (Fitness) - Sharp geometric edges
class AngularNavPainter extends CustomPainter {
  final Color color;
  final bool isDark;

  AngularNavPainter({required this.color, required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = isDark ? Colors.black.withValues(alpha: 0.7) : Colors.white.withValues(alpha: 0.9)
      ..style = PaintingStyle.fill;

    final cutSize = 12.0;

    final path = Path();
    path.moveTo(cutSize, 0);
    path.lineTo(size.width - cutSize, 0);
    path.lineTo(size.width, cutSize);
    path.lineTo(size.width, size.height - cutSize);
    path.lineTo(size.width - cutSize, size.height);
    path.lineTo(cutSize, size.height);
    path.lineTo(0, size.height - cutSize);
    path.lineTo(0, cutSize);
    path.close();

    canvas.drawPath(path, paint);

    final borderPaint = Paint()
      ..color = color.withValues(alpha: 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawPath(path, borderPaint);
  }

  @override
  bool shouldRepaint(AngularNavPainter oldDelegate) => color != oldDelegate.color;
}

/// Card-stack nav (Finance) - 3D layered depth effect
class CardStackNavPainter extends CustomPainter {
  final Color color;
  final bool isDark;

  CardStackNavPainter({required this.color, required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    // Back layer (shadow)
    final backPaint = Paint()
      ..color = color.withValues(alpha: 0.15)
      ..style = PaintingStyle.fill;

    final backRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(4, 6, size.width - 8, size.height - 4),
      const Radius.circular(20),
    );
    canvas.drawRRect(backRect, backPaint);

    // Middle layer
    final midPaint = Paint()
      ..color = color.withValues(alpha: 0.25)
      ..style = PaintingStyle.fill;

    final midRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(2, 3, size.width - 4, size.height - 2),
      const Radius.circular(22),
    );
    canvas.drawRRect(midRect, midPaint);

    // Front layer (main)
    final frontPaint = Paint()
      ..color = isDark ? Colors.black.withValues(alpha: 0.7) : Colors.white.withValues(alpha: 0.9)
      ..style = PaintingStyle.fill;

    final frontRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height - 4),
      const Radius.circular(24),
    );
    canvas.drawRRect(frontRect, frontPaint);

    final borderPaint = Paint()
      ..color = color.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawRRect(frontRect, borderPaint);
  }

  @override
  bool shouldRepaint(CardStackNavPainter oldDelegate) => color != oldDelegate.color;
}

/// Crescent moon nav (Luna) - Asymmetric gentle curve
class CrescentNavPainter extends CustomPainter {
  final Color color;
  final bool isDark;
  final double glowIntensity;

  CrescentNavPainter({required this.color, required this.isDark, this.glowIntensity = 1.0});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = isDark ? Colors.black.withValues(alpha: 0.7) : Colors.white.withValues(alpha: 0.9)
      ..style = PaintingStyle.fill;

    final path = Path();
    path.moveTo(0, size.height * 0.3);
    
    // Left curve up
    path.quadraticBezierTo(
      size.width * 0.15, 0,
      size.width * 0.35, 0,
    );
    
    // Top straight-ish
    path.lineTo(size.width * 0.65, 0);
    
    // Right curve down more dramatically
    path.quadraticBezierTo(
      size.width * 0.85, 0,
      size.width, size.height * 0.15,
    );
    
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();

    // Glow effect
    if (glowIntensity > 0) {
      final glowPaint = Paint()
        ..color = color.withValues(alpha: 0.2 * glowIntensity)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 15);
      canvas.drawPath(path, glowPaint);
    }

    canvas.drawPath(path, paint);

    final borderPaint = Paint()
      ..color = color.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawPath(path, borderPaint);
  }

  @override
  bool shouldRepaint(CrescentNavPainter oldDelegate) => 
      glowIntensity != oldDelegate.glowIntensity || color != oldDelegate.color;
}

/// Organic blob nav (Mood) - Irregular rounded edges
class BlobNavPainter extends CustomPainter {
  final Color color;
  final bool isDark;
  final double morphProgress;

  BlobNavPainter({required this.color, required this.isDark, this.morphProgress = 0});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = isDark ? Colors.black.withValues(alpha: 0.7) : Colors.white.withValues(alpha: 0.9)
      ..style = PaintingStyle.fill;

    final variance = math.sin(morphProgress * math.pi * 2) * 4;

    final path = Path();
    path.moveTo(size.width * 0.1, size.height * 0.4);
    
    path.cubicTo(
      size.width * 0.05, size.height * (0.1 + variance * 0.02),
      size.width * 0.25, -variance,
      size.width * 0.5, size.height * 0.05,
    );
    
    path.cubicTo(
      size.width * 0.75, -variance,
      size.width * 0.95, size.height * (0.1 - variance * 0.02),
      size.width * 0.9, size.height * 0.4,
    );
    
    path.quadraticBezierTo(
      size.width, size.height * 0.7,
      size.width * 0.9, size.height,
    );
    
    path.lineTo(size.width * 0.1, size.height);
    
    path.quadraticBezierTo(
      0, size.height * 0.7,
      size.width * 0.1, size.height * 0.4,
    );

    canvas.drawPath(path, paint);

    final borderPaint = Paint()
      ..color = color.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawPath(path, borderPaint);
  }

  @override
  bool shouldRepaint(BlobNavPainter oldDelegate) => 
      morphProgress != oldDelegate.morphProgress || color != oldDelegate.color;
}

/// Paper fold nav (Notes) - Folded corner detail
class PaperNavPainter extends CustomPainter {
  final Color color;
  final bool isDark;

  PaperNavPainter({required this.color, required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = isDark ? Colors.black.withValues(alpha: 0.7) : Colors.white.withValues(alpha: 0.9)
      ..style = PaintingStyle.fill;

    final foldSize = 20.0;
    final radius = 16.0;

    final path = Path();
    path.moveTo(radius, 0);
    path.lineTo(size.width - foldSize, 0);
    path.lineTo(size.width, foldSize);
    path.lineTo(size.width, size.height - radius);
    path.quadraticBezierTo(size.width, size.height, size.width - radius, size.height);
    path.lineTo(radius, size.height);
    path.quadraticBezierTo(0, size.height, 0, size.height - radius);
    path.lineTo(0, radius);
    path.quadraticBezierTo(0, 0, radius, 0);
    path.close();

    canvas.drawPath(path, paint);

    // Fold triangle
    final foldPaint = Paint()
      ..color = color.withValues(alpha: 0.2)
      ..style = PaintingStyle.fill;

    final foldPath = Path();
    foldPath.moveTo(size.width - foldSize, 0);
    foldPath.lineTo(size.width - foldSize, foldSize);
    foldPath.lineTo(size.width, foldSize);
    foldPath.close();
    canvas.drawPath(foldPath, foldPaint);

    final borderPaint = Paint()
      ..color = color.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawPath(path, borderPaint);
  }

  @override
  bool shouldRepaint(PaperNavPainter oldDelegate) => color != oldDelegate.color;
}

/// Book spine nav (Exam) - Raised center line
class BookSpineNavPainter extends CustomPainter {
  final Color color;
  final bool isDark;

  BookSpineNavPainter({required this.color, required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = isDark ? Colors.black.withValues(alpha: 0.7) : Colors.white.withValues(alpha: 0.9)
      ..style = PaintingStyle.fill;

    final radius = 20.0;
    final spineWidth = 4.0;
    final centerX = size.width / 2;

    // Main shape
    final path = Path();
    path.addRRect(RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Radius.circular(radius),
    ));
    canvas.drawPath(path, paint);

    // Center spine ridge
    final spinePaint = Paint()
      ..color = color.withValues(alpha: 0.2)
      ..style = PaintingStyle.fill;

    canvas.drawRect(
      Rect.fromLTWH(centerX - spineWidth / 2, 0, spineWidth, size.height),
      spinePaint,
    );

    final borderPaint = Paint()
      ..color = color.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawPath(path, borderPaint);
  }

  @override
  bool shouldRepaint(BookSpineNavPainter oldDelegate) => color != oldDelegate.color;
}

/// Bell dome nav (Reminders) - Curved top like bell
class BellDomeNavPainter extends CustomPainter {
  final Color color;
  final bool isDark;
  final double shakeAngle;

  BellDomeNavPainter({required this.color, required this.isDark, this.shakeAngle = 0});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.translate(size.width / 2, size.height);
    canvas.rotate(shakeAngle);
    canvas.translate(-size.width / 2, -size.height);

    final paint = Paint()
      ..color = isDark ? Colors.black.withValues(alpha: 0.7) : Colors.white.withValues(alpha: 0.9)
      ..style = PaintingStyle.fill;

    final path = Path();
    final domeHeight = 12.0;

    path.moveTo(0, domeHeight);
    path.quadraticBezierTo(
      size.width * 0.3, 0,
      size.width * 0.5, 0,
    );
    path.quadraticBezierTo(
      size.width * 0.7, 0,
      size.width, domeHeight,
    );
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();

    canvas.drawPath(path, paint);

    final borderPaint = Paint()
      ..color = color.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawPath(path, borderPaint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(BellDomeNavPainter oldDelegate) => 
      shakeAngle != oldDelegate.shakeAngle || color != oldDelegate.color;
}

/// Flame streak nav (Habit) - Rising edges
class FlameStreakNavPainter extends CustomPainter {
  final Color color;
  final bool isDark;
  final double flickerIntensity;

  FlameStreakNavPainter({required this.color, required this.isDark, this.flickerIntensity = 1.0});

  @override
  void paint(Canvas canvas, Size size) {
    // Flame glow at top
    final glowPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          color.withValues(alpha: 0.3 * flickerIntensity),
          color.withValues(alpha: 0.0),
        ],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, -20, size.width, 30));

    final flamePath = Path();
    flamePath.moveTo(size.width * 0.3, 0);
    flamePath.quadraticBezierTo(size.width * 0.5, -15 * flickerIntensity, size.width * 0.7, 0);
    flamePath.close();
    canvas.drawPath(flamePath, glowPaint);

    // Main nav shape
    final paint = Paint()
      ..color = isDark ? Colors.black.withValues(alpha: 0.7) : Colors.white.withValues(alpha: 0.9)
      ..style = PaintingStyle.fill;

    final path = Path();
    path.moveTo(0, size.height * 0.2);
    path.quadraticBezierTo(0, 0, size.width * 0.15, 0);
    path.lineTo(size.width * 0.35, 0);
    path.quadraticBezierTo(size.width * 0.5, -8 * flickerIntensity, size.width * 0.65, 0);
    path.lineTo(size.width * 0.85, 0);
    path.quadraticBezierTo(size.width, 0, size.width, size.height * 0.2);
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();

    canvas.drawPath(path, paint);

    final borderPaint = Paint()
      ..color = color.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawPath(path, borderPaint);
  }

  @override
  bool shouldRepaint(FlameStreakNavPainter oldDelegate) => 
      flickerIntensity != oldDelegate.flickerIntensity || color != oldDelegate.color;
}

/// Floating island nav (Main) - Elevated with strong shadow
class FloatingIslandNavPainter extends CustomPainter {
  final Color color;
  final bool isDark;

  FloatingIslandNavPainter({required this.color, required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    // Shadow layers
    for (int i = 3; i >= 0; i--) {
      final shadowPaint = Paint()
        ..color = Colors.black.withValues(alpha: 0.05 * (4 - i))
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 8.0 + i * 4);

      final shadowRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 4.0 + i * 2, size.width, size.height - 2),
        const Radius.circular(28),
      );
      canvas.drawRRect(shadowRect, shadowPaint);
    }

    // Main shape
    final paint = Paint()
      ..color = isDark ? Colors.black.withValues(alpha: 0.8) : Colors.white.withValues(alpha: 0.95)
      ..style = PaintingStyle.fill;

    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height - 4),
      const Radius.circular(28),
    );
    canvas.drawRRect(rect, paint);

    final borderPaint = Paint()
      ..color = color.withValues(alpha: 0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawRRect(rect, borderPaint);
  }

  @override
  bool shouldRepaint(FloatingIslandNavPainter oldDelegate) => color != oldDelegate.color;
}
