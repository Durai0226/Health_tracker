import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import '../data/question_bank_data.dart';

/// Service for fetching questions from Firestore cloud storage
/// Used for extended question content beyond local core questions
class QuestionCloudService extends ChangeNotifier {
  static final QuestionCloudService _instance = QuestionCloudService._internal();
  factory QuestionCloudService() => _instance;
  QuestionCloudService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Collection names
  static const String _questionsCollection = 'exam_questions';
  static const String _categoriesCollection = 'exam_question_categories';
  
  // Batch size for pagination
  static const int _batchSize = 100;
  
  // Loading state
  bool _isLoading = false;
  String? _error;
  
  bool get isLoading => _isLoading;
  String? get error => _error;

  String? get _currentUserId {
    final user = firebase_auth.FirebaseAuth.instance.currentUser;
    if (user != null && !user.isAnonymous) {
      return user.uid;
    }
    return null;
  }

  /// Fetch questions from Firestore by category
  Future<List<QuestionBankItem>> fetchQuestionsByCategory(
    String categoryId, {
    int? limit,
    DocumentSnapshot? startAfter,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      Query query = _firestore
          .collection(_questionsCollection)
          .where('examCategory', isEqualTo: categoryId)
          .orderBy('id');

      if (limit != null) {
        query = query.limit(limit);
      } else {
        query = query.limit(_batchSize);
      }

      if (startAfter != null) {
        query = query.startAfterDocument(startAfter);
      }

      final snapshot = await query.get();
      final questions = snapshot.docs.map((doc) => _parseFirestoreDoc(doc)).toList();

      _isLoading = false;
      notifyListeners();
      return questions;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      debugPrint('Error fetching questions: $e');
      return [];
    }
  }

  /// Fetch questions by subject
  Future<List<QuestionBankItem>> fetchQuestionsBySubject(
    String subjectId, {
    int? limit,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      Query query = _firestore
          .collection(_questionsCollection)
          .where('subjectId', isEqualTo: subjectId)
          .orderBy('id');

      if (limit != null) {
        query = query.limit(limit);
      } else {
        query = query.limit(_batchSize);
      }

      final snapshot = await query.get();
      final questions = snapshot.docs.map((doc) => _parseFirestoreDoc(doc)).toList();

      _isLoading = false;
      notifyListeners();
      return questions;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      debugPrint('Error fetching questions by subject: $e');
      return [];
    }
  }

  /// Fetch questions with multiple filters
  Future<List<QuestionBankItem>> fetchFilteredQuestions({
    String? categoryId,
    String? subjectId,
    String? topicId,
    String? difficulty,
    int? year,
    int? limit,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      Query query = _firestore.collection(_questionsCollection);

      if (categoryId != null) {
        query = query.where('examCategory', isEqualTo: categoryId);
      }
      if (subjectId != null) {
        query = query.where('subjectId', isEqualTo: subjectId);
      }
      if (topicId != null) {
        query = query.where('topicId', isEqualTo: topicId);
      }
      if (difficulty != null) {
        query = query.where('difficulty', isEqualTo: difficulty);
      }
      if (year != null) {
        query = query.where('year', isEqualTo: year);
      }

      query = query.limit(limit ?? _batchSize);

      final snapshot = await query.get();
      final questions = snapshot.docs.map((doc) => _parseFirestoreDoc(doc)).toList();

      _isLoading = false;
      notifyListeners();
      return questions;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      debugPrint('Error fetching filtered questions: $e');
      return [];
    }
  }

  /// Fetch a single question by ID
  Future<QuestionBankItem?> fetchQuestionById(String questionId) async {
    try {
      final doc = await _firestore
          .collection(_questionsCollection)
          .doc(questionId)
          .get();

      if (!doc.exists) return null;
      return _parseFirestoreDoc(doc);
    } catch (e) {
      debugPrint('Error fetching question $questionId: $e');
      return null;
    }
  }

  /// Get total question count for a category
  Future<int> getCategoryQuestionCount(String categoryId) async {
    try {
      final snapshot = await _firestore
          .collection(_questionsCollection)
          .where('examCategory', isEqualTo: categoryId)
          .count()
          .get();
      return snapshot.count ?? 0;
    } catch (e) {
      debugPrint('Error getting count for $categoryId: $e');
      return 0;
    }
  }

