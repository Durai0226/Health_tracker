/// Question Bank Data - Core structure and index
/// Individual subject questions are in separate files for maintainability
/// Covers 18 subjects across Government Exams + Entrance Exams
/// Target: 30,000+ questions across all exam categories with step-by-step solutions

import '../models/solution_steps.dart';

// Core competitive exam subjects
import 'questions_quant.dart';
import 'questions_reasoning.dart';
import 'questions_english.dart';
import 'questions_gk.dart';
import 'questions_computer.dart';
import 'questions_science.dart';

// Advanced subjects for JEE/NEET/GATE
import 'subjects/questions_physics_adv.dart';
import 'subjects/questions_chemistry_adv.dart';
import 'subjects/questions_biology.dart';
import 'subjects/questions_math_higher.dart';

// UPSC/Civil Services subjects
import 'subjects/questions_history.dart';
import 'subjects/questions_polity.dart';
import 'subjects/questions_geography.dart';
import 'subjects/questions_economics.dart';
import 'subjects/questions_environment.dart';

// Entrance exam specific subjects
import 'subjects/questions_legal.dart';
import 'subjects/questions_lr_cat.dart';
import 'subjects/questions_di_advanced.dart';

// Banking & Insurance Exams
import 'banking/ibps_po_questions.dart';
import 'banking/sbi_po_questions.dart';
import 'banking/ibps_clerk_questions.dart';
import 'banking/sbi_clerk_questions.dart';
import 'banking/rbi_grade_b_questions.dart';
import 'banking/lic_aao_questions.dart';
import 'banking/banking_bulk_questions.dart';
import 'banking/banking_advanced_questions.dart';

// SSC & Railways Exams
import 'ssc/ssc_cgl_questions.dart';
import 'ssc/ssc_chsl_questions.dart';
import 'ssc/rrb_ntpc_questions.dart';
import 'ssc/ssc_bulk_questions.dart';
import 'ssc/ssc_advanced_questions.dart';

// UPSC Exams
import 'upsc/upsc_prelims_questions.dart';
import 'upsc/upsc_csat_questions.dart';
import 'upsc/upsc_bulk_questions.dart';

// Entrance Exams (JEE/NEET)
import 'entrance/jee_main_questions.dart';
import 'entrance/neet_questions.dart';
import 'entrance/entrance_bulk_questions.dart';
import 'entrance/entrance_advanced_questions.dart';

// Management Exams (CAT/XAT)
import 'management/cat_questions.dart';
import 'management/cat_bulk_questions.dart';

// Other Exams (GATE/CLAT)
import 'others/gate_questions.dart';
import 'others/clat_questions.dart';
import 'others/others_bulk_questions.dart';

// Generated question templates for 30,000+ questions
import 'question_templates.dart';

class QuestionBankItem {
  final String id;
  final String question;
  final List<String> options;
  final int correctIndex;
  final String explanation;
  final String subjectId;
  final String topicId;
  final String difficulty; // easy, medium, hard
  final String? examCategory; // banking, ssc, railways, etc.
  final int? year; // Previous year paper year
  final List<String> tags;
  
  // Step-by-step solution fields
  final SolutionSteps? solutionSteps;
  final String? concept;      // Key concept tested
  final String? formula;      // Formula used (if applicable)
  final String? shortcut;     // Quick trick for competitive exams
  final int? timeTaken;       // Estimated seconds to solve

  const QuestionBankItem({
    required this.id,
    required this.question,
    required this.options,
    required this.correctIndex,
    required this.explanation,
    required this.subjectId,
    required this.topicId,
    this.difficulty = 'medium',
    this.examCategory,
    this.year,
    this.tags = const [],
    this.solutionSteps,
    this.concept,
    this.formula,
    this.shortcut,
    this.timeTaken,
  });

  String get correctAnswer => options[correctIndex];
  
  bool checkAnswer(int selectedIndex) => selectedIndex == correctIndex;
  
  /// Check if this question has detailed step-by-step solution
  bool get hasDetailedSolution => solutionSteps != null;
  
