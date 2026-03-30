import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:crypto/crypto.dart';
import '../data/question_bank_data.dart';
import '../models/solution_steps.dart';

/// Service for batch uploading questions to Firestore
/// Handles large-scale question uploads with progress tracking and validation
class QuestionUploadService extends ChangeNotifier {
  static final QuestionUploadService _instance = QuestionUploadService._internal();
  factory QuestionUploadService() => _instance;
  QuestionUploadService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  static const String _questionsCollection = 'exam_questions';
  static const String _metadataCollection = 'exam_question_metadata';
  static const int _batchLimit = 500; // Firestore batch write limit
  
  // Upload state
  bool _isUploading = false;
  int _totalQuestions = 0;
  int _uploadedQuestions = 0;
  String? _currentCategory;
  String? _error;
  List<String> _duplicateIds = [];
  
  bool get isUploading => _isUploading;
  int get totalQuestions => _totalQuestions;
  int get uploadedQuestions => _uploadedQuestions;
  double get progress => _totalQuestions > 0 ? _uploadedQuestions / _totalQuestions : 0;
  String? get currentCategory => _currentCategory;
  String? get error => _error;
  List<String> get duplicateIds => List.from(_duplicateIds);

  String? get _currentUserId {
    final user = firebase_auth.FirebaseAuth.instance.currentUser;
    if (user != null && !user.isAnonymous) {
      return user.uid;
    }
    return null;
  }

  /// Generate a unique hash for question content (for duplicate detection)
  String _generateQuestionHash(QuestionBankItem question) {
    final content = '${question.question}|${question.options.join('|')}|${question.correctIndex}';
    return md5.convert(utf8.encode(content)).toString();
  }

  /// Validate question structure before upload
  ValidationResult _validateQuestion(QuestionBankItem question) {
    final errors = <String>[];
    
    if (question.id.isEmpty) {
      errors.add('Question ID is required');
    }
    if (question.question.trim().isEmpty) {
      errors.add('Question text is required');
    }
    if (question.options.length < 2) {
      errors.add('At least 2 options are required');
    }
    if (question.correctIndex < 0 || question.correctIndex >= question.options.length) {
      errors.add('Correct index is out of range');
    }
    if (question.subjectId.isEmpty) {
      errors.add('Subject ID is required');
    }
    if (question.examCategory == null || question.examCategory!.isEmpty) {
      errors.add('Exam category is required');
    }
    
    // Validate solution steps if present
    if (question.solutionSteps != null) {
      if (question.solutionSteps!.approach.isEmpty) {
        errors.add('Solution approach is required');
      }
      if (question.solutionSteps!.steps.isEmpty) {
        errors.add('At least one solution step is required');
      }
    }
    
    return ValidationResult(
      isValid: errors.isEmpty,
      errors: errors,
    );
  }

