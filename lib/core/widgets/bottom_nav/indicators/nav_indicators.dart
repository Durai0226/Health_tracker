import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Floating Pill Indicator - Clean horizontal capsule (Image 1 style)
class PillIndicator extends StatelessWidget {
  final Color color;
  final double width;
  final double height;
  final Widget child;

  const PillIndicator({
    super.key,
    required this.color,
    required this.child,
    this.width = 64,
    this.height = 40,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(height / 2),
      ),
      child: Center(child: child),
    );
  }
}

/// Elevated Circle Indicator - Large circle extending above nav (Image 2 style)
class ElevatedCircleIndicator extends StatelessWidget {
  final Color color;
  final double size;
  final Widget child;
  final double glowIntensity;

  const ElevatedCircleIndicator({
    super.key,
    required this.color,
    required this.child,
    this.size = 56,
    this.glowIntensity = 0.4,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: glowIntensity),
            blurRadius: 20,
            spreadRadius: 4,
          ),
          BoxShadow(
            color: color.withValues(alpha: glowIntensity * 0.5),
            blurRadius: 40,
            spreadRadius: 8,
          ),
        ],
      ),
      child: Center(child: child),
    );
  }
}

/// Water Bubble Indicator - Circular floating bubble
class BubbleIndicator extends StatelessWidget {
  final Color color;
  final double size;
  final Widget child;

  const BubbleIndicator({
    super.key,
    required this.color,
    required this.child,
    this.size = 44,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: RadialGradient(
          colors: [
            color.withValues(alpha: 0.3),
            color.withValues(alpha: 0.1),
          ],
        ),
        shape: BoxShape.circle,
        border: Border.all(
          color: color.withValues(alpha: 0.3),
          width: 2,
        ),
      ),
      child: Center(child: child),
    );
  }
}

/// Hexagon Badge Indicator - Angular power badge for Fitness
class HexBadgeIndicator extends StatelessWidget {
  final Color color;
  final double size;
  final Widget child;

  const HexBadgeIndicator({
    super.key,
    required this.color,
    required this.child,
    this.size = 48,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _HexagonPainter(color: color),
      child: SizedBox(
        width: size,
        height: size,
        child: Center(child: child),
      ),
    );
  }
}

class _HexagonPainter extends CustomPainter {
  final Color color;
  _HexagonPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.2)
      ..style = PaintingStyle.fill;

    final path = Path();
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width / 2 - 2;

    for (int i = 0; i < 6; i++) {
      final angle = (i * 60 - 30) * math.pi / 180;
      final x = cx + r * math.cos(angle);
      final y = cy + r * math.sin(angle);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    canvas.drawPath(path, paint);

    // Glow border
    final borderPaint = Paint()
      ..color = color.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawPath(path, borderPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Credit Card Chip Indicator - For Finance
class ChipIndicator extends StatelessWidget {
  final Color color;
  final Widget child;

  const ChipIndicator({
    super.key,
    required this.color,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 36,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withValues(alpha: 0.25),
            color.withValues(alpha: 0.15),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: color.withValues(alpha: 0.4),
          width: 1.5,
        ),
      ),
      child: Center(child: child),
    );
  }
}

/// Crescent Moon Indicator - For Luna Cycle
class CrescentIndicator extends StatelessWidget {
  final Color color;
  final double size;
  final Widget child;

  const CrescentIndicator({
    super.key,
    required this.color,
    required this.child,
    this.size = 44,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        CustomPaint(
          painter: _CrescentPainter(color: color),
          child: SizedBox(width: size, height: size),
        ),
        SizedBox(
          width: size,
          height: size,
          child: Center(child: child),
        ),
      ],
    );
  }
}

class _CrescentPainter extends CustomPainter {
  final Color color;
  _CrescentPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.2)
      ..style = PaintingStyle.fill;

    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width / 2 - 2;

    // Draw main circle
    canvas.drawCircle(Offset(cx, cy), r, paint);

    // Cut out inner circle to create crescent
    final cutPaint = Paint()
      ..blendMode = BlendMode.clear;
    canvas.saveLayer(Rect.fromLTWH(0, 0, size.width, size.height), Paint());
    canvas.drawCircle(Offset(cx, cy), r, paint);
    canvas.drawCircle(Offset(cx + r * 0.4, cy), r * 0.8, cutPaint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Organic Blob Indicator - For Mood
class BlobIndicator extends StatelessWidget {
  final Color color;
  final double size;
  final Widget child;
  final double morphPhase;

  const BlobIndicator({
    super.key,
    required this.color,
    required this.child,
    this.size = 48,
    this.morphPhase = 0,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _BlobPainter(color: color, phase: morphPhase),
      child: SizedBox(
        width: size,
        height: size,
        child: Center(child: child),
      ),
    );
  }
}

class _BlobPainter extends CustomPainter {
  final Color color;
  final double phase;
  _BlobPainter({required this.color, required this.phase});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.2)
      ..style = PaintingStyle.fill;

    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width / 2 - 4;

    final path = Path();
    for (int i = 0; i <= 360; i += 10) {
      final angle = i * math.pi / 180;
      final wobble = math.sin(angle * 3 + phase * math.pi * 2) * 3;
      final x = cx + (r + wobble) * math.cos(angle);
      final y = cy + (r + wobble) * math.sin(angle);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _BlobPainter oldDelegate) => 
      oldDelegate.phase != phase;
}

