import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/constants/app_colors.dart';
import '../models/practice_test_model.dart';
import '../services/exam_prep_service.dart';

class PracticeTestScreen extends StatefulWidget {
  const PracticeTestScreen({super.key});

  @override
  State<PracticeTestScreen> createState() => _PracticeTestScreenState();
}

class _PracticeTestScreenState extends State<PracticeTestScreen>
    with TickerProviderStateMixin {
  final ExamPrepService _service = ExamPrepService();
  
  late AnimationController _fadeController;
  late AnimationController _floatController;
  late AnimationController _progressController;
  
  late Animation<double> _fadeAnimation;
  late Animation<double> _floatAnimation;

  int _currentQuestionIndex = 0;
  String? _selectedAnswer;
  bool _showResult = false;
  bool _isTestMode = false;
  int _correctAnswers = 0;
  String? _selectedTestId;
  List<Question> _currentQuestions = [];
  
  List<PracticeTest> get _tests => _service.practiceTests;
  
  final List<PracticeTest> _sampleTests = [
    PracticeTest(
      id: 'test1',
      title: 'Mathematics Quiz',
      description: 'Test your math knowledge',
      difficulty: TestDifficulty.intermediate,
      questionCount: 10,
      timeLimitMinutes: 15,
      colorHex: '#6366F1',
      bestScore: 85,
      attemptCount: 3,
    ),
    PracticeTest(
      id: 'test2',
      title: 'Physics Fundamentals',
      description: 'Basic physics concepts',
      difficulty: TestDifficulty.beginner,
      questionCount: 15,
      timeLimitMinutes: 20,
      colorHex: '#10B981',
      bestScore: 72,
      attemptCount: 2,
    ),
    PracticeTest(
      id: 'test3',
      title: 'Chemistry Challenge',
      description: 'Advanced chemistry problems',
      difficulty: TestDifficulty.advanced,
      questionCount: 20,
      timeLimitMinutes: 30,
      colorHex: '#F59E0B',
      bestScore: 0,
      attemptCount: 0,
    ),
    PracticeTest(
      id: 'test4',
      title: 'Biology Concepts',
      description: 'Test your biology understanding',
      difficulty: TestDifficulty.intermediate,
      questionCount: 12,
      timeLimitMinutes: 18,
      colorHex: '#EF4444',
      bestScore: 90,
      attemptCount: 5,
    ),
  ];

  final List<Question> _sampleQuestions = [
    Question(
      id: 'q1',
      testId: 'test1',
      questionText: 'What is the derivative of x²?',
      type: QuestionType.multipleChoice,
      options: [
        QuestionOption(id: 'a', text: 'x', isCorrect: false),
        QuestionOption(id: 'b', text: '2x', isCorrect: true),
        QuestionOption(id: 'c', text: '2', isCorrect: false),
        QuestionOption(id: 'd', text: 'x²', isCorrect: false),
      ],
      explanation: 'Using the power rule: d/dx(x^n) = nx^(n-1), so d/dx(x²) = 2x',
      points: 10,
    ),
    Question(
      id: 'q2',
      testId: 'test1',
      questionText: 'What is 15% of 200?',
      type: QuestionType.multipleChoice,
      options: [
        QuestionOption(id: 'a', text: '25', isCorrect: false),
        QuestionOption(id: 'b', text: '30', isCorrect: true),
        QuestionOption(id: 'c', text: '35', isCorrect: false),
        QuestionOption(id: 'd', text: '40', isCorrect: false),
      ],
      explanation: '15% × 200 = 0.15 × 200 = 30',
      points: 10,
    ),
    Question(
      id: 'q3',
      testId: 'test1',
      questionText: 'Which of the following is a prime number?',
      type: QuestionType.multipleChoice,
      options: [
        QuestionOption(id: 'a', text: '15', isCorrect: false),
        QuestionOption(id: 'b', text: '21', isCorrect: false),
        QuestionOption(id: 'c', text: '23', isCorrect: true),
        QuestionOption(id: 'd', text: '25', isCorrect: false),
      ],
      explanation: '23 is only divisible by 1 and itself, making it a prime number.',
      points: 10,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _service.addListener(_onServiceUpdate);
  }

  void _onServiceUpdate() {
    if (mounted) setState(() {});
  }

  void _initAnimations() {
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOutCubic,
    );
    
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat(reverse: true);
    _floatAnimation = Tween<double>(begin: 0, end: 8).animate(
      CurvedAnimation(parent: _floatController, curve: Curves.easeInOut),
    );
    
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    
    _fadeController.forward();
  }

  @override
  void dispose() {
    _service.removeListener(_onServiceUpdate);
    _fadeController.dispose();
    _floatController.dispose();
    _progressController.dispose();
    super.dispose();
  }

  void _startTest(PracticeTest test) {
    HapticFeedback.mediumImpact();
    _selectedTestId = test.id;
    _currentQuestions = _service.getQuestionsByTest(test.id);
    
    // If no questions in service, use sample questions for demo
    if (_currentQuestions.isEmpty) {
      _currentQuestions = _sampleQuestions;
    }
    
    setState(() {
      _isTestMode = true;
      _currentQuestionIndex = 0;
      _selectedAnswer = null;
      _showResult = false;
      _correctAnswers = 0;
    });
  }

  void _showExitConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.getCardBg(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Exit Test?'),
        content: const Text('Your progress will be lost.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Continue'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _isTestMode = false;
                _currentQuestionIndex = 0;
                _selectedAnswer = null;
                _showResult = false;
                _correctAnswers = 0;
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Exit', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showCreateTestDialog() {
    final titleController = TextEditingController();
    final descController = TextEditingController();
    String selectedColor = '#8B5CF6';
    TestDifficulty selectedDifficulty = TestDifficulty.intermediate;
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AppColors.getCardBg(context),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Text('Create Practice Test'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: titleController,
                  decoration: InputDecoration(
                    labelText: 'Test Title',
                    hintText: 'e.g., Math Quiz',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: descController,
                  decoration: InputDecoration(
                    labelText: 'Description (optional)',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 16),
                Text('Difficulty', style: TextStyle(color: AppColors.getTextSecondary(context))),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: TestDifficulty.values.map((diff) {
                    final isSelected = selectedDifficulty == diff;
                    return GestureDetector(
                      onTap: () => setDialogState(() => selectedDifficulty = diff),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: isSelected ? const Color(0xFF8B5CF6) : Colors.grey.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          diff.displayName,
                          style: TextStyle(
                            color: isSelected ? Colors.white : AppColors.getTextSecondary(context),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                Text('Color', style: TextStyle(color: AppColors.getTextSecondary(context))),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: ['#8B5CF6', '#6366F1', '#10B981', '#F59E0B', '#EF4444', '#EC4899'].map((color) {
                    final c = Color(int.parse(color.replaceAll('#', '0xFF')));
                    return GestureDetector(
                      onTap: () => setDialogState(() => selectedColor = color),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: c,
                          shape: BoxShape.circle,
                          border: selectedColor == color
                              ? Border.all(color: Colors.white, width: 3)
                              : null,
                          boxShadow: selectedColor == color
                              ? [BoxShadow(color: c.withOpacity(0.5), blurRadius: 8)]
                              : null,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (titleController.text.trim().isEmpty) return;
                
                final test = PracticeTest(
                  id: '',
                  title: titleController.text.trim(),
                  description: descController.text.trim().isEmpty ? null : descController.text.trim(),
                  difficulty: selectedDifficulty,
                  colorHex: selectedColor,
                );
                
                await _service.createPracticeTest(test);
                if (mounted) Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF8B5CF6),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Create', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _selectAnswer(String answerId) {
    if (_showResult) return;
    HapticFeedback.lightImpact();
    setState(() => _selectedAnswer = answerId);
  }

  void _submitAnswer() {
    if (_selectedAnswer == null) return;
    
    HapticFeedback.mediumImpact();
    final currentQuestion = _sampleQuestions[_currentQuestionIndex];
    final isCorrect = currentQuestion.options
        .any((o) => o.id == _selectedAnswer && o.isCorrect);
    
    if (isCorrect) _correctAnswers++;
    
    setState(() => _showResult = true);
  }

  void _nextQuestion() {
    if (_currentQuestionIndex < _sampleQuestions.length - 1) {
      setState(() {
        _currentQuestionIndex++;
        _selectedAnswer = null;
        _showResult = false;
      });
    } else {
      _showTestResults();
    }
  }

  void _showTestResults() {
    final score = (_correctAnswers / _sampleQuestions.length * 100).round();
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.getCardBg(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: score >= 70 
                    ? const Color(0xFF10B981).withOpacity(0.1)
                    : const Color(0xFFEF4444).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                score >= 70 ? Icons.emoji_events_rounded : Icons.refresh_rounded,
                size: 48,
                color: score >= 70 ? const Color(0xFF10B981) : const Color(0xFFEF4444),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              score >= 70 ? 'Excellent!' : 'Keep Practicing!',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: AppColors.getTextPrimary(context),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'You scored $score%',
              style: TextStyle(
                color: AppColors.getTextSecondary(context),
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildResultStat('$_correctAnswers', 'Correct', const Color(0xFF10B981)),
                _buildResultStat(
                  '${_sampleQuestions.length - _correctAnswers}', 
                  'Wrong', 
                  const Color(0xFFEF4444),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _isTestMode = false;
                _currentQuestionIndex = 0;
                _selectedAnswer = null;
                _showResult = false;
                _correctAnswers = 0;
              });
            },
            child: const Text('Back to Tests'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _currentQuestionIndex = 0;
                _selectedAnswer = null;
                _showResult = false;
                _correctAnswers = 0;
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF8B5CF6),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Try Again', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildResultStat(String value, String label, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w800,
              fontSize: 24,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            color: AppColors.getTextSecondary(context),
            fontSize: 13,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0A0A0F) : const Color(0xFFF8FAFC),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: Stack(
          children: [
            _buildBackground(isDark),
            SafeArea(
              child: Column(
                children: [
                  _buildHeader(theme),
                  Expanded(
                    child: _isTestMode 
                        ? _buildTestMode(theme)
                        : _buildTestList(theme),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBackground(bool isDark) {
    return Stack(
      children: [
        Positioned(
          top: -80,
          left: -60,
          child: AnimatedBuilder(
            animation: _floatController,
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(0, _floatAnimation.value),
                child: Container(
                  width: 220,
                  height: 220,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        const Color(0xFF8B5CF6).withOpacity(isDark ? 0.2 : 0.12),
                        const Color(0xFF8B5CF6).withOpacity(0.0),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        Positioned(
          bottom: 150,
          right: -60,
          child: AnimatedBuilder(
            animation: _floatController,
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(0, -_floatAnimation.value * 0.7),
                child: Container(
                  width: 180,
                  height: 180,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        const Color(0xFF10B981).withOpacity(isDark ? 0.2 : 0.1),
                        const Color(0xFF10B981).withOpacity(0.0),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      child: Row(
        children: [
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              if (_isTestMode) {
                _showExitConfirmation();
              } else {
                Navigator.pop(context);
              }
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
                    _isTestMode ? Icons.close_rounded : Icons.arrow_back_rounded,
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
                  _isTestMode ? 'Quiz Mode' : 'Test Yourself',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.getTextSecondary(context),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                ShaderMask(
                  shaderCallback: (bounds) => const LinearGradient(
                    colors: [Color(0xFF8B5CF6), Color(0xFF6366F1)],
                  ).createShader(bounds),
                  child: Text(
                    'Practice Tests',
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
          if (!_isTestMode)
            GestureDetector(
              onTap: () => _showCreateTestDialog(),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF8B5CF6), Color(0xFF6366F1)],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF8B5CF6).withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Row(
                  children: [
                    Icon(Icons.add_rounded, color: Colors.white, size: 18),
                    SizedBox(width: 6),
                    Text(
                      'New Test',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
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

  Widget _buildTestList(ThemeData theme) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
      itemCount: _sampleTests.length,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: _buildTestCard(theme, _sampleTests[index]),
        );
      },
    );
  }

  Widget _buildTestCard(ThemeData theme, PracticeTest test) {
    final isDark = theme.brightness == Brightness.dark;
    final color = Color(int.parse(test.colorHex.replaceAll('#', '0xFF')));
    
    return GestureDetector(
      onTap: () => _startTest(test),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [color.withOpacity(0.15), color.withOpacity(0.08)]
                : [Colors.white, color.withOpacity(0.05)],
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: color.withOpacity(0.2)),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.15),
              blurRadius: 20,
              offset: const Offset(0, 8),
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
                    gradient: LinearGradient(
                      colors: [color, color.withOpacity(0.8)],
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: color.withOpacity(0.4),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.quiz_rounded, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        test.title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.getTextPrimary(context),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              test.difficulty.displayName,
                              style: TextStyle(
                                color: color,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${test.questionCount} questions',
                            style: TextStyle(
                              color: AppColors.getTextSecondary(context),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.play_arrow_rounded, color: color, size: 22),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                _buildTestStat(
                  Icons.timer_rounded, 
                  test.durationFormatted, 
                  color,
                ),
                const SizedBox(width: 20),
                _buildTestStat(
                  Icons.replay_rounded, 
                  '${test.attemptCount} attempts', 
                  const Color(0xFF3B82F6),
                ),
                const Spacer(),
                if (test.bestScore > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.emoji_events_rounded, 
                          color: Color(0xFF10B981), size: 16),
                        const SizedBox(width: 4),
                        Text(
                          '${test.bestScore.round()}%',
                          style: const TextStyle(
                            color: Color(0xFF10B981),
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
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
    );
  }

  Widget _buildTestStat(IconData icon, String label, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            color: AppColors.getTextSecondary(context),
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildTestMode(ThemeData theme) {
    final currentQuestion = _sampleQuestions[_currentQuestionIndex];
    final isDark = theme.brightness == Brightness.dark;
    
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Question ${_currentQuestionIndex + 1}/${_sampleQuestions.length}',
                    style: TextStyle(
                      color: AppColors.getTextSecondary(context),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF8B5CF6).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.star_rounded, 
                          color: Color(0xFF8B5CF6), size: 16),
                        const SizedBox(width: 4),
                        Text(
                          '${currentQuestion.points} pts',
                          style: const TextStyle(
                            color: Color(0xFF8B5CF6),
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: (_currentQuestionIndex + 1) / _sampleQuestions.length,
                  backgroundColor: const Color(0xFF8B5CF6).withOpacity(0.15),
                  valueColor: const AlwaysStoppedAnimation(Color(0xFF8B5CF6)),
                  minHeight: 6,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: isDark
                          ? [const Color(0xFF1A1A2E), const Color(0xFF16213E)]
                          : [Colors.white, const Color(0xFFF8FAFC)],
                    ),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: const Color(0xFF8B5CF6).withOpacity(0.15),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF8B5CF6).withOpacity(0.1),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Text(
                    currentQuestion.questionText,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.getTextPrimary(context),
                      height: 1.4,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                ...currentQuestion.options.map((option) {
                  final isSelected = _selectedAnswer == option.id;
                  final showCorrect = _showResult && option.isCorrect;
                  final showWrong = _showResult && isSelected && !option.isCorrect;
                  
                  Color borderColor = Colors.transparent;
                  Color bgColor = isDark 
                      ? Colors.white.withOpacity(0.05)
                      : Colors.white;
                  
                  if (showCorrect) {
                    borderColor = const Color(0xFF10B981);
                    bgColor = const Color(0xFF10B981).withOpacity(0.1);
                  } else if (showWrong) {
                    borderColor = const Color(0xFFEF4444);
                    bgColor = const Color(0xFFEF4444).withOpacity(0.1);
                  } else if (isSelected) {
                    borderColor = const Color(0xFF8B5CF6);
                    bgColor = const Color(0xFF8B5CF6).withOpacity(0.1);
                  }
                  
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: GestureDetector(
                      onTap: () => _selectAnswer(option.id),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: bgColor,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: borderColor.withOpacity(borderColor == Colors.transparent ? 0.1 : 1),
                            width: isSelected || showCorrect || showWrong ? 2 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: isSelected || showCorrect || showWrong
                                    ? borderColor.withOpacity(0.2)
                                    : const Color(0xFF8B5CF6).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Center(
                                child: showCorrect
                                    ? const Icon(Icons.check_rounded, 
                                        color: Color(0xFF10B981), size: 18)
                                    : showWrong
                                        ? const Icon(Icons.close_rounded, 
                                            color: Color(0xFFEF4444), size: 18)
                                        : Text(
                                            option.id.toUpperCase(),
                                            style: TextStyle(
                                              color: isSelected 
                                                  ? const Color(0xFF8B5CF6)
                                                  : AppColors.getTextSecondary(context),
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Text(
                                option.text,
                                style: TextStyle(
                                  color: AppColors.getTextPrimary(context),
                                  fontWeight: FontWeight.w500,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
                if (_showResult && currentQuestion.explanation != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF3B82F6).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFF3B82F6).withOpacity(0.2),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.lightbulb_rounded, 
                          color: Color(0xFF3B82F6), size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Explanation',
                                style: TextStyle(
                                  color: Color(0xFF3B82F6),
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                currentQuestion.explanation!,
                                style: TextStyle(
                                  color: AppColors.getTextPrimary(context),
                                  fontSize: 14,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(20),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _showResult 
                  ? _nextQuestion
                  : (_selectedAnswer != null ? _submitAnswer : null),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF8B5CF6),
                disabledBackgroundColor: const Color(0xFF8B5CF6).withOpacity(0.3),
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
              child: Text(
                _showResult 
                    ? (_currentQuestionIndex < _sampleQuestions.length - 1 
                        ? 'Next Question' 
                        : 'See Results')
                    : 'Submit Answer',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

}
