import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/models.dart';
import '../theme/habit_theme.dart';

/// Habit card widget for displaying habit in list
class HabitCard extends StatelessWidget {
  final Habit habit;
  final bool isCompleted;
  final double? progress; // 0.0 - 1.0 for target-based habits
  final VoidCallback? onTap;
  final VoidCallback? onComplete;
  final VoidCallback? onLongPress;

  const HabitCard({
    super.key,
    required this.habit,
    this.isCompleted = false,
    this.progress,
    this.onTap,
    this.onComplete,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: AnimatedContainer(
        duration: HabitTheme.animationMedium,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isCompleted ? habit.color.withOpacity(0.15) : HabitTheme.white,
          borderRadius: BorderRadius.circular(HabitTheme.radiusL),
          border: Border.all(
            color: isCompleted ? habit.color.withOpacity(0.3) : HabitTheme.grayLight,
            width: 1,
          ),
          boxShadow: isCompleted ? null : HabitTheme.subtleShadow,
        ),
        child: Row(
          children: [
            // Completion checkbox
            GestureDetector(
              onTap: () {
                HapticFeedback.mediumImpact();
                onComplete?.call();
              },
              child: AnimatedContainer(
                duration: HabitTheme.animationFast,
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: isCompleted ? habit.color : Colors.transparent,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isCompleted ? habit.color : HabitTheme.gray,
                    width: 2,
                  ),
                ),
                child: isCompleted
                    ? const Icon(
                        Icons.check,
                        size: 16,
                        color: HabitTheme.white,
                      )
                    : null,
              ),
            ),
            const SizedBox(width: 12),
            // Icon
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: habit.color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(HabitTheme.radiusM),
              ),
              child: Icon(
                habit.icon,
                color: habit.color,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    habit.name,
                    style: HabitTheme.b1.copyWith(
                      fontWeight: FontWeight.w600,
                      decoration: isCompleted ? TextDecoration.lineThrough : null,
                      color: isCompleted ? HabitTheme.gray : HabitTheme.dark,
                    ),
                  ),
                  if (habit.hasTarget && habit.targetValue != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      '${progress != null ? (progress! * habit.targetValue!).toStringAsFixed(0) : '0'}/${habit.targetValue!.toStringAsFixed(0)} ${habit.targetUnit ?? ''}',
                      style: HabitTheme.b3.copyWith(
                        color: habit.color,
                      ),
                    ),
                  ] else ...[
                    const SizedBox(height: 4),
                    Text(
                      habit.repeatDescription,
                      style: HabitTheme.description,
                    ),
                  ],
                ],
              ),
            ),
            // Progress or time
            if (habit.hasTarget && progress != null && !isCompleted) ...[
              _buildProgressIndicator(),
            ] else if (habit.timeOfDay != HabitTimeOfDay.anytime) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: HabitTheme.primarySoft,
                  borderRadius: BorderRadius.circular(HabitTheme.radiusFull),
                ),
                child: Text(
                  habit.timeOfDayLabel,
                  style: HabitTheme.caption.copyWith(
                    color: HabitTheme.primary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildProgressIndicator() {
    return SizedBox(
      width: 44,
      height: 44,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircularProgressIndicator(
            value: progress ?? 0,
            strokeWidth: 4,
            backgroundColor: HabitTheme.grayLight,
            valueColor: AlwaysStoppedAnimation(habit.color),
          ),
          Text(
            '${((progress ?? 0) * 100).toInt()}%',
            style: HabitTheme.caption.copyWith(
              fontWeight: FontWeight.w600,
              color: habit.color,
            ),
          ),
        ],
      ),
    );
  }
}

/// Completed habit card (green style from design)
class CompletedHabitCard extends StatelessWidget {
  final Habit habit;
  final String? subtitle;
  final VoidCallback? onTap;
  final VoidCallback? onNote;
  final VoidCallback? onEdit;

  const CompletedHabitCard({
    super.key,
    required this.habit,
    this.subtitle,
    this.onTap,
    this.onNote,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [habit.color, habit.color.withOpacity(0.8)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(HabitTheme.radiusL),
          boxShadow: [
            BoxShadow(
              color: habit.color.withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            // Checkmark
            Container(
              width: 56,
              height: 56,
              margin: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: HabitTheme.white.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check,
                color: HabitTheme.white,
                size: 28,
              ),
            ),
            // Content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      habit.name,
                      style: HabitTheme.b1.copyWith(
                        color: HabitTheme.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: HabitTheme.description.copyWith(
                          color: HabitTheme.white.withOpacity(0.8),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            // Actions
            if (onNote != null || onEdit != null)
              Row(
                children: [
                  if (onNote != null)
                    IconButton(
                      onPressed: onNote,
                      icon: Icon(
                        Icons.note_outlined,
                        color: HabitTheme.white.withOpacity(0.8),
                        size: 20,
                      ),
                    ),
                  if (onEdit != null)
                    IconButton(
                      onPressed: onEdit,
                      icon: Icon(
                        Icons.edit_outlined,
                        color: HabitTheme.white.withOpacity(0.8),
                        size: 20,
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
