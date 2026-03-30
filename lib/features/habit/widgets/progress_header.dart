import 'package:flutter/material.dart';
import '../theme/habit_theme.dart';

/// Progress header card showing daily completion stats
/// "You're almost done!" card from Habit Land design
class ProgressHeader extends StatelessWidget {
  final int completedHabits;
  final int totalHabits;
  final int completedTasks;
  final int totalTasks;
  final int completionPercentage;
  final VoidCallback? onTap;

  const ProgressHeader({
    super.key,
    required this.completedHabits,
    required this.totalHabits,
    required this.completedTasks,
    required this.totalTasks,
    required this.completionPercentage,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isComplete = completionPercentage >= 100;
    
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: HabitTheme.progressCardGradient,
          borderRadius: BorderRadius.circular(HabitTheme.radiusXL),
          boxShadow: HabitTheme.cardShadow,
        ),
        child: Row(
          children: [
            // Avatar/illustration placeholder
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: HabitTheme.white.withOpacity(0.3),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isComplete ? Icons.celebration : Icons.emoji_emotions,
                size: 40,
                color: HabitTheme.primary,
              ),
            ),
            const SizedBox(width: 16),
            // Stats
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isComplete ? "You've done it!" : "You're almost done!",
                    style: HabitTheme.b2.copyWith(
                      color: HabitTheme.dark.withOpacity(0.7),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _buildStatItem(
                        '$completedHabits/$totalHabits',
                        'Habits',
                        HabitTheme.primary,
                      ),
                      const SizedBox(width: 16),
                      _buildStatItem(
                        '$completedTasks/$totalTasks',
                        'Tasks',
                        HabitTheme.categoryExercise,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Progress ring
            _buildProgressRing(),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String value, String label, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: HabitTheme.h2.copyWith(
            color: color,
            fontWeight: FontWeight.w700,
          ),
        ),
        Text(
          label,
          style: HabitTheme.caption.copyWith(
            color: HabitTheme.dark.withOpacity(0.6),
          ),
        ),
      ],
    );
  }

  Widget _buildProgressRing() {
    return SizedBox(
      width: 72,
      height: 72,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Background circle
          SizedBox(
            width: 72,
            height: 72,
            child: CircularProgressIndicator(
              value: 1,
              strokeWidth: 6,
              backgroundColor: Colors.transparent,
              valueColor: AlwaysStoppedAnimation(
                HabitTheme.white.withOpacity(0.3),
              ),
            ),
          ),
          // Progress circle
          SizedBox(
            width: 72,
            height: 72,
            child: CircularProgressIndicator(
              value: completionPercentage / 100,
              strokeWidth: 6,
              backgroundColor: Colors.transparent,
              valueColor: const AlwaysStoppedAnimation(HabitTheme.primary),
              strokeCap: StrokeCap.round,
            ),
          ),
          // Percentage text
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '$completionPercentage%',
                style: HabitTheme.h2.copyWith(
                  color: HabitTheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Tab selector for Habits/Tasks toggle
class HabitTaskToggle extends StatelessWidget {
  final bool isHabitsSelected;
  final ValueChanged<bool> onChanged;

  const HabitTaskToggle({
    super.key,
    required this.isHabitsSelected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: HabitTheme.grayLight,
        borderRadius: BorderRadius.circular(HabitTheme.radiusFull),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildTab('HABITS', isHabitsSelected, () => onChanged(true)),
          _buildTab('TASKS', !isHabitsSelected, () => onChanged(false)),
        ],
      ),
    );
  }

  Widget _buildTab(String label, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: HabitTheme.animationFast,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? HabitTheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(HabitTheme.radiusFull),
        ),
        child: Text(
          label,
          style: HabitTheme.label.copyWith(
            color: isSelected ? HabitTheme.white : HabitTheme.gray,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

/// Category filter dropdown
class CategoryFilter extends StatelessWidget {
  final String selectedGroupId;
  final List<({String id, String name})> groups;
  final ValueChanged<String> onChanged;

  const CategoryFilter({
    super.key,
    required this.selectedGroupId,
    required this.groups,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final selectedGroup = groups.firstWhere(
      (g) => g.id == selectedGroupId,
      orElse: () => (id: 'all', name: 'ALL'),
    );

    return PopupMenuButton<String>(
      onSelected: onChanged,
      offset: const Offset(0, 40),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(HabitTheme.radiusM),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(color: HabitTheme.grayLight),
          borderRadius: BorderRadius.circular(HabitTheme.radiusS),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              selectedGroup.name.toUpperCase(),
              style: HabitTheme.label.copyWith(
                color: HabitTheme.dark,
                fontSize: 13,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(
              Icons.keyboard_arrow_down,
              size: 20,
              color: HabitTheme.dark,
            ),
          ],
        ),
      ),
      itemBuilder: (context) => groups.map((group) {
        return PopupMenuItem<String>(
          value: group.id,
          child: Text(
            group.name,
            style: HabitTheme.b2.copyWith(
              fontWeight: group.id == selectedGroupId
                  ? FontWeight.w600
                  : FontWeight.w400,
            ),
          ),
        );
      }).toList(),
    );
  }
}
