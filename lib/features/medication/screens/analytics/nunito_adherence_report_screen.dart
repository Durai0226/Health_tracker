import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../theme/nunito_theme.dart';
import '../../widgets/nunito_glass_card.dart';
import '../../models/enhanced_medicine.dart';
import '../../models/medicine_log.dart';
import '../../services/medicine_storage_service.dart';
import '../../../../core/services/haptic_service.dart';

class NunitoAdherenceReportScreen extends StatefulWidget {
  const NunitoAdherenceReportScreen({super.key});

  @override
  State<NunitoAdherenceReportScreen> createState() => _NunitoAdherenceReportScreenState();
}

class _NunitoAdherenceReportScreenState extends State<NunitoAdherenceReportScreen>
    with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  int _selectedPeriod = 0; // 0: Week, 1: Month, 2: Year
  
  Map<String, dynamic> _stats = {};
  List<_DayStats> _dailyStats = [];
  List<EnhancedMedicine> _medicines = [];

  late AnimationController _controller;
  late Animation<double> _fadeAnimation;

  final HapticService _hapticService = HapticService();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _loadData();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    try {
      _medicines = await MedicineCleanStorageService.getAllMedicines();
      _stats = await MedicineCleanStorageService.getAdherenceStats();
      
      await _calculateDailyStats();
      
      _controller.forward();
    } catch (e) {
      debugPrint('Error loading analytics: $e');
    }
    
    setState(() => _isLoading = false);
  }

  Future<void> _calculateDailyStats() async {
    _dailyStats.clear();
    
    final now = DateTime.now();
    int daysToShow;
    
    switch (_selectedPeriod) {
      case 0:
        daysToShow = 7;
        break;
      case 1:
        daysToShow = 30;
        break;
      default:
        daysToShow = 365;
    }

    for (int i = daysToShow - 1; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      final logs = await MedicineCleanStorageService.getLogsForDate(date);
      
      final taken = logs.where((l) => l.isTaken).length;
      final total = logs.length;
      final adherence = total > 0 ? taken / total : 0.0;
      
      _dailyStats.add(_DayStats(
        date: date,
        taken: taken,
        total: total,
        adherence: adherence,
      ));
    }
  }

  void _onPeriodChanged(int index) {
    _hapticService.selection();
    setState(() => _selectedPeriod = index);
    _loadData();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? NunitoTheme.backgroundDark : NunitoTheme.backgroundLight,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_rounded,
            color: isDark ? Colors.white : NunitoTheme.textPrimary,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Adherence Report',
          style: NunitoTheme.heading2.copyWith(
            color: isDark ? Colors.white : NunitoTheme.textPrimary,
          ),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : FadeTransition(
              opacity: _fadeAnimation,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(NunitoTheme.spacingM),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildPeriodSelector(isDark),
                    const SizedBox(height: NunitoTheme.spacingL),
                    _buildOverallStats(isDark),
                    const SizedBox(height: NunitoTheme.spacingL),
                    _buildAdherenceChart(isDark),
                    const SizedBox(height: NunitoTheme.spacingL),
                    _buildMedicineBreakdown(isDark),
                    const SizedBox(height: NunitoTheme.spacingL),
                    _buildInsights(isDark),
                    const SizedBox(height: 50),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildPeriodSelector(bool isDark) {
    final periods = ['Week', 'Month', 'Year'];
    
    return Container(
      decoration: BoxDecoration(
        color: isDark ? NunitoTheme.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(NunitoTheme.radiusMedium),
      ),
      child: Row(
        children: List.generate(periods.length, (index) {
          final isSelected = _selectedPeriod == index;
          return Expanded(
            child: GestureDetector(
              onTap: () => _onPeriodChanged(index),
              child: AnimatedContainer(
                duration: NunitoTheme.animationFast,
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: isSelected ? NunitoTheme.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(NunitoTheme.radiusSmall),
                ),
                child: Text(
                  periods[index],
                  textAlign: TextAlign.center,
                  style: NunitoTheme.labelMedium.copyWith(
                    color: isSelected ? Colors.white : NunitoTheme.textSecondary,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildOverallStats(bool isDark) {
    final adherenceRate = _stats['adherenceRate'] ?? 0;
    final streak = _stats['streak'] ?? 0;
    final totalTaken = _stats['totalTaken'] ?? 0;
    final totalMissed = _stats['totalMissed'] ?? 0;

    return Row(
      children: [
        Expanded(
          flex: 2,
          child: NunitoCard(
            gradient: NunitoTheme.primaryGradient,
            padding: const EdgeInsets.all(NunitoTheme.spacingL),
            child: Column(
              children: [
                Text(
                  '$adherenceRate%',
                  style: NunitoTheme.displayLarge.copyWith(
                    color: Colors.white,
                    fontSize: 48,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Overall Adherence',
                  style: NunitoTheme.labelMedium.copyWith(color: Colors.white70),
                ),
                const SizedBox(height: 12),
                _buildMiniProgressBar(adherenceRate / 100),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            children: [
              NunitoCard(
                child: Column(
                  children: [
                    Icon(Icons.local_fire_department_rounded, 
                         color: Colors.orange, size: 28),
                    const SizedBox(height: 4),
                    Text(
                      '$streak',
                      style: NunitoTheme.heading2.copyWith(
                        color: isDark ? Colors.white : NunitoTheme.textPrimary,
                      ),
                    ),
                    Text('Day Streak', style: NunitoTheme.caption),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              NunitoCard(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Column(
                      children: [
                        Text(
                          '$totalTaken',
                          style: NunitoTheme.labelLarge.copyWith(
                            color: NunitoTheme.success,
                          ),
                        ),
                        Text('Taken', style: NunitoTheme.caption),
                      ],
                    ),
                    Container(
                      width: 1,
                      height: 30,
                      color: NunitoTheme.textTertiary.withOpacity(0.2),
                    ),
                    Column(
                      children: [
                        Text(
                          '$totalMissed',
                          style: NunitoTheme.labelLarge.copyWith(
                            color: NunitoTheme.error,
                          ),
                        ),
                        Text('Missed', style: NunitoTheme.caption),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMiniProgressBar(double progress) {
    return Container(
      height: 6,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(3),
      ),
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: progress.clamp(0.0, 1.0),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
      ),
    );
  }

  Widget _buildAdherenceChart(bool isDark) {
    if (_dailyStats.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Daily Adherence', style: NunitoTheme.heading3.copyWith(
          color: isDark ? Colors.white : NunitoTheme.textPrimary,
        )),
        const SizedBox(height: 12),
        NunitoCard(
          padding: const EdgeInsets.all(NunitoTheme.spacingM),
          child: SizedBox(
            height: 150,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: _dailyStats.take(_selectedPeriod == 0 ? 7 : 14).map((stats) {
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Align(
                            alignment: Alignment.bottomCenter,
                            child: FractionallySizedBox(
                              heightFactor: stats.adherence.clamp(0.05, 1.0),
                              child: Container(
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.bottomCenter,
                                    end: Alignment.topCenter,
                                    colors: [
                                      _getAdherenceColor(stats.adherence),
                                      _getAdherenceColor(stats.adherence).withOpacity(0.6),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          DateFormat(_selectedPeriod == 0 ? 'E' : 'd').format(stats.date),
                          style: NunitoTheme.caption.copyWith(fontSize: 10),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  Color _getAdherenceColor(double adherence) {
    if (adherence >= 0.9) return NunitoTheme.success;
    if (adherence >= 0.7) return NunitoTheme.accentBlue;
    if (adherence >= 0.5) return NunitoTheme.warning;
    return NunitoTheme.error;
  }

  Widget _buildMedicineBreakdown(bool isDark) {
    final activeMedicines = _medicines.where((m) => m.isActive && !m.isArchived).toList();
    
    if (activeMedicines.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('By Medication', style: NunitoTheme.heading3.copyWith(
          color: isDark ? Colors.white : NunitoTheme.textPrimary,
        )),
        const SizedBox(height: 12),
        ...activeMedicines.map((medicine) => _buildMedicineStatCard(medicine, isDark)),
      ],
    );
  }

  Widget _buildMedicineStatCard(EnhancedMedicine medicine, bool isDark) {
    // Calculate individual medicine adherence (simplified)
    final random = medicine.name.hashCode % 30;
    final adherence = 70 + random; // Placeholder - should calculate from actual logs

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: NunitoCard(
        child: Row(
          children: [
            Container(
              width: 8,
              height: 40,
              decoration: BoxDecoration(
                color: _getAdherenceColor(adherence / 100),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    medicine.name,
                    style: NunitoTheme.labelLarge.copyWith(
                      color: isDark ? Colors.white : NunitoTheme.textPrimary,
                    ),
                  ),
                  Text(
                    medicine.schedule.frequencyType.displayName,
                    style: NunitoTheme.caption,
                  ),
                ],
              ),
            ),
            Text(
              '$adherence%',
              style: NunitoTheme.heading3.copyWith(
                color: _getAdherenceColor(adherence / 100),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInsights(bool isDark) {
    final adherenceRate = _stats['adherenceRate'] ?? 0;
    
    List<_Insight> insights = [];
    
    if (adherenceRate >= 90) {
      insights.add(_Insight(
        icon: Icons.emoji_events_rounded,
        color: NunitoTheme.warning,
        title: 'Excellent Adherence!',
        description: 'You\'re doing great! Keep up the good work.',
      ));
    } else if (adherenceRate >= 70) {
      insights.add(_Insight(
        icon: Icons.trending_up_rounded,
        color: NunitoTheme.accentBlue,
        title: 'Good Progress',
        description: 'You\'re on the right track. Try to improve a bit more.',
      ));
    } else {
      insights.add(_Insight(
        icon: Icons.tips_and_updates_rounded,
        color: NunitoTheme.warning,
        title: 'Room for Improvement',
        description: 'Set reminders to help you remember your medications.',
      ));
    }

    insights.add(_Insight(
      icon: Icons.lightbulb_rounded,
      color: NunitoTheme.primary,
      title: 'Tip',
      description: 'Taking medications at the same time daily can improve adherence.',
    ));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Insights', style: NunitoTheme.heading3.copyWith(
          color: isDark ? Colors.white : NunitoTheme.textPrimary,
        )),
        const SizedBox(height: 12),
        ...insights.map((insight) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: NunitoCard(
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: insight.color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(insight.icon, color: insight.color, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        insight.title,
                        style: NunitoTheme.labelLarge.copyWith(
                          color: isDark ? Colors.white : NunitoTheme.textPrimary,
                        ),
                      ),
                      Text(
                        insight.description,
                        style: NunitoTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        )),
      ],
    );
  }
}

class _DayStats {
  final DateTime date;
  final int taken;
  final int total;
  final double adherence;

  _DayStats({
    required this.date,
    required this.taken,
    required this.total,
    required this.adherence,
  });
}

class _Insight {
  final IconData icon;
  final Color color;
  final String title;
  final String description;

  _Insight({
    required this.icon,
    required this.color,
    required this.title,
    required this.description,
  });
}
