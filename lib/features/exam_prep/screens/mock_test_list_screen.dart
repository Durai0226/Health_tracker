import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/exam_prep_theme.dart';
import '../models/study_material_model.dart';
import '../data/exam_categories.dart';
import 'mock_test_screen.dart';

/// Mock Test List Screen - Browse and start mock tests
class MockTestListScreen extends StatefulWidget {
  const MockTestListScreen({super.key});

  @override
  State<MockTestListScreen> createState() => _MockTestListScreenState();
}

class _MockTestListScreenState extends State<MockTestListScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _selectedCategory = 'all';

  final List<MockTest> _mockTests = [
    MockTest(
      id: 'mt_ibps_po_1',
      title: 'IBPS PO Prelims Mock 1',
      description: 'Full-length prelims mock test',
      examId: 'ibps_po',
      type: MockTestType.fullLength,
      totalQuestions: 100,
      totalMarks: 100,
      durationMinutes: 60,
      sections: [
        const MockTestSection(id: 's1', name: 'Reasoning', subjectId: 'reasoning', questionCount: 35, marks: 35),
        const MockTestSection(id: 's2', name: 'Quant', subjectId: 'quant', questionCount: 35, marks: 35),
        const MockTestSection(id: 's3', name: 'English', subjectId: 'english', questionCount: 30, marks: 30),
      ],
      createdAt: DateTime.now(),
    ),
    MockTest(
      id: 'mt_ibps_po_2',
      title: 'IBPS PO Prelims Mock 2',
      description: 'Full-length prelims mock test',
      examId: 'ibps_po',
      type: MockTestType.fullLength,
      totalQuestions: 100,
      totalMarks: 100,
      durationMinutes: 60,
      sections: [
        const MockTestSection(id: 's1', name: 'Reasoning', subjectId: 'reasoning', questionCount: 35, marks: 35),
        const MockTestSection(id: 's2', name: 'Quant', subjectId: 'quant', questionCount: 35, marks: 35),
        const MockTestSection(id: 's3', name: 'English', subjectId: 'english', questionCount: 30, marks: 30),
      ],
      isAttempted: true,
      attemptCount: 1,
      createdAt: DateTime.now().subtract(const Duration(days: 7)),
    ),
    MockTest(
      id: 'mt_ssc_cgl_1',
      title: 'SSC CGL Tier 1 Mock 1',
      description: 'Combined Graduate Level mock',
      examId: 'ssc_cgl',
      type: MockTestType.fullLength,
      totalQuestions: 100,
      totalMarks: 200,
      durationMinutes: 60,
      sections: [
        const MockTestSection(id: 's1', name: 'GI & Reasoning', subjectId: 'reasoning', questionCount: 25, marks: 50),
        const MockTestSection(id: 's2', name: 'GK', subjectId: 'gk', questionCount: 25, marks: 50),
        const MockTestSection(id: 's3', name: 'Quant', subjectId: 'quant', questionCount: 25, marks: 50),
        const MockTestSection(id: 's4', name: 'English', subjectId: 'english', questionCount: 25, marks: 50),
      ],
      createdAt: DateTime.now(),
      isPremium: true,
    ),
    MockTest(
      id: 'mt_rrb_ntpc_1',
      title: 'RRB NTPC CBT 1 Mock',
      description: 'Railway NTPC first stage',
      examId: 'rrb_ntpc',
      type: MockTestType.fullLength,
      totalQuestions: 100,
      totalMarks: 100,
      durationMinutes: 90,
      sections: [
        const MockTestSection(id: 's1', name: 'GK', subjectId: 'gk', questionCount: 40, marks: 40),
        const MockTestSection(id: 's2', name: 'Mathematics', subjectId: 'quant', questionCount: 30, marks: 30),
        const MockTestSection(id: 's3', name: 'Reasoning', subjectId: 'reasoning', questionCount: 30, marks: 30),
      ],
      createdAt: DateTime.now(),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  List<MockTest> get _filteredTests {
    if (_selectedCategory == 'all') return _mockTests;
    return _mockTests.where((t) {
      final exam = ExamData.getExamById(t.examId);
      return exam?.categoryId == _selectedCategory;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: ExamPrepTheme.getBackground(context),
      appBar: AppBar(
        backgroundColor: ExamPrepTheme.reasoning,
        elevation: 0,
        title: const Text('Mock Tests', style: TextStyle(color: Colors.white)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          tabs: const [
            Tab(text: 'All Tests'),
            Tab(text: 'Attempted'),
            Tab(text: 'Bookmarked'),
          ],
        ),
      ),
      body: Column(
        children: [
          _buildCategoryFilter(context, isDark),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildTestList(_filteredTests),
                _buildTestList(_filteredTests.where((t) => t.isAttempted).toList()),
                _buildEmptyState('No bookmarked tests'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryFilter(BuildContext context, bool isDark) {
    final categories = [
      {'id': 'all', 'name': 'All', 'color': ExamPrepTheme.primary},
      {'id': 'banking', 'name': 'Banking', 'color': ExamPrepTheme.banking},
      {'id': 'ssc', 'name': 'SSC', 'color': ExamPrepTheme.ssc},
      {'id': 'railways', 'name': 'Railways', 'color': ExamPrepTheme.railways},
    ];

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: categories.map((cat) {
            final isSelected = _selectedCategory == cat['id'];
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  setState(() {
                    _selectedCategory = cat['id'] as String;
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? (cat['color'] as Color)
                        : (cat['color'] as Color).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: (cat['color'] as Color).withOpacity(isSelected ? 0 : 0.3),
                    ),
                  ),
                  child: Text(
                    cat['name'] as String,
                    style: TextStyle(
                      color: isSelected ? Colors.white : cat['color'] as Color,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildTestList(List<MockTest> tests) {
    if (tests.isEmpty) {
      return _buildEmptyState('No tests found');
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: tests.length,
      itemBuilder: (context, index) {
        return _buildTestCard(context, tests[index]);
      },
    );
  }

  Widget _buildTestCard(BuildContext context, MockTest test) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final exam = ExamData.getExamById(test.examId);
    final categoryColor = _getCategoryColor(exam?.categoryId ?? 'banking');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  categoryColor.withOpacity(0.15),
                  categoryColor.withOpacity(0.05),
                ],
              ),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [categoryColor, categoryColor.withOpacity(0.7)],
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.assignment, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              test.title,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                          ),
                          if (test.isPremium)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
                                ),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Text(
                                'PRO',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        test.description,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white54 : Colors.black45,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Info row
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                _buildInfoChip(Icons.quiz_outlined, '${test.totalQuestions} Q'),
                const SizedBox(width: 12),
                _buildInfoChip(Icons.timer_outlined, '${test.durationMinutes} min'),
                const SizedBox(width: 12),
                _buildInfoChip(Icons.grade_outlined, '${test.totalMarks} marks'),
                const Spacer(),
                if (test.isAttempted)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: ExamPrepTheme.success.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle, size: 14, color: ExamPrepTheme.success),
                        const SizedBox(width: 4),
                        Text(
                          'Attempted',
                          style: TextStyle(
                            fontSize: 11,
                            color: ExamPrepTheme.success,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          // Sections
          if (test.sections.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withOpacity(0.03) : Colors.grey.shade50,
              ),
              child: Row(
                children: test.sections.map((section) {
                  return Expanded(
                    child: _buildSectionChip(section),
                  );
                }).toList(),
              ),
            ),
          // Action button
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  HapticFeedback.mediumImpact();
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => MockTestScreen(mockTest: test),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: categoryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  test.isAttempted ? 'Reattempt' : 'Start Test',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String text) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: isDark ? Colors.white54 : Colors.black45),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(
            fontSize: 12,
            color: isDark ? Colors.white54 : Colors.black45,
          ),
        ),
      ],
    );
  }

  Widget _buildSectionChip(MockTestSection section) {
    final color = _getSubjectColor(section.subjectId);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '${section.name}: ${section.questionCount}',
        style: TextStyle(
          fontSize: 10,
          color: color,
          fontWeight: FontWeight.w500,
        ),
        textAlign: TextAlign.center,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.assignment_outlined,
            size: 64,
            color: Colors.grey.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Color _getCategoryColor(String categoryId) {
    switch (categoryId) {
      case 'banking':
        return ExamPrepTheme.banking;
      case 'ssc':
        return ExamPrepTheme.ssc;
      case 'railways':
        return ExamPrepTheme.railways;
      default:
        return ExamPrepTheme.primary;
    }
  }

  Color _getSubjectColor(String subjectId) {
    switch (subjectId) {
      case 'quant':
        return ExamPrepTheme.quantitative;
      case 'reasoning':
        return ExamPrepTheme.reasoning;
      case 'english':
        return ExamPrepTheme.english;
      case 'gk':
        return ExamPrepTheme.generalAwareness;
      default:
        return ExamPrepTheme.primary;
    }
  }
}
