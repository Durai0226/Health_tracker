import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/nunito_theme.dart';

/// Glassmorphism card widget following NUNITO design language
class NunitoGlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double? width;
  final double? height;
  final double borderRadius;
  final Color? backgroundColor;
  final double backgroundOpacity;
  final double blurAmount;
  final bool showBorder;
  final VoidCallback? onTap;
  final Gradient? gradient;
  final List<BoxShadow>? boxShadow;

  const NunitoGlassCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.width,
    this.height,
    this.borderRadius = NunitoTheme.radiusMedium,
    this.backgroundColor,
    this.backgroundOpacity = 0.85,
    this.blurAmount = 10,
    this.showBorder = true,
    this.onTap,
    this.gradient,
    this.boxShadow,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = backgroundColor ??
        (isDark ? NunitoTheme.cardDark : NunitoTheme.cardLight);

    // Calm Clarity: flat opaque surface (no BackdropFilter/glass).
    Widget card = Container(
      width: width,
      height: height,
      padding: padding ?? const EdgeInsets.all(NunitoTheme.spacingM),
      decoration: BoxDecoration(
        color: gradient == null ? bgColor : null,
        gradient: gradient,
        borderRadius: BorderRadius.circular(borderRadius),
        border: (showBorder && isDark)
            ? Border.all(color: Colors.white.withOpacity(0.08), width: 1)
            : null,
        boxShadow: boxShadow ?? NunitoTheme.cardShadow,
      ),
      child: child,
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

/// Simple card without blur effect (better performance)
class NunitoCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double? width;
  final double? height;
  final double borderRadius;
  final Color? backgroundColor;
  final VoidCallback? onTap;
  final Gradient? gradient;
  final List<BoxShadow>? boxShadow;
  final Border? border;

  const NunitoCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.width,
    this.height,
    this.borderRadius = NunitoTheme.radiusMedium,
    this.backgroundColor,
    this.onTap,
    this.gradient,
    this.boxShadow,
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor =
        backgroundColor ?? (isDark ? NunitoTheme.cardDark : NunitoTheme.cardLight);

    Widget card = Container(
      width: width,
      height: height,
      margin: margin,
      padding: padding ?? const EdgeInsets.all(NunitoTheme.spacingM),
      decoration: BoxDecoration(
        color: gradient == null ? bgColor : null,
        gradient: gradient,
        borderRadius: BorderRadius.circular(borderRadius),
        border: border,
        boxShadow: boxShadow ?? NunitoTheme.cardShadow,
      ),
      child: child,
    );

    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        child: card,
      );
    }

    return card;
  }
}

/// Animated card with scale effect on tap
class NunitoAnimatedCard extends StatefulWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double? width;
  final double? height;
  final double borderRadius;
  final Color? backgroundColor;
  final VoidCallback? onTap;
  final Gradient? gradient;
  final List<BoxShadow>? boxShadow;

  const NunitoAnimatedCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.width,
    this.height,
    this.borderRadius = NunitoTheme.radiusMedium,
    this.backgroundColor,
    this.onTap,
    this.gradient,
    this.boxShadow,
  });

  @override
  State<NunitoAnimatedCard> createState() => _NunitoAnimatedCardState();
}

class _NunitoAnimatedCardState extends State<NunitoAnimatedCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.97).animate(
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = widget.backgroundColor ??
        (isDark ? NunitoTheme.cardDark : NunitoTheme.cardLight);

    return GestureDetector(
      onTapDown: widget.onTap != null ? _onTapDown : null,
      onTapUp: widget.onTap != null ? _onTapUp : null,
      onTapCancel: widget.onTap != null ? _onTapCancel : null,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) => Transform.scale(
          scale: _scaleAnimation.value,
          child: Container(
            width: widget.width,
            height: widget.height,
            margin: widget.margin,
            padding:
                widget.padding ?? const EdgeInsets.all(NunitoTheme.spacingM),
            decoration: BoxDecoration(
              color: widget.gradient == null ? bgColor : null,
              gradient: widget.gradient,
              borderRadius: BorderRadius.circular(widget.borderRadius),
              boxShadow: widget.boxShadow ?? NunitoTheme.cardShadow,
            ),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

/// Header card with gradient background
class NunitoHeaderCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;
  final Gradient? gradient;

  const NunitoHeaderCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.borderRadius = NunitoTheme.radiusLarge,
    this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      padding: padding ?? const EdgeInsets.all(NunitoTheme.spacingL),
      decoration: BoxDecoration(
        gradient: gradient ?? NunitoTheme.primaryGradient,
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: NunitoTheme.elevatedShadow,
      ),
      child: child,
    );
  }
}