  /// Get full solution text (for backward compatibility)
  String get fullSolution {
    if (solutionSteps == null) return explanation;
    
    final buffer = StringBuffer();
    buffer.writeln('📝 Approach: ${solutionSteps!.approach}');
    buffer.writeln();
    buffer.writeln('📋 Steps:');
    for (int i = 0; i < solutionSteps!.steps.length; i++) {
      buffer.writeln('${i + 1}. ${solutionSteps!.steps[i]}');
    }
    if (solutionSteps!.commonMistake != null) {
      buffer.writeln();
      buffer.writeln('⚠️ Common Mistake: ${solutionSteps!.commonMistake}');
    }
    if (solutionSteps!.proTip != null) {
      buffer.writeln();
      buffer.writeln('💡 Pro Tip: ${solutionSteps!.proTip}');
    }
    return buffer.toString();
  }
  
  /// Create from JSON (for cloud/local loading)
  factory QuestionBankItem.fromJson(Map<String, dynamic> json) {
    return QuestionBankItem(
      id: json['id'] ?? '',
      question: json['question'] ?? '',
      options: List<String>.from(json['options'] ?? []),
      correctIndex: json['correctIndex'] ?? 0,
      explanation: json['explanation'] ?? '',
      subjectId: json['subjectId'] ?? '',
      topicId: json['topicId'] ?? '',
      difficulty: json['difficulty'] ?? 'medium',
      examCategory: json['examCategory'],
      year: json['year'],
      tags: List<String>.from(json['tags'] ?? []),
      solutionSteps: json['solutionSteps'] != null
          ? SolutionSteps.fromJson(json['solutionSteps'])
          : null,
      concept: json['concept'],
      formula: json['formula'],
      shortcut: json['shortcut'],
      timeTaken: json['timeTaken'],
    );
  }
  
  /// Convert to JSON (for cloud upload)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'question': question,
      'options': options,
      'correctIndex': correctIndex,
      'explanation': explanation,
      'subjectId': subjectId,
      'topicId': topicId,
      'difficulty': difficulty,
      if (examCategory != null) 'examCategory': examCategory,
      if (year != null) 'year': year,
      'tags': tags,
      if (solutionSteps != null) 'solutionSteps': solutionSteps!.toJson(),
      if (concept != null) 'concept': concept,
      if (formula != null) 'formula': formula,
      if (shortcut != null) 'shortcut': shortcut,
      if (timeTaken != null) 'timeTaken': timeTaken,
    };
  }
  
  /// Create a copy with new values
  QuestionBankItem copyWith({
    String? id,
    String? question,
    List<String>? options,
    int? correctIndex,
    String? explanation,
    String? subjectId,
    String? topicId,
    String? difficulty,
    String? examCategory,
    int? year,
    List<String>? tags,
    SolutionSteps? solutionSteps,
    String? concept,
    String? formula,
    String? shortcut,
    int? timeTaken,
  }) {
    return QuestionBankItem(
      id: id ?? this.id,
      question: question ?? this.question,
      options: options ?? this.options,
      correctIndex: correctIndex ?? this.correctIndex,
      explanation: explanation ?? this.explanation,
      subjectId: subjectId ?? this.subjectId,
      topicId: topicId ?? this.topicId,
      difficulty: difficulty ?? this.difficulty,
      examCategory: examCategory ?? this.examCategory,
      year: year ?? this.year,
      tags: tags ?? this.tags,
      solutionSteps: solutionSteps ?? this.solutionSteps,
      concept: concept ?? this.concept,
      formula: formula ?? this.formula,
      shortcut: shortcut ?? this.shortcut,
      timeTaken: timeTaken ?? this.timeTaken,
    );
  }
}

/// Central question bank access
class QuestionBank {
  QuestionBank._();
  
  // Cached generated questions for performance
  static List<QuestionBankItem>? _generatedQuestionsCache;
  static bool _isGenerating = false;
  
  /// Get generated questions with step-by-step solutions (30,000+)
  static List<QuestionBankItem> getGeneratedQuestions() {
    if (_generatedQuestionsCache == null && !_isGenerating) {
      _isGenerating = true;
      _generatedQuestionsCache = _generateAllQuestions();
      _isGenerating = false;
    }
    return _generatedQuestionsCache ?? [];
  }
  
