import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../theme/aqua_theme.dart';

/// Glassmorphism card with dynamic beverage-based styling
class AquaGlassCard extends StatelessWidget {
  final Widget child;
  final String? beverageId;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;
  final bool showGradientBorder;
  final VoidCallback? onTap;
  final double? width;
  final double? height;

  const AquaGlassCard({
    super.key,
    required this.child,
    this.beverageId,
    this.padding,
    this.margin,
    this.borderRadius = AquaTheme.radiusMedium,
    this.showGradientBorder = false,
    this.onTap,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = AquaTheme.isDark(context);
    final beverage = beverageId != null 
        ? AquaTheme.getBeverage(beverageId!) 
        : AquaTheme.getBeverage('water');

    // Calm Clarity: flat opaque surface (no BackdropFilter/glass).
    Widget card = Container(
      width: width,
      height: height,
      margin: margin,
      padding: padding ?? const EdgeInsets.all(AquaTheme.spacingM),
      decoration: BoxDecoration(
        color: isDark ? AquaTheme.cardDark : AquaTheme.cardLight,
        borderRadius: BorderRadius.circular(borderRadius),
        border: isDark
            ? Border.all(color: Colors.white.withOpacity(0.08), width: 1)
            : null,
        boxShadow: AquaTheme.cardShadow(beverage.primary),
      ),
      child: child,
    );

    if (onTap != null) {
      card = GestureDetector(
        onTap: onTap,
        child: card,
      );
    }

    return card;
  }
}

/// Gradient border decoration
class GradientBoxBorder extends BoxBorder {
  final Gradient gradient;
  final double width;

  const GradientBoxBorder({
    required this.gradient,
    this.width = 1.0,
  });

  @override
  BorderSide get bottom => BorderSide.none;

  @override
  BorderSide get top => BorderSide.none;

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.all(width);

  @override
  bool get isUniform => true;

  @override
  void paint(
    Canvas canvas,
    Rect rect, {
    TextDirection? textDirection,
    BoxShape shape = BoxShape.rectangle,
    BorderRadius? borderRadius,
  }) {
    final Paint paint = Paint()
      ..shader = gradient.createShader(rect)
      ..strokeWidth = width
      ..style = PaintingStyle.stroke;

    final RRect rrect = borderRadius != null
        ? borderRadius.toRRect(rect).deflate(width / 2)
        : RRect.fromRectAndRadius(rect.deflate(width / 2), Radius.zero);

    canvas.drawRRect(rrect, paint);
  }

  @override
  ShapeBorder scale(double t) => this;
}

/// Section header with icon and optional action
class AquaSectionHeader extends StatelessWidget {
  final String title;
  final IconData? icon;
  final String? actionText;
  final VoidCallback? onAction;
  final String? beverageId;

  const AquaSectionHeader({
    super.key,
    required this.title,
    this.icon,
    this.actionText,
    this.onAction,
    this.beverageId,
  });

  @override
  Widget build(BuildContext context) {
    final beverage = beverageId != null 
        ? AquaTheme.getBeverage(beverageId!) 
        : AquaTheme.getBeverage('water');

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AquaTheme.spacingM,
        vertical: AquaTheme.spacingS,
      ),
      child: Row(
        children: [
          if (icon != null) ...[
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: beverage.gradient,
                borderRadius: BorderRadius.circular(AquaTheme.radiusSmall),
              ),
              child: Icon(
                icon,
                color: Colors.white,
                size: 16,
              ),
            ),
            const SizedBox(width: AquaTheme.spacingS),
          ],
          Text(
            title,
            style: AquaTheme.heading3.copyWith(
              color: AquaTheme.getTextPrimary(context),
            ),
          ),
          const Spacer(),
          if (actionText != null && onAction != null)
            GestureDetector(
              onTap: onAction,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    actionText!,
                    style: AquaTheme.labelMedium.copyWith(
                      color: beverage.primary,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Symbols.arrow_forward_ios_rounded,
                    size: 12,
                    color: beverage.primary,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Stat card with icon, value and label
class AquaStatCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final String? beverageId;
  final VoidCallback? onTap;

  const AquaStatCard({
    super.key,
    required this.icon,
    required this.value,
    required this.label,
    this.beverageId,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = AquaTheme.isDark(context);
    final beverage = beverageId != null 
        ? AquaTheme.getBeverage(beverageId!) 
        : AquaTheme.getBeverage('water');

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AquaTheme.spacingM),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              beverage.primary.withOpacity(isDark ? 0.2 : 0.1),
              beverage.secondary.withOpacity(isDark ? 0.1 : 0.05),
            ],
          ),
          borderRadius: BorderRadius.circular(AquaTheme.radiusMedium),
          border: Border.all(
            color: beverage.primary.withOpacity(0.2),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: beverage.primary.withOpacity(0.2),
                borderRadius: BorderRadius.circular(AquaTheme.radiusSmall),
              ),
              child: Icon(
                icon,
                color: beverage.primary,
                size: 20,
              ),
            ),
            const SizedBox(height: AquaTheme.spacingS),
            Text(
              value,
              style: AquaTheme.heading2.copyWith(
                color: beverage.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              label,
              style: AquaTheme.bodySmall.copyWith(
                color: AquaTheme.getTextSecondary(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Streak badge widget
class AquaStreakBadge extends StatelessWidget {
  final int streak;
  final bool isCompact;

  const AquaStreakBadge({
    super.key,
    required this.streak,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    if (streak <= 0) return const SizedBox.shrink();

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isCompact ? 10 : 14,
        vertical: isCompact ? 6 : 8,
      ),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFF9500), Color(0xFFFF5E3A)],
        ),
        borderRadius: BorderRadius.circular(AquaTheme.radiusFull),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF9500).withOpacity(0.4),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🔥', style: TextStyle(fontSize: 14)),
          const SizedBox(width: 4),
          Text(
            '$streak',
            style: TextStyle(
              color: Colors.white,
              fontSize: isCompact ? 13 : 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (!isCompact) ...[
            const SizedBox(width: 2),
            const Text(
              'days',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
