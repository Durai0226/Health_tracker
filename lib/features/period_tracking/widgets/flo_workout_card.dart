import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/flo_theme.dart';
import '../models/cycle_workout.dart';
import 'flo_glass_card.dart';

/// Workout recommendation card for Flo fitness section
class FloWorkoutCard extends StatelessWidget {
  final CycleWorkout workout;
  final VoidCallback? onTap;
  final bool showStartButton;

  const FloWorkoutCard({
    super.key,
    required this.workout,
    this.onTap,
    this.showStartButton = true,
  });

  @override
  Widget build(BuildContext context) {
    return FloGlassCard(
      onTap: onTap,
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image placeholder with gradient overlay
          Container(
            height: 120,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  _getCategoryColor(workout.category).withOpacity(0.3),
                  _getCategoryColor(workout.category).withOpacity(0.1),
                ],
              ),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(FloTheme.radiusLg),
              ),
            ),
            child: Stack(
              children: [
                // Category emoji
                Center(
                  child: Text(
                    workout.category.icon,
                    style: const TextStyle(fontSize: 48),
                  ),
                ),
                
                // Intensity badge
                Positioned(
                  top: FloTheme.spacingSm,
                  right: FloTheme.spacingSm,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: FloTheme.spacingSm,
                      vertical: FloTheme.spacingXs,
                    ),
                    decoration: BoxDecoration(
                      color: _getIntensityColor(workout.intensity),
                      borderRadius: BorderRadius.circular(FloTheme.radiusSm),
                    ),
                    child: Text(
                      workout.intensity.displayName,
                      style: FloTheme.labelSmall.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Content
          Padding(
            padding: const EdgeInsets.all(FloTheme.spacingMd),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  workout.name,
                  style: FloTheme.titleLarge.copyWith(
                    color: FloTheme.getTextPrimary(context),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                
                const SizedBox(height: FloTheme.spacingXs),
                
                Text(
                  workout.description,
                  style: FloTheme.bodySmall.copyWith(
                    color: FloTheme.getTextSecondary(context),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                
                const SizedBox(height: FloTheme.spacingMd),
                
                // Stats row
                Row(
                  children: [
                    _StatChip(
                      icon: Icons.timer_outlined,
                      value: '${workout.durationMinutes} min',
                    ),
                    const SizedBox(width: FloTheme.spacingSm),
                    _StatChip(
                      icon: Icons.local_fire_department_rounded,
                      value: '${workout.caloriesBurned} kcal',
                    ),
                  ],
                ),
                
                if (showStartButton) ...[
                  const SizedBox(height: FloTheme.spacingMd),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        HapticFeedback.mediumImpact();
                        onTap?.call();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: FloTheme.periodPink,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          vertical: FloTheme.spacingSm,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(FloTheme.radiusSm),
                        ),
                      ),
                      child: const Text('Start'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getCategoryColor(WorkoutCategory category) {
    switch (category) {
      case WorkoutCategory.meditation:
        return Colors.purple;
      case WorkoutCategory.yoga:
        return Colors.teal;
      case WorkoutCategory.workouts:
        return FloTheme.periodPink;
      case WorkoutCategory.dietPlan:
        return Colors.green;
      case WorkoutCategory.stretching:
        return Colors.orange;
      case WorkoutCategory.breathing:
        return FloTheme.ovulationBlue;
      case WorkoutCategory.cardio:
        return Colors.red;
      case WorkoutCategory.strength:
        return Colors.indigo;
    }
  }

  Color _getIntensityColor(WorkoutIntensity intensity) {
    switch (intensity) {
      case WorkoutIntensity.low:
        return Colors.green;
      case WorkoutIntensity.medium:
        return Colors.orange;
      case WorkoutIntensity.high:
        return Colors.red;
    }
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String value;

  const _StatChip({
    required this.icon,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: FloTheme.spacingSm,
        vertical: FloTheme.spacingXs,
      ),
      decoration: BoxDecoration(
        color: FloTheme.getDivider(context),
        borderRadius: BorderRadius.circular(FloTheme.radiusSm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: FloTheme.getTextSecondary(context)),
          const SizedBox(width: 4),
          Text(
            value,
            style: FloTheme.labelSmall.copyWith(
              color: FloTheme.getTextSecondary(context),
            ),
          ),
        ],
      ),
    );
  }
}

/// Compact workout card for lists
class FloWorkoutCardCompact extends StatelessWidget {
  final CycleWorkout workout;
  final VoidCallback? onTap;

  const FloWorkoutCardCompact({
    super.key,
    required this.workout,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return FloGlassCard(
      onTap: onTap,
      padding: const EdgeInsets.all(FloTheme.spacingMd),
      child: Row(
        children: [
          // Icon
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: FloTheme.periodPinkLight,
              borderRadius: BorderRadius.circular(FloTheme.radiusMd),
            ),
            child: Center(
              child: Text(
                workout.category.icon,
                style: const TextStyle(fontSize: 24),
              ),
            ),
          ),
          
          const SizedBox(width: FloTheme.spacingMd),
          
          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  workout.name,
                  style: FloTheme.titleMedium.copyWith(
                    color: FloTheme.getTextPrimary(context),
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Icon(
                      Icons.timer_outlined,
                      size: 12,
                      color: FloTheme.getTextSecondary(context),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${workout.durationMinutes} min',
                      style: FloTheme.bodySmall.copyWith(
                        color: FloTheme.getTextSecondary(context),
                      ),
                    ),
                    const SizedBox(width: FloTheme.spacingMd),
                    Icon(
                      Icons.local_fire_department_rounded,
                      size: 12,
                      color: FloTheme.getTextSecondary(context),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${workout.caloriesBurned} kcal',
                      style: FloTheme.bodySmall.copyWith(
                        color: FloTheme.getTextSecondary(context),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // Arrow
          Icon(
            Icons.chevron_right_rounded,
            color: FloTheme.getTextSecondary(context),
          ),
        ],
      ),
    );
  }
}

/// Category selector for fitness screen
class FloCategorySelector extends StatelessWidget {
  final WorkoutCategory? selectedCategory;
  final ValueChanged<WorkoutCategory?> onCategorySelected;

  const FloCategorySelector({
    super.key,
    this.selectedCategory,
    required this.onCategorySelected,
  });

  @override
  Widget build(BuildContext context) {
    final categories = [
      WorkoutCategory.meditation,
      WorkoutCategory.yoga,
      WorkoutCategory.workouts,
      WorkoutCategory.dietPlan,
    ];

    return SizedBox(
      height: 90,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: FloTheme.spacingLg),
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final category = categories[index];
          final isSelected = selectedCategory == category;

          return Padding(
            padding: EdgeInsets.only(
              right: index < categories.length - 1 ? FloTheme.spacingMd : 0,
            ),
            child: GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                onCategorySelected(isSelected ? null : category);
              },
              child: AnimatedContainer(
                duration: FloTheme.animFast,
                width: 75,
                padding: const EdgeInsets.all(FloTheme.spacingSm),
                decoration: BoxDecoration(
                  color: isSelected
                      ? FloTheme.periodPink.withOpacity(0.1)
                      : FloTheme.getSurface(context),
                  borderRadius: BorderRadius.circular(FloTheme.radiusMd),
                  border: Border.all(
                    color: isSelected
                        ? FloTheme.periodPink
                        : FloTheme.getDivider(context),
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      category.icon,
                      style: const TextStyle(fontSize: 28),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      category.displayName,
                      style: FloTheme.labelSmall.copyWith(
                        color: isSelected
                            ? FloTheme.periodPink
                            : FloTheme.getTextSecondary(context),
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Workout progress indicator
class FloWorkoutProgress extends StatelessWidget {
  final double percentage;
  final String label;

  const FloWorkoutProgress({
    super.key,
    required this.percentage,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return FloGlassCard(
      padding: const EdgeInsets.all(FloTheme.spacingLg),
      child: Row(
        children: [
          // Progress circle
          SizedBox(
            width: 60,
            height: 60,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: percentage / 100,
                  strokeWidth: 6,
                  backgroundColor: FloTheme.getDivider(context),
                  valueColor: AlwaysStoppedAnimation(FloTheme.periodPink),
                ),
                Text(
                  '${percentage.toInt()}%',
                  style: FloTheme.titleMedium.copyWith(
                    color: FloTheme.periodPink,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(width: FloTheme.spacingLg),
          
          // Label
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'of your target is out.',
                  style: FloTheme.bodyMedium.copyWith(
                    color: FloTheme.getTextSecondary(context),
                  ),
                ),
                const SizedBox(height: FloTheme.spacingXs),
                ElevatedButton(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(
                    backgroundColor: FloTheme.periodPink,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: FloTheme.spacingLg,
                      vertical: FloTheme.spacingSm,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(FloTheme.radiusSm),
                    ),
                  ),
                  child: const Text('Edit Streak'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
