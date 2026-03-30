import 'package:flutter/material.dart';
import 'dart:ui';
import '../theme/luna_theme.dart';

/// Glassmorphism card widget for Luna Cycle
class LunaGlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;
  final Color? color;
  final Color? borderColor;
  final double blur;
  final VoidCallback? onTap;
  final bool showBorder;

  const LunaGlassCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.borderRadius = LunaTheme.radiusLg,
    this.color,
    this.borderColor,
    this.blur = 10,
    this.onTap,
    this.showBorder = true,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = LunaTheme.isDark(context);
    final cardColor = color ?? (isDark 
        ? Colors.white.withOpacity(0.08) 
        : Colors.white.withOpacity(0.85));

    Widget card = Container(
      margin: margin,
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(borderRadius),
        border: showBorder ? Border.all(
          color: borderColor ?? (isDark 
              ? Colors.white.withOpacity(0.1) 
              : LunaTheme.primaryPink.withOpacity(0.1)),
          width: 1,
        ) : null,
        boxShadow: LunaTheme.shadowSm,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Padding(
            padding: padding ?? const EdgeInsets.all(LunaTheme.spacingLg),
            child: child,
          ),
        ),
      ),
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

/// Pink gradient card for Luna Cycle
class LunaPinkCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;
  final VoidCallback? onTap;
  final bool isElevated;

  const LunaPinkCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.borderRadius = LunaTheme.radiusLg,
    this.onTap,
    this.isElevated = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = LunaTheme.isDark(context);

    Widget card = Container(
      margin: margin,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark 
              ? [
                  LunaTheme.primaryPink.withOpacity(0.2),
                  LunaTheme.primaryPinkDark.withOpacity(0.1),
                ]
              : [
                  LunaTheme.primaryPinkSoft,
                  Colors.white,
                ],
        ),
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: LunaTheme.primaryPink.withOpacity(0.15),
          width: 1,
        ),
        boxShadow: isElevated ? LunaTheme.shadowMd : LunaTheme.shadowSm,
      ),
      child: Padding(
        padding: padding ?? const EdgeInsets.all(LunaTheme.spacingLg),
        child: child,
      ),
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

/// Phase-colored card
class LunaPhaseCard extends StatelessWidget {
  final Widget child;
  final LunaCyclePhase phase;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;
  final VoidCallback? onTap;

