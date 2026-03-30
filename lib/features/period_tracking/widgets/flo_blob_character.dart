import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../theme/flo_theme.dart';

/// Animated blob character with face expressions
/// Based on Flo's cute blob illustrations from the Behance design
class FloBlobCharacter extends StatefulWidget {
  final CyclePhaseType phase;
  final double size;
  final bool animate;
  final BlobMood? overrideMood;

  const FloBlobCharacter({
    super.key,
    required this.phase,
    this.size = 60,
    this.animate = true,
    this.overrideMood,
  });

  @override
  State<FloBlobCharacter> createState() => _FloBlobCharacterState();
}

class _FloBlobCharacterState extends State<FloBlobCharacter>
    with TickerProviderStateMixin {
  late AnimationController _bounceController;
  late AnimationController _blinkController;
  late Animation<double> _bounceAnimation;
  late Animation<double> _blinkAnimation;

  @override
  void initState() {
    super.initState();
    
    _bounceController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _blinkController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );

    _bounceAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _bounceController,
        curve: Curves.easeInOut,
      ),
    );

    _blinkAnimation = Tween<double>(begin: 1, end: 0.1).animate(
      CurvedAnimation(
        parent: _blinkController,
        curve: Curves.easeInOut,
      ),
    );

    if (widget.animate) {
      _bounceController.repeat(reverse: true);
      _startBlinking();
    }
  }

  void _startBlinking() async {
    while (mounted && widget.animate) {
      await Future.delayed(Duration(milliseconds: 2000 + math.Random().nextInt(3000)));
      if (mounted) {
        await _blinkController.forward();
        await _blinkController.reverse();
      }
    }
  }

  @override
  void dispose() {
    _bounceController.dispose();
    _blinkController.dispose();
    super.dispose();
  }

  BlobMood get _mood => widget.overrideMood ?? _getMoodForPhase(widget.phase);

  BlobMood _getMoodForPhase(CyclePhaseType phase) {
    switch (phase) {
      case CyclePhaseType.menstrual:
        return BlobMood.tired;
      case CyclePhaseType.follicular:
        return BlobMood.energetic;
      case CyclePhaseType.ovulation:
        return BlobMood.loving;
      case CyclePhaseType.luteal:
        return BlobMood.calm;
      case CyclePhaseType.pms:
        return BlobMood.sensitive;
    }
  }

  Color get _blobColor {
    switch (widget.phase) {
      case CyclePhaseType.menstrual:
        return FloTheme.blobPink;
      case CyclePhaseType.follicular:
        return FloTheme.blobYellow;
      case CyclePhaseType.ovulation:
        return FloTheme.blobBlue;
      case CyclePhaseType.luteal:
        return FloTheme.blobGreen;
      case CyclePhaseType.pms:
        return FloTheme.blobOrange;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_bounceAnimation, _blinkAnimation]),
      builder: (context, child) {
        final bounceOffset = widget.animate 
            ? math.sin(_bounceAnimation.value * math.pi) * 3 
            : 0.0;

        return Transform.translate(
          offset: Offset(0, -bounceOffset),
          child: CustomPaint(
            size: Size(widget.size, widget.size),
            painter: _BlobPainter(
              color: _blobColor,
              mood: _mood,
              eyeOpenness: _blinkAnimation.value,
              bounceValue: _bounceAnimation.value,
            ),
          ),
        );
      },
    );
  }
}

/// Blob mood types
enum BlobMood {
  happy,
  tired,
  energetic,
  loving,
  calm,
  sensitive,
  sad,
  sleepy,
}

/// Custom painter for the blob character
class _BlobPainter extends CustomPainter {
  final Color color;
  final BlobMood mood;
  final double eyeOpenness;
  final double bounceValue;

  _BlobPainter({
    required this.color,
    required this.mood,
    required this.eyeOpenness,
    required this.bounceValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 * 0.85;

    // Blob body with slight wobble
    final wobble = math.sin(bounceValue * math.pi * 2) * 2;
    final path = Path();
    
    // Create organic blob shape
    for (int i = 0; i < 360; i += 10) {
      final angle = i * math.pi / 180;
      final wobbleAmount = math.sin(angle * 3 + bounceValue * math.pi * 2) * 3;
      final r = radius + wobbleAmount + (i % 20 == 0 ? wobble : 0);
      final x = center.dx + r * math.cos(angle);
      final y = center.dy + r * math.sin(angle);
      
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();

    // Shadow
    canvas.drawPath(
      path.shift(const Offset(0, 3)),
      Paint()
        ..color = Colors.black.withOpacity(0.1)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );

    // Body gradient
    final bodyPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.3, -0.3),
        colors: [
          color.withOpacity(0.9),
          color,
          _darken(color, 0.1),
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius));

    canvas.drawPath(path, bodyPaint);

    // Draw face based on mood
    _drawFace(canvas, center, radius, size);
  }