  /// Upload a batch of questions (admin function)
  Future<bool> uploadQuestions(List<QuestionBankItem> questions) async {
    if (_currentUserId == null) {
      _error = 'User not authenticated';
      return false;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final batch = _firestore.batch();
      
      for (final question in questions) {
        final docRef = _firestore.collection(_questionsCollection).doc(question.id);
        batch.set(docRef, _questionToFirestore(question));
      }

      await batch.commit();
      
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      debugPrint('Error uploading questions: $e');
      return false;
    }
  }

  /// Upload questions in batches (for large datasets)
  Future<bool> uploadQuestionsBatched(
    List<QuestionBankItem> questions, {
    Function(int uploaded, int total)? onProgress,
  }) async {
    if (_currentUserId == null) {
      _error = 'User not authenticated';
      return false;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      const batchLimit = 500; // Firestore batch limit
      int uploaded = 0;

      for (int i = 0; i < questions.length; i += batchLimit) {
        final end = (i + batchLimit < questions.length) ? i + batchLimit : questions.length;
        final batchQuestions = questions.sublist(i, end);
        
        final batch = _firestore.batch();
        for (final question in batchQuestions) {
          final docRef = _firestore.collection(_questionsCollection).doc(question.id);
          batch.set(docRef, _questionToFirestore(question));
        }
        
        await batch.commit();
        uploaded += batchQuestions.length;
        onProgress?.call(uploaded, questions.length);
      }

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      debugPrint('Error uploading questions batched: $e');
      return false;
    }
  }

  /// Delete a question (admin function)
  Future<bool> deleteQuestion(String questionId) async {
    if (_currentUserId == null) {
      _error = 'User not authenticated';
      return false;
    }

    try {
      await _firestore.collection(_questionsCollection).doc(questionId).delete();
      return true;
    } catch (e) {
      _error = e.toString();
      debugPrint('Error deleting question: $e');
      return false;
    }
  }

  /// Update a question (admin function)
  Future<bool> updateQuestion(QuestionBankItem question) async {
    if (_currentUserId == null) {
      _error = 'User not authenticated';
      return false;
    }

    try {
      await _firestore
          .collection(_questionsCollection)
          .doc(question.id)
          .update(_questionToFirestore(question));
      return true;
    } catch (e) {
      _error = e.toString();
      debugPrint('Error updating question: $e');
      return false;
    }
  }

  /// Parse Firestore document to QuestionBankItem
  /// Supports new step-by-step solution fields
  QuestionBankItem _parseFirestoreDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    // Ensure id is set from doc.id if not in data
    if (data['id'] == null) {
      data['id'] = doc.id;
    }
    return QuestionBankItem.fromJson(data);
  }

  /// Convert QuestionBankItem to Firestore map
  /// Includes step-by-step solution fields and server timestamp
  Map<String, dynamic> _questionToFirestore(QuestionBankItem q) {
    final json = q.toJson();
    json['updatedAt'] = FieldValue.serverTimestamp();
    return json;
  }

  /// Listen to real-time updates for a category
  Stream<List<QuestionBankItem>> streamCategoryQuestions(String categoryId) {
    return _firestore
        .collection(_questionsCollection)
        .where('examCategory', isEqualTo: categoryId)
        .orderBy('id')
        .limit(_batchSize)
        .snapshots()
        .map((snapshot) => 
            snapshot.docs.map((doc) => _parseFirestoreDoc(doc)).toList());
  }

  /// Get category metadata from cloud
  Future<Map<String, dynamic>?> getCategoryMetadata(String categoryId) async {
    try {
      final doc = await _firestore
          .collection(_categoriesCollection)
          .doc(categoryId)
          .get();
      
      if (!doc.exists) return null;
      return doc.data();
    } catch (e) {
      debugPrint('Error fetching category metadata: $e');
      return null;
    }
  }

  /// Check if cloud has newer questions than local
  Future<bool> hasNewerQuestions(String categoryId, DateTime localLastUpdate) async {
    try {
      final metadata = await getCategoryMetadata(categoryId);
      if (metadata == null) return false;

      final cloudTimestamp = metadata['lastUpdated'] as Timestamp?;
      if (cloudTimestamp == null) return false;

      return cloudTimestamp.toDate().isAfter(localLastUpdate);
    } catch (e) {
      debugPrint('Error checking for newer questions: $e');
      return false;
    }
  }
}
