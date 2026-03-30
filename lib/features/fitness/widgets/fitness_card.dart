import 'package:flutter/material.dart';
import 'dart:ui';
import '../theme/fitness_theme.dart';

/// Reusable dark glass card widget for fitness feature
class FitnessCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final Color? backgroundColor;
  final Color? borderColor;
  final double? borderRadius;
  final bool enableGlass;
  final bool showGlow;
  final Color? glowColor;
  final Gradient? gradient;

  const FitnessCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.onTap,
    this.backgroundColor,
    this.borderColor,
    this.borderRadius,
    this.enableGlass = false,
    this.showGlow = false,
    this.glowColor,
    this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    Widget cardContent = Container(
      padding: padding ?? const EdgeInsets.all(FitnessTheme.spacingMd),
      decoration: BoxDecoration(
        color: enableGlass ? null : (backgroundColor ?? FitnessTheme.cardBackground),
        gradient: gradient,
        borderRadius: BorderRadius.circular(borderRadius ?? FitnessTheme.radiusMd),
        border: Border.all(
          color: borderColor ?? Colors.white.withOpacity(0.08),
          width: 1,
        ),
        boxShadow: showGlow
            ? [
                BoxShadow(
                  color: (glowColor ?? FitnessTheme.primary).withOpacity(0.3),
                  blurRadius: 20,
                  spreadRadius: 0,
                ),
              ]
            : FitnessTheme.cardShadow,
      ),
      child: child,
    );

    if (enableGlass) {
      cardContent = ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius ?? FitnessTheme.radiusMd),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: padding ?? const EdgeInsets.all(FitnessTheme.spacingMd),
            decoration: BoxDecoration(
              color: (backgroundColor ?? FitnessTheme.cardBackground).withOpacity(0.7),
              borderRadius: BorderRadius.circular(borderRadius ?? FitnessTheme.radiusMd),
              border: Border.all(
                color: borderColor ?? Colors.white.withOpacity(0.1),
                width: 1,
              ),
            ),
            child: child,
          ),
        ),
      );
    }

    if (margin != null) {
      cardContent = Padding(padding: margin!, child: cardContent);
    }

    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        child: cardContent,
      );
    }

    return cardContent;
  }
}

