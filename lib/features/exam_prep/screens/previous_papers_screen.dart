/// Previous Year Papers Screen
/// Browse and attempt previous year question papers by exam and year

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/exam_prep_theme.dart';
import '../data/exam_categories.dart';
import '../data/question_bank_data.dart';

class PreviousPapersScreen extends StatefulWidget {
  const PreviousPapersScreen({super.key});

  @override
  State<PreviousPapersScreen> createState() => _PreviousPapersScreenState();
}

class _PreviousPapersScreenState extends State<PreviousPapersScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  String? _selectedExamCategory;
  String? _selectedExamType;
  int? _selectedYear;

  final List<int> _availableYears = [2024, 2023, 2022, 2021, 2020, 2019, 2018];

  final List<Map<String, dynamic>> _examCategories = [
    {'id': 'banking', 'name': 'Banking', 'icon': Icons.account_balance, 'color': ExamPrepTheme.banking},
    {'id': 'ssc', 'name': 'SSC', 'icon': Icons.work, 'color': ExamPrepTheme.ssc},
    {'id': 'railways', 'name': 'Railways', 'icon': Icons.train, 'color': ExamPrepTheme.railways},
    {'id': 'upsc', 'name': 'UPSC', 'icon': Icons.assured_workload, 'color': ExamPrepTheme.statePsc},
    {'id': 'state_psc', 'name': 'State PSC', 'icon': Icons.location_city, 'color': const Color(0xFFF97316)},
    {'id': 'defense', 'name': 'Defense', 'icon': Icons.military_tech, 'color': ExamPrepTheme.defense},
  ];

  final Map<String, List<Map<String, String>>> _examTypes = {
    'banking': [
      {'id': 'ibps_po', 'name': 'IBPS PO'},
      {'id': 'ibps_clerk', 'name': 'IBPS Clerk'},
      {'id': 'sbi_po', 'name': 'SBI PO'},
      {'id': 'sbi_clerk', 'name': 'SBI Clerk'},
      {'id': 'rbi_grade_b', 'name': 'RBI Grade B'},
    ],
    'ssc': [
      {'id': 'ssc_cgl', 'name': 'SSC CGL'},
      {'id': 'ssc_chsl', 'name': 'SSC CHSL'},
      {'id': 'ssc_mts', 'name': 'SSC MTS'},
      {'id': 'ssc_gd', 'name': 'SSC GD'},
    ],
    'railways': [
      {'id': 'rrb_ntpc', 'name': 'RRB NTPC'},
      {'id': 'rrb_group_d', 'name': 'RRB Group D'},
      {'id': 'rrb_alp', 'name': 'RRB ALP'},
      {'id': 'rrb_je', 'name': 'RRB JE'},
    ],
    'upsc': [
      {'id': 'upsc_prelims', 'name': 'UPSC Prelims'},
      {'id': 'upsc_csat', 'name': 'UPSC CSAT'},
      {'id': 'cds', 'name': 'CDS'},
      {'id': 'nda', 'name': 'NDA'},
    ],
    'state_psc': [
      {'id': 'uppsc', 'name': 'UPPSC'},
      {'id': 'bpsc', 'name': 'BPSC'},
      {'id': 'mppsc', 'name': 'MPPSC'},
      {'id': 'rpsc', 'name': 'RPSC'},
    ],
    'defense': [
      {'id': 'cds', 'name': 'CDS'},
      {'id': 'nda', 'name': 'NDA'},
      {'id': 'capf', 'name': 'CAPF'},
      {'id': 'afcat', 'name': 'AFCAT'},
    ],
  };

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
    _fadeController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: ExamPrepTheme.getBackground(context),
      appBar: AppBar(
        backgroundColor: ExamPrepTheme.statePsc,
        elevation: 0,
        title: const Text('Previous Year Papers', style: TextStyle(color: Colors.white)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionTitle('Select Exam Category', Icons.category),
              const SizedBox(height: 12),
              _buildExamCategoryGrid(context, isDark),
              const SizedBox(height: 24),
              if (_selectedExamCategory != null) ...[
                _buildSectionTitle('Select Exam', Icons.quiz),
                const SizedBox(height: 12),
                _buildExamTypeList(context, isDark),
                const SizedBox(height: 24),
              ],
              if (_selectedExamType != null) ...[
                _buildSectionTitle('Select Year', Icons.calendar_today),
                const SizedBox(height: 12),
                _buildYearSelector(context, isDark),
                const SizedBox(height: 24),
              ],
              if (_selectedYear != null) ...[
                _buildSectionTitle('Available Papers', Icons.description),
                const SizedBox(height: 12),
                _buildPapersList(context, isDark),
              ],
              const SizedBox(height: 100),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: ExamPrepTheme.primary, size: 20),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            color: ExamPrepTheme.getTextPrimary(context),
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildExamCategoryGrid(BuildContext context, bool isDark) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 1.0,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: _examCategories.length,
      itemBuilder: (context, index) {
        final category = _examCategories[index];
        final isSelected = _selectedExamCategory == category['id'];
        final color = category['color'] as Color;

        return GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            setState(() {
              _selectedExamCategory = category['id'];
              _selectedExamType = null;
              _selectedYear = null;
            });
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              gradient: isSelected
                  ? LinearGradient(
                      colors: [color, color.withOpacity(0.8)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : null,
              color: isSelected ? null : (isDark ? const Color(0xFF1E1E2E) : Colors.white),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected ? color : (isDark ? Colors.white12 : Colors.grey.shade200),
                width: isSelected ? 2 : 1,
              ),
              boxShadow: isSelected
                  ? [BoxShadow(color: color.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4))]
                  : [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  category['icon'] as IconData,
                  color: isSelected ? Colors.white : color,
                  size: 32,
                ),
                const SizedBox(height: 8),
                Text(
                  category['name'] as String,
                  style: TextStyle(
                    color: isSelected ? Colors.white : ExamPrepTheme.getTextPrimary(context),
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildExamTypeList(BuildContext context, bool isDark) {
    final exams = _examTypes[_selectedExamCategory] ?? [];
    final categoryColor = _examCategories
        .firstWhere((c) => c['id'] == _selectedExamCategory)['color'] as Color;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: exams.map((exam) {
        final isSelected = _selectedExamType == exam['id'];
        return GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            setState(() {
              _selectedExamType = exam['id'];
              _selectedYear = null;
            });
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              gradient: isSelected
                  ? LinearGradient(colors: [categoryColor, categoryColor.withOpacity(0.8)])
                  : null,
              color: isSelected ? null : (isDark ? const Color(0xFF1E1E2E) : Colors.white),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected ? categoryColor : (isDark ? Colors.white12 : Colors.grey.shade300),
              ),
            ),
            child: Text(
              exam['name']!,
              style: TextStyle(
                color: isSelected ? Colors.white : ExamPrepTheme.getTextPrimary(context),
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildYearSelector(BuildContext context, bool isDark) {
    final categoryColor = _examCategories
        .firstWhere((c) => c['id'] == _selectedExamCategory)['color'] as Color;

    return SizedBox(
      height: 50,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _availableYears.length,
        itemBuilder: (context, index) {
          final year = _availableYears[index];
          final isSelected = _selectedYear == year;

          return GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              setState(() {
                _selectedYear = year;
              });
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                gradient: isSelected
                    ? LinearGradient(colors: [categoryColor, categoryColor.withOpacity(0.8)])
                    : null,
                color: isSelected ? null : (isDark ? const Color(0xFF1E1E2E) : Colors.white),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected ? categoryColor : (isDark ? Colors.white12 : Colors.grey.shade300),
                ),
                boxShadow: isSelected
                    ? [BoxShadow(color: categoryColor.withOpacity(0.3), blurRadius: 8)]
                    : null,
              ),
              child: Text(
                year.toString(),
                style: TextStyle(
                  color: isSelected ? Colors.white : ExamPrepTheme.getTextPrimary(context),
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPapersList(BuildContext context, bool isDark) {
    final categoryColor = _examCategories
        .firstWhere((c) => c['id'] == _selectedExamCategory)['color'] as Color;
    final examName = _examTypes[_selectedExamCategory]!
        .firstWhere((e) => e['id'] == _selectedExamType)['name']!;

    final papers = [
      {
        'shift': 'Shift 1',
        'date': '15 Jan $_selectedYear',
        'questions': 100,
        'duration': 60,
        'attempted': false,
      },
      {
        'shift': 'Shift 2',
        'date': '15 Jan $_selectedYear',
        'questions': 100,
        'duration': 60,
        'attempted': true,
        'score': 72,
      },
      {
        'shift': 'Shift 3',
        'date': '16 Jan $_selectedYear',
        'questions': 100,
        'duration': 60,
        'attempted': false,
      },
      {
        'shift': 'Shift 4',
        'date': '16 Jan $_selectedYear',
        'questions': 100,
        'duration': 60,
        'attempted': true,
        'score': 85,
      },
    ];

    return Column(
      children: papers.map((paper) {
        final attempted = paper['attempted'] as bool;
        final score = paper['score'] as int?;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isDark ? Colors.white12 : Colors.grey.shade200),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => _startPaper(context, examName, paper),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [categoryColor, categoryColor.withOpacity(0.7)],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.description, color: Colors.white),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$examName - ${paper['shift']}',
                            style: TextStyle(
                              color: ExamPrepTheme.getTextPrimary(context),
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${paper['date']} • ${paper['questions']} Questions • ${paper['duration']} min',
                            style: TextStyle(
                              color: ExamPrepTheme.getTextSecondary(context),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (attempted && score != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: score >= 70 ? ExamPrepTheme.success.withOpacity(0.1) : ExamPrepTheme.warning.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '$score%',
                          style: TextStyle(
                            color: score >= 70 ? ExamPrepTheme.success : ExamPrepTheme.warning,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: [categoryColor, categoryColor.withOpacity(0.8)]),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'Start',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  void _startPaper(BuildContext context, String examName, Map<String, dynamic> paper) {
    HapticFeedback.mediumImpact();
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildStartPaperSheet(context, examName, paper),
    );
  }

  Widget _buildStartPaperSheet(BuildContext context, String examName, Map<String, dynamic> paper) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final categoryColor = _examCategories
        .firstWhere((c) => c['id'] == _selectedExamCategory)['color'] as Color;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A2E) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade400,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),
          Icon(Icons.description, size: 48, color: categoryColor),
          const SizedBox(height: 16),
          Text(
            '$examName - ${paper['shift']}',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: ExamPrepTheme.getTextPrimary(context),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${paper['date']} • $_selectedYear',
            style: TextStyle(
              color: ExamPrepTheme.getTextSecondary(context),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildInfoChip(Icons.help_outline, '${paper['questions']} Q', isDark),
              _buildInfoChip(Icons.timer, '${paper['duration']} min', isDark),
              _buildInfoChip(Icons.star, '${paper['questions']} marks', isDark),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    side: BorderSide(color: categoryColor),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text('View Solutions', style: TextStyle(color: categoryColor)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _navigateToTest(context, examName, paper);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: categoryColor,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Start Test', style: TextStyle(color: Colors.white)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String text, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.1) : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: ExamPrepTheme.getTextSecondary(context)),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              color: ExamPrepTheme.getTextPrimary(context),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  void _navigateToTest(BuildContext context, String examName, Map<String, dynamic> paper) {
    // Generate questions for the paper
    final questions = QuestionBank.getRandomQuestions(count: paper['questions'] as int);
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Starting $examName - ${paper['shift']}...'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: ExamPrepTheme.success,
      ),
    );
    
    // In production, navigate to MockTestScreen with the paper data
  }
}
