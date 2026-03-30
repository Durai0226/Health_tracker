import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;
import '../theme/aqua_theme.dart';

/// Premium Animated Water Droplet Widget
/// Features: Wave animation, bubble particles, dynamic gradients, glow effects
class AquaDropletWidget extends StatefulWidget {
  final double progress;
  final int currentMl;
  final int goalMl;
  final String beverageId;
  final VoidCallback? onTap;
  final double size;

  const AquaDropletWidget({
    super.key,
    required this.progress,
    required this.currentMl,
    required this.goalMl,
    this.beverageId = 'water',
    this.onTap,
    this.size = 280,
  });

  @override
  State<AquaDropletWidget> createState() => _AquaDropletWidgetState();
}

class _AquaDropletWidgetState extends State<AquaDropletWidget>
    with TickerProviderStateMixin {
  late AnimationController _waveController;
  late AnimationController _bubbleController;
  late AnimationController _glowController;
  late AnimationController _fillController;
  late AnimationController _celebrateController;
  late Animation<double> _fillAnimation;

  double _previousProgress = 0;
  bool _showCelebration = false;

  @override
  void initState() {
    super.initState();
    _initAnimations();
  }

  void _initAnimations() {
    // Wave animation - continuous
    _waveController = AnimationController(
      vsync: this,
      duration: AquaTheme.animationWave,
    )..repeat();

    // Bubble animation - continuous
    _bubbleController = AnimationController(
      vsync: this,
      duration: AquaTheme.animationBubble,
    )..repeat();

    // Glow pulse animation
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    // Fill level animation
    _fillController = AnimationController(
      vsync: this,
      duration: AquaTheme.animationFill,
    );

    _fillAnimation = Tween<double>(
      begin: 0,
      end: widget.progress.clamp(0.0, 1.0),
    ).animate(CurvedAnimation(
      parent: _fillController,
      curve: AquaTheme.curveDefault,
    ));

    // Celebration animation
    _celebrateController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _fillController.forward();
    _previousProgress = widget.progress;
  }

  @override
  void didUpdateWidget(AquaDropletWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    if (oldWidget.progress != widget.progress) {
      final wasComplete = _previousProgress >= 1.0;
      final isComplete = widget.progress >= 1.0;
      
      _fillAnimation = Tween<double>(
        begin: _previousProgress.clamp(0.0, 1.0),
        end: widget.progress.clamp(0.0, 1.0),
      ).animate(CurvedAnimation(
        parent: _fillController,
        curve: AquaTheme.curveDefault,
      ));
      
      _fillController.forward(from: 0);
      _previousProgress = widget.progress;

      // Trigger celebration when goal is reached
      if (!wasComplete && isComplete) {
        _triggerCelebration();
      }
    }
  }

  void _triggerCelebration() {
    HapticFeedback.heavyImpact();
    setState(() => _showCelebration = true);
    _celebrateController.forward(from: 0).then((_) {
      if (mounted) setState(() => _showCelebration = false);
    });
  }

  @override
  void dispose() {
    _waveController.dispose();
    _bubbleController.dispose();
    _glowController.dispose();
    _fillController.dispose();
    _celebrateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final beverage = AquaTheme.getBeverage(widget.beverageId);
    final isDark = AquaTheme.isDark(context);

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        widget.onTap?.call();
      },
      child: AnimatedBuilder(
        animation: Listenable.merge([
          _waveController,
          _bubbleController,
          _glowController,
          _fillAnimation,
          _celebrateController,
        ]),
        builder: (context, child) {
          final progress = _fillAnimation.value.clamp(0.0, 1.0);
          
          return SizedBox(
            width: widget.size,
            height: widget.size * 1.15,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Ambient glow
                _buildAmbientGlow(beverage, progress),
                
                // Main droplet
                _buildDroplet(beverage, progress, isDark),
                
                // Progress info overlay
                _buildProgressInfo(beverage, progress, isDark),
                
                // Celebration particles
                if (_showCelebration) _buildCelebration(beverage),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildAmbientGlow(BeverageThemeData beverage, double progress) {
    final glowOpacity = 0.15 + (_glowController.value * 0.1);
    
    return Positioned.fill(
      child: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.center,
            radius: 0.7,
            colors: [
              beverage.primary.withOpacity(glowOpacity * progress),
              beverage.primary.withOpacity(glowOpacity * 0.3 * progress),
              Colors.transparent,
            ],
            stops: const [0.0, 0.5, 1.0],
          ),
        ),
      ),
    );
  }

  Widget _buildDroplet(BeverageThemeData beverage, double progress, bool isDark) {
    return CustomPaint(
      size: Size(widget.size, widget.size * 1.1),
      painter: _DropletPainter(
        progress: progress,
        waveValue: _waveController.value,
        bubbleValue: _bubbleController.value,
        glowValue: _glowController.value,
        primaryColor: beverage.primary,
        secondaryColor: beverage.secondary,
        isDark: isDark,
      ),
    );
  }

  Widget _buildProgressInfo(BeverageThemeData beverage, double progress, bool isDark) {
    final isComplete = progress >= 1.0;
    final textColor = progress > 0.5 ? Colors.white : AquaTheme.getTextPrimary(context);
    
    return Positioned(
      top: widget.size * 0.25,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Celebration emoji
          if (isComplete)
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.5, end: 1.0),
              duration: const Duration(milliseconds: 600),
              curve: Curves.elasticOut,
              builder: (context, value, child) {
                return Transform.scale(
                  scale: value,
                  child: const Text(
                    '🎉',
                    style: TextStyle(fontSize: 36),
                  ),
                );
              },
            )
          else
            Text(
              beverage.emoji,
              style: const TextStyle(fontSize: 32),
            ),
          
          const SizedBox(height: 8),
          
          // Current amount
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: (isDark ? Colors.black : Colors.white).withOpacity(0.85),
              borderRadius: BorderRadius.circular(AquaTheme.radiusLarge),
              boxShadow: [
                BoxShadow(
                  color: beverage.primary.withOpacity(0.3),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              children: [
                ShaderMask(
                  shaderCallback: (bounds) => beverage.gradient.createShader(bounds),
                  child: Text(
                    '${widget.currentMl}',
                    style: AquaTheme.displayLarge.copyWith(
                      color: Colors.white,
                      fontSize: 38,
                    ),
                  ),
                ),
                Text(
                  'of ${widget.goalMl} ml',
                  style: AquaTheme.bodySmall.copyWith(
                    color: AquaTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 12),
          
          // Percentage badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              gradient: isComplete
                  ? const LinearGradient(
                      colors: [Color(0xFF10B981), Color(0xFF34D399)],
                    )
                  : beverage.gradient,
              borderRadius: BorderRadius.circular(AquaTheme.radiusFull),
              boxShadow: [
                BoxShadow(
                  color: (isComplete ? AquaTheme.success : beverage.primary)
                      .withOpacity(0.4),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isComplete)
                  const Padding(
                    padding: EdgeInsets.only(right: 4),
                    child: Icon(Icons.check, color: Colors.white, size: 16),
                  ),
                Text(
                  '${(progress * 100).toInt()}%',
                  style: AquaTheme.labelLarge.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCelebration(BeverageThemeData beverage) {
    return CustomPaint(
      size: Size(widget.size, widget.size * 1.1),
      painter: _CelebrationPainter(
        animationValue: _celebrateController.value,
        color: beverage.primary,
      ),
    );
  }
}

/// Droplet shape painter with wave and bubble effects
class _DropletPainter extends CustomPainter {
  final double progress;
  final double waveValue;
  final double bubbleValue;
  final double glowValue;
  final Color primaryColor;
  final Color secondaryColor;
  final bool isDark;

  _DropletPainter({
    required this.progress,
    required this.waveValue,
    required this.bubbleValue,
    required this.glowValue,
    required this.primaryColor,
    required this.secondaryColor,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final dropletPath = _createDropletPath(size);
    
    // Draw droplet background
    _drawDropletBackground(canvas, dropletPath, size);
    
    // Draw water fill with waves
    if (progress > 0) {
      _drawWaterFill(canvas, dropletPath, size);
    }
    
    // Draw bubbles
    if (progress > 0.1) {
      _drawBubbles(canvas, dropletPath, size);
    }
    
    // Draw droplet border and glass effect
    _drawDropletOverlay(canvas, dropletPath, size);
  }

  Path _createDropletPath(Size size) {
    final path = Path();
    final w = size.width;
    final h = size.height;
    
    // Droplet shape - teardrop
    path.moveTo(w * 0.5, h * 0.02); // Top point
    
    // Right curve
    path.cubicTo(
      w * 0.5, h * 0.02,
      w * 0.95, h * 0.35,
      w * 0.95, h * 0.55,
    );
    
    // Bottom right curve
    path.cubicTo(
      w * 0.95, h * 0.75,
      w * 0.8, h * 0.95,
      w * 0.5, h * 0.95,
    );
    
    // Bottom left curve
    path.cubicTo(
      w * 0.2, h * 0.95,
      w * 0.05, h * 0.75,
      w * 0.05, h * 0.55,
    );
    
    // Left curve back to top
    path.cubicTo(
      w * 0.05, h * 0.35,
      w * 0.5, h * 0.02,
      w * 0.5, h * 0.02,
    );
    
    path.close();
    return path;
  }

  void _drawDropletBackground(Canvas canvas, Path dropletPath, Size size) {
    // Background fill
    final bgPaint = Paint()
      ..color = isDark 
          ? Colors.grey.shade800.withOpacity(0.3)
          : Colors.grey.shade100.withOpacity(0.5)
      ..style = PaintingStyle.fill;
    
    canvas.drawPath(dropletPath, bgPaint);
  }

  void _drawWaterFill(Canvas canvas, Path dropletPath, Size size) {
    canvas.save();
    canvas.clipPath(dropletPath);
    
    final fillHeight = size.height * 0.93 * progress;
    final fillTop = size.height * 0.95 - fillHeight;
    
    // Water gradient
    final waterPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          primaryColor.withOpacity(0.7),
          primaryColor.withOpacity(0.85),
          secondaryColor,
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromLTWH(0, fillTop, size.width, fillHeight));
    
    // Draw main water body
    canvas.drawRect(
      Rect.fromLTWH(0, fillTop + 15, size.width, fillHeight),
      waterPaint,
    );
    
    // Draw wave on top
    _drawWave(canvas, size, fillTop);
    
    canvas.restore();
  }

  void _drawWave(Canvas canvas, Size size, double waterTop) {
    final wavePaint = Paint()
      ..color = primaryColor.withOpacity(0.8)
      ..style = PaintingStyle.fill;
    
    final wavePath = Path();
    wavePath.moveTo(0, size.height);
    
    for (double x = 0; x <= size.width; x++) {
      final y = waterTop +
          math.sin((x / size.width * 4 * math.pi) + (waveValue * 2 * math.pi)) * 8 +
          math.sin((x / size.width * 2 * math.pi) + (waveValue * 2 * math.pi * 0.7)) * 5;
      wavePath.lineTo(x, y);
    }
    
    wavePath.lineTo(size.width, size.height);
    wavePath.close();
    
    canvas.drawPath(wavePath, wavePaint);
    
    // Second wave layer (lighter)
    final wave2Paint = Paint()
      ..color = primaryColor.withOpacity(0.5)
      ..style = PaintingStyle.fill;
    
    final wave2Path = Path();
    wave2Path.moveTo(0, size.height);
    
    for (double x = 0; x <= size.width; x++) {
      final y = waterTop + 5 +
          math.sin((x / size.width * 3 * math.pi) + (waveValue * 2 * math.pi * 1.3)) * 6;
      wave2Path.lineTo(x, y);
    }
    
    wave2Path.lineTo(size.width, size.height);
    wave2Path.close();
    
    canvas.drawPath(wave2Path, wave2Paint);
  }

  void _drawBubbles(Canvas canvas, Path dropletPath, Size size) {
    canvas.save();
    canvas.clipPath(dropletPath);
    
    final fillHeight = size.height * 0.93 * progress;
    final waterTop = size.height * 0.95 - fillHeight;
    
    final bubbles = [
      _Bubble(0.25, 0.15, 5),
      _Bubble(0.45, 0.35, 4),
      _Bubble(0.65, 0.55, 6),
      _Bubble(0.35, 0.75, 3),
      _Bubble(0.75, 0.25, 4),
      _Bubble(0.55, 0.65, 5),
      _Bubble(0.3, 0.45, 3),
    ];

    for (final bubble in bubbles) {
      final x = size.width * bubble.xRatio;
      final yOffset = (bubbleValue + bubble.yOffset) % 1.0;
      final y = waterTop + fillHeight * (1 - yOffset);

      if (y < size.height * 0.95 && y > waterTop) {
        final opacity = (1 - yOffset) * 0.6;
        final paint = Paint()
          ..color = Colors.white.withOpacity(opacity)
          ..style = PaintingStyle.fill;

        canvas.drawCircle(Offset(x, y), bubble.radius, paint);
        
        // Bubble highlight
        final highlightPaint = Paint()
          ..color = Colors.white.withOpacity(opacity * 0.8)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(
          Offset(x - bubble.radius * 0.3, y - bubble.radius * 0.3),
          bubble.radius * 0.3,
          highlightPaint,
        );
      }
    }
    
    canvas.restore();
  }

  void _drawDropletOverlay(Canvas canvas, Path dropletPath, Size size) {
    // Border
    final borderPaint = Paint()
      ..color = isDark 
          ? Colors.white.withOpacity(0.2)
          : Colors.grey.shade300
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    
    canvas.drawPath(dropletPath, borderPaint);
    
    // Glass highlight (left side)
    final highlightPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [
          Colors.white.withOpacity(0.4),
          Colors.white.withOpacity(0.0),
        ],
      ).createShader(Rect.fromLTWH(
        size.width * 0.08,
        size.height * 0.15,
        size.width * 0.15,
        size.height * 0.6,
      ));
    
    final highlightPath = Path()
      ..moveTo(size.width * 0.12, size.height * 0.2)
      ..quadraticBezierTo(
        size.width * 0.08,
        size.height * 0.5,
        size.width * 0.1,
        size.height * 0.75,
      )
      ..lineTo(size.width * 0.18, size.height * 0.75)
      ..quadraticBezierTo(
        size.width * 0.16,
        size.height * 0.5,
        size.width * 0.2,
        size.height * 0.2,
      )
      ..close();
    
    canvas.drawPath(highlightPath, highlightPaint);
  }

  @override
  bool shouldRepaint(covariant _DropletPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.waveValue != waveValue ||
        oldDelegate.bubbleValue != bubbleValue ||
        oldDelegate.glowValue != glowValue ||
        oldDelegate.primaryColor != primaryColor;
  }
}

class _Bubble {
  final double xRatio;
  final double yOffset;
  final double radius;

  _Bubble(this.xRatio, this.yOffset, this.radius);
}

/// Celebration particles painter
class _CelebrationPainter extends CustomPainter {
  final double animationValue;
  final Color color;

  _CelebrationPainter({
    required this.animationValue,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final random = math.Random(42); // Fixed seed for consistent particles
    
    final particles = List.generate(20, (i) {
      final angle = (i / 20) * 2 * math.pi + random.nextDouble() * 0.5;
      final distance = 50 + random.nextDouble() * 100;
      final particleSize = 4 + random.nextDouble() * 6;
      return _Particle(angle, distance, particleSize);
    });

    for (final particle in particles) {
      final progress = animationValue;
      final x = center.dx + math.cos(particle.angle) * particle.distance * progress;
      final y = center.dy + math.sin(particle.angle) * particle.distance * progress - (progress * 50);
      final opacity = (1 - progress).clamp(0.0, 1.0);
      final scale = 1 - (progress * 0.5);

      final paint = Paint()
        ..color = color.withOpacity(opacity * 0.8)
        ..style = PaintingStyle.fill;

      canvas.drawCircle(
        Offset(x, y),
        particle.size * scale,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _CelebrationPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue;
  }
}

class _Particle {
  final double angle;
  final double distance;
  final double size;

  _Particle(this.angle, this.distance, this.size);
}
