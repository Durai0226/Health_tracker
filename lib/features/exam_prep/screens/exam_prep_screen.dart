import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../models/exam_type.dart';
import '../models/study_subject.dart';
import '../models/mock_test.dart';
import '../models/study_session.dart';
import '../services/exam_prep_service.dart';
import 'add_exam_screen.dart';
import 'study_session_screen.dart';
import 'mock_test_screen.dart';
import 'subject_detail_screen.dart';
import 'exam_analytics_screen.dart';

class ExamPrepScreen extends StatefulWidget {
  const ExamPrepScreen({super.key});

  @override
  State<ExamPrepScreen> createState() => _ExamPrepScreenState();
}

class _ExamPrepScreenState extends State<ExamPrepScreen> {
  final ExamPrepService _service = ExamPrepService();

  @override
  void initState() {
    super.initState();
    _service.init();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _service,
      builder: (context, _) {
        if (_service.exams.isEmpty) {
          return _buildEmptyState();
        }
        return _buildMainContent();
      },
    );
  }

  Widget _buildEmptyState() {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('📚', style: TextStyle(fontSize: 80)),
                const SizedBox(height: 24),
                Text(
                  'Start Your Exam Prep Journey',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  'Add your target exam and track your preparation progress',
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                ElevatedButton.icon(
                  onPressed: () => _navigateToAddExam(),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Add Your Exam'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMainContent() {
    final activeExam = _service.activeExam;
    
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(activeExam),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 100),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (activeExam != null) ...[
                      _buildCountdownCard(activeExam),
                      const SizedBox(height: 20),
                      _buildQuickActions(),
                      const SizedBox(height: 24),
                      _buildTodayStats(),
                      const SizedBox(height: 24),
                      _buildSubjectsSection(activeExam),
                      const SizedBox(height: 24),
                      _buildRecentMockTests(activeExam),
                      const SizedBox(height: 24),
                      _buildStreakCard(),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 80),
        child: FloatingActionButton.extended(
          onPressed: () => _showStartStudySheet(),
          backgroundColor: AppColors.primary,
          icon: const Icon(Icons.play_arrow_rounded),
          label: const Text('Start Studying'),
        ),
      ),
    );
  }

  Widget _buildHeader(ExamType? activeExam) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => _showExamSelector(),
              child: Row(
                children: [
                  if (activeExam != null) ...[
                    Text(
                      activeExam.category.emoji,
                      style: const TextStyle(fontSize: 28),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                activeExam?.name ?? 'Select Exam',
                                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(Icons.keyboard_arrow_down_rounded, size: 20),
                          ],
                        ),
                        if (activeExam?.examDate != null)
                          Text(
                            DateFormat('MMM d, yyyy').format(activeExam!.examDate!),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          _buildHeaderButton(
            icon: Icons.analytics_rounded,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ExamAnalyticsScreen()),
            ),
          ),
          const SizedBox(width: 8),
          _buildHeaderButton(
            icon: Icons.add_rounded,
            onTap: () => _navigateToAddExam(),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderButton({required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(icon, color: AppColors.primary, size: 22),
      ),
    );
  }

  Widget _buildCountdownCard(ExamType exam) {
    final daysLeft = exam.daysUntilExam;
    final isUpcoming = exam.isUpcoming;
    
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            exam.category.color,
            exam.category.color.withOpacity(0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: exam.category.color.withOpacity(0.4),
            blurRadius: 20,
            offset: const Offset(0, 8),
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
                    isUpcoming ? 'Days Until Exam' : 'Exam Date',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withOpacity(0.9),
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (isUpcoming)
                    Text(
                      '$daysLeft',
                      style: const TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    )
                  else
                    Text(
                      exam.examDate != null 
                          ? DateFormat('MMM d').format(exam.examDate!)
                          : 'Not Set',
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                ],
              ),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Text(
                      '${_service.totalStudyHours}',
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      'Hours Studied',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (daysLeft > 0 && daysLeft <= 30) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.warning_rounded, color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    daysLeft <= 7 ? 'Final week! Stay focused!' : 'Less than a month to go!',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
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

  Widget _buildQuickActions() {
    return Row(
      children: [
        Expanded(
          child: _buildActionCard(
            icon: Icons.menu_book_rounded,
            label: 'Study',
            color: AppColors.primary,
            onTap: () => _showStartStudySheet(),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildActionCard(
            icon: Icons.assignment_rounded,
            label: 'Mock Test',
            color: AppColors.warning,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const MockTestScreen()),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildActionCard(
            icon: Icons.replay_rounded,
            label: 'Revision',
            color: AppColors.info,
            onTap: () => _startQuickSession(StudyType.revision),
          ),
        ),
      ],
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTodayStats() {
    final todayMinutes = _service.getTodayStudyMinutes();
    final weekMinutes = _service.getWeekStudyMinutes();
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Study Progress',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  icon: Icons.today_rounded,
                  value: '${todayMinutes ~/ 60}h ${todayMinutes % 60}m',
                  label: 'Today',
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatItem(
                  icon: Icons.date_range_rounded,
                  value: '${weekMinutes ~/ 60}h',
                  label: 'This Week',
                  color: AppColors.info,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatItem(
                  icon: Icons.assignment_turned_in_rounded,
                  value: '${_service.mockTests.length}',
                  label: 'Mock Tests',
                  color: AppColors.warning,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
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

  Widget _buildSubjectsSection(ExamType exam) {
    final subjects = _service.getSubjectsForExam(exam.id);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Subjects',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            GestureDetector(
              onTap: () => _showAddSubjectSheet(),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add_rounded, color: AppColors.primary, size: 18),
                    SizedBox(width: 4),
                    Text(
                      'Add',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (subjects.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Center(
              child: Column(
                children: [
                  Text('📖', style: TextStyle(fontSize: 32)),
                  SizedBox(height: 8),
                  Text(
                    'Add subjects to track your progress',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          )
        else
          ...subjects.map((subject) => _buildSubjectCard(subject)),
      ],
    );
  }

  Widget _buildSubjectCard(StudySubject subject) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => SubjectDetailScreen(subject: subject)),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: subject.color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      subject.name.substring(0, 1).toUpperCase(),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: subject.color,
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
                        subject.name,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '${subject.completedHours}/${subject.targetHours} hours',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${(subject.progressPercent * 100).toInt()}%',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: subject.color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: subject.progressPercent,
                backgroundColor: Colors.grey.shade100,
                valueColor: AlwaysStoppedAnimation(subject.color),
                minHeight: 6,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentMockTests(ExamType exam) {
    final tests = _service.getRecentMockTests(exam.id);
    if (tests.isEmpty) return const SizedBox();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Recent Mock Tests',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const MockTestScreen()),
              ),
              child: const Text(
                'See All',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...tests.take(3).map((test) => _buildMockTestCard(test)),
      ],
    );
  }

  Widget _buildMockTestCard(MockTest test) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: _getGradeColor(test.grade).withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                test.grade,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: _getGradeColor(test.grade),
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
                  test.name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  DateFormat('MMM d, yyyy').format(test.attemptedAt),
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
                '${test.scoredMarks}/${test.totalMarks}',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '${test.percentageScore.toStringAsFixed(1)}%',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _getGradeColor(String grade) {
    switch (grade) {
      case 'A+':
      case 'A':
        return AppColors.success;
      case 'B+':
      case 'B':
        return AppColors.info;
      case 'C':
        return AppColors.warning;
      default:
        return AppColors.error;
    }
  }

  Widget _buildStreakCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.warning,
            AppColors.warning.withOpacity(0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          const Text('🔥', style: TextStyle(fontSize: 40)),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_service.currentStreak} Day Streak',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  'Longest: ${_service.longestStreak} days',
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
    );
  }

  void _navigateToAddExam() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddExamScreen()),
    );
  }

  void _showExamSelector() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Select Exam',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ...List.generate(_service.exams.length, (index) {
              final exam = _service.exams[index];
              final isActive = exam.id == _service.activeExamId;
              return ListTile(
                leading: Text(exam.category.emoji, style: const TextStyle(fontSize: 24)),
                title: Text(exam.name),
                subtitle: exam.examDate != null
                    ? Text(DateFormat('MMM d, yyyy').format(exam.examDate!))
                    : null,
                trailing: isActive
                    ? const Icon(Icons.check_circle_rounded, color: AppColors.primary)
                    : null,
                onTap: () {
                  _service.setActiveExam(exam.id);
                  Navigator.pop(context);
                },
              );
            }),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  void _showStartStudySheet() {
    final subjects = _service.activeExamId != null
        ? _service.getSubjectsForExam(_service.activeExamId!)
        : <StudySubject>[];
    
    if (subjects.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add subjects first'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const StudySessionScreen()),
    );
  }

  void _showAddSubjectSheet() {
    final nameController = TextEditingController();
    final hoursController = TextEditingController(text: '50');
    int selectedColorIndex = 0;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Add Subject',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 20),
                      TextField(
                        controller: nameController,
                        decoration: const InputDecoration(
                          labelText: 'Subject Name',
                          hintText: 'e.g., Mathematics, Physics',
                        ),
                        textCapitalization: TextCapitalization.words,
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: hoursController,
                        decoration: const InputDecoration(
                          labelText: 'Target Hours',
                          hintText: 'e.g., 50',
                        ),
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Color',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 10,
                        children: List.generate(SubjectColors.colors.length, (index) {
                          final color = SubjectColors.colors[index];
                          final isSelected = selectedColorIndex == index;
                          return GestureDetector(
                            onTap: () => setState(() => selectedColorIndex = index),
                            child: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                                border: isSelected
                                    ? Border.all(color: Colors.white, width: 3)
                                    : null,
                                boxShadow: isSelected
                                    ? [BoxShadow(color: color, blurRadius: 8)]
                                    : null,
                              ),
                              child: isSelected
                                  ? const Icon(Icons.check, color: Colors.white, size: 20)
                                  : null,
                            ),
                          );
                        }),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {
                            if (nameController.text.isNotEmpty) {
                              final subject = StudySubject(
                                id: _service.generateId(),
                                name: nameController.text,
                                examId: _service.activeExamId!,
                                color: SubjectColors.colors[selectedColorIndex],
                                targetHours: int.tryParse(hoursController.text) ?? 50,
                                createdAt: DateTime.now(),
                              );
                              _service.addSubject(subject);
                              Navigator.pop(context);
                            }
                          },
                          child: const Text('Add Subject'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _startQuickSession(StudyType type) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StudySessionScreen(initialStudyType: type),
      ),
    );
  }
}
