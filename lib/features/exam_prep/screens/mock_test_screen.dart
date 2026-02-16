import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../models/mock_test.dart';
import '../services/exam_prep_service.dart';

class MockTestScreen extends StatefulWidget {
  const MockTestScreen({super.key});

  @override
  State<MockTestScreen> createState() => _MockTestScreenState();
}

class _MockTestScreenState extends State<MockTestScreen> {
  final ExamPrepService _service = ExamPrepService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Mock Tests'),
      ),
      body: ListenableBuilder(
        listenable: _service,
        builder: (context, _) {
          final tests = _service.activeExamId != null
              ? _service.getMockTestsForExam(_service.activeExamId!)
              : <MockTest>[];

          if (tests.isEmpty) {
            return _buildEmptyState();
          }

          return ListView.builder(
            padding: const EdgeInsets.all(24),
            itemCount: tests.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) {
                return _buildAnalyticsSummary(tests);
              }
              return _buildTestCard(tests[index - 1]);
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddTestSheet,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Test'),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('📝', style: TextStyle(fontSize: 64)),
            const SizedBox(height: 16),
            const Text(
              'No Mock Tests Yet',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Track your mock test scores to analyze your progress',
              style: TextStyle(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _showAddTestSheet,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add Mock Test'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnalyticsSummary(List<MockTest> tests) {
    final avgScore = tests.isNotEmpty
        ? tests.map((t) => t.percentageScore).reduce((a, b) => a + b) / tests.length
        : 0.0;
    final improvement = _service.activeExamId != null 
        ? _service.getMockTestImprovement(_service.activeExamId!)
        : 0.0;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.4),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildSummaryStat(
                value: '${tests.length}',
                label: 'Tests Taken',
              ),
              _buildSummaryStat(
                value: '${avgScore.toStringAsFixed(1)}%',
                label: 'Avg Score',
              ),
              _buildSummaryStat(
                value: '${improvement >= 0 ? '+' : ''}${improvement.toStringAsFixed(1)}%',
                label: 'Last Change',
                isPositive: improvement >= 0,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryStat({
    required String value,
    required String label,
    bool? isPositive,
  }) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: isPositive != null
                ? (isPositive ? Colors.greenAccent : Colors.redAccent)
                : Colors.white,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.white.withOpacity(0.9),
          ),
        ),
      ],
    );
  }

  Widget _buildTestCard(MockTest test) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: _getGradeColor(test.grade).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: Text(
                    test.grade,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: _getGradeColor(test.grade),
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
                      test.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      DateFormat('MMMM d, yyyy').format(test.attemptedAt),
                      style: const TextStyle(
                        fontSize: 13,
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
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '${test.percentageScore.toStringAsFixed(1)}%',
                    style: TextStyle(
                      fontSize: 14,
                      color: _getGradeColor(test.grade),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildTestStat(
                icon: Icons.check_circle_outline_rounded,
                value: '${test.correctAnswers}',
                label: 'Correct',
                color: AppColors.success,
              ),
              const SizedBox(width: 16),
              _buildTestStat(
                icon: Icons.cancel_outlined,
                value: '${test.wrongAnswers}',
                label: 'Wrong',
                color: AppColors.error,
              ),
              const SizedBox(width: 16),
              _buildTestStat(
                icon: Icons.remove_circle_outline_rounded,
                value: '${test.unattempted}',
                label: 'Skipped',
                color: AppColors.textSecondary,
              ),
              const Spacer(),
              Text(
                'Accuracy: ${test.accuracy.toStringAsFixed(1)}%',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTestStat({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
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

  void _showAddTestSheet() {
    final nameController = TextEditingController();
    final totalMarksController = TextEditingController(text: '100');
    final scoredMarksController = TextEditingController();
    final totalQuestionsController = TextEditingController(text: '100');
    final correctController = TextEditingController();
    final wrongController = TextEditingController();
    DateTime selectedDate = DateTime.now();

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
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.85,
            ),
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
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Add Mock Test Result',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 20),
                        TextField(
                          controller: nameController,
                          decoration: const InputDecoration(
                            labelText: 'Test Name',
                            hintText: 'e.g., Mock Test #1',
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: totalMarksController,
                                decoration: const InputDecoration(
                                  labelText: 'Total Marks',
                                ),
                                keyboardType: TextInputType.number,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: TextField(
                                controller: scoredMarksController,
                                decoration: const InputDecoration(
                                  labelText: 'Scored Marks',
                                ),
                                keyboardType: TextInputType.number,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: totalQuestionsController,
                          decoration: const InputDecoration(
                            labelText: 'Total Questions',
                          ),
                          keyboardType: TextInputType.number,
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: correctController,
                                decoration: const InputDecoration(
                                  labelText: 'Correct',
                                ),
                                keyboardType: TextInputType.number,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: TextField(
                                controller: wrongController,
                                decoration: const InputDecoration(
                                  labelText: 'Wrong',
                                ),
                                keyboardType: TextInputType.number,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () {
                              if (nameController.text.isNotEmpty &&
                                  scoredMarksController.text.isNotEmpty) {
                                final totalMarks = int.tryParse(totalMarksController.text) ?? 100;
                                final scoredMarks = int.tryParse(scoredMarksController.text) ?? 0;
                                final totalQuestions = int.tryParse(totalQuestionsController.text) ?? 100;
                                final correct = int.tryParse(correctController.text) ?? 0;
                                final wrong = int.tryParse(wrongController.text) ?? 0;

                                final test = MockTest(
                                  id: _service.generateId(),
                                  examId: _service.activeExamId!,
                                  name: nameController.text,
                                  attemptedAt: selectedDate,
                                  totalMarks: totalMarks,
                                  scoredMarks: scoredMarks,
                                  totalQuestions: totalQuestions,
                                  attemptedQuestions: correct + wrong,
                                  correctAnswers: correct,
                                  wrongAnswers: wrong,
                                );

                                _service.addMockTest(test);
                                Navigator.pop(context);
                              }
                            },
                            child: const Text('Save Result'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
