import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/exam_prep_theme.dart';
import '../data/question_bank_data.dart';
import '../data/exam_categories.dart';
import '../widgets/question_card.dart';
import '../widgets/step_by_solution_widget.dart';

/// Question Bank Screen - Browse all questions with filters
class QuestionBankScreen extends StatefulWidget {
  const QuestionBankScreen({super.key});

  @override
  State<QuestionBankScreen> createState() => _QuestionBankScreenState();
}

class _QuestionBankScreenState extends State<QuestionBankScreen> {
  String? _selectedSubject;
  String? _selectedTopic;
  String _selectedDifficulty = 'all';
  String _searchQuery = '';
  
  List<QuestionBankItem> _filteredQuestions = [];
  final TextEditingController _searchController = TextEditingController();
  final Set<String> _bookmarkedIds = {};

  @override
  void initState() {
    super.initState();
    _loadQuestions();
  }

  void _loadQuestions() {
    var questions = QuestionBank.getAllQuestions();
    
    if (_selectedSubject != null) {
      questions = questions.where((q) => q.subjectId == _selectedSubject).toList();
    }
    if (_selectedTopic != null) {
      questions = questions.where((q) => q.topicId == _selectedTopic).toList();
    }
    if (_selectedDifficulty != 'all') {
      questions = questions.where((q) => q.difficulty == _selectedDifficulty).toList();
    }
    if (_searchQuery.isNotEmpty) {
      questions = questions.where((q) =>
          q.question.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          q.options.any((o) => o.toLowerCase().contains(_searchQuery.toLowerCase()))
      ).toList();
    }
    
    setState(() {
      _filteredQuestions = questions;
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: ExamPrepTheme.getBackground(context),
      appBar: AppBar(
        backgroundColor: ExamPrepTheme.english,
        elevation: 0,
        title: const Text('Question Bank', style: TextStyle(color: Colors.white)),
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
            icon: const Icon(Icons.bookmark_outline, color: Colors.white),
            onPressed: () => _showBookmarked(context),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSearchBar(context, isDark),
          _buildFilterChips(context),
          _buildQuestionCount(context, isDark),
          Expanded(
            child: _filteredQuestions.isEmpty
                ? _buildEmptyState(context, isDark)
                : _buildQuestionList(context, isDark),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(BuildContext context, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      color: ExamPrepTheme.english.withOpacity(0.1),
      child: TextField(
        controller: _searchController,
        onChanged: (value) {
          setState(() {
            _searchQuery = value;
          });
          _loadQuestions();
        },
        decoration: InputDecoration(
          hintText: 'Search questions...',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    setState(() {
                      _searchQuery = '';
                    });
                    _loadQuestions();
                  },
                )
              : null,
          filled: true,
          fillColor: isDark ? const Color(0xFF1E1E2E) : Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }

  Widget _buildFilterChips(BuildContext context) {
    final subjects = [
      {'id': null, 'name': 'All', 'color': ExamPrepTheme.primary},
      {'id': 'quant', 'name': 'Quant', 'color': ExamPrepTheme.quantitative},
      {'id': 'reasoning', 'name': 'Reasoning', 'color': ExamPrepTheme.reasoning},
      {'id': 'english', 'name': 'English', 'color': ExamPrepTheme.english},
      {'id': 'gk', 'name': 'GK', 'color': ExamPrepTheme.generalAwareness},
      {'id': 'computer', 'name': 'Computer', 'color': ExamPrepTheme.computer},
      {'id': 'science', 'name': 'Science', 'color': ExamPrepTheme.generalScience},
    ];

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: subjects.map((subject) {
            final isSelected = _selectedSubject == subject['id'];
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  setState(() {
                    _selectedSubject = subject['id'] as String?;
                    _selectedTopic = null;
                  });
                  _loadQuestions();
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? (subject['color'] as Color)
                        : (subject['color'] as Color).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    subject['name'] as String,
                    style: TextStyle(
                      color: isSelected ? Colors.white : subject['color'] as Color,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
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

  Widget _buildQuestionCount(BuildContext context, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Text(
            '${_filteredQuestions.length} Questions',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white70 : Colors.black54,
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: ExamPrepTheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.shuffle, size: 14, color: ExamPrepTheme.primary),
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _filteredQuestions.shuffle();
                    });
                  },
                  child: Text(
                    'Shuffle',
                    style: TextStyle(
                      fontSize: 12,
                      color: ExamPrepTheme.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionList(BuildContext context, bool isDark) {
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 80),
      itemCount: _filteredQuestions.length,
      itemBuilder: (context, index) {
        final question = _filteredQuestions[index];
        return QuestionListTile(
          question: question,
          index: index,
          onTap: () => _showQuestionDetail(context, question, index),
        );
      },
    );
  }

  Widget _buildEmptyState(BuildContext context, bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off,
            size: 64,
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
            'Try adjusting your filters',
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.white38 : Colors.black38,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              setState(() {
                _selectedSubject = null;
                _selectedTopic = null;
                _selectedDifficulty = 'all';
                _searchQuery = '';
                _searchController.clear();
              });
              _loadQuestions();
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

  void _showQuestionDetail(BuildContext context, QuestionBankItem question, int index) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _QuestionDetailPage(
          question: question,
          questionNumber: index + 1,
          isBookmarked: _bookmarkedIds.contains(question.id),
          onBookmarkToggle: () {
            setState(() {
              if (_bookmarkedIds.contains(question.id)) {
                _bookmarkedIds.remove(question.id);
              } else {
                _bookmarkedIds.add(question.id);
              }
            });
          },
        ),
      ),
    );
  }

  void _showFilterSheet(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final topics = _selectedSubject != null
        ? ExamData.getTopicsBySubject(_selectedSubject!)
        : <Topic>[];

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
              child: Row(
                children: [
                  Text(
                    'Filters',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _selectedTopic = null;
                        _selectedDifficulty = 'all';
                      });
                    },
                    child: const Text('Reset'),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Difficulty
                  Text(
                    'Difficulty',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: isDark ? Colors.white70 : Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    children: [
                      _buildDifficultyChip('All', 'all'),
                      _buildDifficultyChip('Easy', 'easy'),
                      _buildDifficultyChip('Medium', 'medium'),
                      _buildDifficultyChip('Hard', 'hard'),
                    ],
                  ),
                  const SizedBox(height: 24),
                  // Topics (if subject selected)
                  if (_selectedSubject != null && topics.isNotEmpty) ...[
                    Text(
                      'Topics',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: isDark ? Colors.white70 : Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildTopicChip('All Topics', null),
                        ...topics.map((topic) => _buildTopicChip(topic.name, topic.id)),
                      ],
                    ),
                  ],
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

  Widget _buildDifficultyChip(String label, String value) {
    final isSelected = _selectedDifficulty == value;
    Color color;
    switch (value) {
      case 'easy':
        color = ExamPrepTheme.success;
        break;
      case 'medium':
        color = ExamPrepTheme.warning;
        break;
      case 'hard':
        color = ExamPrepTheme.error;
        break;
      default:
        color = ExamPrepTheme.primary;
    }

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedDifficulty = value;
        });
      },
      child: Chip(
        label: Text(label),
        backgroundColor: isSelected ? color : color.withOpacity(0.1),
        labelStyle: TextStyle(
          color: isSelected ? Colors.white : color,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildTopicChip(String label, String? topicId) {
    final isSelected = _selectedTopic == topicId;
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

  void _showBookmarked(BuildContext context) {
    final bookmarkedQuestions = _filteredQuestions
        .where((q) => _bookmarkedIds.contains(q.id))
        .toList();

    if (bookmarkedQuestions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No bookmarked questions'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(
            title: const Text('Bookmarked Questions'),
            backgroundColor: ExamPrepTheme.warning,
          ),
          body: ListView.builder(
            itemCount: bookmarkedQuestions.length,
            itemBuilder: (context, index) {
              return QuestionListTile(
                question: bookmarkedQuestions[index],
                index: index,
                onTap: () => _showQuestionDetail(
                  context,
                  bookmarkedQuestions[index],
                  index,
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Question detail page with full question card
class _QuestionDetailPage extends StatefulWidget {
  final QuestionBankItem question;
  final int questionNumber;
  final bool isBookmarked;
  final VoidCallback onBookmarkToggle;

  const _QuestionDetailPage({
    required this.question,
    required this.questionNumber,
    required this.isBookmarked,
    required this.onBookmarkToggle,
  });

  @override
  State<_QuestionDetailPage> createState() => _QuestionDetailPageState();
}

class _QuestionDetailPageState extends State<_QuestionDetailPage> {
  int? _selectedOption;
  bool _showAnswer = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: ExamPrepTheme.getBackground(context),
      appBar: AppBar(
        backgroundColor: ExamPrepTheme.getSubjectColor(widget.question.subjectId),
        title: Text('Question ${widget.questionNumber}'),
        actions: [
          // Show solution badge if available
          if (widget.question.hasDetailedSolution)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: SolutionPreviewChip(question: widget.question),
            ),
          IconButton(
            icon: Icon(
              widget.isBookmarked ? Icons.bookmark : Icons.bookmark_outline,
            ),
            onPressed: widget.onBookmarkToggle,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  QuestionCard(
                    question: widget.question,
                    questionNumber: widget.questionNumber,
                    selectedOption: _selectedOption,
                    showAnswer: _showAnswer,
                    isBookmarked: widget.isBookmarked,
                    onOptionSelected: (index) {
                      setState(() {
                        _selectedOption = index;
                      });
                    },
                    onBookmark: widget.onBookmarkToggle,
                  ),
                  // Show step-by-step solution when answer is revealed
                  if (_showAnswer && widget.question.hasDetailedSolution)
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: StepBySolutionWidget(
                        question: widget.question,
                        initiallyExpanded: true,
                      ),
                    ),
                ],
              ),
            ),
          ),
          _buildBottomAction(context),
        ],
      ),
    );
  }

  Widget _buildBottomAction(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
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
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _selectedOption == null && !_showAnswer
                ? null
                : () {
                    setState(() {
                      _showAnswer = !_showAnswer;
                    });
                  },
            style: ElevatedButton.styleFrom(
              backgroundColor: _showAnswer
                  ? ExamPrepTheme.primary
                  : ExamPrepTheme.getSubjectColor(widget.question.subjectId),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              _showAnswer ? 'Hide Answer' : 'Check Answer',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
        ),
      ),
    );
  }
}
