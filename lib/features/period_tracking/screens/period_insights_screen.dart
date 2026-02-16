import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../models/cycle_log.dart';
import '../models/symptom_log.dart';
import '../services/period_storage_service.dart';
import '../services/period_prediction_service.dart';
import '../services/period_health_tips_service.dart';

class PeriodInsightsScreen extends StatefulWidget {
  const PeriodInsightsScreen({super.key});

  @override
  State<PeriodInsightsScreen> createState() => _PeriodInsightsScreenState();
}

class _PeriodInsightsScreenState extends State<PeriodInsightsScreen> {
  CycleLog? _currentCycle;
  CyclePhase _currentPhase = CyclePhase.follicular;
  int _cycleDay = 1;
  HealthTip? _dailyTip;
  List<MoodPrediction> _moodPredictions = [];
  PMSPrediction? _pmsPrediction;
  Map<String, DateTime>? _fertileWindow;
  DateTime? _nextPeriod;
  List<String> _motivationalMessages = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    final cycle = PeriodStorageService.getCurrentCycle();
    if (cycle == null) return;

    final today = DateTime.now();
    final cycleDay = PeriodPredictionService.getCurrentCycleDay(cycle.startDate, today);
    final phase = PeriodPredictionService.getCurrentPhase(
      cycle.startDate,
      cycle.cycleLength,
      cycle.periodDuration,
      today,
    );
    final nextPeriod = PeriodPredictionService.predictNextPeriod(cycle.startDate, cycle.cycleLength);
    final fertileWindow = PeriodPredictionService.predictFertileWindow(cycle.startDate, cycle.cycleLength);
    final moodPredictions = PeriodPredictionService.predictMoodPattern(cycle.startDate, cycle.cycleLength);
    final pmsPrediction = PeriodPredictionService.predictPMS(
      PeriodStorageService.getAllSymptomLogs(),
      nextPeriod,
    );
    final dailyTip = PeriodHealthTipsService.getDailyTip(phase, cycleDay);
    final messages = PeriodHealthTipsService.getMotivationalMessages(phase);