  /// Upload a batch of questions with progress tracking
  Future<UploadResult> uploadQuestions(
    List<QuestionBankItem> questions, {
    bool skipDuplicates = true,
    Function(int uploaded, int total)? onProgress,
  }) async {
    if (_currentUserId == null) {
      return UploadResult(
        success: false,
        error: 'User not authenticated',
        uploadedCount: 0,
        skippedCount: 0,
        failedCount: questions.length,
      );
    }

    _isUploading = true;
    _totalQuestions = questions.length;
    _uploadedQuestions = 0;
    _error = null;
    _duplicateIds = [];
    notifyListeners();

    int uploadedCount = 0;
    int skippedCount = 0;
    int failedCount = 0;
    final failedQuestions = <String>[];
    final validationErrors = <String, List<String>>{};

    try {
      // Check for duplicates if needed
      Set<String> existingHashes = {};
      if (skipDuplicates) {
        existingHashes = await _getExistingQuestionHashes();
      }

      // Process in batches
      for (int i = 0; i < questions.length; i += _batchLimit) {
        final end = (i + _batchLimit < questions.length) ? i + _batchLimit : questions.length;
        final batchQuestions = questions.sublist(i, end);
        
        final batch = _firestore.batch();
        int batchCount = 0;
        
        for (final question in batchQuestions) {
          // Validate
          final validation = _validateQuestion(question);
          if (!validation.isValid) {
            validationErrors[question.id] = validation.errors;
            failedCount++;
            failedQuestions.add(question.id);
            continue;
          }
          
          // Check for duplicates
          if (skipDuplicates) {
            final hash = _generateQuestionHash(question);
            if (existingHashes.contains(hash)) {
              _duplicateIds.add(question.id);
              skippedCount++;
              continue;
            }
            existingHashes.add(hash);
          }
          
          // Add to batch
          final docRef = _firestore.collection(_questionsCollection).doc(question.id);
          final data = question.toJson();
          data['contentHash'] = _generateQuestionHash(question);
          data['uploadedAt'] = FieldValue.serverTimestamp();
          data['uploadedBy'] = _currentUserId;
          batch.set(docRef, data);
          batchCount++;
        }
        
        // Commit batch
        if (batchCount > 0) {
          await batch.commit();
          uploadedCount += batchCount;
        }
        
        _uploadedQuestions = i + batchQuestions.length;
        _currentCategory = batchQuestions.isNotEmpty ? batchQuestions.first.examCategory : null;
        notifyListeners();
        onProgress?.call(_uploadedQuestions, _totalQuestions);
      }

      // Update category metadata
      await _updateCategoryMetadata(questions);

      _isUploading = false;
      notifyListeners();

      return UploadResult(
        success: true,
        uploadedCount: uploadedCount,
        skippedCount: skippedCount,
        failedCount: failedCount,
        duplicateIds: _duplicateIds,
        failedQuestions: failedQuestions,
        validationErrors: validationErrors,
      );
    } catch (e) {
      _error = e.toString();
      _isUploading = false;
      notifyListeners();
      
      return UploadResult(
        success: false,
        error: e.toString(),
        uploadedCount: uploadedCount,
        skippedCount: skippedCount,
        failedCount: questions.length - uploadedCount - skippedCount,
      );
    }
  }

  /// Get existing question content hashes for duplicate detection
  Future<Set<String>> _getExistingQuestionHashes() async {
    final hashes = <String>{};
    
    try {
      DocumentSnapshot? lastDoc;
      do {
        Query query = _firestore
            .collection(_questionsCollection)
            .orderBy('id')
            .limit(1000);
        
        if (lastDoc != null) {
          query = query.startAfterDocument(lastDoc);
        }
        
        final snapshot = await query.get();
        
        for (final doc in snapshot.docs) {
          final data = doc.data() as Map<String, dynamic>?;
          final hash = data?['contentHash'] as String?;
          if (hash != null) {
            hashes.add(hash);
          }
        }
        
        lastDoc = snapshot.docs.isNotEmpty ? snapshot.docs.last : null;
      } while (lastDoc != null);
    } catch (e) {
      debugPrint('Error fetching existing hashes: $e');
    }
    
    return hashes;
  }

  /// Update category metadata after upload
  Future<void> _updateCategoryMetadata(List<QuestionBankItem> questions) async {
    // Group by category
    final categoryCount = <String, int>{};
    for (final q in questions) {
      final cat = q.examCategory ?? 'unknown';
      categoryCount[cat] = (categoryCount[cat] ?? 0) + 1;
    }
    
    // Update each category's metadata
    for (final entry in categoryCount.entries) {
      try {
        final docRef = _firestore.collection(_metadataCollection).doc(entry.key);
        await docRef.set({
          'lastUpdated': FieldValue.serverTimestamp(),
          'questionCount': FieldValue.increment(entry.value),
        }, SetOptions(merge: true));
      } catch (e) {
        debugPrint('Error updating metadata for ${entry.key}: $e');
      }
    }
  }

  /// Generate questions with step-by-step solutions from templates
  List<QuestionBankItem> generateQuestionsFromTemplate({
    required String category,
    required String subjectId,
    required String topicId,
    required List<QuestionTemplate> templates,
    int count = 100,
  }) {
    final questions = <QuestionBankItem>[];
    final random = DateTime.now().millisecondsSinceEpoch;
    
    for (int i = 0; i < count; i++) {
      final template = templates[i % templates.length];
      final values = template.generateValues(random + i);
      
      questions.add(QuestionBankItem(
        id: '${category}_${subjectId}_${topicId}_${i.toString().padLeft(5, '0')}',
        question: template.formatQuestion(values),
        options: template.formatOptions(values),
        correctIndex: template.correctIndex,
        explanation: template.formatExplanation(values),
        subjectId: subjectId,
        topicId: topicId,
        difficulty: template.difficulty,
        examCategory: category,
        tags: template.tags,
        solutionSteps: SolutionSteps(
          approach: template.approach,
          steps: template.formatSteps(values),
          commonMistake: template.commonMistake,
          proTip: template.proTip,
        ),
        concept: template.concept,
        formula: template.formula,
        shortcut: template.shortcut,
        timeTaken: template.estimatedTime,
      ));
    }
    
    return questions;
  }

