import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../models/cycle_log.dart';
import '../models/symptom_log.dart';
import '../services/period_storage_service.dart';
import '../services/period_prediction_service.dart';

class PeriodStatisticsScreen extends StatefulWidget {
  const PeriodStatisticsScreen({super.key});

  @override
  State<PeriodStatisticsScreen> createState() => _PeriodStatisticsScreenState();
}

class _PeriodStatisticsScreenState extends State<PeriodStatisticsScreen> {
  Map<String, dynamic> _stats = {};
  List<CycleLog> _cycles = [];
  CycleIrregularityResult? _irregularityResult;
  Map<SymptomType, int> _symptomFrequency = {};
  Map<MoodType, int> _moodFrequency = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    setState(() {
      _stats = PeriodStorageService.getCycleStatistics();
      _cycles = PeriodStorageService.getAllCycles();
      _symptomFrequency = PeriodStorageService.getSymptomFrequency();
      _moodFrequency = PeriodStorageService.getMoodFrequency();
      if (_cycles.length >= 3) {
        _irregularityResult = PeriodPredictionService.detectIrregularities(_cycles);
      }
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
        title: const Text('Cycle Statistics', style: TextStyle(color: AppColors.periodPrimary)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildOverviewCards(),
            const SizedBox(height: 24),
            _buildCycleLengthChart(),
            const SizedBox(height: 24),
            if (_irregularityResult != null) _buildIrregularityCard(),
            const SizedBox(height: 24),
            _buildSymptomTrends(),
            const SizedBox(height: 24),
            _buildMoodTrends(),
            const SizedBox(height: 24),
            _buildCycleHistory(),
          ],
        ),
      ),
    );
  }

  Widget _buildOverviewCards() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Overview',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _buildStatCard(
              'Avg Cycle',
              '${_stats['averageCycleLength'] ?? 28}',
              'days',
              Icons.loop_rounded,
              Colors.purple,
            )),
            const SizedBox(width: 12),
            Expanded(child: _buildStatCard(
              'Avg Period',
              '${_stats['averagePeriodDuration'] ?? 5}',
              'days',
              Icons.water_drop_rounded,
              AppColors.periodPrimary,
            )),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _buildStatCard(
              'Total Cycles',
              '${_stats['totalCycles'] ?? 0}',
              'tracked',
              Icons.calendar_month_rounded,
              Colors.blue,
            )),
            const SizedBox(width: 12),
            Expanded(child: _buildStatCard(
              'Variation',
              '${_stats['cycleVariation'] ?? 0}',
              'days',
              Icons.trending_up_rounded,
              Colors.orange,
            )),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, String unit, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const Spacer(),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            unit,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCycleLengthChart() {
    if (_cycles.isEmpty) {
      return _buildEmptyState('No cycle data yet', 'Start tracking to see your cycle patterns');
    }

    final completedCycles = _cycles.where((c) => c.isComplete).take(12).toList();
    if (completedCycles.isEmpty) {
      return _buildEmptyState('Not enough data', 'Complete a few cycles to see trends');
    }

    final maxLength = completedCycles.map((c) => c.actualCycleLength).reduce((a, b) => a > b ? a : b);
    final avgLength = _stats['averageCycleLength'] ?? 28;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Cycle Length Trend',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.periodLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Last ${completedCycles.length} cycles',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.periodPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 150,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: completedCycles.reversed.map((cycle) {
                final height = (cycle.actualCycleLength / maxLength) * 120;
                final isAboveAvg = cycle.actualCycleLength > avgLength;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          '${cycle.actualCycleLength}',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: isAboveAvg ? Colors.orange : AppColors.periodPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          height: height,
                          decoration: BoxDecoration(
                            color: isAboveAvg ? Colors.orange.shade200 : AppColors.periodHighlight,
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: AppColors.periodHighlight,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 4),
              const Text('Normal', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              const SizedBox(width: 16),
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: Colors.orange.shade200,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 4),
              const Text('Above Average', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildIrregularityCard() {
    final result = _irregularityResult!;
    final color = result.isIrregular ? Colors.orange : Colors.green;
    final icon = result.isIrregular ? Icons.warning_rounded : Icons.check_circle_rounded;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Cycle Regularity Analysis',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Based on ${_cycles.length} tracked cycles',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            result.message,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textPrimary,
            ),
          ),
          if (result.issues.isNotEmpty) ...[
            const SizedBox(height: 12),
            ...result.issues.map((issue) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded, size: 16, color: Colors.orange),
                  const SizedBox(width: 8),
                  Expanded(child: Text(issue, style: const TextStyle(fontSize: 13))),
                ],
              ),
            )),
          ],
        ],
      ),
    );
  }

  Widget _buildSymptomTrends() {
    if (_symptomFrequency.isEmpty) {
      return _buildEmptyState('No symptom data', 'Log symptoms to see trends');
    }

    final sortedSymptoms = _symptomFrequency.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topSymptoms = sortedSymptoms.take(5).toList();
    final maxCount = topSymptoms.first.value;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Most Common Symptoms',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          ...topSymptoms.map((entry) {
            final percentage = entry.value / maxCount;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _getSymptomDisplayName(entry.key),
                        style: const TextStyle(fontSize: 14),
                      ),
                      Text(
                        '${entry.value}x',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppColors.periodPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  LinearProgressIndicator(
                    value: percentage,
                    backgroundColor: AppColors.periodLight,
                    valueColor: const AlwaysStoppedAnimation(AppColors.periodPrimary),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildMoodTrends() {
    if (_moodFrequency.isEmpty) {
      return _buildEmptyState('No mood data', 'Log moods to see trends');
    }

    final sortedMoods = _moodFrequency.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topMoods = sortedMoods.take(6).toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Mood Patterns',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: topMoods.map((entry) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.periodLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Text(
                      _getMoodEmoji(entry.key),
                      style: const TextStyle(fontSize: 28),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${entry.value}x',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.periodPrimary,
                      ),
                    ),
                    Text(
                      _getMoodDisplayName(entry.key),
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildCycleHistory() {
    if (_cycles.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Cycle History',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          ..._cycles.take(10).map((cycle) {
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: cycle.isComplete ? Colors.green.shade100 : AppColors.periodLight,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '${cycle.actualCycleLength}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: cycle.isComplete ? Colors.green : AppColors.periodPrimary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _formatDateRange(cycle.startDate, cycle.endDate),
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                        Text(
                          'Period: ${cycle.periodDuration} days',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!cycle.isComplete)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.periodPrimary,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'Current',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String title, String subtitle) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        children: [
          const Icon(Icons.analytics_outlined, size: 48, color: AppColors.textSecondary),
          const SizedBox(height: 12),
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          Text(subtitle, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
        ],
      ),
    );
  }

  String _getSymptomDisplayName(SymptomType type) {
    return type.name.replaceAllMapped(
      RegExp(r'([A-Z])'),
      (match) => ' ${match.group(0)}',
    ).trim().replaceFirst(type.name[0], type.name[0].toUpperCase());
  }

  String _getMoodEmoji(MoodType mood) {
    switch (mood) {
      case MoodType.happy: return '😊';
      case MoodType.calm: return '😌';
      case MoodType.energetic: return '⚡';
      case MoodType.sensitive: return '🥺';
      case MoodType.anxious: return '😰';
      case MoodType.irritable: return '😤';
      case MoodType.sad: return '😢';
      case MoodType.moodSwings: return '🎭';
      case MoodType.stressed: return '😫';
      case MoodType.tired: return '😴';
      case MoodType.focused: return '🎯';
      case MoodType.confused: return '😕';
    }
  }

  String _getMoodDisplayName(MoodType mood) {
    return mood.name.replaceAllMapped(
      RegExp(r'([A-Z])'),
      (match) => ' ${match.group(0)}',
    ).trim().replaceFirst(mood.name[0], mood.name[0].toUpperCase());
  }

  String _formatDateRange(DateTime start, DateTime? end) {
    final startStr = '${start.day}/${start.month}/${start.year}';
    if (end == null) return '$startStr - Present';
    final endStr = '${end.day}/${end.month}/${end.year}';
    return '$startStr - $endStr';
  }
}
