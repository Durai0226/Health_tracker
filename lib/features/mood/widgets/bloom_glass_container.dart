import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/mood_theme.dart';

/// Glassmorphism container widget for BloomFit mood tracker
class BloomGlassContainer extends StatelessWidget {
  final Widget child;
  final double? width;
  final double? height;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;
  final Color? backgroundColor;
  final double blur;
  final double opacity;
  final Border? border;
  final List<BoxShadow>? boxShadow;
  final VoidCallback? onTap;

  const BloomGlassContainer({
    super.key,
    required this.child,
    this.width,
    this.height,
    this.padding,
    this.margin,
    this.borderRadius = 20,
    this.backgroundColor,
    this.blur = 10,
    this.opacity = 0.8,
    this.border,
    this.boxShadow,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = MoodTheme.isDark(context);
    final bgColor = backgroundColor ??
        (isDark
            ? Colors.white.withOpacity(0.08)
            : Colors.white.withOpacity(opacity));

    Widget container = ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          width: width,
          height: height,
          padding: padding ?? const EdgeInsets.all(MoodTheme.spacingMd),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(borderRadius),
            border: border ??
                Border.all(
                  color: isDark
                      ? Colors.white.withOpacity(0.1)
                      : Colors.white.withOpacity(0.3),
                  width: 1,
                ),
            boxShadow: boxShadow ?? MoodTheme.softShadow,
          ),
          child: child,
        ),
      ),
    );

    if (margin != null) {
      container = Padding(padding: margin!, child: container);
    }

    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        child: container,
      );
    }

    return container;
  }
}

/// Animated glass card with hover/tap effects
class BloomAnimatedGlassCard extends StatefulWidget {
  final Widget child;
  final double? width;
  final double? height;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;
  final VoidCallback? onTap;
  final Color? accentColor;

  const BloomAnimatedGlassCard({
    super.key,
    required this.child,
    this.width,
    this.height,
    this.padding,
    this.margin,
    this.borderRadius = 20,
    this.onTap,
    this.accentColor,
  });

  @override
  State<BloomAnimatedGlassCard> createState() => _BloomAnimatedGlassCardState();
}

class _BloomAnimatedGlassCardState extends State<BloomAnimatedGlassCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: MoodTheme.animationFast,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.97).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    setState(() => _isPressed = true);
    _controller.forward();
  }

  void _onTapUp(TapUpDetails details) {
    setState(() => _isPressed = false);
    _controller.reverse();
  }

  void _onTapCancel() {
    setState(() => _isPressed = false);
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = MoodTheme.isDark(context);
    final accentColor = widget.accentColor ?? MoodTheme.primary;

    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Container(
              margin: widget.margin,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(widget.borderRadius),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: AnimatedContainer(
                    duration: MoodTheme.animationFast,
                    width: widget.width,
                    height: widget.height,
                    padding: widget.padding ??
                        const EdgeInsets.all(MoodTheme.spacingMd),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withOpacity(_isPressed ? 0.12 : 0.08)
                          : Colors.white.withOpacity(_isPressed ? 0.95 : 0.85),
                      borderRadius: BorderRadius.circular(widget.borderRadius),
                      border: Border.all(
                        color: _isPressed
                            ? accentColor.withOpacity(0.5)
                            : (isDark
                                ? Colors.white.withOpacity(0.1)
                                : Colors.white.withOpacity(0.3)),
                        width: _isPressed ? 2 : 1,
                      ),
                      boxShadow: _isPressed
                          ? [
                              BoxShadow(
                                color: accentColor.withOpacity(0.2),
                                blurRadius: 20,
                                offset: const Offset(0, 8),
                              ),
                            ]
                          : MoodTheme.softShadow,
                    ),
                    child: widget.child,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Premium card with gradient border
class BloomPremiumCard extends StatelessWidget {
  final Widget child;
  final double? width;
  final double? height;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;
  final Gradient? gradient;
  final VoidCallback? onTap;

  const BloomPremiumCard({
    super.key,
    required this.child,
    this.width,
    this.height,
    this.padding,
    this.margin,
    this.borderRadius = 20,
    this.gradient,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = MoodTheme.isDark(context);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: margin,
        width: width,
        height: height,
        decoration: BoxDecoration(
          gradient: gradient ?? MoodTheme.primaryGradient,
          borderRadius: BorderRadius.circular(borderRadius),
          boxShadow: MoodTheme.primaryShadow,
        ),
        child: Container(
          margin: const EdgeInsets.all(2),
          padding: padding ?? const EdgeInsets.all(MoodTheme.spacingMd),
          decoration: BoxDecoration(
            color: isDark ? MoodTheme.surfaceDark : MoodTheme.surface,
            borderRadius: BorderRadius.circular(borderRadius - 2),
          ),
          child: child,
        ),
      ),
    );
  }
}
