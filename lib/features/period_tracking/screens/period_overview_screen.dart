
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/storage_service.dart';
import '../models/period_data.dart';
import '../models/cycle_log.dart';
import '../services/period_storage_service.dart';
import '../services/period_prediction_service.dart';
import '../services/period_health_tips_service.dart';
import 'package:intl/intl.dart';
import 'period_calendar_screen.dart';
import 'period_statistics_screen.dart';
import 'period_insights_screen.dart';
import 'period_settings_screen.dart';
import 'symptom_log_screen.dart';

class PeriodOverviewScreen extends StatefulWidget {
  const PeriodOverviewScreen({super.key});

  @override
  State<PeriodOverviewScreen> createState() => _PeriodOverviewScreenState();
}

class _PeriodOverviewScreenState extends State<PeriodOverviewScreen> {
  PeriodData? _periodData;
  CyclePhase _currentPhase = CyclePhase.follicular;
  int _cycleDay = 1;
  HealthTip? _dailyTip;
  Map<String, DateTime>? _fertileWindow;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    final periodData = StorageService.getPeriodData();
    
    if (periodData != null) {
      final today = DateTime.now();
      final cycleDay = PeriodPredictionService.getCurrentCycleDay(periodData.lastPeriodDate, today);
      final phase = PeriodPredictionService.getCurrentPhase(
        periodData.lastPeriodDate,
        periodData.cycleLength,
        periodData.periodDuration,
        today,
      );
      final fertileWindow = PeriodPredictionService.predictFertileWindow(
        periodData.lastPeriodDate,
        periodData.cycleLength,
      );
      final dailyTip = PeriodHealthTipsService.getDailyTip(phase, cycleDay);

      setState(() {
        _periodData = periodData;
        _cycleDay = cycleDay;
        _currentPhase = phase;
        _fertileWindow = fertileWindow;
        _dailyTip = dailyTip;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_periodData == null) {
      return const Scaffold(
        body: Center(child: Text("No period data found.")),
      );
    }

    final today = DateTime.now();
    final daysUntil = _periodData!.daysUntilNextPeriod(today);
    final isOnPeriod = _periodData!.isOnPeriod(today);

    final periodAccent = AppColors.getPeriodAccent(context);
    
    return Scaffold(
      backgroundColor: AppColors.getBackground(context),
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: periodAccent),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text("Period Tracker", style: TextStyle(color: periodAccent)),
        actions: [
          IconButton(
            icon: Icon(Icons.settings_rounded, color: periodAccent),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const PeriodSettingsScreen()),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Status Card with Phase Info
            _buildStatusCard(isOnPeriod, daysUntil),
            const SizedBox(height: 16),
            // Quick Actions
            _buildQuickActions(),
            const SizedBox(height: 16),
            // Daily Tip Card
            if (_dailyTip != null) _buildDailyTipCard(),
            const SizedBox(height: 16),
            // Cycle Info
            _buildCycleInfo(),
            const SizedBox(height: 16),
            // Upcoming Events
            _buildUpcomingEvents(),
            const SizedBox(height: 16),
            // Mini Calendar
            _buildMiniCalendar(_periodData!, today),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showQuickLogSheet(),
        backgroundColor: AppColors.periodPrimary,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Log'),
      ),
    );
  }