  void _drawFace(Canvas canvas, Offset center, double radius, Size size) {
    final eyeY = center.dy - radius * 0.1;
    final eyeSpacing = radius * 0.35;
    final leftEyeX = center.dx - eyeSpacing;
    final rightEyeX = center.dx + eyeSpacing;
    final eyeRadius = radius * 0.12;

    switch (mood) {
      case BlobMood.happy:
      case BlobMood.energetic:
        _drawHappyEyes(canvas, leftEyeX, rightEyeX, eyeY, eyeRadius);
        _drawSmile(canvas, center, radius);
        break;
      case BlobMood.tired:
      case BlobMood.sleepy:
        _drawTiredEyes(canvas, leftEyeX, rightEyeX, eyeY, eyeRadius);
        _drawNeutralMouth(canvas, center, radius);
        break;
      case BlobMood.loving:
        _drawHeartEyes(canvas, leftEyeX, rightEyeX, eyeY, eyeRadius);
        _drawSmile(canvas, center, radius);
        break;
      case BlobMood.calm:
        _drawCalmEyes(canvas, leftEyeX, rightEyeX, eyeY, eyeRadius);
        _drawSmile(canvas, center, radius, small: true);
        break;
      case BlobMood.sensitive:
        _drawSadEyes(canvas, leftEyeX, rightEyeX, eyeY, eyeRadius);
        _drawWavyMouth(canvas, center, radius);
        break;
      case BlobMood.sad:
        _drawSadEyes(canvas, leftEyeX, rightEyeX, eyeY, eyeRadius);
        _drawSadMouth(canvas, center, radius);
        break;
    }
  }

