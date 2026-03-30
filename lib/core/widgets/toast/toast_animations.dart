import 'package:flutter/material.dart';
import 'toast_theme.dart';

/// Shimmer effect painter for toast border
class ShimmerBorderPainter extends CustomPainter {
  final double progress;
  final Color primaryColor;
  final Color secondaryColor;
  final double borderRadius;

  ShimmerBorderPainter({
    required this.progress,
    required this.primaryColor,
    required this.secondaryColor,
    this.borderRadius = 20.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(borderRadius));
    
    // Create shimmer gradient that moves along the border
    final shimmerWidth = size.width * 0.4;
    final shimmerPosition = (progress * (size.width + shimmerWidth * 2)) - shimmerWidth;
    
    final gradient = LinearGradient(
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
      colors: [
        primaryColor.withOpacity(0.0),
        primaryColor.withOpacity(0.6),
        secondaryColor.withOpacity(0.8),
        primaryColor.withOpacity(0.6),
        primaryColor.withOpacity(0.0),
      ],
      stops: const [0.0, 0.3, 0.5, 0.7, 1.0],
      transform: GradientTranslation(shimmerPosition, 0),
    );

    final paint = Paint()
      ..shader = gradient.createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    canvas.drawRRect(rrect, paint);
  }

  @override
  bool shouldRepaint(ShimmerBorderPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

/// Gradient translation for shimmer effect
class GradientTranslation extends GradientTransform {
  final double dx;
  final double dy;

  const GradientTranslation(this.dx, this.dy);

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) {
    return Matrix4.translationValues(dx, dy, 0);
  }
}

/// Progress bar painter for auto-dismiss countdown
class ProgressBarPainter extends CustomPainter {
  final double progress;
  final Color primaryColor;
  final Color secondaryColor;
  final double height;

  ProgressBarPainter({
    required this.progress,
    required this.primaryColor,
    required this.secondaryColor,
    this.height = 3.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Background track
    final bgPaint = Paint()
      ..color = primaryColor.withOpacity(0.15)
      ..style = PaintingStyle.fill;
    
    final bgRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, height),
      const Radius.circular(2),
    );
    canvas.drawRRect(bgRect, bgPaint);

    // Progress fill
    final progressWidth = size.width * progress;
    if (progressWidth > 0) {
      final gradient = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [primaryColor, secondaryColor],
      );
      
      final progressPaint = Paint()
        ..shader = gradient.createShader(
          Rect.fromLTWH(0, 0, progressWidth, height),
        )
        ..style = PaintingStyle.fill;
      
      final progressRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, progressWidth, height),
        const Radius.circular(2),
      );
      canvas.drawRRect(progressRect, progressPaint);

      // Glow effect at the end
      final glowPaint = Paint()
        ..color = secondaryColor.withOpacity(0.6)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
      
      canvas.drawCircle(
        Offset(progressWidth - 2, height / 2),
        3,
        glowPaint,
      );
    }
  }

  @override
  bool shouldRepaint(ProgressBarPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

/// Icon glow painter for pulsing effect
class IconGlowPainter extends CustomPainter {
  final double pulseProgress;
  final Color glowColor;
  final double baseRadius;

  IconGlowPainter({
    required this.pulseProgress,
    required this.glowColor,
    this.baseRadius = 24.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    
    // Outer glow ring
    final outerRadius = baseRadius + (8 * pulseProgress);
    final outerPaint = Paint()
      ..color = glowColor.withOpacity(0.2 * (1 - pulseProgress))
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
    
    canvas.drawCircle(center, outerRadius, outerPaint);

    // Inner glow
    final innerPaint = Paint()
      ..color = glowColor.withOpacity(0.3 * (1 - pulseProgress * 0.5))
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
    
    canvas.drawCircle(center, baseRadius, innerPaint);
  }

  @override
  bool shouldRepaint(IconGlowPainter oldDelegate) {
    return oldDelegate.pulseProgress != pulseProgress;
  }
}

/// Toast entry/exit animation mixin
mixin ToastAnimationMixin<T extends StatefulWidget> on State<T>, TickerProviderStateMixin<T> {
  late AnimationController entryController;
  late AnimationController shimmerController;
  late AnimationController pulseController;
  late AnimationController progressController;
  
  late Animation<Offset> slideAnimation;
  late Animation<double> fadeAnimation;
  late Animation<double> scaleAnimation;
  late Animation<double> shimmerAnimation;
  late Animation<double> pulseAnimation;
  late Animation<double> progressAnimation;

  void initToastAnimations({
    required Duration autoDismissDuration,
    VoidCallback? onDismiss,
  }) {
    // Entry animation controller
    entryController = AnimationController(
      duration: ToastTheme.entryDuration,
      vsync: this,
    );

    // Shimmer animation controller (loops)
    shimmerController = AnimationController(
      duration: ToastTheme.shimmerDuration,
      vsync: this,
    )..repeat();

    // Pulse animation controller (loops)
    pulseController = AnimationController(
      duration: ToastTheme.pulseDuration,
      vsync: this,
    )..repeat(reverse: true);

    // Progress animation controller
    progressController = AnimationController(
      duration: autoDismissDuration,
      vsync: this,
    );

    // Slide from top
    slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: entryController,
      curve: ToastTheme.entryCurve,
    ));

    // Fade in
    fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: entryController,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
    ));

    // Scale up slightly
    scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: entryController,
      curve: Curves.elasticOut,
    ));

    // Shimmer sweep
    shimmerAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(shimmerController);

    // Icon pulse
    pulseAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: pulseController,
      curve: Curves.easeInOut,
    ));

    // Progress countdown
    progressAnimation = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(progressController);

    // Start entry animation
    entryController.forward();

    // Start auto-dismiss countdown
    progressController.forward().then((_) {
      if (mounted) {
        dismissToast(onDismiss: onDismiss);
      }
    });
  }

  Future<void> dismissToast({VoidCallback? onDismiss}) async {
    // Stop other animations
    shimmerController.stop();
    pulseController.stop();
    progressController.stop();

    // Reverse entry animation for exit
    await entryController.reverse();
    
    onDismiss?.call();
  }

  void disposeToastAnimations() {
    entryController.dispose();
    shimmerController.dispose();
    pulseController.dispose();
    progressController.dispose();
  }
}