  /// Generate all questions across 8 exam categories
  static List<QuestionBankItem> _generateAllQuestions() {
    final allGenerated = <QuestionBankItem>[];
    final categories = ['banking', 'ssc', 'upsc', 'jee', 'neet', 'cat', 'gate', 'clat'];
    
    for (final category in categories) {
      // Each category gets ~3,750 questions for 30,000+ total
      allGenerated.addAll(QuestionTemplates.generateCategoryQuestions(category, questionsPerTopic: 470));
    }
    
    return allGenerated;
  }

  /// Get all questions (static + generated = 30,000+)
  static List<QuestionBankItem> getAllQuestions() {
    return [
      // Core competitive subjects
      ...QuantQuestions.all,
      ...ReasoningQuestions.all,
      ...EnglishQuestions.all,
      ...GKQuestions.all,
      ...ComputerQuestions.all,
      ...ScienceQuestions.all,
      // Advanced subjects (JEE/NEET/GATE)
      ...PhysicsAdvQuestions.all,
      ...ChemistryAdvQuestions.all,
      ...BiologyQuestions.all,
      ...MathHigherQuestions.all,
      // UPSC/Civil Services subjects
      ...HistoryQuestions.all,
      ...PolityQuestions.all,
      ...GeographyQuestions.all,
      ...EconomicsQuestions.all,
      ...EnvironmentQuestions.all,
      // Entrance exam subjects
      ...LegalQuestions.all,
      ...LRCATQuestions.all,
      ...DIAdvancedQuestions.all,
      // Banking & Insurance Exams
      ...IBPSPOQuestions.all,
      ...SBIPOQuestions.all,
      ...IBPSClerkQuestions.all,
      ...SBIClerkQuestions.all,
      ...RBIGradeBQuestions.all,
      ...LICAAOQuestions.all,
      ...BankingBulkQuestions.all,
      ...BankingAdvancedQuestions.all,
      // SSC & Railways Exams
      ...SSCCGLQuestions.all,
      ...SSCCHSLQuestions.all,
      ...RRBNTPCQuestions.all,
      ...SSCBulkQuestions.all,
      ...SSCAdvancedQuestions.all,
      // UPSC Exams
      ...UPSCPrelimsQuestions.all,
      ...UPSCCSATQuestions.all,
      ...UPSCBulkQuestions.all,
      // Entrance Exams (JEE/NEET)
      ...JEEMainQuestions.all,
      ...NEETQuestions.all,
      ...EntranceBulkQuestions.all,
      ...EntranceAdvancedQuestions.all,
      // Management Exams (CAT/XAT)
      ...CATQuestions.all,
      ...CATBulkQuestions.all,
      // Other Exams (GATE/CLAT)
      ...GATEQuestions.all,
      ...CLATQuestions.all,
      ...OthersBulkQuestions.all,
      // Generated questions with step-by-step solutions (30,000+)
      ...getGeneratedQuestions(),
    ];
  }
  
  /// Get only static (pre-defined) questions
  static List<QuestionBankItem> getStaticQuestions() {
    return [
      ...QuantQuestions.all,
      ...ReasoningQuestions.all,
      ...EnglishQuestions.all,
      ...GKQuestions.all,
      ...ComputerQuestions.all,
      ...ScienceQuestions.all,
      ...PhysicsAdvQuestions.all,
      ...ChemistryAdvQuestions.all,
      ...BiologyQuestions.all,
      ...MathHigherQuestions.all,
      ...HistoryQuestions.all,
      ...PolityQuestions.all,
      ...GeographyQuestions.all,
      ...EconomicsQuestions.all,
      ...EnvironmentQuestions.all,
      ...LegalQuestions.all,
      ...LRCATQuestions.all,
      ...DIAdvancedQuestions.all,
      ...IBPSPOQuestions.all,
      ...SBIPOQuestions.all,
      ...IBPSClerkQuestions.all,
      ...SBIClerkQuestions.all,
      ...RBIGradeBQuestions.all,
      ...LICAAOQuestions.all,
      ...BankingBulkQuestions.all,
      ...BankingAdvancedQuestions.all,
      ...SSCCGLQuestions.all,
      ...SSCCHSLQuestions.all,
      ...RRBNTPCQuestions.all,
      ...SSCBulkQuestions.all,
      ...SSCAdvancedQuestions.all,
      ...UPSCPrelimsQuestions.all,
      ...UPSCCSATQuestions.all,
      ...UPSCBulkQuestions.all,
      ...JEEMainQuestions.all,
      ...NEETQuestions.all,
      ...EntranceBulkQuestions.all,
      ...EntranceAdvancedQuestions.all,
      ...CATQuestions.all,
      ...CATBulkQuestions.all,
      ...GATEQuestions.all,
      ...CLATQuestions.all,
      ...OthersBulkQuestions.all,
    ];
  }
  
