import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/mood_theme.dart';
import '../models/mood_type.dart';

/// Activity selection chips for mood entry
class MoodActivityChips extends StatelessWidget {
  final List<ActivityType> selectedActivities;
  final ValueChanged<List<ActivityType>> onChanged;
  final int maxSelection;

  const MoodActivityChips({
    super.key,
    required this.selectedActivities,
    required this.onChanged,
    this.maxSelection = 5,
  });

  void _toggleActivity(ActivityType activity) {
    HapticFeedback.selectionClick();
    
    final newSelection = List<ActivityType>.from(selectedActivities);
    
    if (newSelection.contains(activity)) {
      newSelection.remove(activity);
    } else if (newSelection.length < maxSelection) {
      newSelection.add(activity);
    }
    
    onChanged(newSelection);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Activities',
              style: MoodTheme.titleMd.copyWith(
                color: MoodTheme.textPrimary,
              ),
            ),
            Text(
              '${selectedActivities.length}/$maxSelection',
              style: MoodTheme.bodySm.copyWith(
                color: MoodTheme.textMuted,
              ),
            ),
          ],
        ),
        const SizedBox(height: MoodTheme.spacingSm),
        Text(
          'What have you been doing?',
          style: MoodTheme.bodySm.copyWith(
            color: MoodTheme.textSecondary,
          ),
        ),
        const SizedBox(height: MoodTheme.spacingMd),
        
        // Activity chips
        Wrap(
          spacing: MoodTheme.spacingSm,
          runSpacing: MoodTheme.spacingSm,
          children: ActivityType.values.map((activity) {
            final isSelected = selectedActivities.contains(activity);
            final color = MoodTheme.activityColors[activity.value] ?? MoodTheme.primary;
            final icon = MoodTheme.activityIcons[activity.value] ?? Icons.star_rounded;
            
            return _ActivityChip(
              activity: activity,
              isSelected: isSelected,
              color: color,
              icon: icon,
              onTap: () => _toggleActivity(activity),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _ActivityChip extends StatelessWidget {
  final ActivityType activity;
  final bool isSelected;
  final Color color;
  final IconData icon;
  final VoidCallback onTap;

  const _ActivityChip({
    required this.activity,
    required this.isSelected,
    required this.color,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: MoodTheme.animationFast,
        padding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 10,
        ),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.15) : MoodTheme.backgroundSecondary,
          borderRadius: MoodTheme.borderRadiusRound,
          border: Border.all(
            color: isSelected ? color : Colors.transparent,
            width: 2,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: color.withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? color : MoodTheme.textSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              activity.label,
              style: MoodTheme.titleSm.copyWith(
                color: isSelected ? color : MoodTheme.textSecondary,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Compact activity tags display (for lists)
class ActivityTagsRow extends StatelessWidget {
  final List<ActivityType> activities;
  final int maxDisplay;

  const ActivityTagsRow({
    super.key,
    required this.activities,
    this.maxDisplay = 3,
  });

  @override
  Widget build(BuildContext context) {
    if (activities.isEmpty) return const SizedBox.shrink();

    final displayActivities = activities.take(maxDisplay).toList();
    final remaining = activities.length - maxDisplay;

    return Row(
      children: [
        ...displayActivities.map((activity) {
          final color = MoodTheme.activityColors[activity.value] ?? MoodTheme.primary;
          final icon = MoodTheme.activityIcons[activity.value] ?? Icons.star_rounded;
          
          return Padding(
            padding: const EdgeInsets.only(right: 6),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 4,
              ),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: MoodTheme.borderRadiusSm,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 12, color: color),
                  const SizedBox(width: 4),
                  Text(
                    activity.label,
                    style: TextStyle(
                      fontSize: 11,
                      color: color,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
        if (remaining > 0)
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 8,
              vertical: 4,
            ),
            decoration: BoxDecoration(
              color: MoodTheme.textMuted.withOpacity(0.1),
              borderRadius: MoodTheme.borderRadiusSm,
            ),
            child: Text(
              '+$remaining',
              style: const TextStyle(
                fontSize: 11,
                color: MoodTheme.textMuted,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
      ],
    );
  }
}
