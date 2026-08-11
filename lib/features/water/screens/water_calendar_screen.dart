import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:flutter/services.dart';
import '../../../core/design/app_colors_ext.dart';
import '../models/enhanced_water_log.dart';
import '../services/water_service.dart';
import 'water_history_edit_screen.dart';

/// Calendar History Screen - View past water intake by date
class WaterCalendarScreen extends StatefulWidget {
  const WaterCalendarScreen({super.key});

  @override
  State<WaterCalendarScreen> createState() => _WaterCalendarScreenState();
}

class _WaterCalendarScreenState extends State<WaterCalendarScreen> {
  late DateTime _selectedMonth;
  DateTime? _selectedDate;
  DailyWaterData? _selectedDayData;

  @override
  void initState() {
    super.initState();
    _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);
    _selectedDate = DateTime.now();
    _loadSelectedDayData();
  }

  void _loadSelectedDayData() {
    if (_selectedDate != null) {
      _selectedDayData = WaterService.getDataForDate(_selectedDate!);
    }
  }

  void _changeMonth(int delta) {
    setState(() {
      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + delta);
      _selectedDate = null;
      _selectedDayData = null;
    });
  }

  void _selectDate(DateTime date) {
    HapticFeedback.selectionClick();
    setState(() {
      _selectedDate = date;
      _loadSelectedDayData();
    });
  }

  Future<void> _openHistoryEdit() async {
    if (_selectedDate == null) return;
    
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => WaterHistoryEditScreen(date: _selectedDate!),
      ),
    );
    
    if (result == true) {
      _loadSelectedDayData();
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final ext = AppColorsExt.of(context);
    return Scaffold(
      backgroundColor: ext.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Symbols.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('History'),
      ),
      // The month selector + 6-week grid + day details are taller than a
      // 320x568 viewport (and far taller once Dynamic Type is scaled up), so
      // the page scrolls instead of squeezing the details card into whatever
      // is left over.
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildMonthSelector(),
            _buildCalendarGrid(),
            if (_selectedDate != null) _buildDayDetails(),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthSelector() {
    final ext = AppColorsExt.of(context);
    final monthNames = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: ext.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(ext.isDark ? 0.25 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Symbols.chevron_left_rounded),
            onPressed: () => _changeMonth(-1),
          ),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                '${monthNames[_selectedMonth.month - 1]} ${_selectedMonth.year}',
                maxLines: 1,
                softWrap: false,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: ext.textPrimary,
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Symbols.chevron_right_rounded),
            onPressed: _selectedMonth.month == DateTime.now().month &&
                    _selectedMonth.year == DateTime.now().year
                ? null
                : () => _changeMonth(1),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarGrid() {
    final ext = AppColorsExt.of(context);
    final firstDayOfMonth = DateTime(_selectedMonth.year, _selectedMonth.month, 1);
    final lastDayOfMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0);
    final startWeekday = firstDayOfMonth.weekday;
    final daysInMonth = lastDayOfMonth.day;

    // Get data for the month
    final monthData = WaterService.getDataForRange(firstDayOfMonth, lastDayOfMonth);
    final dataMap = <int, DailyWaterData>{};
    for (final day in monthData) {
      dataMap[day.date.day] = day;
    }

    final goal = WaterService.getDailyGoal();
    final dayNames = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ext.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(ext.isDark ? 0.25 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Day names
          Row(
            children: dayNames.map((name) => Expanded(
              child: Center(
                child: Text(
                  name,
                  style: TextStyle(
                    color: ext.textSecondary,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
            )).toList(),
          ),
          const SizedBox(height: 8),
          // Calendar days
          LayoutBuilder(builder: (context, constraints) {
            // A fixed childAspectRatio of 1 pins the row height to the cell
            // width (~36pt on a 320pt phone), which clips the day number once
            // Dynamic Type is scaled up. Derive the row height from the text
            // scaler instead and keep the square cell as the floor, so nothing
            // changes at the default scale.
            final cellWidth = constraints.maxWidth / 7;
            final dayNumberHeight =
                MediaQuery.textScalerOf(context).scale(13) * 1.4 + 8;
            final rowExtent = math.max(cellWidth, dayNumberHeight);

            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                mainAxisExtent: rowExtent,
              ),
              itemCount: 42, // 6 weeks
              itemBuilder: (context, index) {
                final dayOffset = index - (startWeekday - 1);
              
                if (dayOffset < 0 || dayOffset >= daysInMonth) {
                  return const SizedBox.shrink();
                }
              
                final day = dayOffset + 1;
                final date = DateTime(_selectedMonth.year, _selectedMonth.month, day);
                final dayData = dataMap[day];
                final isToday = date.day == DateTime.now().day &&
                    date.month == DateTime.now().month &&
                    date.year == DateTime.now().year;
                final isSelected = _selectedDate != null &&
                    date.day == _selectedDate!.day &&
                    date.month == _selectedDate!.month &&
                    date.year == _selectedDate!.year;
                final isFuture = date.isAfter(DateTime.now());

                // Calculate progress
                double progress = 0;
                if (dayData != null && goal > 0) {
                  progress = dayData.effectiveHydrationMl / goal;
                }

                return GestureDetector(
                  onTap: isFuture ? null : () => _selectDate(date),
                  child: Container(
                    margin: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? ext.water.base
                          : isToday
                              ? ext.water.base.withOpacity(0.12)
                              : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: isToday && !isSelected
                          ? Border.all(color: ext.mark(ext.water), width: 2)
                          : null,
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Progress indicator
                        if (progress > 0 && !isSelected)
                          Positioned.fill(
                            child: Container(
                              margin: const EdgeInsets.all(4),
                              child: CircularProgressIndicator(
                                value: progress.clamp(0.0, 1.0),
                                strokeWidth: 2,
                                backgroundColor: ext.surfaceVariant,
                                valueColor: AlwaysStoppedAnimation(
                                  progress >= 1 ? ext.success.base : ext.water.base,
                                ),
                              ),
                            ),
                          ),
                        // Day number — scaleDown only ever shrinks, so the
                        // default rendering is untouched; it stops a 2-digit
                        // day from spilling out of a narrow cell at 200% text.
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            '$day',
                            maxLines: 1,
                            softWrap: false,
                            style: TextStyle(
                              color: isSelected
                                  ? ext.fillFg(ext.water)
                                  : isFuture
                                      ? ext.textSecondary.withOpacity(0.4)
                                      : ext.textPrimary,
                              fontWeight: isToday || isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        // Goal met indicator
                        if (progress >= 1 && !isSelected)
                          Positioned(
                            bottom: 2,
                            child: Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: ext.success.base,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            );
          }),
          // Legend — a Wrap, not a Row: at 200% text the two labels together
          // are wider than a 320pt card, so they drop onto separate lines
          // instead of overflowing. The 16pt spacing matches the old gap, so
          // the single-line default rendering is unchanged.
          const SizedBox(height: 12),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 16,
            runSpacing: 8,
            children: [
              _buildLegendItem(
                dot: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: ext.success.base,
                    shape: BoxShape.circle,
                  ),
                ),
                label: 'Goal met',
              ),
              _buildLegendItem(
                dot: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    border: Border.all(color: ext.mark(ext.water), width: 2),
                    shape: BoxShape.circle,
                  ),
                ),
                label: 'Today',
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// One legend entry: swatch + label. The label is Flexible so a long
  /// translation wraps inside the card rather than overflowing it.
  Widget _buildLegendItem({required Widget dot, required String label}) {
    final ext = AppColorsExt.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        dot,
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 11, color: ext.textSecondary),
          ),
        ),
      ],
    );
  }

  Widget _buildDayDetails() {
    if (_selectedDayData == null) {
      return _buildEmptyDayDetails();
    }

    final ext = AppColorsExt.of(context);
    final data = _selectedDayData!;
    final goal = WaterService.getDailyGoal();
    final progress = goal > 0 ? data.effectiveHydrationMl / goal : 0.0;

    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ext.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(ext.isDark ? 0.25 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: progress >= 1
                  ? ext.success.base.withOpacity(0.12)
                  : ext.water.base.withOpacity(0.12),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: progress >= 1 ? ext.success.base : ext.water.base,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    progress >= 1 ? Symbols.check_rounded : Symbols.water_drop_rounded,
                    color: progress >= 1 ? ext.success.on : ext.water.on,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _formatDate(_selectedDate!),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: ext.textPrimary,
                        ),
                      ),
                      Text(
                        progress >= 1 ? 'Goal Achieved!' : '${(progress * 100).toInt()}% of goal',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: progress >= 1 ? ext.mark(ext.success) : ext.mark(ext.water),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Flexible + scaleDown: unchanged at normal sizes, shrinks
                // instead of pushing the edit button off a 320pt screen.
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: Text(
                          '${data.effectiveHydrationMl}ml',
                          maxLines: 1,
                          softWrap: false,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: ext.textPrimary,
                          ),
                        ),
                      ),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: Text(
                          'of ${goal}ml',
                          maxLines: 1,
                          softWrap: false,
                          style: TextStyle(
                            color: ext.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: Icon(Symbols.edit_rounded, color: ext.mark(ext.water)),
                  onPressed: () => _openHistoryEdit(),
                  tooltip: 'Edit',
                ),
              ],
            ),
          ),
          // Stats row
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                _buildDayStatItem(
                  icon: Symbols.local_drink_rounded,
                  value: '${data.drinksCount}',
                  label: 'Drinks',
                  color: ext.mark(ext.water),
                ),
                _buildDayStatItem(
                  icon: Symbols.coffee_rounded,
                  value: '${data.totalCaffeineMg}mg',
                  label: 'Caffeine',
                  color: Colors.brown,
                ),
                _buildDayStatItem(
                  icon: Symbols.wine_bar_rounded,
                  value: '${data.alcoholicDrinksCount}',
                  label: 'Alcohol',
                  color: Colors.purple,
                ),
              ],
            ),
          ),
          // Logs list — sized by its content because the whole page scrolls.
          if (data.logs.isEmpty)
            ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 120),
              child: Center(
                child: Text(
                  'No drinks logged',
                  style: TextStyle(color: ext.textSecondary),
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  for (final log in data.logs.reversed) _buildLogItem(log),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyDayDetails() {
    final ext = AppColorsExt.of(context);
    return Container(
      // Without an explicit width this Container sized to its widest child
      // inside the page Column, so the empty state rendered visibly narrower
      // than the month and calendar cards above it — it read as a layout bug.
      width: double.infinity,
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: ext.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Symbols.water_drop_rounded,
            size: 64,
            color: ext.textSecondary.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'No data for this day',
            style: TextStyle(
              color: ext.textSecondary,
              fontSize: 16,
            ),
          ),
          if (_selectedDate != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _formatDate(_selectedDate!),
                style: TextStyle(
                  color: ext.textSecondary.withOpacity(0.7),
                  fontSize: 14,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDayStatItem({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    final ext = AppColorsExt.of(context);
    return Expanded(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(ext.isDark ? 0.18 : 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: ext.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogItem(EnhancedWaterLog log) {
    final ext = AppColorsExt.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ext.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Text(log.beverageEmoji, style: const TextStyle(fontSize: 24)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  log.beverageName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontWeight: FontWeight.w500, color: ext.textPrimary),
                ),
                Text(
                  '${log.time.hour.toString().padLeft(2, '0')}:${log.time.minute.toString().padLeft(2, '0')}',
                  style: TextStyle(
                    fontSize: 12,
                    color: ext.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Text(
                    '+${log.amountMl}ml',
                    maxLines: 1,
                    softWrap: false,
                    style: TextStyle(fontWeight: FontWeight.bold, color: ext.textPrimary),
                  ),
                ),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Text(
                    'Hydration: ${log.effectiveHydrationMl}ml',
                    maxLines: 1,
                    softWrap: false,
                    style: TextStyle(
                      fontSize: 10,
                      color: log.effectiveHydrationMl >= 0
                          ? ext.mark(ext.success)
                          : ext.mark(ext.error),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final dayNames = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    final monthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    
    return '${dayNames[date.weekday - 1]}, ${monthNames[date.month - 1]} ${date.day}';
  }
}