  /// Get questions with detailed step-by-step solutions
  static List<QuestionBankItem> getQuestionsWithSolutions() {
    return getAllQuestions().where((q) => q.hasDetailedSolution).toList();
  }

  /// Get questions by subject
  static List<QuestionBankItem> getBySubject(String subjectId) {
    switch (subjectId.toLowerCase()) {
      // Core competitive subjects
      case 'quant':
      case 'quantitative':
      case 'quantitative aptitude':
        return QuantQuestions.all;
      case 'reasoning':
      case 'reasoning ability':
        return ReasoningQuestions.all;
      case 'english':
      case 'english language':
        return EnglishQuestions.all;
      case 'gk':
      case 'general awareness':
      case 'general knowledge':
      case 'current affairs':
        return GKQuestions.all;
      case 'computer':
      case 'computer awareness':
        return ComputerQuestions.all;
      case 'science':
      case 'general science':
        return ScienceQuestions.all;
      // Advanced subjects (JEE/NEET/GATE)
      case 'physics_adv':
      case 'physics':
      case 'physics (advanced)':
        return PhysicsAdvQuestions.all;
      case 'chemistry_adv':
      case 'chemistry':
      case 'chemistry (advanced)':
        return ChemistryAdvQuestions.all;
      case 'biology':
        return BiologyQuestions.all;
      case 'math_higher':
      case 'mathematics':
      case 'mathematics (higher)':
        return MathHigherQuestions.all;
      // UPSC/Civil Services subjects
      case 'history':
      case 'indian history':
        return HistoryQuestions.all;
      case 'polity':
      case 'indian polity':
        return PolityQuestions.all;
      case 'geography':
        return GeographyQuestions.all;
      case 'economics':
        return EconomicsQuestions.all;
      case 'environment':
      case 'environment & ecology':
        return EnvironmentQuestions.all;
      // Entrance exam subjects
      case 'legal':
      case 'legal aptitude':
        return LegalQuestions.all;
      case 'lr_cat':
      case 'logical reasoning (cat)':
        return LRCATQuestions.all;
      case 'di_advanced':
      case 'data interpretation':
      case 'data interpretation (adv)':
        return DIAdvancedQuestions.all;
      default:
        // Try to find by exact subjectId
        return getAllQuestions().where((q) => q.subjectId == subjectId).toList();
    }
  }

  /// Get questions by topic
  static List<QuestionBankItem> getByTopic(String topicId) {
    return getAllQuestions().where((q) => q.topicId == topicId).toList();
  }

  /// Get questions by difficulty
  static List<QuestionBankItem> getByDifficulty(String difficulty) {
    return getAllQuestions().where((q) => q.difficulty == difficulty).toList();
  }

  /// Get questions by exam category
  static List<QuestionBankItem> getByExamCategory(String category) {
    final cat = category.toLowerCase();
    // SSC category includes railways
    if (cat == 'ssc') {
      return getAllQuestions()
          .where((q) => q.examCategory?.toLowerCase() == 'ssc' || q.examCategory?.toLowerCase() == 'railways')
          .toList();
    }
    return getAllQuestions()
        .where((q) => q.examCategory?.toLowerCase() == cat)
        .toList();
  }

  /// Get previous year questions
  static List<QuestionBankItem> getPreviousYearQuestions({int? year, String? examCategory}) {
    return getAllQuestions().where((q) {
      if (q.year == null) return false;
      if (year != null && q.year != year) return false;
      if (examCategory != null && q.examCategory?.toLowerCase() != examCategory.toLowerCase()) return false;
      return true;
    }).toList();
  }

  /// Get random questions for practice
  static List<QuestionBankItem> getRandomQuestions({
    int count = 10,
    String? subjectId,
    String? topicId,
    String? difficulty,
  }) {
    var questions = getAllQuestions();
    
    if (subjectId != null) {
      questions = questions.where((q) => q.subjectId == subjectId).toList();
    }
    if (topicId != null) {
      questions = questions.where((q) => q.topicId == topicId).toList();
    }
    if (difficulty != null) {
      questions = questions.where((q) => q.difficulty == difficulty).toList();
    }
    
    questions.shuffle();
    return questions.take(count).toList();
  }

