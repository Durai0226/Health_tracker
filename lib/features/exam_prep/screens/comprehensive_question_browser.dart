import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/exam_prep_theme.dart';
import '../data/question_bank_data.dart';

/// Comprehensive Question Browser - Browse ALL questions with proper categorization
class ComprehensiveQuestionBrowser extends StatefulWidget {
  const ComprehensiveQuestionBrowser({super.key});

  @override
  State<ComprehensiveQuestionBrowser> createState() => _ComprehensiveQuestionBrowserState();
}

class _ComprehensiveQuestionBrowserState extends State<ComprehensiveQuestionBrowser> {
  List<ExamCategoryInfo> _categories = [];
  int _totalQuestions = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    Future.microtask(() {
      final categories = QuestionBank.getExamCategories();
      final total = QuestionBank.totalQuestions;
      if (mounted) {
        setState(() {
          _categories = categories;
          _totalQuestions = total;
          _isLoading = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0A0A14) : const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: ExamPrepTheme.primary,
        title: const Text('Question Bank', style: TextStyle(fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                children: [
                  _buildStatsHeader(context, isDark),
                  _buildCategoryGrid(context, isDark),
                  _buildAllSubjectsSection(context, isDark),
                  const SizedBox(height: 100),
                ],
              ),
            ),
    );
  }

  Widget _buildStatsHeader(BuildContext context, bool isDark) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [ExamPrepTheme.primary.withOpacity(0.1), ExamPrepTheme.primaryLight.withOpacity(0.05)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: ExamPrepTheme.primary.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.quiz_outlined, color: ExamPrepTheme.primary, size: 28),
              const SizedBox(width: 12),
              Text('$_totalQuestions', style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: ExamPrepTheme.primary)),
              const SizedBox(width: 8),
              Text('Questions', style: TextStyle(fontSize: 18, color: isDark ? Colors.white70 : Colors.black54)),
            ],
          ),
          const SizedBox(height: 12),
          Text('Across ${_categories.length} Exam Categories', style: TextStyle(fontSize: 14, color: isDark ? Colors.white54 : Colors.black45)),
        ],
      ),
    );
  }

  Widget _buildCategoryGrid(BuildContext context, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(width: 4, height: 24, decoration: BoxDecoration(color: ExamPrepTheme.primary, borderRadius: BorderRadius.circular(2))),
              const SizedBox(width: 12),
              Text('Exam Categories', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
            ],
          ),
          const SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 1.1),
            itemCount: _categories.length,
            itemBuilder: (context, index) => _buildCategoryCard(context, _categories[index], isDark),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryCard(BuildContext context, ExamCategoryInfo category, bool isDark) {
    final color = Color(category.color);
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        Navigator.push(context, MaterialPageRoute(builder: (context) => CategoryDetailScreen(category: category)));
      },
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [color.withOpacity(0.9), color.withOpacity(0.7)]),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: color.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Stack(
          children: [
            Positioned(right: -20, top: -20, child: Container(width: 80, height: 80, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(0.15)))),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(_getIconData(category.icon), color: Colors.white, size: 32),
                  const Spacer(),
                  Text(category.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14), maxLines: 2),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.25), borderRadius: BorderRadius.circular(8)),
                    child: Text('${category.questionCount} Qs', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAllSubjectsSection(BuildContext context, bool isDark) {
    final allQuestions = QuestionBank.getAllQuestions();
    final subjectGroups = <String, List<QuestionBankItem>>{};
    for (final q in allQuestions) {
      subjectGroups.putIfAbsent(q.subjectId, () => []).add(q);
    }
    final sortedSubjects = subjectGroups.entries.toList()..sort((a, b) => b.value.length.compareTo(a.value.length));

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(width: 4, height: 24, decoration: BoxDecoration(color: ExamPrepTheme.primaryLight, borderRadius: BorderRadius.circular(2))),
              const SizedBox(width: 12),
              Text('All Subjects', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
              const Spacer(),
              Text('${sortedSubjects.length} subjects', style: TextStyle(fontSize: 14, color: isDark ? Colors.white54 : Colors.black45)),
            ],
          ),
          const SizedBox(height: 16),
          ...sortedSubjects.take(10).map((entry) => _buildSubjectTile(context, QuestionBank.getSubjectDisplayName(entry.key), entry.key, entry.value, isDark)),
        ],
      ),
    );
  }

  Widget _buildSubjectTile(BuildContext context, String name, String id, List<QuestionBankItem> questions, bool isDark) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        Navigator.push(context, MaterialPageRoute(builder: (context) => SubjectDetailScreen(subjectName: name, subjectId: id, questions: questions)));
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 2))],
        ),
        child: Row(
          children: [
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(color: ExamPrepTheme.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
              child: Center(child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: ExamPrepTheme.primary))),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: isDark ? Colors.white : Colors.black87)),
                  const SizedBox(height: 4),
                  Text('${questions.length} questions', style: TextStyle(fontSize: 13, color: isDark ? Colors.white54 : Colors.black45)),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, size: 16, color: ExamPrepTheme.primary),
          ],
        ),
      ),
    );
  }

  IconData _getIconData(String iconName) {
    switch (iconName) {
      case 'account_balance': return Icons.account_balance;
      case 'train': return Icons.train;
      case 'assured_workload': return Icons.assured_workload;
      case 'school': return Icons.school;
      case 'medical_services': return Icons.medical_services;
      case 'business_center': return Icons.business_center;
      case 'engineering': return Icons.engineering;
      case 'gavel': return Icons.gavel;
      default: return Icons.quiz;
    }
  }
}