  void _drawHappyEyes(Canvas canvas, double leftX, double rightX, double y, double radius) {
    final paint = Paint()
      ..color = FloTheme.textPrimary
      ..style = PaintingStyle.fill;

    // Left eye
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(leftX, y),
        width: radius * 2,
        height: radius * 2 * eyeOpenness,
      ),
      paint,
    );

    // Right eye
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(rightX, y),
        width: radius * 2,
        height: radius * 2 * eyeOpenness,
      ),
      paint,
    );

    // Eye highlights
    if (eyeOpenness > 0.5) {
      final highlightPaint = Paint()..color = Colors.white;
      canvas.drawCircle(
        Offset(leftX - radius * 0.3, y - radius * 0.3),
        radius * 0.3,
        highlightPaint,
      );
      canvas.drawCircle(
        Offset(rightX - radius * 0.3, y - radius * 0.3),
        radius * 0.3,
        highlightPaint,
      );
    }
  }

  void _drawTiredEyes(Canvas canvas, double leftX, double rightX, double y, double radius) {
    final paint = Paint()
      ..color = FloTheme.textPrimary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    // Curved closed eyes (like ^_^)
    final leftPath = Path()
      ..moveTo(leftX - radius, y)
      ..quadraticBezierTo(leftX, y - radius * 0.8, leftX + radius, y);

    final rightPath = Path()
      ..moveTo(rightX - radius, y)
      ..quadraticBezierTo(rightX, y - radius * 0.8, rightX + radius, y);

    canvas.drawPath(leftPath, paint);
    canvas.drawPath(rightPath, paint);
  }

  void _drawHeartEyes(Canvas canvas, double leftX, double rightX, double y, double radius) {
    final paint = Paint()
      ..color = FloTheme.periodPink
      ..style = PaintingStyle.fill;

    _drawHeart(canvas, Offset(leftX, y), radius * 1.2, paint);
    _drawHeart(canvas, Offset(rightX, y), radius * 1.2, paint);
  }

  void _drawHeart(Canvas canvas, Offset center, double size, Paint paint) {
    final path = Path();
    path.moveTo(center.dx, center.dy + size * 0.3);
    path.cubicTo(
      center.dx - size, center.dy - size * 0.3,
      center.dx - size * 0.5, center.dy - size,
      center.dx, center.dy - size * 0.4,
    );
    path.cubicTo(
      center.dx + size * 0.5, center.dy - size,
      center.dx + size, center.dy - size * 0.3,
      center.dx, center.dy + size * 0.3,
    );
    canvas.drawPath(path, paint);
  }

  void _drawCalmEyes(Canvas canvas, double leftX, double rightX, double y, double radius) {
    final paint = Paint()
      ..color = FloTheme.textPrimary
      ..style = PaintingStyle.fill;

    // Simple dot eyes
    canvas.drawCircle(Offset(leftX, y), radius * 0.8, paint);
    canvas.drawCircle(Offset(rightX, y), radius * 0.8, paint);
  }

  void _drawSadEyes(Canvas canvas, double leftX, double rightX, double y, double radius) {
    final paint = Paint()
      ..color = FloTheme.textPrimary
      ..style = PaintingStyle.fill;

    // Sad eyes (droopy)
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(leftX, y),
        width: radius * 1.8,
        height: radius * 1.5 * eyeOpenness,
      ),
      paint,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(rightX, y),
        width: radius * 1.8,
        height: radius * 1.5 * eyeOpenness,
      ),
      paint,
    );

    // Eyebrows (worried)
    final browPaint = Paint()
      ..color = FloTheme.textPrimary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(
      Offset(leftX - radius, y - radius * 1.5),
      Offset(leftX + radius * 0.5, y - radius * 1.8),
      browPaint,
    );
    canvas.drawLine(
      Offset(rightX + radius, y - radius * 1.5),
      Offset(rightX - radius * 0.5, y - radius * 1.8),
      browPaint,
    );
  }

  void _drawSmile(Canvas canvas, Offset center, double radius, {bool small = false}) {
    final paint = Paint()
      ..color = FloTheme.textPrimary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    final mouthY = center.dy + radius * 0.3;
    final mouthWidth = radius * (small ? 0.4 : 0.6);
    final smileDepth = radius * (small ? 0.15 : 0.25);

    final path = Path()
      ..moveTo(center.dx - mouthWidth, mouthY)
      ..quadraticBezierTo(
        center.dx,
        mouthY + smileDepth,
        center.dx + mouthWidth,
        mouthY,
      );

    canvas.drawPath(path, paint);
  }

  void _drawNeutralMouth(Canvas canvas, Offset center, double radius) {
    final paint = Paint()
      ..color = FloTheme.textPrimary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    final mouthY = center.dy + radius * 0.35;
    final mouthWidth = radius * 0.3;

    canvas.drawLine(
      Offset(center.dx - mouthWidth, mouthY),
      Offset(center.dx + mouthWidth, mouthY),
      paint,
    );
  }

  void _drawWavyMouth(Canvas canvas, Offset center, double radius) {
    final paint = Paint()
      ..color = FloTheme.textPrimary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    final mouthY = center.dy + radius * 0.35;
    final mouthWidth = radius * 0.4;

    final path = Path()
      ..moveTo(center.dx - mouthWidth, mouthY)
      ..quadraticBezierTo(
        center.dx - mouthWidth * 0.5,
        mouthY - radius * 0.1,
        center.dx,
        mouthY,
      )
      ..quadraticBezierTo(
        center.dx + mouthWidth * 0.5,
        mouthY + radius * 0.1,
        center.dx + mouthWidth,
        mouthY,
      );

    canvas.drawPath(path, paint);
  }

  void _drawSadMouth(Canvas canvas, Offset center, double radius) {
    final paint = Paint()
      ..color = FloTheme.textPrimary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    final mouthY = center.dy + radius * 0.4;
    final mouthWidth = radius * 0.4;

    final path = Path()
      ..moveTo(center.dx - mouthWidth, mouthY)
      ..quadraticBezierTo(
        center.dx,
        mouthY - radius * 0.2,
        center.dx + mouthWidth,
        mouthY,
      );

    canvas.drawPath(path, paint);
  }

  Color _darken(Color color, double amount) {
    final hsl = HSLColor.fromColor(color);
    return hsl.withLightness((hsl.lightness - amount).clamp(0.0, 1.0)).toColor();
  }

  @override
  bool shouldRepaint(covariant _BlobPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.mood != mood ||
        oldDelegate.eyeOpenness != eyeOpenness ||
        oldDelegate.bounceValue != bounceValue;
  }
}

/// Static blob for decoration
class FloStaticBlob extends StatelessWidget {
  final Color color;
  final double size;
  final BlobMood mood;

  const FloStaticBlob({
    super.key,
    required this.color,
    this.size = 40,
    this.mood = BlobMood.happy,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _BlobPainter(
        color: color,
        mood: mood,
        eyeOpenness: 1.0,
        bounceValue: 0,
      ),
    );
  }
}
