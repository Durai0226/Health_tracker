import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/exam_prep_theme.dart';
import '../widgets/widgets.dart';
import '../data/question_bank_data.dart';
import '../data/exam_categories.dart';

/// Premium Practice Screen - Subject-wise practice
class PremiumPracticeScreen extends StatefulWidget {
  final String? initialSubject;

  const PremiumPracticeScreen({super.key, this.initialSubject});

  @override
  State<PremiumPracticeScreen> createState() => _PremiumPracticeScreenState();
}

class _PremiumPracticeScreenState extends State<PremiumPracticeScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  String? _selectedSubject;
  String? _selectedTopic;
  String _selectedDifficulty = 'all';
  
  List<QuestionBankItem> _questions = [];
  int _currentQuestionIndex = 0;
  int? _selectedOption;
  bool _showAnswer = false;
  
  int _correctCount = 0;
  int _wrongCount = 0;
  final Set<String> _bookmarkedQuestions = {};

  String _selectedCategory = 'all';
  
  final List<Map<String, dynamic>> _examCategories = [
    {'id': 'all', 'name': 'All Subjects', 'icon': Icons.apps},
    {'id': 'competitive', 'name': 'Banking/SSC', 'icon': Icons.account_balance},
    {'id': 'upsc', 'name': 'UPSC/Civil', 'icon': Icons.assured_workload},
    {'id': 'entrance', 'name': 'JEE/NEET', 'icon': Icons.school},
    {'id': 'management', 'name': 'CAT/MBA', 'icon': Icons.business},
  ];

  final List<Map<String, dynamic>> _allSubjects = [
    // Core Competitive Exam Subjects (Banking/SSC/Railways)
    {'id': 'quant', 'name': 'Quantitative', 'icon': Icons.calculate_outlined, 'color': ExamPrepTheme.quantitative, 'category': 'competitive'},
    {'id': 'reasoning', 'name': 'Reasoning', 'icon': Icons.psychology_outlined, 'color': ExamPrepTheme.reasoning, 'category': 'competitive'},
    {'id': 'english', 'name': 'English', 'icon': Icons.menu_book_outlined, 'color': ExamPrepTheme.english, 'category': 'competitive'},
    {'id': 'gk', 'name': 'GK & CA', 'icon': Icons.public_outlined, 'color': ExamPrepTheme.generalAwareness, 'category': 'competitive'},
    {'id': 'computer', 'name': 'Computer', 'icon': Icons.computer_outlined, 'color': ExamPrepTheme.computer, 'category': 'competitive'},
    {'id': 'science', 'name': 'Science', 'icon': Icons.science_outlined, 'color': ExamPrepTheme.generalScience, 'category': 'competitive'},
    // UPSC & Civil Services Subjects
    {'id': 'history', 'name': 'History', 'icon': Icons.history_edu_outlined, 'color': const Color(0xFF8B4513), 'category': 'upsc'},
    {'id': 'polity', 'name': 'Polity', 'icon': Icons.gavel_outlined, 'color': const Color(0xFF1E88E5), 'category': 'upsc'},
    {'id': 'geography', 'name': 'Geography', 'icon': Icons.terrain_outlined, 'color': const Color(0xFF43A047), 'category': 'upsc'},
    {'id': 'economics', 'name': 'Economics', 'icon': Icons.trending_up_outlined, 'color': const Color(0xFFFF9800), 'category': 'upsc'},
    {'id': 'environment', 'name': 'Environment', 'icon': Icons.eco_outlined, 'color': const Color(0xFF2E7D32), 'category': 'upsc'},
    // Entrance Exam Subjects (JEE/NEET/GATE)
    {'id': 'physics_adv', 'name': 'Physics', 'icon': Icons.bolt_outlined, 'color': const Color(0xFF5C6BC0), 'category': 'entrance'},
    {'id': 'chemistry_adv', 'name': 'Chemistry', 'icon': Icons.biotech_outlined, 'color': const Color(0xFFAB47BC), 'category': 'entrance'},
    {'id': 'biology', 'name': 'Biology', 'icon': Icons.local_florist_outlined, 'color': const Color(0xFF66BB6A), 'category': 'entrance'},
    {'id': 'math_higher', 'name': 'Mathematics', 'icon': Icons.functions_outlined, 'color': const Color(0xFF29B6F6), 'category': 'entrance'},
    // Management Exam Subjects (CAT/XAT)
    {'id': 'lr_cat', 'name': 'LR (CAT)', 'icon': Icons.lightbulb_outlined, 'color': const Color(0xFFFFCA28), 'category': 'management'},
    {'id': 'di_advanced', 'name': 'DI Advanced', 'icon': Icons.bar_chart_outlined, 'color': const Color(0xFFEF5350), 'category': 'management'},
    {'id': 'legal', 'name': 'Legal Apt.', 'icon': Icons.balance_outlined, 'color': const Color(0xFF78909C), 'category': 'management'},
  ];

  List<Map<String, dynamic>> get _subjects {
    if (_selectedCategory == 'all') return _allSubjects;
    return _allSubjects.where((s) => s['category'] == _selectedCategory).toList();
  }

  @override
  void initState() {
    super.initState();
    _initTabController();
    _selectedSubject = widget.initialSubject ?? _subjects.first['id'];
    _loadQuestions();
  }

  void _initTabController() {
    _tabController = TabController(length: _subjects.length, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging && _tabController.index < _subjects.length) {
        setState(() {
          _selectedSubject = _subjects[_tabController.index]['id'];
          _selectedTopic = null;
          _loadQuestions();
        });
      }
    });
  }

  void _onCategoryChanged(String category) {
    setState(() {
      _selectedCategory = category;
      _tabController.dispose();
      _initTabController();
      _selectedSubject = _subjects.first['id'];
      _loadQuestions();
    });
  }

  void _loadQuestions() {
    setState(() {
      _questions = QuestionBank.getBySubject(_selectedSubject!);
      if (_selectedTopic != null) {
        _questions = _questions.where((q) => q.topicId == _selectedTopic).toList();
      }
      if (_selectedDifficulty != 'all') {
        _questions = _questions.where((q) => q.difficulty == _selectedDifficulty).toList();
      }
      _questions.shuffle();
      _currentQuestionIndex = 0;
      _selectedOption = null;
      _showAnswer = false;
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentSubject = _subjects.firstWhere((s) => s['id'] == _selectedSubject);

    return Scaffold(
      backgroundColor: ExamPrepTheme.getBackground(context),
      appBar: AppBar(
        backgroundColor: currentSubject['color'],
        elevation: 0,
        title: const Text('Practice', style: TextStyle(color: Colors.white)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list, color: Colors.white),
            onPressed: () => _showFilterSheet(context),
          ),
          IconButton(
            icon: const Icon(Icons.analytics_outlined, color: Colors.white),
            onPressed: () => _showStatsDialog(context),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          tabs: _subjects.map((subject) {
            return Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(subject['icon'] as IconData, size: 18),
                  const SizedBox(width: 6),
                  Text(subject['name'] as String),
                ],
              ),
            );
          }).toList(),
        ),
      ),
      body: _questions.isEmpty
          ? _buildEmptyState(context, isDark)
          : Column(
              children: [
                _buildCategorySelector(context, isDark),
                _buildProgressBar(context),
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      children: [
                        QuestionCard(
                          question: _questions[_currentQuestionIndex],
                          questionNumber: _currentQuestionIndex + 1,
                          selectedOption: _selectedOption,
                          showAnswer: _showAnswer,
                          isBookmarked: _bookmarkedQuestions.contains(
                            _questions[_currentQuestionIndex].id,
                          ),
                          onOptionSelected: _onOptionSelected,
                          onBookmark: _toggleBookmark,
                          onReport: () => _reportQuestion(context),
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
                _buildBottomControls(context, isDark),
              ],
            ),
    );
  }

  Widget _buildEmptyState(BuildContext context, bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.quiz_outlined,
            size: 80,
            color: Colors.grey.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'No questions found',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white60 : Colors.black54,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Try changing the filters',
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.white38 : Colors.black38,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              setState(() {
                _selectedTopic = null;
                _selectedDifficulty = 'all';
                _loadQuestions();
              });
            },
            icon: const Icon(Icons.refresh),
            label: const Text('Reset Filters'),
            style: ElevatedButton.styleFrom(
              backgroundColor: ExamPrepTheme.primary,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategorySelector(BuildContext context, bool isDark) {
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: _examCategories.length,
        itemBuilder: (context, index) {
          final category = _examCategories[index];
          final isSelected = _selectedCategory == category['id'];
          
          return GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              _onCategoryChanged(category['id'] as String);
            },
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                gradient: isSelected
                    ? LinearGradient(colors: [ExamPrepTheme.primary, ExamPrepTheme.primaryLight])
                    : null,
                color: isSelected ? null : (isDark ? const Color(0xFF2A2A3E) : Colors.grey.shade100),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected ? ExamPrepTheme.primary : Colors.transparent,
                  width: 1.5,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    category['icon'] as IconData,
                    size: 16,
                    color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black54),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    category['name'] as String,
                    style: TextStyle(
                      color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black54),
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildProgressBar(BuildContext context) {
    final currentSubject = _subjects.firstWhere((s) => s['id'] == _selectedSubject);
    final progress = _questions.isNotEmpty
        ? (_currentQuestionIndex + 1) / _questions.length
        : 0.0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: (currentSubject['color'] as Color).withOpacity(0.1),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Question ${_currentQuestionIndex + 1} of ${_questions.length}',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: currentSubject['color'] as Color,
                ),
              ),
              Row(
                children: [
                  _buildMiniStat(Icons.check_circle, '$_correctCount', ExamPrepTheme.success),
                  const SizedBox(width: 12),
                  _buildMiniStat(Icons.cancel, '$_wrongCount', ExamPrepTheme.error),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: (currentSubject['color'] as Color).withOpacity(0.2),
              valueColor: AlwaysStoppedAnimation(currentSubject['color'] as Color),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStat(IconData icon, String value, Color color) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 4),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: color,
            fontSize: 13,
          ),
        ),
      ],
    );
  }

  Widget _buildBottomControls(BuildContext context, bool isDark) {
    final currentSubject = _subjects.firstWhere((s) => s['id'] == _selectedSubject);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            // Previous button
            IconButton(
              onPressed: _currentQuestionIndex > 0
                  ? () => _navigateQuestion(-1)
                  : null,
              icon: const Icon(Icons.arrow_back_ios),
              color: currentSubject['color'] as Color,
            ),
            const SizedBox(width: 8),
            // Main action button
            Expanded(
              child: ElevatedButton(
                onPressed: _selectedOption == null && !_showAnswer
                    ? null
                    : () {
                        if (_showAnswer) {
                          _navigateQuestion(1);
                        } else {
                          _checkAnswer();
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _showAnswer
                      ? ExamPrepTheme.primary
                      : currentSubject['color'] as Color,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  _showAnswer
                      ? (_currentQuestionIndex < _questions.length - 1
                          ? 'Next Question'
                          : 'Finish')
                      : 'Check Answer',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Skip button
            IconButton(
              onPressed: !_showAnswer ? () => _skipQuestion() : null,
              icon: const Icon(Icons.skip_next),
              color: currentSubject['color'] as Color,
            ),
          ],
        ),
      ),
    );
  }

  void _onOptionSelected(int index) {
    if (!_showAnswer) {
      HapticFeedback.lightImpact();
      setState(() {
        _selectedOption = index;
      });
    }
  }

  void _checkAnswer() {
    HapticFeedback.mediumImpact();
    setState(() {
      _showAnswer = true;
      if (_selectedOption == _questions[_currentQuestionIndex].correctIndex) {
        _correctCount++;
      } else {
        _wrongCount++;
      }
    });
  }

  void _skipQuestion() {
    HapticFeedback.lightImpact();
    _navigateQuestion(1);
  }

  void _navigateQuestion(int direction) {
    final newIndex = _currentQuestionIndex + direction;
    
    if (newIndex >= 0 && newIndex < _questions.length) {
      HapticFeedback.lightImpact();
      setState(() {
        _currentQuestionIndex = newIndex;
        _selectedOption = null;
        _showAnswer = false;
      });
    } else if (newIndex >= _questions.length) {
      _showCompletionDialog();
    }
  }

  void _toggleBookmark() {
    HapticFeedback.lightImpact();
    setState(() {
      final questionId = _questions[_currentQuestionIndex].id;
      if (_bookmarkedQuestions.contains(questionId)) {
        _bookmarkedQuestions.remove(questionId);
      } else {
        _bookmarkedQuestions.add(questionId);
      }
    });
  }

  void _reportQuestion(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Report Question'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildReportOption('Incorrect answer', Icons.error_outline),
            _buildReportOption('Unclear question', Icons.help_outline),
            _buildReportOption('Typo/Grammar', Icons.spellcheck),
            _buildReportOption('Other issue', Icons.flag_outlined),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Widget _buildReportOption(String label, IconData icon) {
    return ListTile(
      leading: Icon(icon),
      title: Text(label),
      onTap: () {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Report submitted. Thank you!'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      },
    );
  }

  void _showFilterSheet(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final topics = ExamData.getTopicsBySubject(_selectedSubject!);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.6,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade400,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Filter Questions',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(
                    'Difficulty',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white70 : Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    children: [
                      _buildFilterChip('All', 'all', _selectedDifficulty == 'all'),
                      _buildFilterChip('Easy', 'easy', _selectedDifficulty == 'easy'),
                      _buildFilterChip('Medium', 'medium', _selectedDifficulty == 'medium'),
                      _buildFilterChip('Hard', 'hard', _selectedDifficulty == 'hard'),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Topic',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white70 : Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildTopicChip('All Topics', null, _selectedTopic == null),
                      ...topics.map((topic) => _buildTopicChip(
                        topic.name,
                        topic.id,
                        _selectedTopic == topic.id,
                      )),
                    ],
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _loadQuestions();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ExamPrepTheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Apply Filters',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, String value, bool isSelected) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedDifficulty = value;
        });
      },
      child: Chip(
        label: Text(label),
        backgroundColor: isSelected
            ? ExamPrepTheme.primary
            : ExamPrepTheme.primary.withOpacity(0.1),
        labelStyle: TextStyle(
          color: isSelected ? Colors.white : ExamPrepTheme.primary,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildTopicChip(String label, String? topicId, bool isSelected) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedTopic = topicId;
        });
      },
      child: Chip(
        label: Text(label),
        backgroundColor: isSelected
            ? ExamPrepTheme.primary
            : ExamPrepTheme.primary.withOpacity(0.1),
        labelStyle: TextStyle(
          color: isSelected ? Colors.white : ExamPrepTheme.primary,
          fontWeight: FontWeight.w500,
          fontSize: 12,
        ),
      ),
    );
  }

  void _showStatsDialog(BuildContext context) {
    final total = _correctCount + _wrongCount;
    final accuracy = total > 0 ? (_correctCount / total * 100) : 0;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.analytics_outlined),
            const SizedBox(width: 8),
            const Text('Session Stats'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildStatRow('Correct', '$_correctCount', ExamPrepTheme.success),
            _buildStatRow('Wrong', '$_wrongCount', ExamPrepTheme.error),
            _buildStatRow('Total', '$total', ExamPrepTheme.primary),
            const Divider(),
            _buildStatRow('Accuracy', '${accuracy.toStringAsFixed(1)}%',
                accuracy >= 70 ? ExamPrepTheme.success : ExamPrepTheme.warning),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  void _showCompletionDialog() {
    final total = _correctCount + _wrongCount;
    final accuracy = total > 0 ? (_correctCount / total * 100) : 0;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Practice Complete! 🎉'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.emoji_events,
              size: 60,
              color: Colors.amber,
            ),
            const SizedBox(height: 16),
            Text(
              '${accuracy.toStringAsFixed(0)}% Accuracy',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text('$_correctCount correct out of $total questions'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _correctCount = 0;
                _wrongCount = 0;
                _loadQuestions();
              });
            },
            child: const Text('Practice Again'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: ExamPrepTheme.primary,
            ),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }
}