/// Category Detail Screen
class CategoryDetailScreen extends StatelessWidget {
  final ExamCategoryInfo category;
  const CategoryDetailScreen({super.key, required this.category});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = Color(category.color);
    final questions = QuestionBank.getByExamCategory(category.id);
    final subjectGroups = QuestionBank.getQuestionsBySubjectForCategory(category.id);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0A0A14) : const Color(0xFFF5F7FA),
      appBar: AppBar(backgroundColor: color, title: Text(category.name)),
      body: questions.isEmpty
          ? Center(child: Text('No questions yet', style: TextStyle(color: isDark ? Colors.white54 : Colors.black45)))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildStatsCard(context, isDark, color, questions),
                  const SizedBox(height: 20),
                  Text('Subjects (${subjectGroups.length})', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
                  const SizedBox(height: 12),
                  ...subjectGroups.entries.map((e) => _buildSubjectCard(context, e.key, e.value, isDark, color)),
                  const SizedBox(height: 80),
                ],
              ),
            ),
      floatingActionButton: questions.isNotEmpty ? FloatingActionButton.extended(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => SubjectDetailScreen(subjectName: category.name, subjectId: category.id, questions: questions, color: color))),
        backgroundColor: color,
        icon: const Icon(Icons.play_arrow),
        label: const Text('Practice All'),
      ) : null,
    );
  }

  Widget _buildStatsCard(BuildContext context, bool isDark, Color color, List<QuestionBankItem> questions) {
    final diff = QuestionBank.getDifficultyDistribution(questions);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(gradient: LinearGradient(colors: [color.withOpacity(0.1), color.withOpacity(0.05)]), borderRadius: BorderRadius.circular(16), border: Border.all(color: color.withOpacity(0.2))),
      child: Column(
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.quiz, color: color, size: 28),
            const SizedBox(width: 12),
            Text('${questions.length}', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: color)),
            const SizedBox(width: 8),
            Text('Questions', style: TextStyle(fontSize: 16, color: isDark ? Colors.white70 : Colors.black54)),
          ]),
          const SizedBox(height: 16),
          Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
            _buildBadge('Easy', diff['easy'] ?? 0, ExamPrepTheme.success),
            _buildBadge('Medium', diff['medium'] ?? 0, ExamPrepTheme.warning),
            _buildBadge('Hard', diff['hard'] ?? 0, ExamPrepTheme.error),
          ]),
        ],
      ),
    );
  }

  Widget _buildBadge(String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(20)),
      child: Text('$label: $count', style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 12)),
    );
  }

  Widget _buildSubjectCard(BuildContext context, String id, List<QuestionBankItem> questions, bool isDark, Color color) {
    final name = QuestionBank.getSubjectDisplayName(id);
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => SubjectDetailScreen(subjectName: name, subjectId: id, questions: questions, color: color))),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: isDark ? const Color(0xFF1E1E2E) : Colors.white, borderRadius: BorderRadius.circular(12)),
        child: Row(
          children: [
            Container(width: 50, height: 50, decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)), child: Center(child: Text(name.isNotEmpty ? name[0] : '?', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)))),
            const SizedBox(width: 16),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: isDark ? Colors.white : Colors.black87)),
              const SizedBox(height: 4),
              Text('${questions.length} questions', style: TextStyle(fontSize: 13, color: isDark ? Colors.white54 : Colors.black45)),
            ])),
            Icon(Icons.arrow_forward_ios, size: 16, color: color),
          ],
        ),
      ),
    );
  }
}

