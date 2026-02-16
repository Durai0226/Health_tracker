import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../models/cycle_log.dart';
import '../models/symptom_log.dart';
import '../services/period_storage_service.dart';
import '../services/period_prediction_service.dart';
import 'symptom_log_screen.dart';

class PeriodCalendarScreen extends StatefulWidget {
  const PeriodCalendarScreen({super.key});

  @override
  State<PeriodCalendarScreen> createState() => _PeriodCalendarScreenState();
}

class _PeriodCalendarScreenState extends State<PeriodCalendarScreen> {
  DateTime _selectedMonth = DateTime.now();
  DateTime? _selectedDate;
  CycleLog? _currentCycle;
  List<SymptomLog> _symptomLogs = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    setState(() {
      _currentCycle = PeriodStorageService.getCurrentCycle();
      final startOfMonth = DateTime(_selectedMonth.year, _selectedMonth.month, 1);
      final endOfMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0);
      _symptomLogs = PeriodStorageService.getSymptomLogsForDateRange(startOfMonth, endOfMonth);
    });
  }

  void _changeMonth(int delta) {
    setState(() {
      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + delta);
      _loadData();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.periodPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Period Calendar', style: TextStyle(color: AppColors.periodPrimary)),
        actions: [
          IconButton(
            icon: const Icon(Icons.today_rounded, color: AppColors.periodPrimary),
            onPressed: () {
              setState(() {
                _selectedMonth = DateTime.now();
                _selectedDate = DateTime.now();
                _loadData();
              });
            },
          ),
        ],
      ),
      body: Column(
        children: [
          _buildMonthSelector(),
          _buildLegend(),
          Expanded(child: _buildCalendar()),
          if (_selectedDate != null) _buildSelectedDateInfo(),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddOptions,
        backgroundColor: AppColors.periodPrimary,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Log'),
      ),
    );
  }

  Widget _buildMonthSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            onPressed: () => _changeMonth(-1),
            icon: const Icon(Icons.chevron_left_rounded),
            color: AppColors.periodPrimary,
          ),
          Text(
            DateFormat('MMMM yyyy').format(_selectedMonth),
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.periodPrimary,
            ),
          ),
          IconButton(
            onPressed: () => _changeMonth(1),
            icon: const Icon(Icons.chevron_right_rounded),
            color: AppColors.periodPrimary,
          ),
        ],
      ),
    );
  }

  Widget _buildLegend() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Wrap(
        spacing: 16,
        runSpacing: 8,
        children: [
          _legendItem(AppColors.periodHighlight, 'Period'),
          _legendItem(Colors.blue.shade100, 'Fertile'),
          _legendItem(Colors.purple.shade100, 'Ovulation'),
          _legendItem(Colors.orange.shade100, 'PMS'),
          _legendItem(Colors.green.shade100, 'Logged'),
        ],
      ),
    );
  }

  Widget _legendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
      ],
    );
  }

  Widget _buildCalendar() {
    final firstDayOfMonth = DateTime(_selectedMonth.year, _selectedMonth.month, 1);
    final daysInMonth = DateUtils.getDaysInMonth(_selectedMonth.year, _selectedMonth.month);
    final firstWeekday = firstDayOfMonth.weekday % 7;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Weekday headers
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: ['S', 'M', 'T', 'W', 'T', 'F', 'S']
                .map((d) => SizedBox(
                      width: 40,
                      child: Text(
                        d,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ))
                .toList(),
          ),
          const SizedBox(height: 8),
          // Calendar grid
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                childAspectRatio: 1,
              ),
              itemCount: 42,
              itemBuilder: (context, index) {
                if (index < firstWeekday || index >= firstWeekday + daysInMonth) {
                  return const SizedBox();
                }
                final day = index - firstWeekday + 1;
                final date = DateTime(_selectedMonth.year, _selectedMonth.month, day);
                return _buildDayCell(date);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDayCell(DateTime date) {
    final today = DateTime.now();
    final isToday = date.year == today.year && date.month == today.month && date.day == today.day;
    final isSelected = _selectedDate != null &&
        date.year == _selectedDate!.year &&
        date.month == _selectedDate!.month &&
        date.day == _selectedDate!.day;

    // Determine day status
    Color? bgColor;
    bool hasSymptomLog = _symptomLogs.any((l) =>
        l.date.year == date.year && l.date.month == date.month && l.date.day == date.day);

    if (_currentCycle != null) {
      final cycleStart = _currentCycle!.startDate;
      final cycleLength = _currentCycle!.cycleLength;
      final periodDuration = _currentCycle!.periodDuration;

      // Check if on period
      if (date.isAfter(cycleStart.subtract(const Duration(days: 1))) &&
          date.isBefore(cycleStart.add(Duration(days: periodDuration)))) {
        bgColor = AppColors.periodHighlight;
      }
      // Check if in fertile window
      else if (PeriodPredictionService.isInFertileWindow(date, cycleStart, cycleLength)) {
        bgColor = Colors.blue.shade100;
        if (PeriodPredictionService.isOvulationDay(date, cycleStart, cycleLength)) {
          bgColor = Colors.purple.shade100;
        }
      }
      // Check if in PMS window
      else {
        final nextPeriod = PeriodPredictionService.predictNextPeriod(cycleStart, cycleLength);
        final pmsWindow = PeriodPredictionService.predictPMSWindow(nextPeriod);
        if (date.isAfter(pmsWindow['start']!.subtract(const Duration(days: 1))) &&
            date.isBefore(pmsWindow['end']!.add(const Duration(days: 1)))) {
          bgColor = Colors.orange.shade100;
        }
      }
    }

    if (hasSymptomLog && bgColor == null) {
      bgColor = Colors.green.shade100;
    }

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedDate = date;
        });
      },
      child: Container(
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: bgColor ?? (isSelected ? AppColors.periodLight : Colors.transparent),
          shape: BoxShape.circle,
          border: isToday
              ? Border.all(color: AppColors.periodPrimary, width: 2)
              : (isSelected ? Border.all(color: AppColors.periodPrimary, width: 1) : null),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Text(
              '${date.day}',
              style: TextStyle(
                fontWeight: isToday || isSelected ? FontWeight.bold : FontWeight.normal,
                color: isToday ? AppColors.periodPrimary : AppColors.textPrimary,
              ),
            ),
            if (hasSymptomLog)
              Positioned(
                bottom: 4,
                child: Container(
                  width: 4,
                  height: 4,
                  decoration: const BoxDecoration(
                    color: AppColors.periodPrimary,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectedDateInfo() {
    if (_selectedDate == null) return const SizedBox.shrink();

    final symptomLog = _symptomLogs.firstWhere(
      (l) => l.date.year == _selectedDate!.year &&
             l.date.month == _selectedDate!.month &&
             l.date.day == _selectedDate!.day,
      orElse: () => SymptomLog(
        id: 'temp',
        date: _selectedDate!,
      ),
    );

    String phaseText = 'Unknown Phase';
    if (_currentCycle != null) {
      final phase = _currentCycle!.getPhaseForDate(_selectedDate!);
      phaseText = _getPhaseDisplayName(phase);
    }

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                DateFormat('EEEE, MMM d').format(_selectedDate!),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.periodLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  phaseText,
                  style: const TextStyle(
                    color: AppColors.periodPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (symptomLog.symptoms.isNotEmpty || symptomLog.moods.isNotEmpty) ...[
            if (symptomLog.symptoms.isNotEmpty)
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: symptomLog.symptoms.map((s) => Chip(
                  label: Text(_getSymptomDisplayName(s.type)),
                  backgroundColor: AppColors.periodLight,
                  labelStyle: const TextStyle(fontSize: 12),
                  padding: EdgeInsets.zero,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                )).toList(),
              ),
            if (symptomLog.moods.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Wrap(
                  spacing: 8,
                  children: symptomLog.moods.map((m) => Text(
                    _getMoodEmoji(m),
                    style: const TextStyle(fontSize: 20),
                  )).toList(),
                ),
              ),
          ] else
            const Text(
              'No logs for this day',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _navigateToSymptomLog(_selectedDate!),
              icon: const Icon(Icons.edit_rounded),
              label: Text(symptomLog.symptoms.isEmpty ? 'Add Log' : 'Edit Log'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.periodPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(12),
                decoration: const BoxDecoration(
                  color: AppColors.periodLight,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.water_drop_rounded, color: AppColors.periodPrimary),
              ),
              title: const Text('Log Period Start'),
              subtitle: const Text('Start a new cycle'),
              onTap: () {
                Navigator.pop(context);
                _logPeriodStart();
              },
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_circle_outline_rounded, color: Colors.green),
              ),
              title: const Text('Log Period End'),
              subtitle: const Text('End current period'),
              onTap: () {
                Navigator.pop(context);
                _logPeriodEnd();
              },
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.purple.shade50,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.note_add_rounded, color: Colors.purple),
              ),
              title: const Text('Log Symptoms & Mood'),
              subtitle: const Text('Track how you feel'),
              onTap: () {
                Navigator.pop(context);
                _navigateToSymptomLog(_selectedDate ?? DateTime.now());
              },
            ),
          ],
        ),
      ),
    );
  }

  void _logPeriodStart() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now(),
      builder: (context, child) => Theme(
        data: ThemeData.light().copyWith(
          colorScheme: const ColorScheme.light(primary: AppColors.periodPrimary),
        ),
        child: child!,
      ),
    );
    if (date != null) {
      await PeriodStorageService.startNewCycle(date);
      _loadData();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Period started on ${DateFormat('MMM d').format(date)}'),
          backgroundColor: AppColors.periodPrimary,
        ),
      );
    }
  }

  void _logPeriodEnd() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: _currentCycle?.startDate ?? DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now(),
      builder: (context, child) => Theme(
        data: ThemeData.light().copyWith(
          colorScheme: const ColorScheme.light(primary: AppColors.periodPrimary),
        ),
        child: child!,
      ),
    );
    if (date != null) {
      await PeriodStorageService.endCurrentPeriod(date);
      _loadData();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Period ended on ${DateFormat('MMM d').format(date)}'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  void _navigateToSymptomLog(DateTime date) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => SymptomLogScreen(date: date)),
    );
    _loadData();
  }

  String _getPhaseDisplayName(CyclePhase phase) {
    switch (phase) {
      case CyclePhase.menstrual:
        return 'Menstrual';
      case CyclePhase.follicular:
        return 'Follicular';
      case CyclePhase.ovulation:
        return 'Ovulation';
      case CyclePhase.luteal:
        return 'Luteal';
      case CyclePhase.pms:
        return 'PMS';
    }
  }

  String _getSymptomDisplayName(SymptomType type) {
    return type.name.replaceAllMapped(
      RegExp(r'([A-Z])'),
      (match) => ' ${match.group(0)}',
    ).trim();
  }

  String _getMoodEmoji(MoodType mood) {
    switch (mood) {
      case MoodType.happy:
        return '😊';
      case MoodType.calm:
        return '😌';
      case MoodType.energetic:
        return '⚡';
      case MoodType.sensitive:
        return '🥺';
      case MoodType.anxious:
        return '😰';
      case MoodType.irritable:
        return '😤';
      case MoodType.sad:
        return '😢';
      case MoodType.moodSwings:
        return '🎭';
      case MoodType.stressed:
        return '😫';
      case MoodType.tired:
        return '😴';
      case MoodType.focused:
        return '🎯';
      case MoodType.confused:
        return '😕';
    }
  }
}
