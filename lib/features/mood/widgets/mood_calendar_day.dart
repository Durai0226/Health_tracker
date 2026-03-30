import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/mood_theme.dart';
import '../models/mood_type.dart';
import '../models/mood_insight.dart';

/// Calendar day cell widget for mood calendar view
class MoodCalendarDay extends StatelessWidget {
  final DateTime date;
  final DailyMoodSummary? summary;
  final bool isSelected;
  final bool isToday;
  final bool isCurrentMonth;
  final VoidCallback? onTap;

  const MoodCalendarDay({
    super.key,
    required this.date,
    this.summary,
    this.isSelected = false,
    this.isToday = false,
    this.isCurrentMonth = true,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasMood = summary?.dominantMood != null;
    final moodColor = hasMood
        ? MoodTheme.getMoodColor(summary!.dominantMood!.value)
        : Colors.transparent;
    final moodLightColor = hasMood
        ? MoodTheme.getMoodLightColor(summary!.dominantMood!.value)
        : Colors.transparent;

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap?.call();
      },
      child: AnimatedContainer(
        duration: MoodTheme.animationFast,
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: isSelected
              ? MoodTheme.primary.withOpacity(0.2)
              : hasMood
                  ? moodLightColor
                  : Colors.transparent,
          borderRadius: MoodTheme.borderRadiusSm,
          border: Border.all(
            color: isSelected
                ? MoodTheme.primary
                : isToday
                    ? MoodTheme.primary.withOpacity(0.5)
                    : hasMood
                        ? moodColor.withOpacity(0.3)
                        : Colors.transparent,
            width: isSelected || isToday ? 2 : 1,
          ),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Day number
            Text(
              '${date.day}',
              style: MoodTheme.titleSm.copyWith(
                color: isCurrentMonth
                    ? (hasMood ? moodColor : MoodTheme.textPrimary)
                    : MoodTheme.textMuted,
                fontWeight: isToday || isSelected
                    ? FontWeight.bold
                    : FontWeight.normal,
              ),
            ),
            
            // Mood indicator dot
            if (hasMood)
              Positioned(
                bottom: 4,
                child: Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: moodColor,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            
            // Multiple entries indicator
            if (summary != null && summary!.entryCount > 1)
              Positioned(
                top: 2,
                right: 2,
                child: Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: moodColor,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '${summary!.entryCount}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Calendar header with month/year and navigation
class MoodCalendarHeader extends StatelessWidget {
  final DateTime currentMonth;
  final VoidCallback onPreviousMonth;
  final VoidCallback onNextMonth;
  final VoidCallback? onMonthTap;

  const MoodCalendarHeader({
    super.key,
    required this.currentMonth,
    required this.onPreviousMonth,
    required this.onNextMonth,
    this.onMonthTap,
  });

  String get _monthYear {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return '${months[currentMonth.month - 1]} ${currentMonth.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: MoodTheme.spacingMd,
        vertical: MoodTheme.spacingSm,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Previous month button
          _NavigationButton(
            icon: Icons.chevron_left_rounded,
            onTap: onPreviousMonth,
          ),
          
          // Month/Year title
          GestureDetector(
            onTap: onMonthTap,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: MoodTheme.spacingMd,
                vertical: MoodTheme.spacingSm,
              ),
              decoration: BoxDecoration(
                color: MoodTheme.primarySoft,
                borderRadius: MoodTheme.borderRadiusRound,
              ),
              child: Text(
                _monthYear,
                style: MoodTheme.titleMd.copyWith(
                  color: MoodTheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          
          // Next month button
          _NavigationButton(
            icon: Icons.chevron_right_rounded,
            onTap: onNextMonth,
          ),
        ],
      ),
    );
  }
}

class _NavigationButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _NavigationButton({
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        borderRadius: MoodTheme.borderRadiusRound,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: MoodTheme.backgroundSecondary,
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            color: MoodTheme.textPrimary,
            size: 24,
          ),
        ),
      ),
    );
  }
}

/// Weekday header row
class MoodCalendarWeekdays extends StatelessWidget {
  const MoodCalendarWeekdays({super.key});

  @override
  Widget build(BuildContext context) {
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: MoodTheme.spacingSm),
      child: Row(
        children: weekdays.map((day) {
          final isWeekend = day == 'Sat' || day == 'Sun';
          return Expanded(
            child: Center(
              child: Text(
                day,
                style: MoodTheme.caption.copyWith(
                  color: isWeekend ? MoodTheme.primary : MoodTheme.textMuted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

/// Mood legend for calendar
class MoodCalendarLegend extends StatelessWidget {
  const MoodCalendarLegend({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: MoodTheme.spacingMd),
      child: Row(
        children: MoodType.primaryMoods.map((mood) {
          return Padding(
            padding: const EdgeInsets.only(right: MoodTheme.spacingMd),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: MoodTheme.getMoodColor(mood.value),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  mood.label,
                  style: MoodTheme.caption.copyWith(
                    color: MoodTheme.textSecondary,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}
