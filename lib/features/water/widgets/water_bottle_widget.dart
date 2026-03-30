import 'package:flutter/material.dart';
import 'dart:math' as math;

/// Premium 3D Water Bottle Widget with wave animations
/// Modern 2025/2026 glassmorphism design
class WaterBottleWidget extends StatefulWidget {
  final double progress;
  final int currentMl;
  final int goalMl;
  final Color waterColor;
  final VoidCallback? onTap;

  const WaterBottleWidget({
    super.key,
    required this.progress,
    required this.currentMl,
    required this.goalMl,
    this.waterColor = const Color(0xFF4FC3F7),
    this.onTap,
  });

  @override
  State<WaterBottleWidget> createState() => _WaterBottleWidgetState();
}

class _WaterBottleWidgetState extends State<WaterBottleWidget>
    with TickerProviderStateMixin {
  late AnimationController _waveController;
  late AnimationController _bubbleController;
  late AnimationController _glowController;
  late AnimationController _fillController;
  late Animation<double> _fillAnimation;

  double _previousProgress = 0;

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    )..repeat();

    _bubbleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat();

    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _fillController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _fillAnimation = Tween<double>(
      begin: 0,
      end: widget.progress,
    ).animate(CurvedAnimation(
      parent: _fillController,
      curve: Curves.easeOutCubic,
    ));

    _fillController.forward();
    _previousProgress = widget.progress;
  }

  @override
  void didUpdateWidget(WaterBottleWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.progress != widget.progress) {
      _fillAnimation = Tween<double>(
        begin: _previousProgress,
        end: widget.progress,
      ).animate(CurvedAnimation(
        parent: _fillController,
        curve: Curves.easeOutCubic,
      ));
      _fillController.forward(from: 0);
      _previousProgress = widget.progress;
    }
  }

  @override
  void dispose() {
    _waveController.dispose();
    _bubbleController.dispose();
    _glowController.dispose();
    _fillController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: Listenable.merge([
          _waveController,
          _bubbleController,
          _glowController,
          _fillAnimation,
        ]),
        builder: (context, child) {
          final progress = _fillAnimation.value.clamp(0.0, 1.0);
          return SizedBox(
            width: 180,
            height: 280,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Ambient glow
                _buildAmbientGlow(progress),
                // Bottle body
                _buildBottleBody(progress),
                // Water content
                _buildWaterContent(progress),
                // Bottle overlay (glass effect)
                _buildGlassOverlay(),
                // Progress info
                _buildProgressInfo(progress),
                // Bubbles
                if (progress > 0.1) _buildBubbles(progress),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildAmbientGlow(double progress) {
    final glowOpacity = 0.2 + (_glowController.value * 0.15);
    return Positioned.fill(
      child: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.center,
            radius: 0.8,
            colors: [
              widget.waterColor.withOpacity(glowOpacity * progress),
              Colors.transparent,
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottleBody(double progress) {
    return CustomPaint(
      size: const Size(180, 280),
      painter: _BottleBodyPainter(
        progress: progress,
        glowValue: _glowController.value,
      ),
    );
  }

  Widget _buildWaterContent(double progress) {
    return ClipPath(
      clipper: _BottleClipper(),
      child: Stack(
        children: [
          // Water fill
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 220 * progress,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    widget.waterColor.withOpacity(0.6),
                    widget.waterColor.withOpacity(0.8),
                    widget.waterColor,
                  ],
                ),
              ),
            ),
          ),
          // Wave effect
          if (progress > 0.05)
            Positioned(
              bottom: 220 * progress - 15,
              left: 0,
              right: 0,
              child: CustomPaint(
                size: const Size(180, 30),
                painter: _WavePainter(
                  animationValue: _waveController.value,
                  color: widget.waterColor,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildGlassOverlay() {
    return CustomPaint(
      size: const Size(180, 280),
      painter: _GlassOverlayPainter(),
    );
  }

  Widget _buildProgressInfo(double progress) {
    final isComplete = progress >= 1.0;
    return Positioned(
      top: 60,
      child: Column(
        children: [
          if (isComplete)
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.8, end: 1.2),
              duration: const Duration(milliseconds: 600),
              curve: Curves.elasticOut,
              builder: (context, value, child) {
                return Transform.scale(
                  scale: value,
                  child: const Text(
                    '🎉',
                    style: TextStyle(fontSize: 32),
                  ),
                );
              },
            ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.9),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: widget.waterColor.withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                Text(
                  '${widget.currentMl}',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: widget.waterColor.withBlue(200),
                  ),
                ),
                Text(
                  'of ${widget.goalMl} ml',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isComplete
                    ? [const Color(0xFF4CAF50), const Color(0xFF8BC34A)]
                    : [widget.waterColor, widget.waterColor.withBlue(255)],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${(progress * 100).toInt()}%',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBubbles(double progress) {
    return CustomPaint(
      size: const Size(180, 280),
      painter: _BubblePainter(
        animationValue: _bubbleController.value,
        waterHeight: 220 * progress,
      ),
    );
  }
}

/// Bottle body shape painter
class _BottleBodyPainter extends CustomPainter {
  final double progress;
  final double glowValue;

  _BottleBodyPainter({
    required this.progress,
    required this.glowValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey.shade200.withOpacity(0.3)
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = Colors.grey.shade300
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final path = _createBottlePath(size);
    canvas.drawPath(path, paint);
    canvas.drawPath(path, borderPaint);
  }

  Path _createBottlePath(Size size) {
    final path = Path();
    final w = size.width;
    final h = size.height;

    // Bottle neck
    path.moveTo(w * 0.35, 0);
    path.lineTo(w * 0.35, h * 0.08);
    path.quadraticBezierTo(w * 0.2, h * 0.12, w * 0.15, h * 0.2);

    // Left side
    path.lineTo(w * 0.12, h * 0.85);
    path.quadraticBezierTo(w * 0.12, h, w * 0.25, h);

    // Bottom
    path.lineTo(w * 0.75, h);
    path.quadraticBezierTo(w * 0.88, h, w * 0.88, h * 0.85);

    // Right side
    path.lineTo(w * 0.85, h * 0.2);
    path.quadraticBezierTo(w * 0.8, h * 0.12, w * 0.65, h * 0.08);

    // Neck right
    path.lineTo(w * 0.65, 0);
    path.close();

    return path;
  }

  @override
  bool shouldRepaint(covariant _BottleBodyPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.glowValue != glowValue;
  }
}

/// Clipper for water content
class _BottleClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    final w = size.width;
    final h = size.height;

    // Inner bottle shape (slightly smaller)
    path.moveTo(w * 0.36, h * 0.08);
    path.quadraticBezierTo(w * 0.22, h * 0.12, w * 0.17, h * 0.2);
    path.lineTo(w * 0.14, h * 0.85);
    path.quadraticBezierTo(w * 0.14, h * 0.98, w * 0.26, h * 0.98);
    path.lineTo(w * 0.74, h * 0.98);
    path.quadraticBezierTo(w * 0.86, h * 0.98, w * 0.86, h * 0.85);
    path.lineTo(w * 0.83, h * 0.2);
    path.quadraticBezierTo(w * 0.78, h * 0.12, w * 0.64, h * 0.08);
    path.close();

    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

/// Glass overlay effect
class _GlassOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Left highlight
    final highlightPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [
          Colors.white.withOpacity(0.4),
          Colors.white.withOpacity(0.0),
        ],
      ).createShader(Rect.fromLTWH(w * 0.15, h * 0.15, w * 0.15, h * 0.7));

    final highlightPath = Path()
      ..moveTo(w * 0.18, h * 0.22)
      ..quadraticBezierTo(w * 0.16, h * 0.5, w * 0.16, h * 0.8)
      ..lineTo(w * 0.22, h * 0.8)
      ..quadraticBezierTo(w * 0.22, h * 0.5, w * 0.24, h * 0.22)
      ..close();

    canvas.drawPath(highlightPath, highlightPaint);

    // Cap
    final capPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.grey.shade400,
          Colors.grey.shade600,
        ],
      ).createShader(Rect.fromLTWH(w * 0.32, 0, w * 0.36, h * 0.06));

    final capPath = Path()
      ..addRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.32, 0, w * 0.36, h * 0.06),
        const Radius.circular(4),
      ));

    canvas.drawPath(capPath, capPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Wave animation painter
class _WavePainter extends CustomPainter {
  final double animationValue;
  final Color color;

  _WavePainter({
    required this.animationValue,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withOpacity(0.6)
      ..style = PaintingStyle.fill;

    final path = Path();
    path.moveTo(0, size.height);

    for (double i = 0; i <= size.width; i++) {
      final y = size.height / 2 +
          math.sin((i / size.width * 4 * math.pi) +
                  (animationValue * 2 * math.pi)) *
              8 +
          math.sin((i / size.width * 2 * math.pi) +
                  (animationValue * 2 * math.pi * 0.7)) *
              4;
      path.lineTo(i, y);
    }

    path.lineTo(size.width, size.height);
    path.close();
    canvas.drawPath(path, paint);

    // Second wave layer
    final paint2 = Paint()
      ..color = color.withOpacity(0.4)
      ..style = PaintingStyle.fill;

    final path2 = Path();
    path2.moveTo(0, size.height);

    for (double i = 0; i <= size.width; i++) {
      final y = size.height / 2 +
          math.sin((i / size.width * 3 * math.pi) +
                  (animationValue * 2 * math.pi * 1.3)) *
              6;
      path2.lineTo(i, y);
    }

    path2.lineTo(size.width, size.height);
    path2.close();
    canvas.drawPath(path2, paint2);
  }

  @override
  bool shouldRepaint(covariant _WavePainter oldDelegate) {
    return oldDelegate.animationValue != animationValue;
  }
}

/// Bubble animation painter
class _BubblePainter extends CustomPainter {
  final double animationValue;
  final double waterHeight;

  _BubblePainter({
    required this.animationValue,
    required this.waterHeight,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final bubbles = [
      _Bubble(0.3, 0.2, 4),
      _Bubble(0.5, 0.4, 3),
      _Bubble(0.7, 0.6, 5),
      _Bubble(0.4, 0.8, 3),
      _Bubble(0.6, 0.3, 4),
    ];

    for (final bubble in bubbles) {
      final x = size.width * bubble.xRatio;
      final baseY = size.height - waterHeight;
      final yOffset = (animationValue + bubble.yOffset) % 1.0;
      final y = baseY + waterHeight * (1 - yOffset);

      if (y < size.height && y > baseY) {
        final opacity = (1 - yOffset) * 0.6;
        final paint = Paint()
          ..color = Colors.white.withOpacity(opacity)
          ..style = PaintingStyle.fill;

        canvas.drawCircle(Offset(x, y), bubble.radius, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _BubblePainter oldDelegate) {
    return oldDelegate.animationValue != animationValue ||
        oldDelegate.waterHeight != waterHeight;
  }
}

class _Bubble {
  final double xRatio;
  final double yOffset;
  final double radius;

  _Bubble(this.xRatio, this.yOffset, this.radius);
}