/// Workout card with image/gradient header
class WorkoutCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String duration;
  final String difficulty;
  final String bodyPart;
  final int exerciseCount;
  final VoidCallback? onTap;
  final bool showBadge;
  final String? badgeText;
  final Widget? leadingWidget;

  const WorkoutCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.duration,
    required this.difficulty,
    required this.bodyPart,
    required this.exerciseCount,
    this.onTap,
    this.showBadge = false,
    this.badgeText,
    this.leadingWidget,
  });

  @override
  Widget build(BuildContext context) {
    final bodyPartColor = FitnessTheme.getBodyPartColor(bodyPart);
    final difficultyColor = FitnessTheme.getDifficultyColor(difficulty);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: FitnessTheme.spacingMd),
        decoration: BoxDecoration(
          color: FitnessTheme.cardBackground,
          borderRadius: FitnessTheme.borderRadiusMd,
          border: Border.all(
            color: Colors.white.withOpacity(0.05),
            width: 1,
          ),
          boxShadow: FitnessTheme.cardShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with gradient
            Container(
              height: 100,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    bodyPartColor.withOpacity(0.3),
                    bodyPartColor.withOpacity(0.1),
                  ],
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(FitnessTheme.radiusMd),
                  topRight: Radius.circular(FitnessTheme.radiusMd),
                ),
              ),
              child: Stack(
                children: [
                  // Body part icon
                  Positioned(
                    right: FitnessTheme.spacingMd,
                    top: FitnessTheme.spacingMd,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: FitnessTheme.spacingSm,
                        vertical: FitnessTheme.spacingXs,
                      ),
                      decoration: BoxDecoration(
                        color: bodyPartColor.withOpacity(0.2),
                        borderRadius: FitnessTheme.borderRadiusSm,
                        border: Border.all(
                          color: bodyPartColor.withOpacity(0.5),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        bodyPart.toUpperCase(),
                        style: FitnessTheme.caption.copyWith(
                          color: bodyPartColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  // Leading widget or icon
                  if (leadingWidget != null)
                    Positioned(
                      left: FitnessTheme.spacingMd,
                      bottom: FitnessTheme.spacingMd,
                      child: leadingWidget!,
                    ),
                  // Badge
                  if (showBadge && badgeText != null)
                    Positioned(
                      left: FitnessTheme.spacingMd,
                      top: FitnessTheme.spacingMd,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: FitnessTheme.spacingSm,
                          vertical: FitnessTheme.spacingXs,
                        ),
                        decoration: BoxDecoration(
                          color: FitnessTheme.primary,
                          borderRadius: FitnessTheme.borderRadiusSm,
                        ),
                        child: Text(
                          badgeText!,
                          style: FitnessTheme.caption.copyWith(
                            color: FitnessTheme.textOnPrimary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            // Content
            Padding(
              padding: const EdgeInsets.all(FitnessTheme.spacingMd),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: FitnessTheme.titleLg,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: FitnessTheme.spacingXs),
                  Text(
                    subtitle,
                    style: FitnessTheme.bodySm,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: FitnessTheme.spacingMd),
                  // Stats row
                  Row(
                    children: [
                      _buildStat(Icons.timer_outlined, duration),
                      const SizedBox(width: FitnessTheme.spacingMd),
                      _buildStat(Icons.fitness_center, '$exerciseCount exercises'),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: FitnessTheme.spacingSm,
                          vertical: FitnessTheme.spacingXs,
                        ),
                        decoration: BoxDecoration(
                          color: difficultyColor.withOpacity(0.15),
                          borderRadius: FitnessTheme.borderRadiusSm,
                        ),
                        child: Text(
                          difficulty,
                          style: FitnessTheme.caption.copyWith(
                            color: difficultyColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStat(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: FitnessTheme.textMuted),
        const SizedBox(width: 4),
        Text(text, style: FitnessTheme.bodySm),
      ],
    );
  }
}

/// Compact exercise card for lists
class ExerciseCard extends StatelessWidget {
  final String name;
  final String duration;
  final int? reps;
  final int index;
  final bool isActive;
  final bool isCompleted;
  final VoidCallback? onTap;
  final Widget? leading;

  const ExerciseCard({
    super.key,
    required this.name,
    required this.duration,
    this.reps,
    required this.index,
    this.isActive = false,
    this.isCompleted = false,
    this.onTap,
    this.leading,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(FitnessTheme.spacingMd),
        margin: const EdgeInsets.only(bottom: FitnessTheme.spacingSm),
        decoration: BoxDecoration(
          color: isActive
              ? FitnessTheme.primary.withOpacity(0.1)
              : FitnessTheme.cardBackground,
          borderRadius: FitnessTheme.borderRadiusMd,
          border: Border.all(
            color: isActive
                ? FitnessTheme.primary
                : Colors.white.withOpacity(0.05),
            width: isActive ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            // Index or checkmark
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: isCompleted
                    ? FitnessTheme.success
                    : (isActive ? FitnessTheme.primary : FitnessTheme.surface),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: isCompleted
                    ? const Icon(Icons.check, color: Colors.white, size: 20)
                    : Text(
                        '${index + 1}',
                        style: FitnessTheme.titleSm.copyWith(
                          color: isActive
                              ? FitnessTheme.textOnPrimary
                              : FitnessTheme.textSecondary,
                        ),
                      ),
              ),
            ),
            const SizedBox(width: FitnessTheme.spacingMd),
            // Exercise thumbnail or icon
            if (leading != null) ...[
              leading!,
              const SizedBox(width: FitnessTheme.spacingMd),
            ],
            // Name and duration
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: FitnessTheme.titleSm.copyWith(
                      color: isActive ? FitnessTheme.primary : null,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    reps != null ? '$reps reps' : duration,
                    style: FitnessTheme.bodySm,
                  ),
                ],
              ),
            ),
            // Arrow
            Icon(
              Icons.chevron_right,
              color: FitnessTheme.textMuted,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

/// Body part selection card
class BodyPartCard extends StatelessWidget {
  final String name;
  final IconData icon;
  final int workoutCount;
  final bool isSelected;
  final VoidCallback? onTap;

  const BodyPartCard({
    super.key,
    required this.name,
    required this.icon,
    required this.workoutCount,
    this.isSelected = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = FitnessTheme.getBodyPartColor(name);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: FitnessTheme.animationFast,
        padding: const EdgeInsets.all(FitnessTheme.spacingMd),
        decoration: BoxDecoration(
          gradient: isSelected
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [color, color.withOpacity(0.7)],
                )
              : null,
          color: isSelected ? null : FitnessTheme.cardBackground,
          borderRadius: FitnessTheme.borderRadiusMd,
          border: Border.all(
            color: isSelected ? color : Colors.white.withOpacity(0.05),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: color.withOpacity(0.3),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 28,
              color: isSelected ? FitnessTheme.textOnPrimary : color,
            ),
            const SizedBox(height: 6),
            Text(
              name,
              style: FitnessTheme.titleSm.copyWith(
                color: isSelected ? FitnessTheme.textOnPrimary : null,
                fontSize: 13,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              '$workoutCount workouts',
              style: FitnessTheme.caption.copyWith(
                color: isSelected
                    ? FitnessTheme.textOnPrimary.withValues(alpha: 0.8)
                    : FitnessTheme.textMuted,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Stats card for progress display
class StatsCard extends StatelessWidget {
  final String title;
  final String value;
  final String? subtitle;
  final IconData icon;
  final Color? color;
  final double? progress;

  const StatsCard({
    super.key,
    required this.title,
    required this.value,
    this.subtitle,
    required this.icon,
    this.color,
    this.progress,
  });

  @override
  Widget build(BuildContext context) {
    final accentColor = color ?? FitnessTheme.primary;

    return FitnessCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(FitnessTheme.spacingSm),
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.15),
                  borderRadius: FitnessTheme.borderRadiusSm,
                ),
                child: Icon(icon, color: accentColor, size: 20),
              ),
              const Spacer(),
              if (progress != null)
                SizedBox(
                  width: 40,
                  height: 40,
                  child: CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 3,
                    backgroundColor: FitnessTheme.surface,
                    valueColor: AlwaysStoppedAnimation(accentColor),
                  ),
                ),
            ],
          ),
          const SizedBox(height: FitnessTheme.spacingMd),
          Text(
            value,
            style: FitnessTheme.statValue.copyWith(color: accentColor),
          ),
          const SizedBox(height: FitnessTheme.spacingXs),
          Text(title, style: FitnessTheme.bodySm),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(subtitle!, style: FitnessTheme.caption),
          ],
        ],
      ),
    );
  }
}