/// Subject Detail Screen - List all questions
class SubjectDetailScreen extends StatefulWidget {
  final String subjectName;
  final String subjectId;
  final List<QuestionBankItem> questions;
  final Color? color;

  const SubjectDetailScreen({super.key, required this.subjectName, required this.subjectId, required this.questions, this.color});

  @override
  State<SubjectDetailScreen> createState() => _SubjectDetailScreenState();
}

class _SubjectDetailScreenState extends State<SubjectDetailScreen> {
  String _difficulty = 'all';
  late List<QuestionBankItem> _filtered;

  @override
  void initState() {
    super.initState();
    _filtered = widget.questions;
  }

  void _applyFilter() {
    setState(() {
      _filtered = _difficulty == 'all' ? widget.questions : widget.questions.where((q) => q.difficulty == _difficulty).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = widget.color ?? ExamPrepTheme.primary;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0A0A14) : const Color(0xFFF5F7FA),
      appBar: AppBar(backgroundColor: color, title: Text(widget.subjectName)),
      body: Column(
        children: [
          _buildFilterRow(isDark, color),
          Padding(padding: const EdgeInsets.all(16), child: Text('${_filtered.length} Questions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? Colors.white : Colors.black87))),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _filtered.length,
              itemBuilder: (context, index) => _buildQuestionTile(context, _filtered[index], index, isDark, color),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterRow(bool isDark, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      color: color.withOpacity(0.1),
      child: Row(
        children: [
          _buildChip('All', 'all', color),
          _buildChip('Easy', 'easy', ExamPrepTheme.success),
          _buildChip('Medium', 'medium', ExamPrepTheme.warning),
          _buildChip('Hard', 'hard', ExamPrepTheme.error),
        ],
      ),
    );
  }

  Widget _buildChip(String label, String value, Color color) {
    final isSelected = _difficulty == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () {
          setState(() => _difficulty = value);
          _applyFilter();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(color: isSelected ? color : color.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
          child: Text(label, style: TextStyle(color: isSelected ? Colors.white : color, fontWeight: FontWeight.w600, fontSize: 13)),
        ),
      ),
    );
  }

  Widget _buildQuestionTile(BuildContext context, QuestionBankItem q, int index, bool isDark, Color color) {
    final diffColor = q.difficulty == 'easy' ? ExamPrepTheme.success : q.difficulty == 'hard' ? ExamPrepTheme.error : ExamPrepTheme.warning;
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => QuestionViewScreen(question: q, number: index + 1, color: color))),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: isDark ? const Color(0xFF1E1E2E) : Colors.white, borderRadius: BorderRadius.circular(12)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)), child: Text('Q${index + 1}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: color))),
              const SizedBox(width: 8),
              Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: diffColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8)), child: Text(q.difficulty.toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: diffColor))),
              const Spacer(),
              Icon(Icons.arrow_forward_ios, size: 14, color: isDark ? Colors.white38 : Colors.black26),
            ]),
            const SizedBox(height: 12),
            Text(q.question, style: TextStyle(fontSize: 14, height: 1.4, color: isDark ? Colors.white70 : Colors.black87), maxLines: 3, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }
}

