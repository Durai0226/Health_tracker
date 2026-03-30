import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/exam_prep_theme.dart';
import '../data/question_bank_data.dart';
import '../models/study_material_model.dart';

/// Mock Test Screen - Full-length timed test experience
class MockTestScreen extends StatefulWidget {
  final MockTest mockTest;

  const MockTestScreen({super.key, required this.mockTest});

  @override
  State<MockTestScreen> createState() => _MockTestScreenState();
}

class _MockTestScreenState extends State<MockTestScreen>
    with TickerProviderStateMixin {
  late List<QuestionBankItem> _questions;
  late List<int?> _selectedAnswers;
  late List<bool> _markedForReview;
  
  int _currentIndex = 0;
  int _timeRemaining = 0;
  Timer? _timer;
  bool _isSubmitted = false;
  
  late AnimationController _timerAnimController;

  @override
  void initState() {
    super.initState();
    _initializeTest();
    _timerAnimController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
  }

  void _initializeTest() {
    // Generate questions for mock test
    _questions = QuestionBank.generateMockTest(
      examId: widget.mockTest.examId,
      totalQuestions: widget.mockTest.totalQuestions,
    );
    
    _selectedAnswers = List.filled(_questions.length, null);
    _markedForReview = List.filled(_questions.length, false);
    _timeRemaining = widget.mockTest.durationMinutes * 60;
    
    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_timeRemaining > 0) {
        setState(() {
          _timeRemaining--;
        });
        
        // Warning animation when time is low
        if (_timeRemaining == 300) { // 5 minutes left
          _timerAnimController.repeat(reverse: true);
        }
      } else {
        _submitTest();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _timerAnimController.dispose();
    super.dispose();
  }

  String get _formattedTime {
    final hours = _timeRemaining ~/ 3600;
    final minutes = (_timeRemaining % 3600) ~/ 60;
    final seconds = _timeRemaining % 60;
    
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return WillPopScope(
      onWillPop: () async {
        return await _showExitConfirmation();
      },
      child: Scaffold(
        backgroundColor: ExamPrepTheme.getBackground(context),
        appBar: _buildAppBar(context, isDark),
        body: _isSubmitted
            ? _buildResultsView(context, isDark)
            : Column(
                children: [
                  _buildProgressSection(context, isDark),
                  Expanded(
                    child: _buildQuestionSection(context, isDark),
                  ),
                  _buildBottomNavigation(context, isDark),
                ],
              ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context, bool isDark) {
    final isTimeWarning = _timeRemaining <= 300;
    
    return AppBar(
      backgroundColor: isDark ? const Color(0xFF1E1E2E) : Colors.white,
      elevation: 0,
      leading: IconButton(
        icon: Icon(Icons.close, color: isDark ? Colors.white : Colors.black87),
        onPressed: () async {
          if (await _showExitConfirmation()) {
            Navigator.pop(context);
          }
        },
      ),
      title: Text(
        widget.mockTest.title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: isDark ? Colors.white : Colors.black87,
        ),
      ),
      actions: [
        // Timer
        AnimatedBuilder(
          animation: _timerAnimController,
          builder: (context, child) {
            return Container(
              margin: const EdgeInsets.only(right: 16),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isTimeWarning
                    ? ExamPrepTheme.error.withOpacity(0.1 + (_timerAnimController.value * 0.2))
                    : ExamPrepTheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isTimeWarning ? ExamPrepTheme.error : ExamPrepTheme.primary,
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.timer_outlined,
                    size: 18,
                    color: isTimeWarning ? ExamPrepTheme.error : ExamPrepTheme.primary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _formattedTime,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: isTimeWarning ? ExamPrepTheme.error : ExamPrepTheme.primary,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildProgressSection(BuildContext context, bool isDark) {
    final answered = _selectedAnswers.where((a) => a != null).length;
    final reviewed = _markedForReview.where((m) => m).length;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Stats row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatPill('Answered', '$answered', ExamPrepTheme.success),
              _buildStatPill('Remaining', '${_questions.length - answered}', ExamPrepTheme.warning),
              _buildStatPill('Marked', '$reviewed', ExamPrepTheme.primary),
            ],
          ),
          const SizedBox(height: 12),
          // Question palette button
          GestureDetector(
            onTap: () => _showQuestionPalette(context),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: ExamPrepTheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.grid_view, size: 16, color: ExamPrepTheme.primary),
                  const SizedBox(width: 6),
                  Text(
                    'Question Palette',
                    style: TextStyle(
                      color: ExamPrepTheme.primary,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatPill(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: color,
              fontSize: 14,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color.withOpacity(0.8),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionSection(BuildContext context, bool isDark) {
    if (_questions.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    final question = _questions[_currentIndex];

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Question header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  gradient: ExamPrepTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  'Q${_currentIndex + 1}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const Spacer(),
              // Mark for review
              GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  setState(() {
                    _markedForReview[_currentIndex] = !_markedForReview[_currentIndex];
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _markedForReview[_currentIndex]
                        ? ExamPrepTheme.warning.withOpacity(0.2)
                        : Colors.grey.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _markedForReview[_currentIndex]
                          ? ExamPrepTheme.warning
                          : Colors.grey,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _markedForReview[_currentIndex]
                            ? Icons.flag
                            : Icons.flag_outlined,
                        size: 16,
                        color: _markedForReview[_currentIndex]
                            ? ExamPrepTheme.warning
                            : Colors.grey,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Review',
                        style: TextStyle(
                          fontSize: 12,
                          color: _markedForReview[_currentIndex]
                              ? ExamPrepTheme.warning
                              : Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Question text
          Text(
            question.question,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.white : Colors.black87,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),
          // Options
          ...List.generate(
            question.options.length,
            (index) => _buildOption(context, index, question, isDark),
          ),
        ],
      ),
    );
  }

  Widget _buildOption(BuildContext context, int index, QuestionBankItem question, bool isDark) {
    final isSelected = _selectedAnswers[_currentIndex] == index;

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        setState(() {
          _selectedAnswers[_currentIndex] = index;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? ExamPrepTheme.primary.withOpacity(0.15)
              : (isDark ? const Color(0xFF2A2A3E) : Colors.grey.shade50),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? ExamPrepTheme.primary : Colors.transparent,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: isSelected ? ExamPrepTheme.primary : Colors.transparent,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected
                      ? ExamPrepTheme.primary
                      : (isDark ? Colors.white38 : Colors.grey),
                  width: 2,
                ),
              ),
              child: Center(
                child: Text(
                  String.fromCharCode(65 + index),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: isSelected
                        ? Colors.white
                        : (isDark ? Colors.white70 : Colors.black54),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                question.options[index],
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? Colors.white : Colors.black87,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomNavigation(BuildContext context, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            // Previous
            IconButton(
              onPressed: _currentIndex > 0 ? () => _navigateTo(_currentIndex - 1) : null,
              icon: const Icon(Icons.arrow_back_ios),
              color: ExamPrepTheme.primary,
            ),
            // Clear selection
            TextButton(
              onPressed: _selectedAnswers[_currentIndex] != null
                  ? () {
                      setState(() {
                        _selectedAnswers[_currentIndex] = null;
                      });
                    }
                  : null,
              child: const Text('Clear'),
            ),
            const Spacer(),
            // Submit button (only on last question or via palette)
            if (_currentIndex == _questions.length - 1)
              ElevatedButton(
                onPressed: _submitTest,
                style: ElevatedButton.styleFrom(
                  backgroundColor: ExamPrepTheme.success,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Submit', style: TextStyle(fontWeight: FontWeight.bold)),
              )
            else
              ElevatedButton(
                onPressed: () => _navigateTo(_currentIndex + 1),
                style: ElevatedButton.styleFrom(
                  backgroundColor: ExamPrepTheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Next', style: TextStyle(fontWeight: FontWeight.bold)),
                    SizedBox(width: 4),
                    Icon(Icons.arrow_forward_ios, size: 16),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _navigateTo(int index) {
    if (index >= 0 && index < _questions.length) {
      HapticFeedback.lightImpact();
      setState(() {
        _currentIndex = index;
      });
    }
  }

  void _showQuestionPalette(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade400,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Text(
                    'Question Palette',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close'),
                  ),
                ],
              ),
            ),
            // Legend
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildLegendItem('Answered', ExamPrepTheme.success),
                  _buildLegendItem('Not Answered', Colors.grey),
                  _buildLegendItem('Marked', ExamPrepTheme.warning),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Grid
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 6,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                ),
                itemCount: _questions.length,
                itemBuilder: (context, index) {
                  final isAnswered = _selectedAnswers[index] != null;
                  final isMarked = _markedForReview[index];
                  final isCurrent = index == _currentIndex;

                  Color bgColor;
                  if (isMarked) {
                    bgColor = ExamPrepTheme.warning;
                  } else if (isAnswered) {
                    bgColor = ExamPrepTheme.success;
                  } else {
                    bgColor = Colors.grey;
                  }

                  return GestureDetector(
                    onTap: () {
                      Navigator.pop(context);
                      _navigateTo(index);
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: bgColor.withOpacity(isCurrent ? 1 : 0.7),
                        borderRadius: BorderRadius.circular(8),
                        border: isCurrent
                            ? Border.all(color: ExamPrepTheme.primary, width: 3)
                            : null,
                      ),
                      child: Center(
                        child: Text(
                          '${index + 1}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            // Submit button
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _submitTest();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ExamPrepTheme.success,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Submit Test',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  Future<bool> _showExitConfirmation() async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Exit Test?'),
            content: const Text(
              'Your progress will be lost. Are you sure you want to exit?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: ExamPrepTheme.error,
                ),
                child: const Text('Exit'),
              ),
            ],
          ),
        ) ??
        false;
  }

  void _submitTest() {
    _timer?.cancel();
    setState(() {
      _isSubmitted = true;
    });
  }

  Widget _buildResultsView(BuildContext context, bool isDark) {
    int correct = 0;
    int wrong = 0;
    int skipped = 0;

    for (int i = 0; i < _questions.length; i++) {
      if (_selectedAnswers[i] == null) {
        skipped++;
      } else if (_selectedAnswers[i] == _questions[i].correctIndex) {
        correct++;
      } else {
        wrong++;
      }
    }

    final score = correct - (wrong * widget.mockTest.negativeMarking);
    final percentage = (correct / _questions.length * 100);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          // Score circle
          Container(
            width: 160,
            height: 160,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  percentage >= 70
                      ? ExamPrepTheme.success
                      : (percentage >= 50 ? ExamPrepTheme.warning : ExamPrepTheme.error),
                  percentage >= 70
                      ? ExamPrepTheme.success.withOpacity(0.7)
                      : (percentage >= 50
                          ? ExamPrepTheme.warning.withOpacity(0.7)
                          : ExamPrepTheme.error.withOpacity(0.7)),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: (percentage >= 70
                          ? ExamPrepTheme.success
                          : (percentage >= 50 ? ExamPrepTheme.warning : ExamPrepTheme.error))
                      .withOpacity(0.4),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${percentage.toStringAsFixed(0)}%',
                  style: const TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const Text(
                  'Score',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          // Stats grid
          Row(
            children: [
              Expanded(
                child: _buildResultStat('Correct', '$correct', ExamPrepTheme.success),
              ),
              Expanded(
                child: _buildResultStat('Wrong', '$wrong', ExamPrepTheme.error),
              ),
              Expanded(
                child: _buildResultStat('Skipped', '$skipped', Colors.grey),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildResultStat('Total', '${_questions.length}', ExamPrepTheme.primary),
              ),
              Expanded(
                child: _buildResultStat(
                  'Net Score',
                  score.toStringAsFixed(2),
                  ExamPrepTheme.primary,
                ),
              ),
              Expanded(
                child: _buildResultStat(
                  'Time Used',
                  _formatTimeUsed(),
                  ExamPrepTheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          // Action buttons
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                // View solutions
              },
              icon: const Icon(Icons.visibility),
              label: const Text('View Solutions'),
              style: ElevatedButton.styleFrom(
                backgroundColor: ExamPrepTheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.home),
              label: const Text('Back to Dashboard'),
              style: OutlinedButton.styleFrom(
                foregroundColor: ExamPrepTheme.primary,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultStat(String label, String value, Color color) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      margin: const EdgeInsets.all(4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: isDark ? Colors.white60 : Colors.black54,
            ),
          ),
        ],
      ),
    );
  }

  String _formatTimeUsed() {
    final totalSeconds = widget.mockTest.durationMinutes * 60;
    final usedSeconds = totalSeconds - _timeRemaining;
    final minutes = usedSeconds ~/ 60;
    final seconds = usedSeconds % 60;
    return '${minutes}m ${seconds}s';
  }
}
