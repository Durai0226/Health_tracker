import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
    with TickerProviderStateMixin {
  final ExamPrepService _examPrepService = ExamPrepService();
  late TabController _tabController;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  
  ExamStatus? _filterStatus;
  ExamType? _filterType;
  int _selectedTabIndex = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() => _selectedTabIndex = _tabController.index);
      }
    });
    _examPrepService.addListener(_onServiceUpdate);
    
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOutCubic,
    );
    _fadeController.forward();
  }

  void _onServiceUpdate() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _tabController.dispose();
    _fadeController.dispose();
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
      .toList()
    ..sort((a, b) => a.examDate.compareTo(b.examDate));

  List<Exam> get _completedExams => _filteredExams
      .where((e) => e.status == ExamStatus.completed)
      .toList()
    ..sort((a, b) => b.examDate.compareTo(a.examDate));

  List<Exam> get _allExams => _filteredExams
    ..sort((a, b) => a.examDate.compareTo(b.examDate));

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0A0A0F) : const Color(0xFFF8FAFC),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SafeArea(
          child: Column(
            children: [
              // Premium Header
              _buildPremiumHeader(theme),
              // Tab Selector
              _buildPremiumTabs(theme),
              // Content
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildExamList(_upcomingExams, theme, emptyMessage: 'No upcoming exams', emptyIcon: Icons.event_available_rounded),
                    _buildExamList(_completedExams, theme, emptyMessage: 'No completed exams', emptyIcon: Icons.check_circle_outline_rounded),
                    _buildExamList(_allExams, theme, emptyMessage: 'No exams yet', emptyIcon: Icons.event_note_rounded),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: _buildPremiumFAB(theme),
    );
  }

  Widget _buildPremiumHeader(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    final hasFilters = _filterStatus != null || _filterType != null;
    
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      child: Row(
        children: [
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              Navigator.pop(context);
            },
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: (isDark ? Colors.white : Colors.black).withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: (isDark ? Colors.white : Colors.black).withOpacity(0.1),
                    ),
                  ),
                  child: Icon(
                    Icons.arrow_back_rounded,
                    color: AppColors.getTextPrimary(context),
                    size: 20,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your Exams',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.getTextSecondary(context),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                ShaderMask(
                  shaderCallback: (bounds) => LinearGradient(
                    colors: [AppColors.warning, const Color(0xFFFF6B00)],
                  ).createShader(bounds),
                  child: Text(
                    'Exam Schedule',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Filter Button
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              _showFilterDialog();
            },
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: hasFilters
                            ? AppColors.primary.withOpacity(0.15)
                            : (isDark ? Colors.white : Colors.black).withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: hasFilters
                              ? AppColors.primary.withOpacity(0.3)
                              : (isDark ? Colors.white : Colors.black).withOpacity(0.1),
                        ),
                      ),
                      child: Icon(
                        Icons.tune_rounded,
                        color: hasFilters ? AppColors.primary : AppColors.getTextPrimary(context),
                        size: 20,
                      ),
                    ),
                  ),
                ),
                if (hasFilters)
                  Positioned(
                    top: 0,
                    right: 0,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                        border: Border.all(color: isDark ? const Color(0xFF0A0A0F) : const Color(0xFFF8FAFC), width: 2),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          // Calendar Button
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              _showCalendarView();
            },
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: (isDark ? Colors.white : Colors.black).withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: (isDark ? Colors.white : Colors.black).withOpacity(0.1),
                    ),
                  ),
                  child: Icon(
                    Icons.calendar_month_rounded,
                    color: AppColors.getTextPrimary(context),
                    size: 20,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPremiumTabs(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    final tabs = [
      {'label': 'Upcoming', 'count': _upcomingExams.length, 'color': AppColors.warning},
      {'label': 'Completed', 'count': _completedExams.length, 'color': AppColors.success},
      {'label': 'All', 'count': _allExams.length, 'color': AppColors.primary},
    ];
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: (isDark ? Colors.white : Colors.black).withOpacity(0.06),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: List.generate(tabs.length, (index) {
          final tab = tabs[index];
          final isSelected = _selectedTabIndex == index;
          
          return Expanded(
            child: GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                _tabController.animateTo(index);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  gradient: isSelected
                      ? LinearGradient(
                          colors: [
                            (tab['color'] as Color).withOpacity(0.15),
                            (tab['color'] as Color).withOpacity(0.08),
                          ],
                        )
                      : null,
                  borderRadius: BorderRadius.circular(12),
                  border: isSelected
                      ? Border.all(color: (tab['color'] as Color).withOpacity(0.2))
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      tab['label'] as String,
                      style: TextStyle(
                        color: isSelected
                            ? tab['color'] as Color
                            : AppColors.getTextSecondary(context),
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? (tab['color'] as Color).withOpacity(0.2)
                            : (isDark ? Colors.white : Colors.black).withOpacity(0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${tab['count']}',
                        style: TextStyle(
                          color: isSelected
                              ? tab['color'] as Color
                              : AppColors.getTextSecondary(context),
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildPremiumFAB(ThemeData theme) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        _navigateToAddExam();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppColors.warning, Color(0xFFFF6B00)],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppColors.warning.withOpacity(0.4),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.add_rounded, color: Colors.white, size: 22),
            const SizedBox(width: 8),
            Text(
              'Add Exam',
              style: theme.textTheme.labelLarge?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExamList(List<Exam> exams, ThemeData theme, {String? emptyMessage, IconData? emptyIcon}) {
    final isDark = theme.brightness == Brightness.dark;
    
    if (exams.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.warning.withOpacity(0.15),
                      AppColors.warning.withOpacity(0.08),
                    ],
                  ),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  emptyIcon ?? Icons.event_note_rounded,
                  size: 48,
                  color: AppColors.warning,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                emptyMessage ?? 'No exams',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: AppColors.getTextPrimary(context),
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Add your first exam to start tracking',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppColors.getTextSecondary(context),
                ),
              ),
              const SizedBox(height: 24),
              GestureDetector(
                onTap: () {
                  HapticFeedback.mediumImpact();
                  _navigateToAddExam();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.warning, Color(0xFFFF6B00)],
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.warning.withOpacity(0.4),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.add_rounded, color: Colors.white, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Add Exam',
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
      itemCount: exams.length,
      itemBuilder: (context, index) {
        final exam = exams[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _buildPremiumExamCard(exam, theme),
        );
      },
    );
  }

  Widget _buildPremiumExamCard(Exam exam, ThemeData theme) {
    final subject = _examPrepService.getSubjectById(exam.subjectId);
    final daysRemaining = exam.daysRemaining;
    final isDark = theme.brightness == Brightness.dark;
    final statusColor = _getStatusColor(exam.status);
    final daysColor = _getDaysColor(daysRemaining);

    return Dismissible(
      key: Key(exam.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Icon(Icons.delete_rounded, color: Colors.white, size: 28),
      ),
      confirmDismiss: (direction) async {
        HapticFeedback.mediumImpact();
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
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          _showExamDetails(exam);
        },
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? [
                      Colors.white.withOpacity(0.06),
                      Colors.white.withOpacity(0.03),
                    ]
                  : [
                      Colors.white,
                      statusColor.withOpacity(0.03),
                    ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: (isDark ? Colors.white : statusColor).withOpacity(0.1),
            ),
            boxShadow: [
              BoxShadow(
                color: statusColor.withOpacity(0.08),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Exam Type Icon
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [statusColor, statusColor.withOpacity(0.8)],
                      ),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: statusColor.withOpacity(0.4),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Text(
                      exam.examType.emoji,
                      style: const TextStyle(fontSize: 22),
                    ),
                  ),
                  const SizedBox(width: 14),
                  // Title and Subject
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          exam.title,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.getTextPrimary(context),
                            letterSpacing: -0.3,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            if (subject != null) ...[
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: Color(int.parse(subject.colorHex.replaceAll('#', '0xFF'))),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                            ],
                            Expanded(
                              child: Text(
                                subject?.name ?? 'Unknown Subject',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: AppColors.getTextSecondary(context),
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Days Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: daysColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Text(
                          exam.status == ExamStatus.completed
                              ? '✓'
                              : daysRemaining == 0
                                  ? 'Today'
                                  : '$daysRemaining',
                          style: TextStyle(
                            color: daysColor,
                            fontWeight: FontWeight.w800,
                            fontSize: exam.status == ExamStatus.completed || daysRemaining == 0 ? 14 : 18,
                          ),
                        ),
                        if (exam.status != ExamStatus.completed && daysRemaining > 0)
                          Text(
                            'days',
                            style: TextStyle(
                              color: daysColor,
                              fontWeight: FontWeight.w600,
                              fontSize: 10,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Date and Location Row
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: (isDark ? Colors.white : Colors.black).withOpacity(0.05),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.schedule_rounded, size: 14, color: AppColors.getTextSecondary(context)),
                        const SizedBox(width: 6),
                        Text(
                          DateFormat('EEE, MMM dd • HH:mm').format(exam.examDate),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.getTextSecondary(context),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (exam.location != null && exam.location!.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: (isDark ? Colors.white : Colors.black).withOpacity(0.05),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.location_on_rounded, size: 14, color: AppColors.getTextSecondary(context)),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                exam.location!,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: AppColors.getTextSecondary(context),
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              // Progress Bar
              if (exam.status != ExamStatus.completed) ...[
                const SizedBox(height: 16),
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
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: AppColors.getTextSecondary(context),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Text(
                                '${(exam.studyProgress * 100).toInt()}%',
                                style: TextStyle(
                                  color: statusColor,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Stack(
                            children: [
                              Container(
                                height: 6,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(3),
                                  color: statusColor.withOpacity(0.12),
                                ),
                              ),
                              FractionallySizedBox(
                                widthFactor: exam.studyProgress.clamp(0.0, 1.0),
                                child: Container(
                                  height: 6,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(3),
                                    gradient: LinearGradient(
                                      colors: [statusColor, statusColor.withOpacity(0.7)],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Quick Study Button
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        // Navigate to study session for this exam
                      },
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [AppColors.success, const Color(0xFF059669)],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.success.withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 20),
                      ),
                    ),
                  ],
                ),
              ] else ...[
                const SizedBox(height: 12),
                // Completed badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.success.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle_rounded, color: AppColors.success, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        exam.gradePercentage != null
                            ? 'Completed • ${exam.gradePercentage!.toStringAsFixed(0)}%'
                            : 'Completed',
                        style: TextStyle(
                          color: AppColors.success,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Color _getDaysColor(int days) {
    if (days <= 1) return const Color(0xFFEF4444);
    if (days <= 3) return AppColors.warning;
    if (days <= 7) return const Color(0xFFF59E0B);
    return AppColors.success;
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