    setState(() {
      _currentCycle = cycle;
      _cycleDay = cycleDay;
      _currentPhase = phase;
      _nextPeriod = nextPeriod;
      _fertileWindow = fertileWindow;
      _moodPredictions = moodPredictions;
      _pmsPrediction = pmsPrediction;
      _dailyTip = dailyTip;
      _motivationalMessages = messages;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_currentCycle == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: AppColors.periodPrimary),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Text('Insights', style: TextStyle(color: AppColors.periodPrimary)),
        ),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.insights_rounded, size: 64, color: AppColors.textSecondary),
              SizedBox(height: 16),
              Text('No cycle data yet', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              Text('Start tracking to see personalized insights'),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          _buildAppBar(),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildPhaseCard(),
                  const SizedBox(height: 20),
                  _buildDailyTipCard(),
                  const SizedBox(height: 20),
                  _buildUpcomingEvents(),
                  const SizedBox(height: 20),
                  _buildMoodPrediction(),
                  const SizedBox(height: 20),
                  if (_pmsPrediction != null && _pmsPrediction!.predictedSymptoms.isNotEmpty)
                    _buildPMSPredictionCard(),
                  const SizedBox(height: 20),
                  _buildMotivationCard(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 200,
      pinned: true,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: AppColors.periodGradient,
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '$_cycleDay',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Day $_cycleDay of your cycle',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              _getPhaseDisplayName(_currentPhase),
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.white.withOpacity(0.9),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPhaseCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
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
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _getPhaseColor(_currentPhase).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _getPhaseIcon(_currentPhase),
                  color: _getPhaseColor(_currentPhase),
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_getPhaseDisplayName(_currentPhase)} Phase',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      _getPhaseDescription(_currentPhase),
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Phase progress indicator
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
        final isCurrent = index == currentIndex;
        return Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 2),
            height: 6,
            decoration: BoxDecoration(
              color: isActive ? _getPhaseColor(phases[index]) : Colors.grey.shade200,
              borderRadius: BorderRadius.circular(3),
              border: isCurrent ? Border.all(color: Colors.white, width: 1) : null,
              boxShadow: isCurrent
                  ? [BoxShadow(color: _getPhaseColor(phases[index]), blurRadius: 4)]
                  : null,
            ),
          ),
        );
      }),
    );
  }

  Widget _buildDailyTipCard() {
    if (_dailyTip == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.purple.shade50, Colors.pink.shade50],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(_dailyTip!.icon, style: const TextStyle(fontSize: 32)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _dailyTip!.title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _dailyTip!.description,
            style: const TextStyle(color: AppColors.textPrimary),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildMiniTip(
                  Icons.restaurant_rounded,
                  'Nutrition',
                  _dailyTip!.nutritionTip,
                  Colors.green,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMiniTip(
                  Icons.fitness_center_rounded,
                  'Exercise',
                  _dailyTip!.exerciseTip,
                  Colors.orange,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniTip(IconData icon, String title, String tip, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 4),
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            tip,
            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildUpcomingEvents() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Upcoming',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          if (_fertileWindow != null)
            _buildEventItem(
              Icons.favorite_rounded,
              'Fertile Window',
              '${DateFormat('MMM d').format(_fertileWindow!['start']!)} - ${DateFormat('MMM d').format(_fertileWindow!['end']!)}',
              Colors.blue,
              _isUpcoming(_fertileWindow!['start']!),
            ),
          if (_fertileWindow != null)
            _buildEventItem(
              Icons.star_rounded,
              'Ovulation Day',
              DateFormat('MMM d').format(_fertileWindow!['ovulation']!),
              Colors.purple,
              _isUpcoming(_fertileWindow!['ovulation']!),
            ),
          if (_nextPeriod != null)
            _buildEventItem(
              Icons.water_drop_rounded,
              'Next Period',
              DateFormat('MMM d').format(_nextPeriod!),
              AppColors.periodPrimary,
              true,
            ),
          if (_pmsPrediction?.pmsWindowStart != null)
            _buildEventItem(
              Icons.psychology_rounded,
              'PMS Window',
              '${DateFormat('MMM d').format(_pmsPrediction!.pmsWindowStart!)} - ${DateFormat('MMM d').format(_pmsPrediction!.pmsWindowEnd!)}',
              Colors.orange,
              _isUpcoming(_pmsPrediction!.pmsWindowStart!),
            ),
        ],
      ),
    );
  }

  Widget _buildEventItem(IconData icon, String title, String date, Color color, bool show) {
    if (!show) return const SizedBox.shrink();
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
                Text(date, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
        ],
      ),
    );
  }

  Widget _buildMoodPrediction() {
    final today = DateTime.now();
    final todayPrediction = _moodPredictions.firstWhere(
      (p) => p.date.year == today.year && p.date.month == today.month && p.date.day == today.day,
      orElse: () => _moodPredictions.isNotEmpty ? _moodPredictions.first : MoodPrediction(
        date: today,
        phase: _currentPhase,
        predictedMoods: [],
        energyLevel: EnergyLevel.medium,
        tips: '',
      ),
    );

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Today\'s Mood Prediction',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              // Energy indicator
              Expanded(
                child: _buildPredictionItem(
                  'Energy',
                  _getEnergyEmoji(todayPrediction.energyLevel),
                  _getEnergyDisplayName(todayPrediction.energyLevel),
                ),
              ),
              // Predicted moods
              Expanded(
                child: _buildPredictionItem(
                  'Mood',
                  todayPrediction.predictedMoods.isNotEmpty
                      ? _getMoodEmoji(todayPrediction.predictedMoods.first)
                      : '😊',
                  todayPrediction.predictedMoods.isNotEmpty
                      ? _getMoodDisplayName(todayPrediction.predictedMoods.first)
                      : 'Balanced',
                ),
              ),
            ],
          ),
          if (todayPrediction.tips.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.periodLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.lightbulb_outline_rounded, color: AppColors.periodPrimary, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      todayPrediction.tips,
                      style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPredictionItem(String label, String emoji, String value) {
    return Column(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 40)),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
      ],
    );
  }

  Widget _buildPMSPredictionCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.psychology_rounded, color: Colors.orange),
              SizedBox(width: 8),
              Text(
                'PMS Prediction',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Based on your history, you may experience:',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _pmsPrediction!.predictedSymptoms.take(4).map((symptom) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _getSymptomDisplayName(symptom),
                  style: const TextStyle(fontSize: 12),
                ),
              );
            }).toList(),
          ),
          if (_pmsPrediction!.confidence > 0) ...[
            const SizedBox(height: 12),
            Text(
              'Confidence: ${_pmsPrediction!.confidence}%',
              style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMotivationCard() {
    if (_motivationalMessages.isEmpty) return const SizedBox.shrink();

    final randomMessage = _motivationalMessages[DateTime.now().day % _motivationalMessages.length];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppColors.periodGradient,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Icon(Icons.format_quote_rounded, color: Colors.white.withOpacity(0.5), size: 32),
          const SizedBox(height: 8),
          Text(
            randomMessage,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // Helper methods
  bool _isUpcoming(DateTime date) {
    final today = DateTime.now();
    final diff = date.difference(today).inDays;
    return diff >= 0 && diff <= 14;
  }

  String _getPhaseDisplayName(CyclePhase phase) {
    switch (phase) {
      case CyclePhase.menstrual: return 'Menstrual';
      case CyclePhase.follicular: return 'Follicular';
      case CyclePhase.ovulation: return 'Ovulation';
      case CyclePhase.luteal: return 'Luteal';
      case CyclePhase.pms: return 'PMS';
    }
  }

  String _getPhaseDescription(CyclePhase phase) {
    switch (phase) {
      case CyclePhase.menstrual: return 'Rest and restore your energy';
      case CyclePhase.follicular: return 'Rising energy and creativity';
      case CyclePhase.ovulation: return 'Peak energy and confidence';
      case CyclePhase.luteal: return 'Winding down, good for detail work';
      case CyclePhase.pms: return 'Time for extra self-care';
    }
  }

  Color _getPhaseColor(CyclePhase phase) {
    switch (phase) {
      case CyclePhase.menstrual: return AppColors.periodPrimary;
      case CyclePhase.follicular: return Colors.green;
      case CyclePhase.ovulation: return Colors.purple;
      case CyclePhase.luteal: return Colors.blue;
      case CyclePhase.pms: return Colors.orange;
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

  String _getEnergyEmoji(EnergyLevel level) {
    switch (level) {
      case EnergyLevel.veryLow: return '🔋';
      case EnergyLevel.low: return '🪫';
      case EnergyLevel.medium: return '⚡';
      case EnergyLevel.high: return '💪';
      case EnergyLevel.veryHigh: return '🚀';
    }
  }

  String _getEnergyDisplayName(EnergyLevel level) {
    switch (level) {
      case EnergyLevel.veryLow: return 'Very Low';
      case EnergyLevel.low: return 'Low';
      case EnergyLevel.medium: return 'Medium';
      case EnergyLevel.high: return 'High';
      case EnergyLevel.veryHigh: return 'Very High';
    }
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
    ).trim();
  }

  String _getSymptomDisplayName(SymptomType symptom) {
    return symptom.name.replaceAllMapped(
      RegExp(r'([A-Z])'),
      (match) => ' ${match.group(0)}',
    ).trim();
  }
}
