/// Problem Solving Approach Model
/// Defines HOW to think about and solve each question type

import 'solution_steps.dart';

/// Represents a complete problem-solving methodology for a question type
class ProblemSolvingApproach {
  final String questionType;
  final String conceptRequired;
  final String howToRecognize;
  final List<String> thinkingProcess;
  final String whatToLookFor;
  final List<String> commonPatterns;
  final String timeManagement;
  final List<String> avoidMistakes;
  final List<String> proTips;
  final String difficultyLevel; // easy, medium, hard
  final int recommendedTime; // in seconds

  const ProblemSolvingApproach({
    required this.questionType,
    required this.conceptRequired,
    required this.howToRecognize,
    required this.thinkingProcess,
    required this.whatToLookFor,
    required this.commonPatterns,
    required this.timeManagement,
    required this.avoidMistakes,
    this.proTips = const [],
    this.difficultyLevel = 'medium',
    this.recommendedTime = 60,
  });

  Map<String, dynamic> toJson() => {
    'questionType': questionType,
    'conceptRequired': conceptRequired,
    'howToRecognize': howToRecognize,
    'thinkingProcess': thinkingProcess,
    'whatToLookFor': whatToLookFor,
    'commonPatterns': commonPatterns,
    'timeManagement': timeManagement,
    'avoidMistakes': avoidMistakes,
    'proTips': proTips,
    'difficultyLevel': difficultyLevel,
    'recommendedTime': recommendedTime,
  };

  factory ProblemSolvingApproach.fromJson(Map<String, dynamic> json) {
    return ProblemSolvingApproach(
      questionType: json['questionType'] as String,
      conceptRequired: json['conceptRequired'] as String,
      howToRecognize: json['howToRecognize'] as String,
      thinkingProcess: List<String>.from(json['thinkingProcess'] ?? []),
      whatToLookFor: json['whatToLookFor'] as String,
      commonPatterns: List<String>.from(json['commonPatterns'] ?? []),
      timeManagement: json['timeManagement'] as String,
      avoidMistakes: List<String>.from(json['avoidMistakes'] ?? []),
      proTips: List<String>.from(json['proTips'] ?? []),
      difficultyLevel: json['difficultyLevel'] as String? ?? 'medium',
      recommendedTime: json['recommendedTime'] as int? ?? 60,
    );
  }
}

/// Enhanced question with full problem-solving approach
class EnhancedQuestion {
  final String id;
  final String examType; // banking, ssc, upsc, jee, neet, cat, gate, clat
  final String subject;
  final String topic;
  final String subtopic;
  final String question;
  final List<String> options;
  final int correctOptionIndex;
  final String explanation;
  final SolutionSteps? solutionSteps;
  final ProblemSolvingApproach? approach;
  final String difficulty; // easy, medium, hard
  final int marks;
  final double negativeMarks;
  final int timeInSeconds;
  final List<String> tags;
  final String? yearAsked; // For PYQs
  final String? examShift; // Morning/Evening
  final bool isPreviousYear;
  final List<String> relatedQuestionIds;

  const EnhancedQuestion({
    required this.id,
    required this.examType,
    required this.subject,
    required this.topic,
    this.subtopic = '',
    required this.question,
    required this.options,
    required this.correctOptionIndex,
    required this.explanation,
    this.solutionSteps,
    this.approach,
    this.difficulty = 'medium',
    this.marks = 1,
    this.negativeMarks = 0.25,
    this.timeInSeconds = 60,
    this.tags = const [],
    this.yearAsked,
    this.examShift,
    this.isPreviousYear = false,
    this.relatedQuestionIds = const [],
  });

  String get correctAnswer => options[correctOptionIndex];

  Map<String, dynamic> toJson() => {
    'id': id,
    'examType': examType,
    'subject': subject,
    'topic': topic,
    'subtopic': subtopic,
    'question': question,
    'options': options,
    'correctOptionIndex': correctOptionIndex,
    'explanation': explanation,
    'solutionSteps': solutionSteps?.toJson(),
    'approach': approach?.toJson(),
    'difficulty': difficulty,
    'marks': marks,
    'negativeMarks': negativeMarks,
    'timeInSeconds': timeInSeconds,
    'tags': tags,
    'yearAsked': yearAsked,
    'examShift': examShift,
    'isPreviousYear': isPreviousYear,
    'relatedQuestionIds': relatedQuestionIds,
  };

