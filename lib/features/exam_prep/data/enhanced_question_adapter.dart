/// Enhanced Question Adapter
/// Bridges the new EnhancedQuestion format with existing QuestionBankItem format

import '../models/problem_solving_approach.dart';
import '../models/solution_steps.dart';
import 'question_bank_data.dart';
import 'templates/question_templates.dart' as enhanced;

/// Adapter to convert EnhancedQuestion to QuestionBankItem
class EnhancedQuestionAdapter {
  /// Convert a single EnhancedQuestion to QuestionBankItem
  static QuestionBankItem toQuestionBankItem(EnhancedQuestion eq) {
    return QuestionBankItem(
      id: eq.id,
      question: eq.question,
      options: eq.options,
      correctIndex: eq.correctOptionIndex,
      explanation: eq.explanation,
      subjectId: _normalizeSubjectId(eq.subject),
      topicId: _normalizeTopicId(eq.topic),
      difficulty: eq.difficulty,
      examCategory: eq.examType,
      tags: eq.tags,
      solutionSteps: _convertApproachToSteps(eq.approach),
      concept: eq.approach?.conceptRequired,
      timeTaken: eq.timeInSeconds,
    );
  }

  /// Convert list of EnhancedQuestions to QuestionBankItems
  static List<QuestionBankItem> toQuestionBankItems(List<EnhancedQuestion> questions) {
    return questions.map(toQuestionBankItem).toList();
  }

  /// Get all enhanced questions as QuestionBankItems for a specific exam
  static List<QuestionBankItem> getForExam(String examType) {
    final enhancedQuestions = enhanced.MasterQuestionGenerator.generateForExam(examType);
    return toQuestionBankItems(enhancedQuestions);
  }

  /// Get all enhanced questions as QuestionBankItems
  static List<QuestionBankItem> getAll() {
    final enhancedQuestions = enhanced.MasterQuestionGenerator.generateAllQuestions();
    return toQuestionBankItems(enhancedQuestions);
  }

  /// Get question count for each exam type
  static Map<String, int> getQuestionCounts() {
    return enhanced.MasterQuestionGenerator.examQuestionCounts;
  }

  /// Get total question count
  static int get totalCount => enhanced.MasterQuestionGenerator.totalQuestionCount;

  /// Normalize subject ID to match existing system
  static String _normalizeSubjectId(String subject) {
    final normalized = subject.toLowerCase().replaceAll(' ', '_');
    final mapping = {
      'quantitative_aptitude': 'quant',
      'reasoning_ability': 'reasoning',
      'logical_reasoning': 'reasoning',
      'english_language': 'english',
      'general_awareness': 'gk',
      'general_knowledge': 'gk',
      'current_affairs': 'gk',
      'general_studies': 'gk',
      'physics': 'physics_adv',
      'chemistry': 'chemistry_adv',
      'biology': 'biology',
      'mathematics': 'math_higher',
      'data_interpretation': 'di_advanced',
      'verbal_ability': 'english',
      'legal_reasoning': 'legal',
      'legal_knowledge': 'legal',
      'engineering_mathematics': 'math_higher',
      'computer_science': 'computer',
      'digital_logic': 'computer',
    };
    return mapping[normalized] ?? normalized;
  }

  /// Normalize topic ID to match existing system
  static String _normalizeTopicId(String topic) {
    return topic.toLowerCase().replaceAll(' ', '_').replaceAll('-', '_');
  }

  /// Convert ProblemSolvingApproach to SolutionSteps
  static SolutionSteps? _convertApproachToSteps(ProblemSolvingApproach? approach) {
    if (approach == null) return null;
    
    return SolutionSteps(
      approach: approach.howToRecognize,
      steps: approach.thinkingProcess,
      commonMistake: approach.avoidMistakes.isNotEmpty ? approach.avoidMistakes.first : null,
      proTip: approach.timeManagement,
    );
  }
}

/// Extended QuestionBank that includes enhanced questions
class ExtendedQuestionBank {
  ExtendedQuestionBank._();

  /// Get all questions including enhanced templates
  static List<QuestionBankItem> getAllQuestions() {
    return [
      ...QuestionBank.getStaticQuestions(),
      ...QuestionBank.getGeneratedQuestions(),
      ...EnhancedQuestionAdapter.getAll(),
    ];
  }

  /// Get questions by exam category including enhanced
  static List<QuestionBankItem> getByExamCategory(String category) {
    final static = QuestionBank.getByExamCategory(category);
    final enhanced = EnhancedQuestionAdapter.getForExam(category);
    return [...static, ...enhanced];
  }

  /// Get total question count
  static int get totalQuestions {
    return QuestionBank.totalQuestions + EnhancedQuestionAdapter.totalCount;
  }

  /// Get question statistics
  static Map<String, dynamic> getStats() {
    return {
      'staticQuestions': QuestionBank.getStaticQuestions().length,
      'generatedQuestions': QuestionBank.getGeneratedQuestions().length,
      'enhancedQuestions': EnhancedQuestionAdapter.totalCount,
      'totalQuestions': totalQuestions,
      'examBreakdown': EnhancedQuestionAdapter.getQuestionCounts(),
    };
  }
}