  /// Delete all questions in a category (admin function)
  Future<bool> deleteCategoryQuestions(String categoryId) async {
    if (_currentUserId == null) return false;
    
    try {
      final snapshot = await _firestore
          .collection(_questionsCollection)
          .where('examCategory', isEqualTo: categoryId)
          .get();
      
      final batch = _firestore.batch();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      
      await batch.commit();
      return true;
    } catch (e) {
      debugPrint('Error deleting category questions: $e');
      return false;
    }
  }

  /// Get upload statistics
  Future<Map<String, int>> getUploadStatistics() async {
    final stats = <String, int>{};
    
    try {
      final categories = ['banking', 'ssc', 'upsc', 'jee', 'neet', 'cat', 'gate', 'clat'];
      
      for (final cat in categories) {
        final snapshot = await _firestore
            .collection(_questionsCollection)
            .where('examCategory', isEqualTo: cat)
            .count()
            .get();
        stats[cat] = snapshot.count ?? 0;
      }
    } catch (e) {
      debugPrint('Error getting upload statistics: $e');
    }
    
    return stats;
  }
}

/// Validation result for a question
class ValidationResult {
  final bool isValid;
  final List<String> errors;
  
  const ValidationResult({
    required this.isValid,
    this.errors = const [],
  });
}

/// Result of an upload operation
class UploadResult {
  final bool success;
  final String? error;
  final int uploadedCount;
  final int skippedCount;
  final int failedCount;
  final List<String> duplicateIds;
  final List<String> failedQuestions;
  final Map<String, List<String>> validationErrors;
  
  const UploadResult({
    required this.success,
    this.error,
    required this.uploadedCount,
    required this.skippedCount,
    required this.failedCount,
    this.duplicateIds = const [],
    this.failedQuestions = const [],
    this.validationErrors = const {},
  });
  
  @override
  String toString() {
    return 'UploadResult(success: $success, uploaded: $uploadedCount, skipped: $skippedCount, failed: $failedCount)';
  }
}

/// Template for generating questions with parameterized values
class QuestionTemplate {
  final String questionPattern;
  final List<String> optionPatterns;
  final int correctIndex;
  final String explanationPattern;
  final String approach;
  final List<String> stepPatterns;
  final String? commonMistake;
  final String? proTip;
  final String? concept;
  final String? formula;
  final String? shortcut;
  final String difficulty;
  final List<String> tags;
  final int estimatedTime;
  final Map<String, dynamic> Function(int seed) valueGenerator;
  
  const QuestionTemplate({
    required this.questionPattern,
    required this.optionPatterns,
    required this.correctIndex,
    required this.explanationPattern,
    required this.approach,
    required this.stepPatterns,
    this.commonMistake,
    this.proTip,
    this.concept,
    this.formula,
    this.shortcut,
    this.difficulty = 'medium',
    this.tags = const [],
    this.estimatedTime = 60,
    required this.valueGenerator,
  });
  
  Map<String, dynamic> generateValues(int seed) => valueGenerator(seed);
  
  String formatQuestion(Map<String, dynamic> values) {
    return _replaceValues(questionPattern, values);
  }
  
  List<String> formatOptions(Map<String, dynamic> values) {
    return optionPatterns.map((p) => _replaceValues(p, values)).toList();
  }
  
  String formatExplanation(Map<String, dynamic> values) {
    return _replaceValues(explanationPattern, values);
  }
  
  List<String> formatSteps(Map<String, dynamic> values) {
    return stepPatterns.map((p) => _replaceValues(p, values)).toList();
  }
  
  String _replaceValues(String pattern, Map<String, dynamic> values) {
    String result = pattern;
    for (final entry in values.entries) {
      result = result.replaceAll('{${entry.key}}', entry.value.toString());
    }
    return result;
  }
}