  /// Generate mock test
  static List<QuestionBankItem> generateMockTest({
    required String examId,
    required int totalQuestions,
    Map<String, int>? sectionDistribution,
  }) {
    List<QuestionBankItem> mockTest = [];
    
    if (sectionDistribution != null) {
      for (final entry in sectionDistribution.entries) {
        final sectionQuestions = getBySubject(entry.key);
        sectionQuestions.shuffle();
        mockTest.addAll(sectionQuestions.take(entry.value));
      }
    } else {
      final allQuestions = getAllQuestions();
      allQuestions.shuffle();
      mockTest = allQuestions.take(totalQuestions).toList();
    }
    
    return mockTest;
  }

  /// Get question count by subject
  static Map<String, int> getQuestionCountBySubject() {
    return {
      // Core competitive subjects
      'Quantitative Aptitude': QuantQuestions.all.length,
      'Reasoning': ReasoningQuestions.all.length,
      'English': EnglishQuestions.all.length,
      'General Awareness': GKQuestions.all.length,
      'Computer': ComputerQuestions.all.length,
      'General Science': ScienceQuestions.all.length,
      // Advanced subjects (JEE/NEET/GATE)
      'Physics (Advanced)': PhysicsAdvQuestions.all.length,
      'Chemistry (Advanced)': ChemistryAdvQuestions.all.length,
      'Biology': BiologyQuestions.all.length,
      'Mathematics (Higher)': MathHigherQuestions.all.length,
      // UPSC/Civil Services
      'Indian History': HistoryQuestions.all.length,
      'Indian Polity': PolityQuestions.all.length,
      'Geography': GeographyQuestions.all.length,
      'Economics': EconomicsQuestions.all.length,
      'Environment & Ecology': EnvironmentQuestions.all.length,
      // Entrance exams
      'Legal Aptitude': LegalQuestions.all.length,
      'Logical Reasoning (CAT)': LRCATQuestions.all.length,
      'Data Interpretation (Adv)': DIAdvancedQuestions.all.length,
    };
  }

  /// Get total question count
  static int get totalQuestions => getAllQuestions().length;

  /// Get all exam categories with their question counts
  static List<ExamCategoryInfo> getExamCategories() {
    final all = getAllQuestions();
    
    return [
      ExamCategoryInfo(
        id: 'banking',
        name: 'Banking & Insurance',
        icon: 'account_balance',
        color: 0xFF1E88E5,
        description: 'IBPS PO/Clerk, SBI PO/Clerk, RBI, LIC',
        questionCount: all.where((q) => q.examCategory == 'banking').length,
        subjects: ['Quantitative', 'Reasoning', 'English', 'Banking Awareness'],
      ),
      ExamCategoryInfo(
        id: 'ssc',
        name: 'SSC & Railways',
        icon: 'train',
        color: 0xFF43A047,
        description: 'SSC CGL, CHSL, RRB NTPC, Group D',
        questionCount: all.where((q) => q.examCategory == 'ssc' || q.examCategory == 'railways').length,
        subjects: ['Quantitative', 'Reasoning', 'English', 'General Awareness'],
      ),
      ExamCategoryInfo(
        id: 'upsc',
        name: 'UPSC Civil Services',
        icon: 'assured_workload',
        color: 0xFF8E24AA,
        description: 'Prelims, CSAT, Mains',
        questionCount: all.where((q) => q.examCategory == 'upsc').length,
        subjects: ['History', 'Polity', 'Geography', 'Economics', 'Environment'],
      ),
      ExamCategoryInfo(
        id: 'jee',
        name: 'JEE Main & Advanced',
        icon: 'school',
        color: 0xFFFF7043,
        description: 'Engineering Entrance',
        questionCount: all.where((q) => q.examCategory == 'jee').length,
        subjects: ['Physics', 'Chemistry', 'Mathematics'],
      ),
      ExamCategoryInfo(
        id: 'neet',
        name: 'NEET',
        icon: 'medical_services',
        color: 0xFF26A69A,
        description: 'Medical Entrance',
        questionCount: all.where((q) => q.examCategory == 'neet').length,
        subjects: ['Physics', 'Chemistry', 'Biology'],
      ),
      ExamCategoryInfo(
        id: 'cat',
        name: 'CAT & Management',
        icon: 'business_center',
        color: 0xFFFFB300,
        description: 'CAT, XAT, MAT, SNAP',
        questionCount: all.where((q) => q.examCategory == 'cat').length,
        subjects: ['Quantitative', 'VARC', 'DILR'],
      ),
      ExamCategoryInfo(
        id: 'gate',
        name: 'GATE',
        icon: 'engineering',
        color: 0xFF5C6BC0,
        description: 'Graduate Aptitude Test',
        questionCount: all.where((q) => q.examCategory == 'gate').length,
        subjects: ['Programming', 'Data Structures', 'Algorithms', 'Digital Logic'],
      ),
      ExamCategoryInfo(
        id: 'clat',
        name: 'CLAT & Law',
        icon: 'gavel',
        color: 0xFF78909C,
        description: 'Law Entrance',
        questionCount: all.where((q) => q.examCategory == 'clat').length,
        subjects: ['Legal Aptitude', 'English', 'Logical Reasoning', 'GK'],
      ),
    ];
  }

