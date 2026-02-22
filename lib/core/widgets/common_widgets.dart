import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/app_colors.dart';
import '../constants/app_spacing.dart';

// Common Card Widget with consistent styling
class CommonCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double? borderRadius;
  final Color? backgroundColor;
  final VoidCallback? onTap;
  final List<BoxShadow>? boxShadow;
  final Gradient? gradient;
  final Border? border;
  final double? elevation;

  const CommonCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin,
    this.borderRadius = 14,
    this.backgroundColor,
    this.onTap,
    this.boxShadow,
    this.gradient,
    this.border,
    this.elevation,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);
    
    Widget cardWidget = Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: gradient != null ? null : (backgroundColor ?? AppColors.getCardBg(context)),
        gradient: gradient,
        borderRadius: BorderRadius.circular(borderRadius!),
        border: border ?? (isDark ? Border.all(color: AppColors.darkBorder.withOpacity(0.5)) : null),
        boxShadow: boxShadow ?? [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
            blurRadius: elevation ?? 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );

    if (onTap != null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(borderRadius!),
          child: cardWidget,
        ),
      );
    }

    return cardWidget;
  }
}

// Elevated Card with premium styling
class ElevatedCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double? borderRadius;
  final Color? shadowColor;
  final VoidCallback? onTap;

  const ElevatedCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.margin,
    this.borderRadius = 16,
    this.shadowColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);
    
    return CommonCard(
      padding: padding,
      margin: margin,
      borderRadius: borderRadius,
      onTap: onTap,
      backgroundColor: isDark 
          ? AppColors.darkElevatedCard 
          : Colors.white,
      border: Border.all(
        color: isDark
            ? AppColors.darkBorder.withOpacity(0.5)
            : Colors.white.withOpacity(0.8),
        width: 1,
      ),
      boxShadow: [
        BoxShadow(
          color: (shadowColor ?? AppColors.primary).withOpacity(0.15),
          blurRadius: 12,
          offset: const Offset(0, 4),
          spreadRadius: -8,
        ),
      ],
      child: child,
    );
  }
}

// Gradient Card for special sections
class GradientCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double? borderRadius;
  final List<Color> colors;
  final VoidCallback? onTap;

  const GradientCard({
    super.key,
    required this.child,
    required this.colors,
    this.padding = const EdgeInsets.all(16),
    this.margin,
    this.borderRadius = 16,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return CommonCard(
      padding: padding,
      margin: margin,
      borderRadius: borderRadius,
      onTap: onTap,
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: colors,
      ),
      boxShadow: [
        BoxShadow(
          color: colors.first.withOpacity(0.3),
          blurRadius: 12,
          offset: const Offset(0, 6),
        ),
      ],
      child: child,
    );
  }
}

// Common Button variants
enum ButtonVariant {
  primary,
  secondary,
  outline,
  danger,
  success,
  gradient,
}

class CommonButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final ButtonVariant variant;
  final IconData? icon;
  final bool isLoading;
  final EdgeInsetsGeometry? padding;
  final double? borderRadius;
  final Size? minimumSize;
  final TextStyle? textStyle;
  final Color? backgroundColor;

  const CommonButton({
    super.key,
    required this.text,
    this.onPressed,
    this.variant = ButtonVariant.primary,
    this.icon,
    this.isLoading = false,
    this.padding,
    this.borderRadius = 12,
    this.minimumSize,
    this.textStyle,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);

    if (isLoading) {
      return _buildLoadingButton(context, isDark);
    }

    switch (variant) {
      case ButtonVariant.primary:
        return _buildElevatedButton(
          context,
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
        );
      
      case ButtonVariant.secondary:
        return _buildElevatedButton(
          context,
          backgroundColor: isDark ? AppColors.darkCard : Colors.grey[100]!,
          foregroundColor: AppColors.getTextPrimary(context),
        );
      
      case ButtonVariant.outline:
        return _buildOutlineButton(context, isDark);
      
      case ButtonVariant.danger:
        return _buildElevatedButton(
          context,
          backgroundColor: AppColors.error,
          foregroundColor: Colors.white,
        );
      
      case ButtonVariant.success:
        return _buildElevatedButton(
          context,
          backgroundColor: AppColors.success,
          foregroundColor: Colors.white,
        );
      
      case ButtonVariant.gradient:
        return _buildGradientButton(context);
    }
  }

  Widget _buildElevatedButton(
    BuildContext context, {
    required Color backgroundColor,
    required Color foregroundColor,
  }) {
    // Use custom backgroundColor if provided, otherwise use the passed backgroundColor
    final finalBackgroundColor = this.backgroundColor ?? backgroundColor;
    if (icon != null) {
      return ElevatedButton.icon(
        onPressed: onPressed == null ? null : () {
          HapticFeedback.lightImpact();
          onPressed!();
        },
        icon: Icon(icon, size: 18),
        label: Text(text),
        style: ElevatedButton.styleFrom(
          backgroundColor: finalBackgroundColor,
          foregroundColor: foregroundColor,
          padding: padding ?? const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadius!),
          ),
          minimumSize: minimumSize ?? const Size(100, 40),
          textStyle: textStyle ?? const TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 14,
          ),
        ),
      );
    }

    return ElevatedButton(
      onPressed: onPressed == null ? null : () {
        HapticFeedback.lightImpact();
        onPressed!();
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: finalBackgroundColor,
        foregroundColor: foregroundColor,
        padding: padding ?? const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(borderRadius!),
        ),
        minimumSize: minimumSize ?? const Size(100, 40),
        textStyle: textStyle ?? const TextStyle(
          fontWeight: FontWeight.w500,
          fontSize: 14,
        ),
      ),
      child: Text(text),
    );
  }

  Widget _buildOutlineButton(BuildContext context, bool isDark) {
    if (icon != null) {
      return OutlinedButton.icon(
        onPressed: onPressed == null ? null : () {
          HapticFeedback.lightImpact();
          onPressed!();
        },
        icon: Icon(icon, size: 18),
        label: Text(text),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          padding: padding ?? const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          side: BorderSide(color: AppColors.primary, width: 1),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadius!),
          ),
          minimumSize: minimumSize ?? const Size(100, 40),
          textStyle: textStyle ?? const TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 14,
          ),
        ),
      );
    }

    return OutlinedButton(
      onPressed: onPressed == null ? null : () {
        HapticFeedback.lightImpact();
        onPressed!();
      },
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primary,
        padding: padding ?? const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        side: BorderSide(color: AppColors.primary, width: 1),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(borderRadius!),
        ),
        minimumSize: minimumSize ?? const Size(100, 40),
        textStyle: textStyle ?? const TextStyle(
          fontWeight: FontWeight.w500,
          fontSize: 14,
        ),
      ),
      child: Text(text),
    );
  }

  Widget _buildGradientButton(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary, AppColors.primary.withOpacity(0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(borderRadius!),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed == null ? null : () {
            HapticFeedback.lightImpact();
            onPressed!();
          },
          borderRadius: BorderRadius.circular(borderRadius!),
          child: Container(
            padding: padding ?? const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            constraints: BoxConstraints(
              minWidth: minimumSize?.width ?? 100,
              minHeight: minimumSize?.height ?? 40,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[
                  Icon(icon, color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                ],
                Text(
                  text,
                  style: textStyle?.copyWith(color: Colors.white) ?? 
                    const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                    ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingButton(BuildContext context, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.6),
        borderRadius: BorderRadius.circular(borderRadius!),
      ),
      child: Container(
        padding: padding ?? const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        constraints: BoxConstraints(
          minWidth: minimumSize?.width ?? 100,
          minHeight: minimumSize?.height ?? 40,
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
            SizedBox(width: 8),
            Text(
              'Loading...',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Icon Button variant for common usage
class CommonIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final Color? backgroundColor;
  final Color? iconColor;
  final double? size;
  final double? iconSize;
  final EdgeInsetsGeometry? padding;

  const CommonIconButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.backgroundColor,
    this.iconColor,
    this.size = 44,
    this.iconSize = 20,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: backgroundColor ?? AppColors.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: padding ?? EdgeInsets.zero,
            child: Icon(
              icon,
              color: iconColor ?? AppColors.primary,
              size: iconSize,
            ),
          ),
        ),
      ),
    );
  }
}

// List Tile Card for consistent list items
class ListTileCard extends StatelessWidget {
  final Widget? leading;
  final Widget? title;
  final Widget? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;

  const ListTileCard({
    super.key,
    this.leading,
    this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.padding,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    return CommonCard(
      padding: EdgeInsets.zero,
      margin: margin ?? const EdgeInsets.only(bottom: 12),
      onTap: onTap,
      child: ListTile(
        contentPadding: padding ?? const EdgeInsets.all(16),
        leading: leading,
        title: title,
        subtitle: subtitle,
        trailing: trailing,
      ),
    );
  }
}

// Analytics Card for dashboard-style layouts
class AnalyticsCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final String mainValue;
  final String mainLabel;
  final List<Map<String, String>> stats;
  final String trend;

  const AnalyticsCard({
    super.key,
    required this.title,
    required this.icon,
    required this.color,
    required this.mainValue,
    required this.mainLabel,
    required this.stats,
    required this.trend,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.getCardBg(context),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [color, color.withOpacity(0.8)]),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: color.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(icon, color: Colors.white, size: 18),
              ),
              _buildTrendIndicator(trend, color),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            mainValue,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
              letterSpacing: -0.5,
            ),
          ),
          Text(
            mainLabel,
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: stats.map((stat) => Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    stat['value']!,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    stat['label']!,
                    style: const TextStyle(
                      fontSize: 9,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            )).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildTrendIndicator(String trend, Color color) {
    IconData icon;
    Color bgColor;
    
    switch (trend) {
      case 'up':
        icon = Icons.trending_up_rounded;
        bgColor = AppColors.success;
        break;
      case 'down':
        icon = Icons.trending_down_rounded;
        bgColor = AppColors.error;
        break;
      default:
        icon = Icons.remove_rounded;
        bgColor = AppColors.textSecondary;
    }

    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: bgColor.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, size: 14, color: bgColor),
    );
  }
}