  Widget _buildStatusCard(bool isOnPeriod, int daysUntil) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: AppColors.periodGradient,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.periodPrimary.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Day $_cycleDay',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withOpacity(0.8),
                    ),
                  ),
                  Text(
                    _getPhaseDisplayName(_currentPhase),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isOnPeriod ? Icons.water_drop_rounded : _getPhaseIcon(_currentPhase),
                  size: 28,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  isOnPeriod ? "You're on your period" : "Period in ",
                  style: const TextStyle(fontSize: 16, color: Colors.white),
                ),
                if (!isOnPeriod)
                  Text(
                    "$daysUntil days",
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Phase Progress
          _buildPhaseProgress(),
        ],
      ),
    );
  }

  Widget _buildPhaseProgress() {
    const phases = CyclePhase.values;
    final currentIndex = phases.indexOf(_currentPhase);

    return Row(
      children: List.generate(phases.length, (index) {
        final isActive = index <= currentIndex;
        return Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 2),
            height: 4,
            decoration: BoxDecoration(
              color: isActive ? Colors.white : Colors.white.withOpacity(0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildQuickActions() {
    return Row(
      children: [
        Expanded(child: _buildActionCard(
          'Calendar',
          Icons.calendar_month_rounded,
          Colors.blue,
          () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PeriodCalendarScreen())),
        )),
        const SizedBox(width: 12),
        Expanded(child: _buildActionCard(
          'Insights',
          Icons.insights_rounded,
          Colors.purple,
          () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PeriodInsightsScreen())),
        )),
        const SizedBox(width: 12),
        Expanded(child: _buildActionCard(
          'Statistics',
          Icons.analytics_rounded,
          Colors.orange,
          () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PeriodStatisticsScreen())),
        )),
      ],
    );
  }

  Widget _buildActionCard(String label, IconData icon, Color color, VoidCallback onTap) {
    final isDark = AppColors.isDark(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: AppColors.getCardDecoration(context, borderRadius: 16),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(isDark ? 0.2 : 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppColors.getTextPrimary(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDailyTipCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppColors.getCardDecoration(context, borderRadius: 16),
      child: Row(
        children: [
          Text(_dailyTip!.icon, style: const TextStyle(fontSize: 32)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _dailyTip!.title,
                  style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.getTextPrimary(context)),
                ),
                Text(
                  _dailyTip!.description,
                  style: TextStyle(fontSize: 12, color: AppColors.getTextSecondary(context)),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: AppColors.getTextSecondary(context)),
        ],
      ),
    );
  }

  Widget _buildCycleInfo() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AppColors.getCardDecoration(context),
      child: Column(
        children: [
          _buildInfoRow(Icons.calendar_today_rounded, "Last Period",
              DateFormat('MMM d, yyyy').format(_periodData!.lastPeriodDate)),
          const Divider(height: 24),
          _buildInfoRow(Icons.event_rounded, "Next Period",
              DateFormat('MMM d, yyyy').format(_periodData!.nextPeriodDate)),
          const Divider(height: 24),
          _buildInfoRow(Icons.loop_rounded, "Cycle Length", "${_periodData!.cycleLength} days"),
        ],
      ),
    );
  }

  Widget _buildUpcomingEvents() {
    if (_fertileWindow == null) return const SizedBox.shrink();

    final isDark = AppColors.isDark(context);
    final today = DateTime.now();
    final ovulation = _fertileWindow!['ovulation']!;
    final fertileStart = _fertileWindow!['start']!;
    final isInFertileWindow = today.isAfter(fertileStart.subtract(const Duration(days: 1))) &&
        today.isBefore(_fertileWindow!['end']!.add(const Duration(days: 1)));

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isInFertileWindow 
            ? (isDark ? Colors.blue.withOpacity(0.15) : Colors.blue.shade50) 
            : AppColors.getCardBg(context),
        borderRadius: BorderRadius.circular(16),
        border: isInFertileWindow 
            ? Border.all(color: isDark ? Colors.blue.withOpacity(0.3) : Colors.blue.shade200) 
            : (isDark ? Border.all(color: AppColors.darkBorder.withOpacity(0.5)) : null),
        boxShadow: [
          BoxShadow(
            color: AppColors.getCardShadow(context),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isInFertileWindow ? Icons.favorite_rounded : Icons.star_rounded,
                color: isInFertileWindow ? Colors.blue : Colors.purple,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                isInFertileWindow ? 'Fertile Window Active' : 'Upcoming',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isInFertileWindow ? Colors.blue : AppColors.getTextPrimary(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildEventChip(
                  'Ovulation',
                  DateFormat('MMM d').format(ovulation),
                  Colors.purple,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildEventChip(
                  'Fertile Window',
                  '${DateFormat('MMM d').format(fertileStart)} - ${DateFormat('MMM d').format(_fertileWindow!['end']!)}',
                  Colors.blue,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEventChip(String label, String date, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w500)),
          Text(date, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.periodLight,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: AppColors.periodPrimary, size: 20),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(label, style: const TextStyle(color: AppColors.textSecondary)),
        ),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _buildMiniCalendar(PeriodData data, DateTime today) {
    final startOfMonth = DateTime(today.year, today.month, 1);
    final daysInMonth = DateUtils.getDaysInMonth(today.year, today.month);

    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PeriodCalendarScreen())),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  DateFormat('MMMM yyyy').format(today),
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Text(
                  'View Full Calendar →',
                  style: TextStyle(fontSize: 12, color: AppColors.periodPrimary),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: ["S", "M", "T", "W", "T", "F", "S"]
                  .map((d) => SizedBox(
                        width: 36,
                        child: Text(d, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textSecondary)),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 4,
              runSpacing: 8,
              children: List.generate(daysInMonth + startOfMonth.weekday % 7, (index) {
                if (index < startOfMonth.weekday % 7) {
                  return const SizedBox(width: 36, height: 36);
                }
                final day = startOfMonth.add(Duration(days: index - startOfMonth.weekday % 7));
                final isOnPeriod = data.isOnPeriod(day);
                final isToday = day.day == today.day && day.month == today.month;
                final isFertile = _fertileWindow != null &&
                    day.isAfter(_fertileWindow!['start']!.subtract(const Duration(days: 1))) &&
                    day.isBefore(_fertileWindow!['end']!.add(const Duration(days: 1)));
                final isOvulation = _fertileWindow != null &&
                    day.year == _fertileWindow!['ovulation']!.year &&
                    day.month == _fertileWindow!['ovulation']!.month &&
                    day.day == _fertileWindow!['ovulation']!.day;

                Color? bgColor;
                if (isOnPeriod) {
                  bgColor = AppColors.periodHighlight;
                } else if (isOvulation) {
                  bgColor = Colors.purple.shade100;
                } else if (isFertile) {
                  bgColor = Colors.blue.shade50;
                } else if (isToday) {
                  bgColor = AppColors.periodPrimary.withOpacity(0.1);
                }

                return Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: bgColor ?? Colors.transparent,
                    shape: BoxShape.circle,
                    border: isToday ? Border.all(color: AppColors.periodPrimary, width: 2) : null,
                  ),
                  child: Center(
                    child: Text(
                      "${day.day}",
                      style: TextStyle(
                        fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                        color: isOnPeriod ? AppColors.periodPrimary : AppColors.textPrimary,
                        fontSize: 14,
                      ),
                    ),
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  void _showQuickLogSheet() {
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
              onTap: () async {
                Navigator.pop(context);
                final date = await showDatePicker(
                  context: context,
                  initialDate: DateTime.now(),
                  firstDate: DateTime.now().subtract(const Duration(days: 30)),
                  lastDate: DateTime.now(),
                );
                if (date != null) {
                  await PeriodStorageService.startNewCycle(date);
                  _loadData();
                }
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
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => SymptomLogScreen(date: DateTime.now())),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  String _getPhaseDisplayName(CyclePhase phase) {
    switch (phase) {
      case CyclePhase.menstrual: return 'Menstrual Phase';
      case CyclePhase.follicular: return 'Follicular Phase';
      case CyclePhase.ovulation: return 'Ovulation Phase';
      case CyclePhase.luteal: return 'Luteal Phase';
      case CyclePhase.pms: return 'PMS Phase';
    }
  }

  IconData _getPhaseIcon(CyclePhase phase) {
    switch (phase) {
      case CyclePhase.menstrual: return Icons.water_drop_rounded;
      case CyclePhase.follicular: return Icons.trending_up_rounded;
      case CyclePhase.ovulation: return Icons.star_rounded;
      case CyclePhase.luteal: return Icons.nightlight_rounded;
      case CyclePhase.pms: return Icons.psychology_rounded;
    }
  }
}