/// Swipe-to-dismiss gesture handler
class ToastDismissible extends StatefulWidget {
  final Widget child;
  final VoidCallback onDismiss;
  final double dismissThreshold;

  const ToastDismissible({
    super.key,
    required this.child,
    required this.onDismiss,
    this.dismissThreshold = 0.3,
  });

  @override
  State<ToastDismissible> createState() => _ToastDismissibleState();
}

class _ToastDismissibleState extends State<ToastDismissible>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  double _dragExtent = 0.0;
  bool _isDragging = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleDragStart(DragStartDetails details) {
    _isDragging = true;
    _controller.stop();
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    if (!_isDragging) return;
    
    setState(() {
      _dragExtent += details.delta.dy;
      // Only allow upward swipe (negative values)
      if (_dragExtent > 0) _dragExtent = 0;
    });
  }

  void _handleDragEnd(DragEndDetails details) {
    _isDragging = false;
    
    final screenHeight = MediaQuery.of(context).size.height;
    final dismissDistance = screenHeight * widget.dismissThreshold;
    
    if (_dragExtent.abs() > dismissDistance || 
        details.velocity.pixelsPerSecond.dy < -500) {
      // Dismiss
      widget.onDismiss();
    } else {
      // Spring back
      _controller.value = _dragExtent / dismissDistance;
      _controller.animateTo(0, curve: Curves.elasticOut);
      _controller.addListener(() {
        setState(() {
          _dragExtent = _controller.value * dismissDistance;
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onVerticalDragStart: _handleDragStart,
      onVerticalDragUpdate: _handleDragUpdate,
      onVerticalDragEnd: _handleDragEnd,
      child: Transform.translate(
        offset: Offset(0, _dragExtent),
        child: Opacity(
          opacity: (1 - (_dragExtent.abs() / 200)).clamp(0.0, 1.0),
          child: widget.child,
        ),
      ),
    );
  }
}

/// Bouncing icon animation widget
class BouncingIcon extends StatefulWidget {
  final IconData icon;
  final Color color;
  final double size;
  final bool animate;

  const BouncingIcon({
    super.key,
    required this.icon,
    required this.color,
    this.size = 28.0,
    this.animate = true,
  });

  @override
  State<BouncingIcon> createState() => _BouncingIconState();
}

class _BouncingIconState extends State<BouncingIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 1.2).chain(CurveTween(curve: Curves.easeOut)),
        weight: 30,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.2, end: 0.9).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 20,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 0.9, end: 1.05).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 25,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.05, end: 1.0).chain(CurveTween(curve: Curves.easeIn)),
        weight: 25,
      ),
    ]).animate(_controller);

    if (widget.animate) {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Icon(
            widget.icon,
            color: widget.color,
            size: widget.size,
          ),
        );
      },
    );
  }
}
