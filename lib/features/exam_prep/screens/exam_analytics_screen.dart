import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../models/exam_type.dart';
import '../models/study_session.dart';
import '../services/exam_prep_service.dart';

class ExamAnalyticsScreen extends StatelessWidget {
  const ExamAnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final service = ExamPrepService();
    
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Analytics')),
      body: ListenableBuilder(
        listenable: service,
        builder: (context, _) {
          if (service.activeExamId == null) {
            return const Center(child: Text('No exam selected'));
          }
          
          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildOverviewCard(service),
                const SizedBox(height: 24),
                _buildStudyTypeBreakdown(service),
                const SizedBox(height: 24),
                _buildWeeklyProgress(service),
                const SizedBox(height: 24),
                _buildMockTestTrend(service),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildOverviewCard(ExamPrepService service) {
    final exam = service.activeExam;
    
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            exam?.category.color ?? AppColors.primary,
            (exam?.category.color ?? AppColors.primary).withOpacity(0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatColumn('${service.totalStudyHours}', 'Total Hours'),
              _buildStatColumn('${service.sessions.length}', 'Sessions'),
              _buildStatColumn('${service.currentStreak}', 'Day Streak'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatColumn(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        Text(
          label,
          style: TextStyle(color: Colors.white.withOpacity(0.9)),
        ),
      ],
    );
  }

  Widget _buildStudyTypeBreakdown(ExamPrepService service) {
    final timeByType = service.activeExamId != null 
        ? service.getStudyTimeByType(service.activeExamId!)
        : <StudyType, int>{};
    
    if (timeByType.isEmpty) return const SizedBox();
    
    final total = timeByType.values.fold(0, (a, b) => a + b);
    final sorted = timeByType.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Study Type Breakdown',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          ...sorted.map((entry) {
            final percent = total > 0 ? entry.value / total : 0.0;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                children: [
                  Row(
                    children: [
                      Text(entry.key.emoji, style: const TextStyle(fontSize: 18)),
                      const SizedBox(width: 8),
                      Expanded(child: Text(entry.key.name)),
                      Text('${entry.value} min'),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: percent,
                      backgroundColor: Colors.grey.shade100,
                      minHeight: 6,
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

  Widget _buildWeeklyProgress(ExamPrepService service) {
    final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    
    final dailyMinutes = List.generate(7, (i) {
      final date = weekStart.add(Duration(days: i));
      return service.sessions
          .where((s) => _isSameDay(s.startTime, date))
          .fold(0, (sum, s) => sum + s.durationMinutes);
    });
    
    final maxMinutes = dailyMinutes.reduce((a, b) => a > b ? a : b);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'This Week',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 120,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(7, (i) {
                final height = maxMinutes > 0 
                    ? (dailyMinutes[i] / maxMinutes) * 80 
                    : 0.0;
                final isToday = i == now.weekday - 1;
                return Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      '${dailyMinutes[i]}',
                      style: const TextStyle(
                        fontSize: 10,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      width: 28,
                      height: height.clamp(4.0, 80.0),
                      decoration: BoxDecoration(
                        color: isToday ? AppColors.primary : AppColors.primary.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      days[i],
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                        color: isToday ? AppColors.primary : AppColors.textSecondary,
                      ),
                    ),
                  ],
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMockTestTrend(ExamPrepService service) {
    final tests = service.activeExamId != null 
        ? service.getMockTestsForExam(service.activeExamId!)
        : [];
    
    if (tests.length < 2) return const SizedBox();
    
    final improvement = service.getMockTestImprovement(service.activeExamId!);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Mock Test Performance',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Icon(
                improvement >= 0 ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                color: improvement >= 0 ? AppColors.success : AppColors.error,
                size: 32,
              ),
              const SizedBox(width: 12),
              Text(
                '${improvement >= 0 ? '+' : ''}${improvement.toStringAsFixed(1)}%',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: improvement >= 0 ? AppColors.success : AppColors.error,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'from last test',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ],
          ),
        ],
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}
