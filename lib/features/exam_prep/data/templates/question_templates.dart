/// Question Templates Barrel File
/// Exports all exam-specific question generators

export 'banking_questions.dart';
export 'ssc_questions.dart';
export 'jee_neet_questions.dart';
export 'cat_gate_questions.dart';
export 'upsc_clat_questions.dart';

import 'banking_questions.dart';
import 'ssc_questions.dart';
import 'jee_neet_questions.dart';
import 'cat_gate_questions.dart';
import 'upsc_clat_questions.dart';
import '../../models/problem_solving_approach.dart';

/// Master Question Generator
/// Generates questions for all 8 exam types with problem-solving methodology
class MasterQuestionGenerator {
  /// Get total question count across all exams
  static int get totalQuestionCount {
    return BankingQuestionTemplates.totalQuestionCount +
        SSCQuestionTemplates.totalQuestionCount +
        JEEQuestionTemplates.totalQuestionCount +
        NEETQuestionTemplates.totalQuestionCount +
        CATQuestionTemplates.totalQuestionCount +
        GATEQuestionTemplates.totalQuestionCount +
        UPSCQuestionTemplates.totalQuestionCount +
        CLATQuestionTemplates.totalQuestionCount;
  }

  /// Generate all questions for a specific exam
  static List<EnhancedQuestion> generateForExam(String examType) {
    switch (examType.toLowerCase()) {
      case 'banking':
      case 'ibps':
      case 'sbi':
      case 'rbi':
        return BankingQuestionTemplates.generateAllQuestions();
      case 'ssc':
      case 'ssc-cgl':
      case 'ssc-chsl':
        return SSCQuestionTemplates.generateAllQuestions();
      case 'jee':
      case 'jee-main':
      case 'jee-advanced':
        return JEEQuestionTemplates.generateAllQuestions();
      case 'neet':
        return NEETQuestionTemplates.generateAllQuestions();
      case 'cat':
      case 'mba':
        return CATQuestionTemplates.generateAllQuestions();
      case 'gate':
        return GATEQuestionTemplates.generateAllQuestions();
      case 'upsc':
      case 'ias':
      case 'civil-services':
        return UPSCQuestionTemplates.generateAllQuestions();
      case 'clat':
      case 'law':
        return CLATQuestionTemplates.generateAllQuestions();
      default:
        return [];
    }
  }

  /// Generate all questions for all exams
  static List<EnhancedQuestion> generateAllQuestions() {
    return [
      ...BankingQuestionTemplates.generateAllQuestions(),
      ...SSCQuestionTemplates.generateAllQuestions(),
      ...JEEQuestionTemplates.generateAllQuestions(),
      ...NEETQuestionTemplates.generateAllQuestions(),
      ...CATQuestionTemplates.generateAllQuestions(),
      ...GATEQuestionTemplates.generateAllQuestions(),
      ...UPSCQuestionTemplates.generateAllQuestions(),
      ...CLATQuestionTemplates.generateAllQuestions(),
    ];
  }

  /// Get questions by subject for a specific exam
  static List<EnhancedQuestion> getBySubject(String examType, String subject) {
    final allQuestions = generateForExam(examType);
    return allQuestions
        .where((q) => q.subject.toLowerCase() == subject.toLowerCase())
        .toList();
  }

  /// Get questions by topic
  static List<EnhancedQuestion> getByTopic(String examType, String topic) {
    final allQuestions = generateForExam(examType);
    return allQuestions
        .where((q) => q.topic.toLowerCase() == topic.toLowerCase())
        .toList();
  }

  /// Get questions by difficulty
  static List<EnhancedQuestion> getByDifficulty(
      String examType, String difficulty) {
    final allQuestions = generateForExam(examType);
    return allQuestions
        .where((q) => q.difficulty.toLowerCase() == difficulty.toLowerCase())
        .toList();
  }

  /// Get exam statistics
  static Map<String, dynamic> getExamStats(String examType) {
    final questions = generateForExam(examType);
    final subjects = <String>{};
    final topics = <String>{};
    final difficulties = <String, int>{};

    for (final q in questions) {
      subjects.add(q.subject);
      topics.add(q.topic);
      difficulties[q.difficulty] = (difficulties[q.difficulty] ?? 0) + 1;
    }

    return {
      'totalQuestions': questions.length,
      'subjects': subjects.toList(),
      'topics': topics.toList(),
      'difficultyDistribution': difficulties,
    };
  }

  /// Get all supported exam types
  static List<String> get supportedExams => [
        'Banking (IBPS/SBI/RBI)',
        'SSC (CGL/CHSL/MTS)',
        'JEE (Main/Advanced)',
        'NEET',
        'CAT (MBA)',
        'GATE',
        'UPSC (Civil Services)',
        'CLAT (Law)',
      ];

  /// Get exam-specific question counts
  static Map<String, int> get examQuestionCounts => {
        'Banking': BankingQuestionTemplates.totalQuestionCount,
        'SSC': SSCQuestionTemplates.totalQuestionCount,
        'JEE': JEEQuestionTemplates.totalQuestionCount,
        'NEET': NEETQuestionTemplates.totalQuestionCount,
        'CAT': CATQuestionTemplates.totalQuestionCount,
        'GATE': GATEQuestionTemplates.totalQuestionCount,
        'UPSC': UPSCQuestionTemplates.totalQuestionCount,
        'CLAT': CLATQuestionTemplates.totalQuestionCount,
      };
}
