/// Thinking Guides Barrel File
/// Exports all subject-specific thinking methodologies

export 'reasoning_thinking.dart';
export 'quant_thinking.dart';

import 'reasoning_thinking.dart';
import 'quant_thinking.dart';
import '../../models/problem_solving_approach.dart';

/// Master Thinking Guide Provider
/// Provides thinking methodologies for all question types across exams
class ThinkingGuideProvider {
  /// Get all reasoning thinking guides
  static List<ThinkingGuide> get reasoningGuides =>
      ReasoningThinkingGuides.all;

  /// Get all quantitative aptitude thinking guides
  static List<ThinkingGuide> get quantGuides =>
      QuantThinkingGuides.all;

  /// Get all thinking guides
  static List<ThinkingGuide> get allGuides => [
        ...reasoningGuides,
        ...quantGuides,
      ];

  /// Get thinking guide by question type
  static ThinkingGuide? getGuideFor(String questionType) {
    final normalized = questionType.toLowerCase().replaceAll(' ', '_');
    
    // Check reasoning guides
    final reasoningGuide = reasoningGuides.where(
      (g) => g.questionType.toLowerCase().replaceAll(' ', '_') == normalized,
    );
    if (reasoningGuide.isNotEmpty) return reasoningGuide.first;
    
    // Check quant guides
    final quantGuide = quantGuides.where(
      (g) => g.questionType.toLowerCase().replaceAll(' ', '_') == normalized,
    );
    if (quantGuide.isNotEmpty) return quantGuide.first;
    
    return null;
  }

  /// Get guides by subject
  static List<ThinkingGuide> getBySubject(String subject) {
    switch (subject.toLowerCase()) {
      case 'reasoning':
      case 'logical reasoning':
      case 'analytical reasoning':
        return reasoningGuides;
      case 'quant':
      case 'quantitative aptitude':
      case 'mathematics':
        return quantGuides;
      default:
        return [];
    }
  }

  /// Get all question types covered
  static List<String> get coveredQuestionTypes =>
      allGuides.map((g) => g.questionType).toList();

  /// Get guide statistics
  static Map<String, dynamic> get stats => {
        'totalGuides': allGuides.length,
        'reasoningGuides': reasoningGuides.length,
        'quantGuides': quantGuides.length,
        'questionTypes': coveredQuestionTypes,
      };
}