/// Question View Screen
class QuestionViewScreen extends StatefulWidget {
  final QuestionBankItem question;
  final int number;
  final Color color;

  const QuestionViewScreen({super.key, required this.question, required this.number, required this.color});

  @override
  State<QuestionViewScreen> createState() => _QuestionViewScreenState();
}

class _QuestionViewScreenState extends State<QuestionViewScreen> {
  int? _selected;
  bool _showAnswer = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final q = widget.question;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0A0A14) : const Color(0xFFF5F7FA),
      appBar: AppBar(backgroundColor: widget.color, title: Text('Question ${widget.number}')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildMeta(isDark),
            const SizedBox(height: 20),
            Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: isDark ? const Color(0xFF1E1E2E) : Colors.white, borderRadius: BorderRadius.circular(16)), child: Text(q.question, style: TextStyle(fontSize: 16, height: 1.6, fontWeight: FontWeight.w500, color: isDark ? Colors.white : Colors.black87))),
            const SizedBox(height: 20),
            ...List.generate(q.options.length, (i) => _buildOption(i, isDark)),
            if (_showAnswer) ...[const SizedBox(height: 20), _buildExplanation(isDark)],
            const SizedBox(height: 100),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottom(isDark),
    );
  }

  Widget _buildMeta(bool isDark) {
    final diffColor = widget.question.difficulty == 'easy' ? ExamPrepTheme.success : widget.question.difficulty == 'hard' ? ExamPrepTheme.error : ExamPrepTheme.warning;
    return Row(children: [
      Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: diffColor.withOpacity(0.15), borderRadius: BorderRadius.circular(20)), child: Text(widget.question.difficulty.toUpperCase(), style: TextStyle(color: diffColor, fontWeight: FontWeight.w600, fontSize: 12))),
      const SizedBox(width: 8),
      Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: widget.color.withOpacity(0.15), borderRadius: BorderRadius.circular(20)), child: Text(QuestionBank.getTopicDisplayName(widget.question.topicId), style: TextStyle(color: widget.color, fontWeight: FontWeight.w500, fontSize: 12))),
    ]);
  }

  Widget _buildOption(int i, bool isDark) {
    final isSelected = _selected == i;
    final isCorrect = widget.question.correctIndex == i;
    Color bg, border, text;
    if (_showAnswer) {
      if (isCorrect) { bg = ExamPrepTheme.success.withOpacity(0.15); border = ExamPrepTheme.success; text = ExamPrepTheme.success; }
      else if (isSelected) { bg = ExamPrepTheme.error.withOpacity(0.15); border = ExamPrepTheme.error; text = ExamPrepTheme.error; }
      else { bg = isDark ? const Color(0xFF1E1E2E) : Colors.white; border = Colors.transparent; text = isDark ? Colors.white70 : Colors.black54; }
    } else {
      if (isSelected) { bg = widget.color.withOpacity(0.15); border = widget.color; text = widget.color; }
      else { bg = isDark ? const Color(0xFF1E1E2E) : Colors.white; border = Colors.transparent; text = isDark ? Colors.white70 : Colors.black87; }
    }
    return GestureDetector(
      onTap: _showAnswer ? null : () => setState(() => _selected = i),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12), border: Border.all(color: border, width: 2)),
        child: Row(children: [
          Container(width: 32, height: 32, decoration: BoxDecoration(color: isSelected || (_showAnswer && isCorrect) ? (isCorrect ? ExamPrepTheme.success : ExamPrepTheme.error) : widget.color.withOpacity(0.1), shape: BoxShape.circle), child: Center(child: _showAnswer && isCorrect ? const Icon(Icons.check, color: Colors.white, size: 18) : _showAnswer && isSelected && !isCorrect ? const Icon(Icons.close, color: Colors.white, size: 18) : Text(String.fromCharCode(65 + i), style: TextStyle(fontWeight: FontWeight.bold, color: isSelected ? Colors.white : widget.color)))),
          const SizedBox(width: 16),
          Expanded(child: Text(widget.question.options[i], style: TextStyle(fontSize: 15, color: text, fontWeight: isSelected || (_showAnswer && isCorrect) ? FontWeight.w600 : FontWeight.normal))),
        ]),
      ),
    );
  }

  Widget _buildExplanation(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: ExamPrepTheme.success.withOpacity(0.1), borderRadius: BorderRadius.circular(16), border: Border.all(color: ExamPrepTheme.success.withOpacity(0.3))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Icon(Icons.lightbulb_outline, color: ExamPrepTheme.success, size: 20), const SizedBox(width: 8), Text('Explanation', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: ExamPrepTheme.success))]),
        const SizedBox(height: 12),
        Text(widget.question.explanation, style: TextStyle(fontSize: 14, height: 1.6, color: isDark ? Colors.white70 : Colors.black87)),
      ]),
    );
  }

  Widget _buildBottom(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: isDark ? const Color(0xFF1E1E2E) : Colors.white, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, -2))]),
      child: SafeArea(
        child: SizedBox(width: double.infinity, child: ElevatedButton(
          onPressed: _selected == null && !_showAnswer ? null : () => setState(() => _showAnswer = !_showAnswer),
          style: ElevatedButton.styleFrom(backgroundColor: _showAnswer ? ExamPrepTheme.primary : widget.color, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          child: Text(_showAnswer ? 'Hide Answer' : 'Check Answer', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        )),
      ),
    );
  }
}