  factory EnhancedQuestion.fromJson(Map<String, dynamic> json) {
    return EnhancedQuestion(
      id: json['id'] as String,
      examType: json['examType'] as String,
      subject: json['subject'] as String,
      topic: json['topic'] as String,
      subtopic: json['subtopic'] as String? ?? '',
      question: json['question'] as String,
      options: List<String>.from(json['options']),
      correctOptionIndex: json['correctOptionIndex'] as int,
      explanation: json['explanation'] as String,
      solutionSteps: json['solutionSteps'] != null
          ? SolutionSteps.fromJson(json['solutionSteps'])
          : null,
      approach: json['approach'] != null
          ? ProblemSolvingApproach.fromJson(json['approach'])
          : null,
      difficulty: json['difficulty'] as String? ?? 'medium',
      marks: json['marks'] as int? ?? 1,
      negativeMarks: (json['negativeMarks'] as num?)?.toDouble() ?? 0.25,
      timeInSeconds: json['timeInSeconds'] as int? ?? 60,
      tags: List<String>.from(json['tags'] ?? []),
      yearAsked: json['yearAsked'] as String?,
      examShift: json['examShift'] as String?,
      isPreviousYear: json['isPreviousYear'] as bool? ?? false,
      relatedQuestionIds: List<String>.from(json['relatedQuestionIds'] ?? []),
    );
  }
}

/// Thinking guide for a specific question type
class ThinkingGuide {
  final String questionType;
  final String subject;
  final String description;
  final List<RecognitionPattern> recognitionPatterns;
  final List<String> mentalFramework;
  final List<String> keyObservations;
  final List<StrategyOption> strategies;
  final List<String> executionSteps;
  final List<String> verificationMethods;
  final List<CommonMistake> commonMistakes;
  final List<String> shortcuts;
  final int averageTime;

  const ThinkingGuide({
    required this.questionType,
    required this.subject,
    required this.description,
    required this.recognitionPatterns,
    required this.mentalFramework,
    required this.keyObservations,
    required this.strategies,
    required this.executionSteps,
    required this.verificationMethods,
    this.commonMistakes = const [],
    this.shortcuts = const [],
    this.averageTime = 60,
  });

  Map<String, dynamic> toJson() => {
    'questionType': questionType,
    'subject': subject,
    'description': description,
    'recognitionPatterns': recognitionPatterns.map((e) => e.toJson()).toList(),
    'mentalFramework': mentalFramework,
    'keyObservations': keyObservations,
    'strategies': strategies.map((e) => e.toJson()).toList(),
    'executionSteps': executionSteps,
    'verificationMethods': verificationMethods,
    'commonMistakes': commonMistakes.map((e) => e.toJson()).toList(),
    'shortcuts': shortcuts,
    'averageTime': averageTime,
  };
}

class RecognitionPattern {
  final String pattern;
  final String indicator;
  final List<String> keywords;

  const RecognitionPattern({
    required this.pattern,
    required this.indicator,
    this.keywords = const [],
  });

  Map<String, dynamic> toJson() => {
    'pattern': pattern,
    'indicator': indicator,
    'keywords': keywords,
  };
}

class StrategyOption {
  final String name;
  final String description;
  final String whenToUse;
  final List<String> steps;

  const StrategyOption({
    required this.name,
    required this.description,
    required this.whenToUse,
    required this.steps,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'description': description,
    'whenToUse': whenToUse,
    'steps': steps,
  };
}

class CommonMistake {
  final String mistake;
  final String why;
  final String howToAvoid;

  const CommonMistake({
    required this.mistake,
    required this.why,
    required this.howToAvoid,
  });

  Map<String, dynamic> toJson() => {
    'mistake': mistake,
    'why': why,
    'howToAvoid': howToAvoid,
  };
}