  const LunaPhaseCard({
    super.key,
    required this.child,
    required this.phase,
    this.padding,
    this.margin,
    this.borderRadius = LunaTheme.radiusXl,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = LunaTheme.isDark(context);
    final phaseColor = LunaTheme.getPhaseColor(phase);

    Widget card = Container(
      margin: margin,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            phaseColor.withOpacity(isDark ? 0.25 : 0.15),
            phaseColor.withOpacity(isDark ? 0.1 : 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: phaseColor.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Padding(
        padding: padding ?? const EdgeInsets.all(LunaTheme.spacingLg),
        child: child,
      ),
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

/// Feature card with gradient
class LunaFeatureCard extends StatelessWidget {
  final Widget child;
  final LunaFeature feature;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;
  final VoidCallback? onTap;

  const LunaFeatureCard({
    super.key,
    required this.child,
    required this.feature,
    this.padding,
    this.margin,
    this.borderRadius = LunaTheme.radiusLg,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final gradient = LunaTheme.getFeatureGradient(feature);

    Widget card = Container(
      margin: margin,
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: LunaTheme.shadowColored(
          LunaTheme.getFeatureColor(feature),
          opacity: 0.3,
        ),
      ),
      child: Padding(
        padding: padding ?? const EdgeInsets.all(LunaTheme.spacingLg),
        child: child,
      ),
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

/// Stat card for displaying numbers
class LunaStatCard extends StatelessWidget {
  final String label;
  final String value;
  final String? unit;
  final IconData? icon;
  final Color? color;
  final VoidCallback? onTap;

  const LunaStatCard({
    super.key,
    required this.label,
    required this.value,
    this.unit,
    this.icon,
    this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cardColor = color ?? LunaTheme.primaryPink;

    return LunaGlassCard(
      onTap: onTap,
      padding: const EdgeInsets.all(LunaTheme.spacingLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null)
            Container(
              padding: const EdgeInsets.all(LunaTheme.spacingSm),
              decoration: BoxDecoration(
                color: cardColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(LunaTheme.radiusSm),
              ),
              child: Icon(icon, color: cardColor, size: 20),
            ),
          if (icon != null) const SizedBox(height: LunaTheme.spacingMd),
          Text(
            label,
            style: LunaTheme.bodySmall.copyWith(
              color: LunaTheme.getTextSecondary(context),
            ),
          ),
          const SizedBox(height: LunaTheme.spacingXs),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value,
                style: LunaTheme.displaySmall.copyWith(
                  color: cardColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (unit != null) ...[
                const SizedBox(width: 4),
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    unit!,
                    style: LunaTheme.bodySmall.copyWith(color: cardColor),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// Quick action button
class LunaQuickActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;
  final VoidCallback onTap;
  final bool isCompact;

  const LunaQuickActionButton({
    super.key,
    required this.icon,
    required this.label,
    this.color,
    required this.onTap,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    final buttonColor = color ?? LunaTheme.primaryPink;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: isCompact ? LunaTheme.spacingMd : LunaTheme.spacingLg,
          vertical: isCompact ? LunaTheme.spacingSm : LunaTheme.spacingMd,
        ),
        decoration: BoxDecoration(
          color: buttonColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(LunaTheme.radiusFull),
          border: Border.all(
            color: buttonColor.withOpacity(0.2),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: buttonColor, size: isCompact ? 16 : 20),
            const SizedBox(width: LunaTheme.spacingSm),
            Text(
              label,
              style: (isCompact ? LunaTheme.labelSmall : LunaTheme.labelLarge)
                  .copyWith(color: buttonColor),
            ),
          ],
        ),
      ),
    );
  }
}

/// Animated gradient card
class LunaAnimatedGradientCard extends StatefulWidget {
  final Widget child;
  final List<Color> colors;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;
  final VoidCallback? onTap;

  const LunaAnimatedGradientCard({
    super.key,
    required this.child,
    required this.colors,
    this.padding,
    this.margin,
    this.borderRadius = LunaTheme.radiusLg,
    this.onTap,
  });

  @override
  State<LunaAnimatedGradientCard> createState() => _LunaAnimatedGradientCardState();
}

class _LunaAnimatedGradientCardState extends State<LunaAnimatedGradientCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Alignment> _topAlignmentAnimation;
  late Animation<Alignment> _bottomAlignmentAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 4),
      vsync: this,
    )..repeat(reverse: true);

    _topAlignmentAnimation = TweenSequence<Alignment>([
      TweenSequenceItem(
        tween: Tween(begin: Alignment.topLeft, end: Alignment.topRight),
        weight: 1,
      ),
      TweenSequenceItem(
        tween: Tween(begin: Alignment.topRight, end: Alignment.bottomRight),
        weight: 1,
      ),
    ]).animate(_controller);

    _bottomAlignmentAnimation = TweenSequence<Alignment>([
      TweenSequenceItem(
        tween: Tween(begin: Alignment.bottomRight, end: Alignment.bottomLeft),
        weight: 1,
      ),
      TweenSequenceItem(
        tween: Tween(begin: Alignment.bottomLeft, end: Alignment.topLeft),
        weight: 1,
      ),
    ]).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          margin: widget.margin,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: _topAlignmentAnimation.value,
              end: _bottomAlignmentAnimation.value,
              colors: widget.colors,
            ),
            borderRadius: BorderRadius.circular(widget.borderRadius),
            boxShadow: LunaTheme.shadowMd,
          ),
          child: child,
        );
      },
      child: GestureDetector(
        onTap: widget.onTap,
        child: Padding(
          padding: widget.padding ?? const EdgeInsets.all(LunaTheme.spacingLg),
          child: widget.child,
        ),
      ),
    );
  }
}

/// Section header widget
class LunaSectionHeader extends StatelessWidget {
  final String title;
  final IconData? icon;
  final String? actionLabel;
  final VoidCallback? onActionTap;
  final Color? color;

  const LunaSectionHeader({
    super.key,
    required this.title,
    this.icon,
    this.actionLabel,
    this.onActionTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: LunaTheme.spacingLg,
        vertical: LunaTheme.spacingSm,
      ),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              color: color ?? LunaTheme.primaryPink,
              size: 20,
            ),
            const SizedBox(width: LunaTheme.spacingSm),
          ],
          Text(
            title,
            style: LunaTheme.headlineSmall.copyWith(
              color: LunaTheme.getTextPrimary(context),
            ),
          ),
          const Spacer(),
          if (actionLabel != null && onActionTap != null)
            TextButton(
              onPressed: onActionTap,
              child: Text(
                actionLabel!,
                style: LunaTheme.labelMedium.copyWith(
                  color: LunaTheme.primaryPink,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
