import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/habit_theme.dart';

/// Horizontal week day selector widget (Mon-Sun)
class WeekSelector extends StatefulWidget {
  final DateTime selectedDate;
  final ValueChanged<DateTime> onDateSelected;
  final DateTime? startDate;

  const WeekSelector({
    super.key,
    required this.selectedDate,
    required this.onDateSelected,
    this.startDate,
  });

  @override
  State<WeekSelector> createState() => _WeekSelectorState();
}

class _WeekSelectorState extends State<WeekSelector> {
  late ScrollController _scrollController;
  late DateTime _weekStart;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _weekStart = _getWeekStart(widget.selectedDate);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  DateTime _getWeekStart(DateTime date) {
    return date.subtract(Duration(days: date.weekday - 1));
  }

  @override
  Widget build(BuildContext context) {
    final days = List.generate(7, (i) => _weekStart.add(Duration(days: i)));
    final today = DateTime.now();

    return SizedBox(
      height: 72,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: days.map((date) {
          final isSelected = _isSameDay(date, widget.selectedDate);
          final isToday = _isSameDay(date, today);
          final isPast = date.isBefore(DateTime(today.year, today.month, today.day));

          return GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              widget.onDateSelected(date);
            },
            child: AnimatedContainer(
              duration: HabitTheme.animationFast,
              width: 44,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    HabitTheme.dayLabelsFull[date.weekday - 1],
                    style: HabitTheme.caption.copyWith(
                      color: isSelected ? HabitTheme.primary : HabitTheme.gray,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                  const SizedBox(height: 8),
                  AnimatedContainer(
                    duration: HabitTheme.animationFast,
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? HabitTheme.primary
                          : isToday
                              ? HabitTheme.primarySoft
                              : Colors.transparent,
                      shape: BoxShape.circle,
                      border: isToday && !isSelected
                          ? Border.all(color: HabitTheme.primary, width: 1.5)
                          : null,
                    ),
                    child: Center(
                      child: Text(
                        date.day.toString(),
                        style: HabitTheme.b2.copyWith(
                          color: isSelected
                              ? HabitTheme.white
                              : isPast
                                  ? HabitTheme.gray
                                  : HabitTheme.dark,
                          fontWeight: isSelected || isToday
                              ? FontWeight.w600
                              : FontWeight.w400,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}

/// Compact day selector pills (M T W T F S S) for habit creation
class DayPillSelector extends StatelessWidget {
  final List<int> selectedDays; // 0-6 for Mon-Sun
  final ValueChanged<List<int>> onChanged;
  final bool enabled;

  const DayPillSelector({
    super.key,
    required this.selectedDays,
    required this.onChanged,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: List.generate(7, (index) {
        final isSelected = selectedDays.contains(index);
        return GestureDetector(
          onTap: enabled
              ? () {
                  HapticFeedback.lightImpact();
                  final newDays = List<int>.from(selectedDays);
                  if (isSelected) {
                    newDays.remove(index);
                  } else {
                    newDays.add(index);
                  }
                  newDays.sort();
                  onChanged(newDays);
                }
              : null,
          child: AnimatedContainer(
            duration: HabitTheme.animationFast,
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: isSelected ? HabitTheme.primary : HabitTheme.grayLight,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                HabitTheme.dayLabelsShort[index],
                style: HabitTheme.b3.copyWith(
                  color: isSelected ? HabitTheme.white : HabitTheme.dark,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}
