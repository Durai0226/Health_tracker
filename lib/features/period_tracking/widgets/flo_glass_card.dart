import 'package:flutter/material.dart';
import 'dart:ui';
import '../theme/flo_theme.dart';

/// Glassmorphism card widget for Flo-style period tracking UI
class FloGlassCard extends StatelessWidget {
  final Widget child;
  final Color? color;
  final Color? borderColor;
  final double borderRadius;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double blur;
  final double opacity;
  final VoidCallback? onTap;
  final List<BoxShadow>? shadows;
  final Gradient? gradient;

  const FloGlassCard({
    super.key,
    required this.child,
    this.color,
    this.borderColor,
    this.borderRadius = FloTheme.radiusLg,
    this.padding,
    this.margin,
    this.blur = 10,
    this.opacity = 0.8,
    this.onTap,
    this.shadows,
    this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = FloTheme.isDark(context);
    final baseColor = color ?? (isDark ? Colors.white : Colors.white);

    Widget card = ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          padding: padding ?? const EdgeInsets.all(FloTheme.spacingLg),
          decoration: BoxDecoration(
            gradient: gradient,
            color: gradient == null ? baseColor.withOpacity(isDark ? 0.1 : opacity) : null,
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(
              color: borderColor ?? (isDark ? Colors.white.withOpacity(0.1) : Colors.white.withOpacity(0.3)),
              width: 1,
            ),
            boxShadow: shadows ?? FloTheme.shadowSm,
          ),
          child: child,
        ),
      ),
    );

    if (margin != null) {
      card = Padding(padding: margin!, child: card);
    }

    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        child: card,
      );
    }

    return card;
  }
}

/// Phase-colored glass card
class FloPhaseCard extends StatelessWidget {
  final Widget child;
  final CyclePhaseType phase;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final bool useGradient;

  const FloPhaseCard({
    super.key,
    required this.child,
    required this.phase,
    this.padding,
    this.margin,
    this.onTap,
    this.useGradient = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = FloTheme.isDark(context);
    final phaseColor = FloTheme.getPhaseColor(phase);

    return FloGlassCard(
      color: phaseColor.withOpacity(isDark ? 0.2 : 0.15),
      borderColor: phaseColor.withOpacity(0.3),
      gradient: useGradient ? FloTheme.getPhaseGradient(phase) : null,
      padding: padding,
      margin: margin,
      onTap: onTap,
      shadows: FloTheme.shadowColored(phaseColor),
      child: child,
    );
  }
}

/// Animated glass card with scale effect
class FloAnimatedGlassCard extends StatefulWidget {
  final Widget child;
  final Color? color;
  final double borderRadius;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;

  const FloAnimatedGlassCard({
    super.key,
    required this.child,
    this.color,
    this.borderRadius = FloTheme.radiusLg,
    this.padding,
    this.margin,
    this.onTap,
  });

  @override
  State<FloAnimatedGlassCard> createState() => _FloAnimatedGlassCardState();
}

class _FloAnimatedGlassCardState extends State<FloAnimatedGlassCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: FloTheme.animFast,
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.98).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    _controller.forward();
  }

  void _onTapUp(TapUpDetails details) {
    _controller.reverse();
    widget.onTap?.call();
  }

  void _onTapCancel() {
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) => Transform.scale(
          scale: _scaleAnimation.value,
          child: FloGlassCard(
            color: widget.color,
            borderRadius: widget.borderRadius,
            padding: widget.padding,
            margin: widget.margin,
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

/// Simple stat card with icon and value
class FloStatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color? color;
  final VoidCallback? onTap;

  const FloStatCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cardColor = color ?? FloTheme.periodPink;

    return FloGlassCard(
      onTap: onTap,
      color: cardColor.withOpacity(0.1),
      borderColor: cardColor.withOpacity(0.2),
      padding: const EdgeInsets.all(FloTheme.spacingMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: cardColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(FloTheme.radiusSm),
            ),
            child: Icon(icon, color: cardColor, size: 20),
          ),
          const SizedBox(height: FloTheme.spacingSm),
          Text(
            value,
            style: FloTheme.headlineMedium.copyWith(
              color: FloTheme.getTextPrimary(context),
            ),
          ),
          Text(
            title,
            style: FloTheme.bodySmall.copyWith(
              color: FloTheme.getTextSecondary(context),
            ),
          ),
        ],
      ),
    );
  }
}

/// Pregnancy chance indicator card
class FloPregnancyChanceCard extends StatelessWidget {
  final bool isHigh;
  final VoidCallback? onTap;

  const FloPregnancyChanceCard({
    super.key,
    required this.isHigh,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return FloGlassCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(
        horizontal: FloTheme.spacingLg,
        vertical: FloTheme.spacingMd,
      ),
      child: Row(
        children: [
          Icon(
            Icons.favorite_rounded,
            color: isHigh ? FloTheme.periodPink : FloTheme.textSecondary,
            size: 24,
          ),
          const SizedBox(width: FloTheme.spacingMd),
          Expanded(
            child: Text(
              'Chances of Pregnancy',
              style: FloTheme.bodyMedium.copyWith(
                color: FloTheme.getTextPrimary(context),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: FloTheme.spacingMd,
              vertical: FloTheme.spacingXs,
            ),
            decoration: BoxDecoration(
              color: isHigh
                  ? FloTheme.periodPink.withOpacity(0.2)
                  : FloTheme.lutealGreen.withOpacity(0.2),
              borderRadius: BorderRadius.circular(FloTheme.radiusFull),
            ),
            child: Text(
              isHigh ? 'High' : 'Low',
              style: FloTheme.labelSmall.copyWith(
                color: isHigh ? FloTheme.periodPink : FloTheme.lutealGreenAccent,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
