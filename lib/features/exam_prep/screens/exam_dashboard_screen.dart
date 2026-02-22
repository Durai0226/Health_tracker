import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/exam_prep_service.dart';
import '../models/exam_model.dart';
import '../models/study_session_model.dart';
import '../models/study_analytics_model.dart';
import 'exam_list_screen.dart';
import 'subject_list_screen.dart';
import 'study_session_screen.dart';
import 'study_analytics_screen.dart';
import 'add_exam_screen.dart';

class ExamDashboardScreen extends StatefulWidget {
  const ExamDashboardScreen({super.key});

  @override
  State<ExamDashboardScreen> createState() => _ExamDashboardScreenState();
}

class _ExamDashboardScreenState extends State<ExamDashboardScreen> {
  final ExamPrepService _examPrepService = ExamPrepService();

  @override
  void initState() {
    super.initState();
    _initService();
  }

  Future<void> _initService() async {
    if (!_examPrepService.isInitialized) {
      await _examPrepService.init();
      if (mounted) setState(() {});
    }
    _examPrepService.addListener(_onServiceUpdate);
  }

  void _onServiceUpdate() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _examPrepService.removeListener(_onServiceUpdate);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final todayStats = _examPrepService.getTodayStats();
    final upcomingExams = _examPrepService.getUpcomingExams(days: 14);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Dashboard',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: false,
        elevation: 0,
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            icon: const Icon(Icons.analytics_outlined),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const StudyAnalyticsScreen()),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            await _examPrepService.syncFromCloud();
          },
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Text(
                    _getGreeting(),
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(child: const SizedBox(height: 16)),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _buildTodayProgressCard(theme, todayStats),
                ),
              ),
              SliverToBoxAdapter(child: const SizedBox(height: 16)),
              SliverToBoxAdapter(
                child: _buildQuickActions(theme),
              ),
              SliverToBoxAdapter(child: const SizedBox(height: 16)),
              if (_examPrepService.hasActiveSession)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _buildActiveSessionCard(theme),
                  ),
                ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _buildSectionHeader(theme, 'Upcoming Exams', onSeeAll: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ExamListScreen()),
                    );
                  }),
                ),
              ),
              SliverToBoxAdapter(child: const SizedBox(height: 12)),
              if (upcomingExams.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _buildEmptyState(
                      theme,
                      icon: Icons.event_note,
                      message: 'No upcoming exams',
                      actionLabel: 'Add Exam',
                      onAction: () => _navigateToAddExam(),
                    ),
                  ),
                )
              else
                ...upcomingExams.take(3).map((exam) => SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _buildExamCard(theme, exam),
                  ),
                )),
              SliverToBoxAdapter(child: const SizedBox(height: 16)),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _buildSectionHeader(theme, 'Recent Sessions', onSeeAll: () {}),
                ),
              ),
              SliverToBoxAdapter(child: const SizedBox(height: 12)),
              ..._examPrepService.studySessions
                  .take(5)
                  .map((session) => SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: _buildSessionCard(theme, session),
                    ),
                  )),
              SliverToBoxAdapter(child: const SizedBox(height: 80)),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _startQuickStudy(),
        child: const Icon(Icons.play_arrow),
      ),
    );
  }

  Widget _buildTodayProgressCard(ThemeData theme, DailyStudyStats stats) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: theme.colorScheme.primary.withOpacity(0.12),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Today's Progress",
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  stats.goalAchieved ? '🎉 Goal Met!' : '${(stats.goalProgress * 100).toInt()}%',
                  style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${stats.totalMinutes}',
                      style: theme.textTheme.headlineLarge?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'minutes studied',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${stats.sessionCount}',
                      style: theme.textTheme.headlineLarge?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'sessions',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${stats.pomodoroCount}',
                      style: theme.textTheme.headlineLarge?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'pomodoros',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: stats.goalProgress,
              backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
              valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Goal: ${stats.goalMinutes} minutes',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions(ThemeData theme) {
    return SizedBox(
      height: 88,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          _buildCompactAction(theme, Icons.school, 'Subjects', () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const SubjectListScreen()),
          )),
          _buildCompactAction(theme, Icons.event, 'Exams', () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ExamListScreen()),
          )),
          _buildCompactAction(theme, Icons.timer, 'Pomodoro', () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const StudySessionScreen()),
          )),
          _buildCompactAction(theme, Icons.grade, 'Grades', () {}),
        ],
      ),
    );
  }

  Widget _buildCompactAction(
    ThemeData theme,
    IconData icon,
    String label,
    VoidCallback onTap,
  ) {
    return Container(
      width: 90,
      margin: const EdgeInsets.only(right: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.black.withOpacity(0.05)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 22),
              const SizedBox(height: 6),
              Text(
                label,
                style: theme.textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActiveSessionCard(ThemeData theme) {
    final remaining = _examPrepService.remainingSeconds;
    final mins = remaining ~/ 60;
    final secs = remaining % 60;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withOpacity(0.06),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(Icons.timer, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')} remaining',
              style: theme.textTheme.bodyMedium,
            ),
          ),
          TextButton(
            onPressed: () => _examPrepService.togglePauseResume(),
            child: Text(_examPrepService.isPaused ? 'Resume' : 'Pause'),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(ThemeData theme, String title, {VoidCallback? onSeeAll}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        if (onSeeAll != null)
          TextButton(
            onPressed: onSeeAll,
            child: const Text('See All'),
          ),
      ],
    );
  }

  Widget _buildExamCard(ThemeData theme, Exam exam) {
    final daysRemaining = exam.daysRemaining;
    final subject = _examPrepService.getSubjectById(exam.subjectId);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.black.withOpacity(0.05),
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: _getDaysColor(daysRemaining).withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '$daysRemaining',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: _getDaysColor(daysRemaining),
                ),
              ),
              Text(
                'days',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: _getDaysColor(daysRemaining),
                ),
              ),
            ],
          ),
        ),
        title: Text(
          exam.title,
          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              subject?.name ?? 'Unknown Subject',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 4),
            Text(
              DateFormat('MMM dd, yyyy • HH:mm').format(exam.examDate),
              style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: exam.studyProgress,
              backgroundColor: Colors.grey.withOpacity(0.2),
              valueColor: AlwaysStoppedAnimation<Color>(
                exam.studyProgress >= 1.0 ? Colors.green : theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Study Progress: ${(exam.studyProgress * 100).toInt()}%',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
        trailing: Text(
          exam.examType.emoji,
          style: const TextStyle(fontSize: 24),
        ),
      ),
    );
  }

  Widget _buildStreakInfo(ThemeData theme) {
    final analytics = _examPrepService.analytics;
    final currentStreak = analytics?.currentStreak ?? 0;
    final longestStreak = analytics?.longestStreak ?? 0;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          const Text('🔥'),
          const SizedBox(width: 8),
          Text(
            '$currentStreak day streak',
            style: theme.textTheme.bodyMedium,
          ),
          const Spacer(),
          Text(
            'Longest $longestStreak',
            style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionCard(ThemeData theme, dynamic session) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Text(session.sessionType.emoji, style: const TextStyle(fontSize: 24)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  session.sessionType.displayName,
                  style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
                ),
                Text(
                  DateFormat('MMM dd, HH:mm').format(session.startTime),
                  style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
                ),
              ],
            ),
          ),
          Text(
            '${session.actualMinutes} min',
            style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(
    ThemeData theme, {
    required IconData icon,
    required String message,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    return Container(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          Icon(icon, size: 48, color: Colors.grey),
          const SizedBox(height: 16),
          Text(
            message,
            style: theme.textTheme.bodyLarge?.copyWith(color: Colors.grey),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: onAction,
              child: Text(actionLabel),
            ),
          ],
        ],
      ),
    );
  }

  Color _getDaysColor(int days) {
    if (days <= 1) return Colors.red;
    if (days <= 3) return Colors.orange;
    if (days <= 7) return Colors.amber;
    return Colors.green;
  }

  void _navigateToAddExam() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddExamScreen()),
    );
  }

  void _startQuickStudy() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const StudySessionScreen()),
    );
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return "Good morning 👋";
    if (hour < 17) return "Keep going 💪";
    return "Great work today ✨";
  }
}
