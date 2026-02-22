import 'dart:math';
import 'package:flutter/material.dart';
import 'ocean_aquarium_game.dart';

/// Coral Painter for different coral types
class CoralPainter extends CustomPainter {
  final CoralType type;
  final double size;

  CoralPainter({required this.type, required this.size});

  @override
  void paint(Canvas canvas, Size canvasSize) {
    switch (type) {
      case CoralType.brain:
        _paintBrainCoral(canvas, canvasSize);
        break;
      case CoralType.fan:
        _paintFanCoral(canvas, canvasSize);
        break;
      case CoralType.staghorn:
        _paintStaghornCoral(canvas, canvasSize);
        break;
      case CoralType.mushroom:
        _paintMushroomCoral(canvas, canvasSize);
        break;
    }
  }

  void _paintBrainCoral(Canvas canvas, Size canvasSize) {
    final paint = Paint()
      ..style = PaintingStyle.fill
      ..color = const Color(0xFFFF6B9D).withOpacity(0.8);

    // Main body
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(canvasSize.width / 2, canvasSize.height * 0.7),
        width: size * 0.8,
        height: size * 0.6,
      ),
      paint,
    );

    // Brain-like patterns
    paint
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = const Color(0xFFFF1744).withOpacity(0.6);

    for (int i = 0; i < 5; i++) {
      final path = Path();
      final startY = canvasSize.height * 0.5 + i * 8;
      path.moveTo(canvasSize.width * 0.3, startY);
      path.quadraticBezierTo(
        canvasSize.width * 0.4,
        startY + 5,
        canvasSize.width * 0.5,
        startY,
      );
      path.quadraticBezierTo(
        canvasSize.width * 0.6,
        startY - 5,
        canvasSize.width * 0.7,
        startY,
      );
      canvas.drawPath(path, paint);
    }
  }

  void _paintFanCoral(Canvas canvas, Size canvasSize) {
    final paint = Paint()
      ..style = PaintingStyle.fill
      ..color = const Color(0xFF9C27B0).withOpacity(0.7);

    final centerX = canvasSize.width / 2;
    final centerY = canvasSize.height;

    // Draw fan segments
    for (int i = 0; i < 7; i++) {
      final angle = -pi / 2 + (i - 3) * 0.3;
      final path = Path();
      path.moveTo(centerX, centerY);
      
      final x1 = centerX + cos(angle - 0.15) * size * 0.8;
      final y1 = centerY + sin(angle - 0.15) * size * 0.8;
      final x2 = centerX + cos(angle + 0.15) * size * 0.8;
      final y2 = centerY + sin(angle + 0.15) * size * 0.8;
      
      path.lineTo(x1, y1);
      path.quadraticBezierTo(
        centerX + cos(angle) * size,
        centerY + sin(angle) * size,
        x2,
        y2,
      );
      path.close();
      
      paint.color = Color.lerp(
        const Color(0xFF9C27B0),
        const Color(0xFFE1BEE7),
        i / 7,
      )!.withOpacity(0.7);
      
      canvas.drawPath(path, paint);
    }

    // Stem
    paint.color = const Color(0xFF6A1B9A).withOpacity(0.8);
    canvas.drawRect(
      Rect.fromCenter(
        center: Offset(centerX, centerY - 5),
        width: 8,
        height: 15,
      ),
      paint,
    );
  }

  void _paintStaghornCoral(Canvas canvas, Size canvasSize) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFFFFAB91).withOpacity(0.8);

    final centerX = canvasSize.width / 2;
    final centerY = canvasSize.height;

    // Draw branching structure
    _drawBranch(canvas, paint, centerX, centerY, -pi / 2, size * 0.7, 0);
  }

  void _drawBranch(Canvas canvas, Paint paint, double x, double y, double angle, double length, int depth) {
    if (depth > 2 || length < 10) return;

    final endX = x + cos(angle) * length;
    final endY = y + sin(angle) * length;

    canvas.drawLine(Offset(x, y), Offset(endX, endY), paint);

    // Branch left and right
    _drawBranch(canvas, paint, endX, endY, angle - 0.5, length * 0.7, depth + 1);
    _drawBranch(canvas, paint, endX, endY, angle + 0.5, length * 0.7, depth + 1);
  }

  void _paintMushroomCoral(Canvas canvas, Size canvasSize) {
    final paint = Paint()..style = PaintingStyle.fill;

    final centerX = canvasSize.width / 2;
    final centerY = canvasSize.height * 0.7;

    // Cap
    paint.color = const Color(0xFF4CAF50).withOpacity(0.8);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(centerX, centerY),
        width: size * 0.9,
        height: size * 0.4,
      ),
      paint,
    );

    // Spots on cap
    paint.color = const Color(0xFF81C784).withOpacity(0.6);
    for (int i = 0; i < 5; i++) {
      final spotX = centerX + (i - 2) * size * 0.15;
      canvas.drawCircle(Offset(spotX, centerY), 3, paint);
    }

    // Stem
    paint.color = const Color(0xFF388E3C).withOpacity(0.8);
    canvas.drawRect(
      Rect.fromCenter(
        center: Offset(centerX, centerY + size * 0.3),
        width: size * 0.2,
        height: size * 0.4,
      ),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Jellyfish Painter
class JellyfishPainter extends CustomPainter {
  final Color color;
  final double pulseScale;

  JellyfishPainter({required this.color, required this.pulseScale});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    final centerX = size.width / 2;
    final centerY = size.height * 0.3;

    // Bell/dome
    final bellPath = Path();
    bellPath.moveTo(centerX - size.width * 0.4 * pulseScale, centerY);
    bellPath.quadraticBezierTo(
      centerX - size.width * 0.3 * pulseScale,
      centerY - size.height * 0.25 * pulseScale,
      centerX,
      centerY - size.height * 0.3 * pulseScale,
    );
    bellPath.quadraticBezierTo(
      centerX + size.width * 0.3 * pulseScale,
      centerY - size.height * 0.25 * pulseScale,
      centerX + size.width * 0.4 * pulseScale,
      centerY,
    );
    bellPath.close();

    // Gradient fill
    paint.shader = RadialGradient(
      colors: [
        color.withOpacity(0.8),
        color.withOpacity(0.4),
      ],
    ).createShader(Rect.fromCircle(
      center: Offset(centerX, centerY - size.height * 0.15),
      radius: size.width * 0.4,
    ));

    canvas.drawPath(bellPath, paint);

    // Glow effect
    paint.shader = null;
    paint.color = color.withOpacity(0.3);
    paint.maskFilter = const MaskFilter.blur(BlurStyle.normal, 15);
    canvas.drawPath(bellPath, paint);

    // Tentacles
    paint.maskFilter = null;
    paint.style = PaintingStyle.stroke;
    paint.strokeWidth = 2;
    paint.color = color.withOpacity(0.6);

    for (int i = 0; i < 8; i++) {
      final path = Path();
      final startX = centerX + (i - 3.5) * size.width * 0.1;
      path.moveTo(startX, centerY);

      for (int j = 0; j < 4; j++) {
        final y = centerY + j * size.height * 0.2;
        final x = startX + sin(j * 0.5 + i) * 5;
        path.lineTo(x, y);
      }

      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

/// Treasure Chest Painter
class TreasureChestPainter extends CustomPainter {
  final bool isOpen;
  final double glowIntensity;

  TreasureChestPainter({required this.isOpen, required this.glowIntensity});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    final centerX = size.width / 2;
    final centerY = size.height / 2;

    // Chest base
    paint.color = const Color(0xFF8B4513);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(centerX, centerY + 10),
          width: size.width * 0.8,
          height: size.height * 0.5,
        ),
        const Radius.circular(8),
      ),
      paint,
    );

    // Gold bands
    paint.color = const Color(0xFFFFD700);
    canvas.drawRect(
      Rect.fromCenter(
        center: Offset(centerX, centerY + 5),
        width: size.width * 0.8,
        height: 4,
      ),
      paint,
    );
    canvas.drawRect(
      Rect.fromCenter(
        center: Offset(centerX, centerY + 20),
        width: size.width * 0.8,
        height: 4,
      ),
      paint,
    );

    // Lid
    if (isOpen) {
      // Open lid
      paint.color = const Color(0xFF654321);
      final lidPath = Path();
      lidPath.moveTo(centerX - size.width * 0.4, centerY - 15);
      lidPath.lineTo(centerX - size.width * 0.35, centerY - 35);
      lidPath.quadraticBezierTo(
        centerX,
        centerY - 40,
        centerX + size.width * 0.35,
        centerY - 35,
      );
      lidPath.lineTo(centerX + size.width * 0.4, centerY - 15);
      lidPath.close();
      canvas.drawPath(lidPath, paint);

      // Treasure glow
      if (glowIntensity > 0) {
        paint.color = const Color(0xFFFFD700).withOpacity(0.6 * glowIntensity);
        paint.maskFilter = const MaskFilter.blur(BlurStyle.normal, 20);
        canvas.drawCircle(
          Offset(centerX, centerY),
          30,
          paint,
        );

        // Gold coins
        paint.maskFilter = null;
        paint.color = const Color(0xFFFFD700);
        for (int i = 0; i < 5; i++) {
          canvas.drawCircle(
            Offset(
              centerX + (i - 2) * 8,
              centerY + 5,
            ),
            6,
            paint,
          );
        }
      }
    } else {
      // Closed lid
      paint.color = const Color(0xFF654321);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(centerX, centerY - 10),
            width: size.width * 0.8,
            height: size.height * 0.4,
          ),
          const Radius.circular(8),
        ),
        paint,
      );

      // Lock
      paint.color = const Color(0xFFFFD700);
      canvas.drawCircle(Offset(centerX, centerY), 8, paint);
      paint.color = const Color(0xFF8B4513);
      canvas.drawCircle(Offset(centerX, centerY), 4, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
