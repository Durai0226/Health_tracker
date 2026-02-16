import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/constants/app_colors.dart';
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
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('History'),
      ),
      body: Column(
        children: [
          _buildMonthSelector(),
          _buildCalendarGrid(),
          if (_selectedDate != null) Expanded(child: _buildDayDetails()),
        ],
      ),
    );
  }

  Widget _buildMonthSelector() {
    final monthNames = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () => _changeMonth(-1),
          ),
          Text(
            '${monthNames[_selectedMonth.month - 1]} ${_selectedMonth.year}',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
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
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
            )).toList(),
          ),
          const SizedBox(height: 8),
          // Calendar days
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              childAspectRatio: 1,
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
                        ? AppColors.info
                        : isToday
                            ? AppColors.info.withOpacity(0.1)
                            : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    border: isToday && !isSelected
                        ? Border.all(color: AppColors.info, width: 2)
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
                              backgroundColor: Colors.grey.shade200,
                              valueColor: AlwaysStoppedAnimation(
                                progress >= 1 ? AppColors.success : AppColors.info,
                              ),
                            ),
                          ),
                        ),
                      // Day number
                      Text(
                        '$day',
                        style: TextStyle(
                          color: isSelected
                              ? Colors.white
                              : isFuture
                                  ? AppColors.textSecondary.withOpacity(0.4)
                                  : AppColors.textPrimary,
                          fontWeight: isToday || isSelected
                              ? FontWeight.bold
                              : FontWeight.normal,
                          fontSize: 13,
                        ),
                      ),
                      // Goal met indicator
                      if (progress >= 1 && !isSelected)
                        Positioned(
                          bottom: 2,
                          child: Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: AppColors.success,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
          // Legend
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  color: AppColors.success,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 4),
              const Text(
                'Goal met',
                style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
              ),
              const SizedBox(width: 16),
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.info, width: 2),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 4),
              const Text(
                'Today',
                style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDayDetails() {
    if (_selectedDayData == null) {
      return _buildEmptyDayDetails();
    }

    final data = _selectedDayData!;
    final goal = WaterService.getDailyGoal();
    final progress = goal > 0 ? data.effectiveHydrationMl / goal : 0.0;

    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
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
                  ? AppColors.success.withOpacity(0.1)
                  : AppColors.info.withOpacity(0.1),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: progress >= 1 ? AppColors.success : AppColors.info,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    progress >= 1 ? Icons.check : Icons.water_drop,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _formatDate(_selectedDate!),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        progress >= 1 ? 'Goal Achieved!' : '${(progress * 100).toInt()}% of goal',
                        style: TextStyle(
                          color: progress >= 1 ? AppColors.success : AppColors.info,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${data.effectiveHydrationMl}ml',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'of ${goal}ml',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.edit_outlined, color: AppColors.info),
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
                  icon: Icons.local_drink,
                  value: '${data.drinksCount}',
                  label: 'Drinks',
                  color: AppColors.info,
                ),
                _buildDayStatItem(
                  icon: Icons.coffee,
                  value: '${data.totalCaffeineMg}mg',
                  label: 'Caffeine',
                  color: Colors.brown,
                ),
                _buildDayStatItem(
                  icon: Icons.wine_bar,
                  value: '${data.alcoholicDrinksCount}',
                  label: 'Alcohol',
                  color: Colors.purple,
                ),
              ],
            ),
          ),
          // Logs list
          Expanded(
            child: data.logs.isEmpty
                ? const Center(
                    child: Text(
                      'No drinks logged',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: data.logs.length,
                    itemBuilder: (context, index) {
                      final log = data.logs.reversed.toList()[index];
                      return _buildLogItem(log);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyDayDetails() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.water_drop_outlined,
            size: 64,
            color: AppColors.textSecondary.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          const Text(
            'No data for this day',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 16,
            ),
          ),
          if (_selectedDate != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _formatDate(_selectedDate!),
                style: TextStyle(
                  color: AppColors.textSecondary.withOpacity(0.7),
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
    return Expanded(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
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
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogItem(EnhancedWaterLog log) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
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
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                Text(
                  '${log.time.hour.toString().padLeft(2, '0')}:${log.time.minute.toString().padLeft(2, '0')}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '+${log.amountMl}ml',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(
                'Hydration: ${log.effectiveHydrationMl}ml',
                style: TextStyle(
                  fontSize: 10,
                  color: log.effectiveHydrationMl >= 0
                      ? AppColors.success
                      : AppColors.error,
                ),
              ),
            ],
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
