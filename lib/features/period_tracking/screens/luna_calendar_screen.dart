import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/luna_theme.dart';
import '../widgets/luna_widgets.dart';
import '../services/period_storage_service.dart';

/// Calendar screen for Luna Cycle
class LunaCalendarScreen extends StatefulWidget {
  const LunaCalendarScreen({super.key});

  @override
  State<LunaCalendarScreen> createState() => _LunaCalendarScreenState();
}

class _LunaCalendarScreenState extends State<LunaCalendarScreen> {
  DateTime _focusedMonth = DateTime.now();
  DateTime? _selectedDate;
  Set<DateTime> _periodDates = {};
  Set<DateTime> _fertileDates = {};
  Set<DateTime> _predictedPeriodDates = {};

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
    _loadCycleData();
  }

  void _loadCycleData() {
    final cycles = PeriodCleanStorageService.getAllCycles();
    final settings = PeriodCleanStorageService.getSettings();

    _periodDates = {};
    _fertileDates = {};
    _predictedPeriodDates = {};

    for (final cycle in cycles) {
      // Add period dates
      for (int i = 0; i < (cycle.endDate?.difference(cycle.startDate).inDays ?? settings.defaultPeriodDuration); i++) {
        _periodDates.add(DateTime(
          cycle.startDate.year,
          cycle.startDate.month,
          cycle.startDate.day + i,
        ));
      }

      // Calculate fertile window (typically days 10-17 of cycle)
      for (int i = 10; i <= 17; i++) {
        final fertileDate = cycle.startDate.add(Duration(days: i));
        _fertileDates.add(DateTime(
          fertileDate.year,
          fertileDate.month,
          fertileDate.day,
        ));
      }
    }

    // Add predicted period dates
    if (cycles.isNotEmpty) {
      final lastCycle = cycles.first;
      final nextPeriod = lastCycle.startDate.add(Duration(days: settings.defaultCycleLength));
      for (int i = 0; i < settings.defaultPeriodDuration; i++) {
        final predictedDate = nextPeriod.add(Duration(days: i));
        _predictedPeriodDates.add(DateTime(
          predictedDate.year,
          predictedDate.month,
          predictedDate.day,
        ));
      }
    }

    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LunaTheme.getBackground(context),
      appBar: LunaAppBar(
        title: 'Calendar',
        actions: [
          IconButton(
            icon: Icon(
              Icons.today,
              color: LunaTheme.primaryPink,
            ),
            onPressed: () {
              setState(() {
                _focusedMonth = DateTime.now();
                _selectedDate = DateTime.now();
              });
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Month navigation
          _buildMonthHeader(),
          
          // Weekday headers
          _buildWeekdayHeaders(),
          
          // Calendar grid
          Expanded(
            child: _buildCalendarGrid(),
          ),
          
          // Legend
          _buildLegend(),
          
          // Selected date info
          if (_selectedDate != null)
            _buildSelectedDateInfo(),
        ],
      ),
    );
  }

  Widget _buildMonthHeader() {
    return Padding(
      padding: const EdgeInsets.all(LunaTheme.spacingLg),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () {
              setState(() {
                _focusedMonth = DateTime(
                  _focusedMonth.year,
                  _focusedMonth.month - 1,
                );
              });
            },
          ),
          Text(
            _getMonthYearString(_focusedMonth),
            style: LunaTheme.headlineMedium.copyWith(
              color: LunaTheme.getTextPrimary(context),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: () {
              setState(() {
                _focusedMonth = DateTime(
                  _focusedMonth.year,
                  _focusedMonth.month + 1,
                );
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildWeekdayHeaders() {
    const weekdays = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: LunaTheme.spacingLg),
      child: Row(
        children: weekdays.map((day) {
          return Expanded(
            child: Center(
              child: Text(
                day,
                style: LunaTheme.labelMedium.copyWith(
                  color: LunaTheme.getTextSecondary(context),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildCalendarGrid() {
    final firstDayOfMonth = DateTime(_focusedMonth.year, _focusedMonth.month, 1);
    final lastDayOfMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1, 0);
    final startWeekday = firstDayOfMonth.weekday % 7;
    final daysInMonth = lastDayOfMonth.day;

    final days = <Widget>[];

    // Empty cells for days before the first of the month
    for (int i = 0; i < startWeekday; i++) {
      days.add(const SizedBox());
    }

    // Days of the month
    for (int day = 1; day <= daysInMonth; day++) {
      final date = DateTime(_focusedMonth.year, _focusedMonth.month, day);
      days.add(_buildDayCell(date));
    }

    return GridView.count(
      crossAxisCount: 7,
      padding: const EdgeInsets.all(LunaTheme.spacingLg),
      mainAxisSpacing: LunaTheme.spacingSm,
      crossAxisSpacing: LunaTheme.spacingSm,
      children: days,
    );
  }

  Widget _buildDayCell(DateTime date) {
    final normalizedDate = DateTime(date.year, date.month, date.day);
    final isToday = _isSameDay(date, DateTime.now());
    final isSelected = _selectedDate != null && _isSameDay(date, _selectedDate!);
    final isPeriod = _periodDates.contains(normalizedDate);
    final isFertile = _fertileDates.contains(normalizedDate);
    final isPredicted = _predictedPeriodDates.contains(normalizedDate);

    Color? backgroundColor;
    Color textColor = LunaTheme.getTextPrimary(context);

    if (isPeriod) {
      backgroundColor = LunaTheme.primaryPink;
      textColor = Colors.white;
    } else if (isPredicted) {
      backgroundColor = LunaTheme.primaryPink.withOpacity(0.3);
    } else if (isFertile) {
      backgroundColor = LunaTheme.ovulationBlue.withOpacity(0.3);
    }

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _selectedDate = date);
      },
      child: Container(
        decoration: BoxDecoration(
          color: backgroundColor,
          shape: BoxShape.circle,
          border: isSelected
              ? Border.all(color: LunaTheme.primaryPink, width: 2)
              : isToday
                  ? Border.all(color: LunaTheme.primaryPink.withOpacity(0.5), width: 1)
                  : null,
        ),
        child: Center(
          child: Text(
            '${date.day}',
            style: LunaTheme.titleMedium.copyWith(
              color: textColor,
              fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLegend() {
    return Padding(
      padding: const EdgeInsets.all(LunaTheme.spacingLg),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildLegendItem('Period', LunaTheme.primaryPink),
          const SizedBox(width: LunaTheme.spacingLg),
          _buildLegendItem('Predicted', LunaTheme.primaryPink.withOpacity(0.3)),
          const SizedBox(width: LunaTheme.spacingLg),
          _buildLegendItem('Fertile', LunaTheme.ovulationBlue.withOpacity(0.3)),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: LunaTheme.spacingXs),
        Text(
          label,
          style: LunaTheme.labelSmall.copyWith(
            color: LunaTheme.getTextSecondary(context),
          ),
        ),
      ],
    );
  }

  Widget _buildSelectedDateInfo() {
    final normalizedDate = DateTime(
      _selectedDate!.year,
      _selectedDate!.month,
      _selectedDate!.day,
    );
    
    String status = 'No data';
    Color statusColor = LunaTheme.getTextSecondary(context);

    if (_periodDates.contains(normalizedDate)) {
      status = 'Period day';
      statusColor = LunaTheme.primaryPink;
    } else if (_predictedPeriodDates.contains(normalizedDate)) {
      status = 'Predicted period';
      statusColor = LunaTheme.primaryPink;
    } else if (_fertileDates.contains(normalizedDate)) {
      status = 'Fertile window';
      statusColor = LunaTheme.ovulationBlue;
    }

    return Container(
      margin: const EdgeInsets.all(LunaTheme.spacingLg),
      padding: const EdgeInsets.all(LunaTheme.spacingLg),
      decoration: BoxDecoration(
        color: LunaTheme.getSurface(context),
        borderRadius: BorderRadius.circular(LunaTheme.radiusLg),
        boxShadow: LunaTheme.shadowSm,
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _formatDate(_selectedDate!),
                style: LunaTheme.titleLarge.copyWith(
                  color: LunaTheme.getTextPrimary(context),
                ),
              ),
              Text(
                status,
                style: LunaTheme.bodyMedium.copyWith(color: statusColor),
              ),
            ],
          ),
          const Spacer(),
          ElevatedButton(
            onPressed: () {
              // Log for this date
            },
            child: const Text('Log'),
          ),
        ],
      ),
    );
  }

  String _getMonthYearString(DateTime date) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return '${months[date.month - 1]} ${date.year}';
  }

  String _formatDate(DateTime date) {
    const weekdays = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${weekdays[date.weekday % 7]}, ${months[date.month - 1]} ${date.day}';
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}
