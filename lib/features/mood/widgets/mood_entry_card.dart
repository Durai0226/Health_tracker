import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/mood_entry.dart';
import '../models/quick_mood_level.dart';
import '../theme/mood_theme.dart';

/// Detailed mood entry card matching Behance design
/// Shows: mood emoji + label, activity tags, journal text, timestamp
class MoodEntryCard extends StatelessWidget {
  final MoodEntry entry;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;

  const MoodEntryCard({
    super.key,
    required this.entry,
    this.onTap,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final quickMood = QuickMoodLevel.fromMoodType(entry.mood);
    
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap?.call();
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: MoodTheme.spacingMd),
        padding: const EdgeInsets.all(MoodTheme.spacingMd),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: MoodTheme.borderRadiusLg,
          boxShadow: MoodTheme.softShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: mood emoji + label + edit button
            Row(
              children: [
                Text(
                  quickMood.emoji,
                  style: const TextStyle(fontSize: 28),
                ),
                const SizedBox(width: 10),
                Text(
                  quickMood.label,
                  style: MoodTheme.titleLg.copyWith(
                    color: MoodTheme.textPrimary,
                  ),
                ),
                const Spacer(),
                if (onEdit != null)
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      onEdit?.call();
                    },
                    child: Icon(
                      Icons.edit_outlined,
                      size: 20,
                      color: MoodTheme.textMuted,
                    ),
                  ),
              ],
            ),

            // Activity tags
            if (entry.activities.isNotEmpty) ...[
              const SizedBox(height: 12),
              _buildActivityTags(),
            ],

            // Journal text
            if (entry.note != null && entry.note!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                entry.note!,
                style: MoodTheme.bodyMd.copyWith(
                  color: MoodTheme.textPrimary,
                  height: 1.5,
                ),
                maxLines: 6,
                overflow: TextOverflow.ellipsis,
              ),
            ],

            // Timestamp
            const SizedBox(height: 12),
            Text(
              _formatTimestamp(entry.timestamp),
              style: MoodTheme.caption.copyWith(
                color: MoodTheme.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityTags() {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: entry.activities.map((activity) {
        final activityName = activity.value.toLowerCase();
        final icon = MoodTheme.activityIcons[activityName];
        final color = MoodTheme.activityColors[activityName] ?? 
            MoodTheme.textSecondary;
        
        return Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 5,
          ),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: MoodTheme.borderRadiusRound,
            border: Border.all(
              color: color.withOpacity(0.2),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 14, color: color),
                const SizedBox(width: 4),
              ],
              Text(
                activity.label,
                style: MoodTheme.caption.copyWith(
                  color: color,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final isToday = timestamp.year == now.year && 
        timestamp.month == now.month && 
        timestamp.day == now.day;

    final hour = timestamp.hour;
    final minute = timestamp.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    final hour12 = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);

    final months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];

    if (isToday) {
      return 'Today at $hour12:$minute $period';
    } else {
      return '$hour12:$minute $period, ${timestamp.day} ${months[timestamp.month - 1]} ${timestamp.year}';
    }
  }

}

/// Compact mood entry for lists
class MoodEntryCompactCard extends StatelessWidget {
  final MoodEntry entry;
  final VoidCallback? onTap;

  const MoodEntryCompactCard({
    super.key,
    required this.entry,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final quickMood = QuickMoodLevel.fromMoodType(entry.mood);
    final moodColor = MoodTheme.getMoodColor(entry.mood.value);

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap?.call();
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: MoodTheme.spacingSm),
        padding: const EdgeInsets.all(MoodTheme.spacingMd),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: MoodTheme.borderRadiusMd,
          boxShadow: MoodTheme.softShadow,
        ),
        child: Row(
          children: [
            // Mood indicator
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: moodColor.withOpacity(0.15),
                borderRadius: MoodTheme.borderRadiusSm,
              ),
              child: Center(
                child: Text(
                  quickMood.emoji,
                  style: const TextStyle(fontSize: 24),
                ),
              ),
            ),
            const SizedBox(width: MoodTheme.spacingMd),
            
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    quickMood.label,
                    style: MoodTheme.titleSm.copyWith(
                      color: moodColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    entry.isToday
                        ? 'Today at ${entry.formattedTime}'
                        : entry.formattedDate,
                    style: MoodTheme.caption.copyWith(
                      color: MoodTheme.textMuted,
                    ),
                  ),
                ],
              ),
            ),

            // Intensity badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: moodColor.withOpacity(0.1),
                borderRadius: MoodTheme.borderRadiusRound,
              ),
              child: Text(
                '${entry.intensity}/5',
                style: MoodTheme.caption.copyWith(
                  color: moodColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