/// Paper Tab Indicator - For Notes
class PaperTabIndicator extends StatelessWidget {
  final Color color;
  final Widget child;

  const PaperTabIndicator({
    super.key,
    required this.color,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _PaperTabPainter(color: color),
      child: SizedBox(
        width: 56,
        height: 44,
        child: Center(child: child),
      ),
    );
  }
}

class _PaperTabPainter extends CustomPainter {
  final Color color;
  _PaperTabPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.15)
      ..style = PaintingStyle.fill;

    final foldSize = 8.0;
    final path = Path()
      ..moveTo(0, foldSize)
      ..lineTo(foldSize, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawPath(path, paint);

    // Fold line
    final foldPaint = Paint()
      ..color = color.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawLine(Offset(0, foldSize), Offset(foldSize, 0), foldPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Bookmark Ribbon Indicator - For Exam Prep
class BookmarkIndicator extends StatelessWidget {
  final Color color;
  final Widget child;

  const BookmarkIndicator({
    super.key,
    required this.color,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          top: -8,
          left: 0,
          right: 0,
          child: Center(
            child: CustomPaint(
              painter: _BookmarkPainter(color: color),
              child: const SizedBox(width: 28, height: 52),
            ),
          ),
        ),
        SizedBox(
          width: 48,
          height: 44,
          child: Center(child: child),
        ),
      ],
    );
  }
}

class _BookmarkPainter extends CustomPainter {
  final Color color;
  _BookmarkPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.2)
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, size.height - 8)
      ..lineTo(size.width / 2, size.height - 16)
      ..lineTo(0, size.height - 8)
      ..close();

    canvas.drawPath(path, paint);

    // Border
    final borderPaint = Paint()
      ..color = color.withValues(alpha: 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawPath(path, borderPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Flame Badge Indicator - For Habit
class FlameBadgeIndicator extends StatelessWidget {
  final Color color;
  final double size;
  final Widget child;
  final double flickerPhase;

  const FlameBadgeIndicator({
    super.key,
    required this.color,
    required this.child,
    this.size = 48,
    this.flickerPhase = 0,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _FlameBadgePainter(color: color, phase: flickerPhase),
      child: SizedBox(
        width: size,
        height: size,
        child: Center(child: child),
      ),
    );
  }
}

class _FlameBadgePainter extends CustomPainter {
  final Color color;
  final double phase;
  _FlameBadgePainter({required this.color, required this.phase});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [
          color.withValues(alpha: 0.3),
          color.withValues(alpha: 0.1),
        ],
        center: const Alignment(0, 0.3),
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;

    final cx = size.width / 2;
    final baseY = size.height * 0.85;
    final flicker = math.sin(phase * math.pi * 2) * 2;

    final path = Path()
      ..moveTo(cx - size.width * 0.35, baseY)
      ..quadraticBezierTo(
        cx - size.width * 0.3, size.height * 0.5,
        cx, size.height * 0.1 + flicker,
      )
      ..quadraticBezierTo(
        cx + size.width * 0.3, size.height * 0.5,
        cx + size.width * 0.35, baseY,
      )
      ..quadraticBezierTo(
        cx, size.height * 0.7,
        cx - size.width * 0.35, baseY,
      );

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _FlameBadgePainter oldDelegate) => 
      oldDelegate.phase != phase;
}

/// Bell Highlight Indicator - For Reminders
class BellHighlightIndicator extends StatelessWidget {
  final Color color;
  final Widget child;
  final double shakeOffset;

  const BellHighlightIndicator({
    super.key,
    required this.color,
    required this.child,
    this.shakeOffset = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: Offset(shakeOffset, 0),
      child: Container(
        width: 52,
        height: 40,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(child: child),
      ),
    );
  }
}