  /// Get questions grouped by subject for a specific exam category
  static Map<String, List<QuestionBankItem>> getQuestionsBySubjectForCategory(String categoryId) {
    final questions = getByExamCategory(categoryId);
    final Map<String, List<QuestionBankItem>> grouped = {};
    
    for (final q in questions) {
      final subject = q.subjectId;
      if (!grouped.containsKey(subject)) {
        grouped[subject] = [];
      }
      grouped[subject]!.add(q);
    }
    
    return grouped;
  }

  /// Get questions grouped by topic for a subject
  static Map<String, List<QuestionBankItem>> getQuestionsByTopic(List<QuestionBankItem> questions) {
    final Map<String, List<QuestionBankItem>> grouped = {};
    
    for (final q in questions) {
      final topic = q.topicId;
      if (!grouped.containsKey(topic)) {
        grouped[topic] = [];
      }
      grouped[topic]!.add(q);
    }
    
    return grouped;
  }

  /// Get difficulty distribution for questions
  static Map<String, int> getDifficultyDistribution(List<QuestionBankItem> questions) {
    return {
      'easy': questions.where((q) => q.difficulty == 'easy').length,
      'medium': questions.where((q) => q.difficulty == 'medium').length,
      'hard': questions.where((q) => q.difficulty == 'hard').length,
    };
  }

  /// Get unique subjects from questions
  static List<String> getUniqueSubjects(List<QuestionBankItem> questions) {
    return questions.map((q) => q.subjectId).toSet().toList();
  }

  /// Get unique topics from questions
  static List<String> getUniqueTopics(List<QuestionBankItem> questions) {
    return questions.map((q) => q.topicId).toSet().toList();
  }

  /// Get subject display name
  static String getSubjectDisplayName(String subjectId) {
    final displayNames = {
      'quant': 'Quantitative Aptitude',
      'reasoning': 'Reasoning Ability',
      'english': 'English Language',
      'gk': 'General Knowledge',
      'computer': 'Computer Awareness',
      'science': 'General Science',
      'physics_adv': 'Physics',
      'chemistry_adv': 'Chemistry',
      'biology': 'Biology',
      'math_higher': 'Mathematics',
      'history': 'Indian History',
      'polity': 'Indian Polity',
      'geography': 'Geography',
      'economics': 'Economics',
      'environment': 'Environment & Ecology',
      'legal': 'Legal Aptitude',
      'lr_cat': 'Logical Reasoning',
      'di_advanced': 'Data Interpretation',
    };
    return displayNames[subjectId] ?? subjectId.replaceAll('_', ' ').toUpperCase();
  }

  /// Get topic display name
  static String getTopicDisplayName(String topicId) {
    return topicId.replaceAll('_', ' ').split(' ').map((w) => 
      w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : w
    ).join(' ');
  }
}

/// Exam Category Information Model
class ExamCategoryInfo {
  final String id;
  final String name;
  final String icon;
  final int color;
  final String description;
  final int questionCount;
  final List<String> subjects;

  const ExamCategoryInfo({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
    required this.description,
    required this.questionCount,
    required this.subjects,
  });
}