/// Search delegate for questions
class QuestionSearchDelegate extends SearchDelegate<QuestionBankItem?> {
  @override
  List<Widget> buildActions(BuildContext context) => [IconButton(icon: const Icon(Icons.clear), onPressed: () => query = '')];

  @override
  Widget buildLeading(BuildContext context) => IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => close(context, null));

  @override
  Widget buildResults(BuildContext context) => _buildSearchResults(context);

  @override
  Widget buildSuggestions(BuildContext context) => _buildSearchResults(context);

  Widget _buildSearchResults(BuildContext context) {
    if (query.isEmpty) return const Center(child: Text('Search questions...'));
    final results = QuestionBank.getAllQuestions().where((q) => q.question.toLowerCase().contains(query.toLowerCase())).take(50).toList();
    if (results.isEmpty) return const Center(child: Text('No results found'));
    return ListView.builder(
      itemCount: results.length,
      itemBuilder: (context, i) => ListTile(
        title: Text(results[i].question, maxLines: 2, overflow: TextOverflow.ellipsis),
        subtitle: Text(QuestionBank.getSubjectDisplayName(results[i].subjectId)),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => QuestionViewScreen(question: results[i], number: i + 1, color: ExamPrepTheme.primary))),
      ),
    );
  }
}

/// All Subjects Screen
class AllSubjectsScreen extends StatelessWidget {
  final List<MapEntry<String, List<QuestionBankItem>>> subjects;
  const AllSubjectsScreen({super.key, required this.subjects});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(title: const Text('All Subjects'), backgroundColor: ExamPrepTheme.primary),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: subjects.length,
        itemBuilder: (context, i) {
          final entry = subjects[i];
          final name = QuestionBank.getSubjectDisplayName(entry.key);
          return ListTile(
            leading: CircleAvatar(backgroundColor: ExamPrepTheme.primary.withOpacity(0.1), child: Text(name[0], style: TextStyle(color: ExamPrepTheme.primary))),
            title: Text(name),
            trailing: Text('${entry.value.length}'),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => SubjectDetailScreen(subjectName: name, subjectId: entry.key, questions: entry.value))),
          );
        },
      ),
    );
  }
}
