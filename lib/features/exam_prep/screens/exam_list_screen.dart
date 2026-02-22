import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/exam_prep_service.dart';
import '../models/exam_model.dart';
import 'add_exam_screen.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/common_tab_widgets.dart';
import '../../../core/widgets/common_widgets.dart';

class ExamListScreen extends StatefulWidget {
  const ExamListScreen({super.key});

  @override
  State<ExamListScreen> createState() => _ExamListScreenState();
}

class _ExamListScreenState extends State<ExamListScreen>
    with SingleTickerProviderStateMixin {
  final ExamPrepService _examPrepService = ExamPrepService();
  late TabController _tabController;
  ExamStatus? _filterStatus;
  ExamType? _filterType;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _examPrepService.addListener(_onServiceUpdate);
  }

  void _onServiceUpdate() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _tabController.dispose();
    _examPrepService.removeListener(_onServiceUpdate);
    super.dispose();
  }

  List<Exam> get _filteredExams {
    var exams = _examPrepService.exams;
    
    if (_filterStatus != null) {
      exams = exams.where((e) => e.status == _filterStatus).toList();
    }
    if (_filterType != null) {
      exams = exams.where((e) => e.examType == _filterType).toList();
    }
    
    return exams;
  }

  List<Exam> get _upcomingExams => _filteredExams
      .where((e) => e.status == ExamStatus.upcoming)
      .toList();

  List<Exam> get _completedExams => _filteredExams
      .where((e) => e.status == ExamStatus.completed)
      .toList();

  List<Exam> get _allExams => _filteredExams;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Exams'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterDialog,
          ),
          IconButton(
            icon: const Icon(Icons.calendar_month),
            onPressed: _showCalendarView,
          ),
        ],
        bottom: CommonTabBar(
          tabs: ['Upcoming (${_upcomingExams.length})', 'Completed (${_completedExams.length})', 'All (${_allExams.length})'],
          controller: _tabController,
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildExamList(_upcomingExams, theme, emptyMessage: 'No upcoming exams'),
          _buildExamList(_completedExams, theme, emptyMessage: 'No completed exams'),
          _buildExamList(_allExams, theme, emptyMessage: 'No exams yet'),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _navigateToAddExam(),
        icon: const Icon(Icons.add),
        label: const Text('Add Exam'),
      ),
    );
  }

  Widget _buildExamList(List<Exam> exams, ThemeData theme, {String? emptyMessage}) {
    if (exams.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.event_note, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              emptyMessage ?? 'No exams',
              style: theme.textTheme.titleMedium?.copyWith(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _navigateToAddExam,
              icon: const Icon(Icons.add),
              label: const Text('Add Exam'),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: exams.length,
      itemBuilder: (context, index) {
        final exam = exams[index];
        return _buildExamCard(exam, theme);
      },
    );
  }

  Widget _buildExamCard(Exam exam, ThemeData theme) {
    final subject = _examPrepService.getSubjectById(exam.subjectId);
    final daysRemaining = exam.daysRemaining;

    return Dismissible(
      key: Key(exam.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: Colors.red,
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (direction) async {
        return await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Delete Exam'),
            content: Text('Are you sure you want to delete "${exam.title}"?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Delete'),
              ),
            ],
          ),
        );
      },
      onDismissed: (direction) {
        _examPrepService.deleteExam(exam.id);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${exam.title} deleted')),
        );
      },
      child: Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: InkWell(
          onTap: () => _showExamDetails(exam),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _getStatusColor(exam.status).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        exam.examType.emoji,
                        style: const TextStyle(fontSize: 24),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            exam.title,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            subject?.name ?? 'Unknown Subject',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _buildStatusChip(exam, daysRemaining, theme),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text(
                      DateFormat('EEE, MMM dd, yyyy • HH:mm').format(exam.examDate),
                      style: theme.textTheme.bodySmall,
                    ),
                    const Spacer(),
                    if (exam.location != null) ...[
                      Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Text(
                        exam.location!,
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Study Progress',
                                style: theme.textTheme.bodySmall,
                              ),
                              Text(
                                '${(exam.studyProgress * 100).toInt()}%',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          LinearProgressIndicator(
                            value: exam.studyProgress,
                            backgroundColor: Colors.grey.withOpacity(0.2),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (exam.status == ExamStatus.completed && exam.obtainedMarks != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: (exam.isPassed ?? false)
                          ? Colors.green.withOpacity(0.1)
                          : Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Column(
                          children: [
                            Text(
                              '${exam.obtainedMarks}/${exam.totalMarks}',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text('Score', style: theme.textTheme.bodySmall),
                          ],
                        ),
                        Column(
                          children: [
                            Text(
                              '${exam.gradePercentage?.toStringAsFixed(1)}%',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text('Percentage', style: theme.textTheme.bodySmall),
                          ],
                        ),
                        Column(
                          children: [
                            Text(
                              exam.grade ?? '-',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text('Grade', style: theme.textTheme.bodySmall),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip(Exam exam, int daysRemaining, ThemeData theme) {
    if (exam.status == ExamStatus.completed) {
      return Chip(
        label: const Text('Completed'),
        backgroundColor: Colors.green.withOpacity(0.2),
        labelStyle: const TextStyle(color: Colors.green),
      );
    }

    if (daysRemaining <= 0) {
      return Chip(
        label: const Text('Today'),
        backgroundColor: Colors.red.withOpacity(0.2),
        labelStyle: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
      );
    }

    final color = _getDaysColor(daysRemaining);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        '$daysRemaining days',
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Color _getStatusColor(ExamStatus status) {
    switch (status) {
      case ExamStatus.upcoming:
        return Colors.blue;
      case ExamStatus.in_progress:
        return Colors.orange;
      case ExamStatus.completed:
        return Colors.green;
      case ExamStatus.missed:
        return Colors.red;
      case ExamStatus.cancelled:
        return Colors.grey;
    }
  }

  Color _getDaysColor(int days) {
    if (days <= 1) return Colors.red;
    if (days <= 3) return Colors.orange;
    if (days <= 7) return Colors.amber;
    return Colors.green;
  }

  void _showFilterDialog() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Filter Exams',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            Text('By Status', style: Theme.of(context).textTheme.titleSmall),
            Wrap(
              spacing: 8,
              children: [
                FilterChip(
                  label: const Text('All'),
                  selected: _filterStatus == null,
                  onSelected: (_) {
                    setState(() => _filterStatus = null);
                    Navigator.pop(context);
                  },
                ),
                ...ExamStatus.values.map((status) => FilterChip(
                      label: Text(status.displayName),
                      selected: _filterStatus == status,
                      onSelected: (_) {
                        setState(() => _filterStatus = status);
                        Navigator.pop(context);
                      },
                    )),
              ],
            ),
            const SizedBox(height: 16),
            Text('By Type', style: Theme.of(context).textTheme.titleSmall),
            Wrap(
              spacing: 8,
              children: [
                FilterChip(
                  label: const Text('All'),
                  selected: _filterType == null,
                  onSelected: (_) {
                    setState(() => _filterType = null);
                    Navigator.pop(context);
                  },
                ),
                ...ExamType.values.map((type) => FilterChip(
                      label: Text('${type.emoji} ${type.displayName}'),
                      selected: _filterType == type,
                      onSelected: (_) {
                        setState(() => _filterType = type);
                        Navigator.pop(context);
                      },
                    )),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showCalendarView() {
    // TODO: Implement calendar view
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Calendar view coming soon!')),
    );
  }

  void _showExamDetails(Exam exam) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddExamScreen(exam: exam),
      ),
    );
  }

  void _navigateToAddExam() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddExamScreen()),
    );
  }
}
