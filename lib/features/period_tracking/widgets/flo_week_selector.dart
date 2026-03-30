import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../theme/flo_theme.dart';

/// Horizontal week selector with "Today" highlight
/// Matches the Flo design from the Behance case study
class FloWeekSelector extends StatefulWidget {
  final DateTime selectedDate;
  final DateTime? periodStartDate;
  final int cycleLength;
  final int periodDuration;
  final ValueChanged<DateTime>? onDateSelected;
  final Map<String, DateTime>? fertileWindow;

  const FloWeekSelector({
    super.key,
    required this.selectedDate,
    this.periodStartDate,
    this.cycleLength = 28,
    this.periodDuration = 5,
    this.onDateSelected,
    this.fertileWindow,
  });

  @override
  State<FloWeekSelector> createState() => _FloWeekSelectorState();
}

class _FloWeekSelectorState extends State<FloWeekSelector> {
  late ScrollController _scrollController;
  late List<DateTime> _weekDays;
  final double _itemWidth = 48;
  final double _spacing = 8;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _generateWeekDays();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToToday());
  }

  void _generateWeekDays() {
    final today = DateTime.now();
    final startOfWeek = today.subtract(Duration(days: today.weekday % 7));
    
    _weekDays = List.generate(7, (index) {
      return startOfWeek.add(Duration(days: index));
    });
  }

  void _scrollToToday() {
    final today = DateTime.now();
    final todayIndex = _weekDays.indexWhere((d) =>
        d.year == today.year && d.month == today.month && d.day == today.day);
    
    if (todayIndex >= 0 && _scrollController.hasClients) {
      final offset = (todayIndex * (_itemWidth + _spacing)) -
          (MediaQuery.of(context).size.width / 2 - _itemWidth / 2);
      _scrollController.animateTo(
        offset.clamp(0, _scrollController.position.maxScrollExtent),
        duration: FloTheme.animNormal,
        curve: Curves.easeOutCubic,
      );
    }
  }

  bool _isOnPeriod(DateTime date) {
    if (widget.periodStartDate == null) return false;
    final daysSincePeriod = date.difference(widget.periodStartDate!).inDays;
    return daysSincePeriod >= 0 && daysSincePeriod < widget.periodDuration;
  }

  bool _isFertile(DateTime date) {
    if (widget.fertileWindow == null) return false;
    final start = widget.fertileWindow!['start'];
    final end = widget.fertileWindow!['end'];
    if (start == null || end == null) return false;
    return date.isAfter(start.subtract(const Duration(days: 1))) &&
        date.isBefore(end.add(const Duration(days: 1)));
  }

  bool _isOvulation(DateTime date) {
    if (widget.fertileWindow == null) return false;
    final ovulation = widget.fertileWindow!['ovulation'];
    if (ovulation == null) return false;
    return date.year == ovulation.year &&
        date.month == ovulation.month &&
        date.day == ovulation.day;
  }

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Date header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: FloTheme.spacingLg),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                DateFormat('d MMMM, yyyy').format(widget.selectedDate),
                style: FloTheme.bodyMedium.copyWith(
                  color: FloTheme.getTextSecondary(context),
                ),
              ),
              // Week toggle badge (optional)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: FloTheme.spacingMd,
                  vertical: FloTheme.spacingXs,
                ),
                decoration: BoxDecoration(
                  color: FloTheme.periodPink.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(FloTheme.radiusFull),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.calendar_today_rounded,
                      size: 14,
                      color: FloTheme.periodPink,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        
        const SizedBox(height: FloTheme.spacingMd),

        // Week days row
        SizedBox(
          height: 80,
          child: ListView.builder(
            controller: _scrollController,
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: FloTheme.spacingLg),
            itemCount: _weekDays.length,
            itemBuilder: (context, index) {
              final date = _weekDays[index];
              final isToday = date.year == today.year &&
                  date.month == today.month &&
                  date.day == today.day;
              final isSelected = date.year == widget.selectedDate.year &&
                  date.month == widget.selectedDate.month &&
                  date.day == widget.selectedDate.day;
              final isOnPeriod = _isOnPeriod(date);
              final isFertile = _isFertile(date);
              final isOvulation = _isOvulation(date);

              return Padding(
                padding: EdgeInsets.only(right: index < 6 ? _spacing : 0),
                child: _DayItem(
                  date: date,
                  isToday: isToday,
                  isSelected: isSelected,
                  isOnPeriod: isOnPeriod,
                  isFertile: isFertile,
                  isOvulation: isOvulation,
                  width: _itemWidth,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    widget.onDateSelected?.call(date);
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }
}

class _DayItem extends StatelessWidget {
  final DateTime date;
  final bool isToday;
  final bool isSelected;
  final bool isOnPeriod;
  final bool isFertile;
  final bool isOvulation;
  final double width;
  final VoidCallback onTap;

  const _DayItem({
    required this.date,
    required this.isToday,
    required this.isSelected,
    required this.isOnPeriod,
    required this.isFertile,
    required this.isOvulation,
    required this.width,
    required this.onTap,
  });

  Color _getBackgroundColor(BuildContext context) {
    if (isSelected || isToday) {
      if (isOnPeriod) return FloTheme.periodPink;
      if (isOvulation) return FloTheme.ovulationBlue;
      if (isFertile) return FloTheme.ovulationBlue.withOpacity(0.5);
      return FloTheme.periodPink;
    }
    if (isOnPeriod) return FloTheme.periodPinkLight;
    if (isOvulation) return FloTheme.ovulationBlue.withOpacity(0.3);
    if (isFertile) return FloTheme.ovulationBlue.withOpacity(0.1);
    return Colors.transparent;
  }

  Color _getTextColor(BuildContext context) {
    if (isSelected || isToday) return Colors.white;
    if (isOnPeriod) return FloTheme.periodPink;
    if (isFertile || isOvulation) return FloTheme.ovulationBlueDark;
    return FloTheme.getTextPrimary(context);
  }

  @override
  Widget build(BuildContext context) {
    final dayName = DateFormat('E').format(date)[0];
    final bgColor = _getBackgroundColor(context);
    final textColor = _getTextColor(context);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: FloTheme.animFast,
        width: width,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(FloTheme.radiusMd),
          border: isToday && !isSelected
              ? Border.all(color: FloTheme.periodPink, width: 2)
              : null,
          boxShadow: (isSelected || isToday) ? FloTheme.shadowSm : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Day name
            Text(
              dayName,
              style: FloTheme.labelSmall.copyWith(
                color: textColor.withOpacity(0.7),
              ),
            ),
            
            const SizedBox(height: 4),
            
            // Day number
            if (isToday && !isSelected)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: FloTheme.periodPink,
                  borderRadius: BorderRadius.circular(FloTheme.radiusSm),
                ),
                child: Text(
                  'Today',
                  style: FloTheme.labelSmall.copyWith(
                    color: Colors.white,
                    fontSize: 9,
                  ),
                ),
              )
            else
              Text(
                '${date.day}',
                style: FloTheme.headlineMedium.copyWith(
                  color: textColor,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                ),
              ),
            
            // Indicator dot
            if (isOnPeriod || isFertile || isOvulation)
              Container(
                margin: const EdgeInsets.only(top: 4),
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isOnPeriod
                      ? (isSelected ? Colors.white : FloTheme.periodPink)
                      : (isSelected ? Colors.white : FloTheme.ovulationBlue),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Extended month calendar view
class FloMonthCalendar extends StatefulWidget {
  final DateTime selectedDate;
  final DateTime? periodStartDate;
  final int cycleLength;
  final int periodDuration;
  final ValueChanged<DateTime>? onDateSelected;
  final Map<String, DateTime>? fertileWindow;

  const FloMonthCalendar({
    super.key,
    required this.selectedDate,
    this.periodStartDate,
    this.cycleLength = 28,
    this.periodDuration = 5,
    this.onDateSelected,
    this.fertileWindow,
  });

  @override
  State<FloMonthCalendar> createState() => _FloMonthCalendarState();
}

class _FloMonthCalendarState extends State<FloMonthCalendar> {
  late DateTime _currentMonth;

  @override
  void initState() {
    super.initState();
    _currentMonth = DateTime(widget.selectedDate.year, widget.selectedDate.month, 1);
  }

  void _previousMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1, 1);
    });
  }

  void _nextMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 1);
    });
  }

  bool _isOnPeriod(DateTime date) {
    if (widget.periodStartDate == null) return false;
    final daysSincePeriod = date.difference(widget.periodStartDate!).inDays;
    final cycleDay = daysSincePeriod % widget.cycleLength;
    return cycleDay >= 0 && cycleDay < widget.periodDuration;
  }

  bool _isFertile(DateTime date) {
    if (widget.fertileWindow == null) return false;
    final start = widget.fertileWindow!['start'];
    final end = widget.fertileWindow!['end'];
    if (start == null || end == null) return false;
    return date.isAfter(start.subtract(const Duration(days: 1))) &&
        date.isBefore(end.add(const Duration(days: 1)));
  }

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final daysInMonth = DateUtils.getDaysInMonth(_currentMonth.year, _currentMonth.month);
    final firstDayOfMonth = DateTime(_currentMonth.year, _currentMonth.month, 1);
    final startingWeekday = firstDayOfMonth.weekday % 7;

    return Column(
      children: [
        // Month header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: FloTheme.spacingLg),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                onPressed: _previousMonth,
                icon: const Icon(Icons.chevron_left_rounded),
                color: FloTheme.getTextPrimary(context),
              ),
              Text(
                DateFormat('MMMM yyyy').format(_currentMonth),
                style: FloTheme.headlineMedium.copyWith(
                  color: FloTheme.getTextPrimary(context),
                ),
              ),
              IconButton(
                onPressed: _nextMonth,
                icon: const Icon(Icons.chevron_right_rounded),
                color: FloTheme.getTextPrimary(context),
              ),
            ],
          ),
        ),

        // Weekday headers
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: FloTheme.spacingLg,
            vertical: FloTheme.spacingSm,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: ['S', 'M', 'T', 'W', 'T', 'F', 'S']
                .map((d) => SizedBox(
                      width: 36,
                      child: Text(
                        d,
                        textAlign: TextAlign.center,
                        style: FloTheme.labelSmall.copyWith(
                          color: FloTheme.getTextSecondary(context),
                        ),
                      ),
                    ))
                .toList(),
          ),
        ),

        // Calendar grid
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: FloTheme.spacingLg),
          child: Wrap(
            spacing: 4,
            runSpacing: 8,
            children: List.generate(daysInMonth + startingWeekday, (index) {
              if (index < startingWeekday) {
                return const SizedBox(width: 36, height: 36);
              }

              final day = index - startingWeekday + 1;
              final date = DateTime(_currentMonth.year, _currentMonth.month, day);
              final isToday = date.year == today.year &&
                  date.month == today.month &&
                  date.day == today.day;
              final isSelected = date.year == widget.selectedDate.year &&
                  date.month == widget.selectedDate.month &&
                  date.day == widget.selectedDate.day;
              final isOnPeriod = _isOnPeriod(date);
              final isFertile = _isFertile(date);

              Color? bgColor;
              if (isSelected) {
                bgColor = FloTheme.periodPink;
              } else if (isOnPeriod) {
                bgColor = FloTheme.periodPinkLight;
              } else if (isFertile) {
                bgColor = FloTheme.ovulationBlue.withOpacity(0.2);
              }

              return GestureDetector(
                onTap: () => widget.onDateSelected?.call(date),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: bgColor,
                    shape: BoxShape.circle,
                    border: isToday && !isSelected
                        ? Border.all(color: FloTheme.periodPink, width: 2)
                        : null,
                  ),
                  child: Center(
                    child: Text(
                      '$day',
                      style: FloTheme.bodyMedium.copyWith(
                        fontWeight: isToday || isSelected
                            ? FontWeight.bold
                            : FontWeight.normal,
                        color: isSelected
                            ? Colors.white
                            : isOnPeriod
                                ? FloTheme.periodPink
                                : FloTheme.getTextPrimary(context),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),

        // Legend
        Padding(
          padding: const EdgeInsets.all(FloTheme.spacingLg),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _LegendItem(
                color: FloTheme.periodPink,
                label: 'Period phase',
              ),
              const SizedBox(width: FloTheme.spacingXl),
              _LegendItem(
                color: FloTheme.ovulationBlue,
                label: 'Fertile window',
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendItem({
    required this.color,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: FloTheme.bodySmall.copyWith(
            color: FloTheme.getTextSecondary(context),
          ),
        ),
      ],
    );
  }
}
