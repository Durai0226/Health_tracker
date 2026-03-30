import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../models/exam_model.dart';
import '../data/question_bank_data.dart';
import 'question_loader_service.dart';
import 'question_cloud_service.dart';
import '../models/subject_model.dart';
import '../models/topic_model.dart';
import '../models/study_session_model.dart';
import '../models/grade_model.dart';
import '../models/study_plan_model.dart';
import '../models/exam_template_model.dart';
import '../models/study_analytics_model.dart';
import '../models/flashcard_model.dart';
import '../models/practice_test_model.dart';
import '../../../core/services/notification_service.dart';
import '../../reminders/models/reminder_model.dart';

class ExamPrepService extends ChangeNotifier {
  static final ExamPrepService _instance = ExamPrepService._internal();
  factory ExamPrepService() => _instance;
  ExamPrepService._internal();

  static const String _examsBoxName = 'exams';
  static const String _subjectsBoxName = 'subjects';
  static const String _topicsBoxName = 'topics';
  static const String _studySessionsBoxName = 'study_sessions';
  static const String _gradesBoxName = 'grades';
  static const String _studyPlansBoxName = 'study_plans';
  static const String _templatesBoxName = 'exam_templates';
  static const String _analyticsBoxName = 'study_analytics';
  static const String _flashcardDecksBoxName = 'flashcard_decks';
  static const String _flashcardsBoxName = 'flashcards';
  static const String _practiceTestsBoxName = 'practice_tests';
  static const String _questionsBoxName = 'questions';

  SharedPreferences? _prefs;

  bool _isInitialized = false;
  final _uuid = const Uuid();

  // Cached data
  List<Exam> _exams = [];
  List<Subject> _subjects = [];
  List<Topic> _topics = [];
  List<StudySession> _studySessions = [];
  List<Grade> _grades = [];
  List<StudyPlan> _studyPlans = [];
  List<ExamTemplate> _templates = [];
  StudyAnalytics? _analytics;
  List<FlashcardDeck> _flashcardDecks = [];
  List<Flashcard> _flashcards = [];
  List<PracticeTest> _practiceTests = [];
  List<Question> _questions = [];
  
  // Question loader services
  QuestionLoaderService? _questionLoaderService;
  QuestionCloudService? _questionCloudService;
  List<QuestionBankItem> _questionBank = [];
  bool _questionsLoaded = false;

  // Active study session
  StudySession? _activeSession;
  Timer? _sessionTimer;
  int _remainingSeconds = 0;
  DateTime? _sessionStartTime;
  bool _isPaused = false;

  // Getters - return mutable copies to allow UI sorting/filtering
  List<Exam> get exams => List.from(_exams);
  List<Subject> get subjects => List.from(_subjects);
  List<Topic> get topics => List.from(_topics);
  List<StudySession> get studySessions => List.from(_studySessions);
  List<Grade> get grades => List.from(_grades);
  List<StudyPlan> get studyPlans => List.from(_studyPlans);
  List<ExamTemplate> get templates => List.from(_templates);
  StudyAnalytics? get analytics => _analytics;
  List<FlashcardDeck> get flashcardDecks => List.from(_flashcardDecks);
  List<Flashcard> get flashcards => List.from(_flashcards);
  List<PracticeTest> get practiceTests => List.from(_practiceTests);
  List<Question> get questions => List.from(_questions);
  List<QuestionBankItem> get questionBank => List.from(_questionBank);
  bool get questionsLoaded => _questionsLoaded;
  StudySession? get activeSession => _activeSession;
  int get remainingSeconds => _remainingSeconds;
  bool get hasActiveSession => _activeSession != null;
  bool get isPaused => _isPaused;
  bool get isInitialized => _isInitialized;

  String? get _currentUserId {
    final user = firebase_auth.FirebaseAuth.instance.currentUser;
    if (user != null && !user.isAnonymous) {
      return user.uid;
    }
    return null;
  }

  // Initialize service
  Future<void> init() async {
    if (_isInitialized) return;

    try {
      // Initialize SharedPreferences
      _prefs = await SharedPreferences.getInstance();

      // Load cached data
      await _loadLocalData();

      // Initialize analytics if not exists
      if (_analytics == null) {
        _analytics = StudyAnalytics(id: _uuid.v4());
        await _saveAnalytics();
      }

      // Load built-in templates
      await _loadBuiltInTemplates();
      
      // Initialize question loader service
      await _initializeQuestionServices();

      _isInitialized = true;
      debugPrint('✓ ExamPrepService initialized');
      notifyListeners();
    } catch (e) {
      debugPrint('Error initializing ExamPrepService: $e');
      rethrow;
    }
  }

  Future<void> _loadLocalData() async {
    if (_prefs == null) return;

    try {
      // Load exams
      final examsJson = _prefs!.getString('exam_prep_$_examsBoxName');
      if (examsJson != null) {
        final List<dynamic> examsList = jsonDecode(examsJson);
        _exams = examsList.map((e) => Exam.fromJson(e)).toList();
        _exams.sort((a, b) => a.examDate.compareTo(b.examDate));
      }

      // Load subjects
      final subjectsJson = _prefs!.getString('exam_prep_$_subjectsBoxName');
      if (subjectsJson != null) {
        final List<dynamic> subjectsList = jsonDecode(subjectsJson);
        _subjects = subjectsList.map((e) => Subject.fromJson(e)).toList();
      }

      // Load topics
      final topicsJson = _prefs!.getString('exam_prep_$_topicsBoxName');
      if (topicsJson != null) {
        final List<dynamic> topicsList = jsonDecode(topicsJson);
        _topics = topicsList.map((e) => Topic.fromJson(e)).toList();
      }

      // Load study sessions
      final sessionsJson = _prefs!.getString('exam_prep_$_studySessionsBoxName');
      if (sessionsJson != null) {
        final List<dynamic> sessionsList = jsonDecode(sessionsJson);
        _studySessions = sessionsList.map((e) => StudySession.fromJson(e)).toList();
      }

      // Load grades
      final gradesJson = _prefs!.getString('exam_prep_$_gradesBoxName');
      if (gradesJson != null) {
        final List<dynamic> gradesList = jsonDecode(gradesJson);
        _grades = gradesList.map((e) => Grade.fromJson(e)).toList();
      }

      // Load study plans
      final plansJson = _prefs!.getString('exam_prep_$_studyPlansBoxName');
      if (plansJson != null) {
        final List<dynamic> plansList = jsonDecode(plansJson);
        _studyPlans = plansList.map((e) => StudyPlan.fromJson(e)).toList();
      }

      // Load analytics
      final analyticsJson = _prefs!.getString('exam_prep_$_analyticsBoxName');
      if (analyticsJson != null) {
        _analytics = StudyAnalytics.fromJson(jsonDecode(analyticsJson));
      }

      // Load flashcard decks
      final decksJson = _prefs!.getString('exam_prep_$_flashcardDecksBoxName');
      if (decksJson != null) {
        final List<dynamic> decksList = jsonDecode(decksJson);
        _flashcardDecks = decksList.map((e) => FlashcardDeck.fromJson(e)).toList();
      }

      // Load flashcards
      final cardsJson = _prefs!.getString('exam_prep_$_flashcardsBoxName');
      if (cardsJson != null) {
        final List<dynamic> cardsList = jsonDecode(cardsJson);
        _flashcards = cardsList.map((e) => Flashcard.fromJson(e)).toList();
      }

      // Load practice tests
      final testsJson = _prefs!.getString('exam_prep_$_practiceTestsBoxName');
      if (testsJson != null) {
        final List<dynamic> testsList = jsonDecode(testsJson);
        _practiceTests = testsList.map((e) => PracticeTest.fromJson(e)).toList();
      }

      // Load questions
      final questionsJson = _prefs!.getString('exam_prep_$_questionsBoxName');
      if (questionsJson != null) {
        final List<dynamic> questionsList = jsonDecode(questionsJson);
        _questions = questionsList.map((e) => Question.fromJson(e)).toList();
      }

      debugPrint('✓ ExamPrepService: Loaded local data successfully');
    } catch (e) {
      debugPrint('Error loading local data: $e');
      // Initialize with empty lists on error
      _exams = [];
      _subjects = [];
      _topics = [];
      _studySessions = [];
      _grades = [];
      _studyPlans = [];
      _templates = [];
      _analytics = null;
      _flashcardDecks = [];
      _flashcards = [];
      _practiceTests = [];
      _questions = [];
    }
  }

  // Save methods for SharedPreferences persistence
  Future<void> _saveExams() async {
    if (_prefs == null) return;
    await _prefs!.setString('exam_prep_$_examsBoxName', jsonEncode(_exams.map((e) => e.toJson()).toList()));
  }

  Future<void> _saveSubjects() async {
    if (_prefs == null) return;
    await _prefs!.setString('exam_prep_$_subjectsBoxName', jsonEncode(_subjects.map((s) => s.toJson()).toList()));
  }

  Future<void> _saveTopics() async {
    if (_prefs == null) return;
    await _prefs!.setString('exam_prep_$_topicsBoxName', jsonEncode(_topics.map((t) => t.toJson()).toList()));
  }

  Future<void> _saveStudySessions() async {
    if (_prefs == null) return;
    await _prefs!.setString('exam_prep_$_studySessionsBoxName', jsonEncode(_studySessions.map((s) => s.toJson()).toList()));
  }

  Future<void> _saveGrades() async {
    if (_prefs == null) return;
    await _prefs!.setString('exam_prep_$_gradesBoxName', jsonEncode(_grades.map((g) => g.toJson()).toList()));
  }

  Future<void> _saveStudyPlans() async {
    if (_prefs == null) return;
    await _prefs!.setString('exam_prep_$_studyPlansBoxName', jsonEncode(_studyPlans.map((p) => p.toJson()).toList()));
  }

  Future<void> _saveFlashcardDecks() async {
    if (_prefs == null) return;
    await _prefs!.setString('exam_prep_$_flashcardDecksBoxName', jsonEncode(_flashcardDecks.map((d) => d.toJson()).toList()));
  }

  Future<void> _saveFlashcards() async {
    if (_prefs == null) return;
    await _prefs!.setString('exam_prep_$_flashcardsBoxName', jsonEncode(_flashcards.map((c) => c.toJson()).toList()));
  }

  Future<void> _savePracticeTests() async {
    if (_prefs == null) return;
    await _prefs!.setString('exam_prep_$_practiceTestsBoxName', jsonEncode(_practiceTests.map((t) => t.toJson()).toList()));
  }

  Future<void> _saveQuestions() async {
    if (_prefs == null) return;
    await _prefs!.setString('exam_prep_$_questionsBoxName', jsonEncode(_questions.map((q) => q.toJson()).toList()));
  }

  // ==================== EXAM CRUD ====================

  Future<Exam> createExam(Exam exam) async {
    final newExam = exam.copyWith(id: _uuid.v4());
    
    _exams.add(newExam);
    _exams.sort((a, b) => a.examDate.compareTo(b.examDate));
    await _saveExams();
    
    // Schedule reminders
    if (newExam.reminderEnabled) {
      await _scheduleExamReminders(newExam);
    }

    // Sync to cloud
    await _syncToCloud('exams', newExam.id, newExam.toJson());
    
    notifyListeners();
    return newExam;
  }

  Future<void> updateExam(Exam exam) async {
    final index = _exams.indexWhere((e) => e.id == exam.id);
    if (index != -1) {
      _exams[index] = exam;
      _exams.sort((a, b) => a.examDate.compareTo(b.examDate));
      await _saveExams();
      
      // Update reminders
      if (exam.reminderEnabled) {
        await _scheduleExamReminders(exam);
      }
      
      await _syncToCloud('exams', exam.id, exam.toJson());
      notifyListeners();
    }
  }

  Future<void> deleteExam(String examId) async {
    _exams.removeWhere((e) => e.id == examId);
    await _saveExams();
    await _deleteFromCloud('exams', examId);
    
    // Cancel reminders
    await NotificationService().cancelNotification(examId.hashCode);
    
    notifyListeners();
  }

  Exam? getExamById(String id) {
    try {
      return _exams.firstWhere((e) => e.id == id);
    } catch (_) {
      return null;
    }
  }

  List<Exam> getUpcomingExams({int days = 30}) {
    final now = DateTime.now();
    final cutoff = now.add(Duration(days: days));
    return _exams.where((e) => 
      e.examDate.isAfter(now) && 
      e.examDate.isBefore(cutoff) &&
      e.status == ExamStatus.upcoming
    ).toList();
  }

  List<Exam> getExamsBySubject(String subjectId) {
    return _exams.where((e) => e.subjectId == subjectId).toList();
  }

  List<Exam> getExamsForDate(DateTime date) {
    final targetDate = DateTime(date.year, date.month, date.day);
    return _exams.where((e) {
      final examDay = DateTime(e.examDate.year, e.examDate.month, e.examDate.day);
      return examDay == targetDate;
    }).toList();
  }

  // ==================== SUBJECT CRUD ====================

  Future<Subject> createSubject(Subject subject) async {
    final newSubject = subject.copyWith(id: _uuid.v4());
    
    _subjects.add(newSubject);
    _subjects.sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
    await _saveSubjects();
    await _syncToCloud('subjects', newSubject.id, newSubject.toJson());
    
    notifyListeners();
    return newSubject;
  }

  Future<void> updateSubject(Subject subject) async {
    final index = _subjects.indexWhere((s) => s.id == subject.id);
    if (index != -1) {
      _subjects[index] = subject;
      await _saveSubjects();
      await _syncToCloud('subjects', subject.id, subject.toJson());
      notifyListeners();
    }
  }

  Future<void> deleteSubject(String subjectId) async {
    _subjects.removeWhere((s) => s.id == subjectId);
    await _saveSubjects();
    await _deleteFromCloud('subjects', subjectId);
    
    // Delete related topics
    final relatedTopics = _topics.where((t) => t.subjectId == subjectId).toList();
    for (final topic in relatedTopics) {
      await deleteTopic(topic.id);
    }
    
    notifyListeners();
  }

  Subject? getSubjectById(String id) {
    try {
      return _subjects.firstWhere((s) => s.id == id);
    } catch (_) {
      return null;
    }
  }

  List<Subject> getActiveSubjects() {
    return _subjects.where((s) => !s.isArchived).toList();
  }

  // ==================== TOPIC CRUD ====================

  Future<Topic> createTopic(Topic topic) async {
    final newTopic = topic.copyWith(id: _uuid.v4());
    
    _topics.add(newTopic);
    await _saveTopics();
    await _syncToCloud('topics', newTopic.id, newTopic.toJson());
    
    // Update subject's topic list
    final subject = getSubjectById(newTopic.subjectId);
    if (subject != null) {
      final updatedTopicIds = [...subject.topicIds, newTopic.id];
      await updateSubject(subject.copyWith(topicIds: updatedTopicIds));
    }
    
    notifyListeners();
    return newTopic;
  }

  Future<void> updateTopic(Topic topic) async {
    final index = _topics.indexWhere((t) => t.id == topic.id);
    if (index != -1) {
      _topics[index] = topic;
      await _saveTopics();
      await _syncToCloud('topics', topic.id, topic.toJson());
      notifyListeners();
    }
  }

  Future<void> deleteTopic(String topicId) async {
    final topic = getTopicById(topicId);
    if (topic != null) {
      // Remove from subject's topic list
      final subject = getSubjectById(topic.subjectId);
      if (subject != null) {
        final updatedTopicIds = subject.topicIds.where((id) => id != topicId).toList();
        await updateSubject(subject.copyWith(topicIds: updatedTopicIds));
      }
      
      // Delete child topics recursively
      for (final childId in topic.childTopicIds) {
        await deleteTopic(childId);
      }
    }
    
    _topics.removeWhere((t) => t.id == topicId);
    await _saveTopics();
    await _deleteFromCloud('topics', topicId);
    
    notifyListeners();
  }

  Topic? getTopicById(String id) {
    try {
      return _topics.firstWhere((t) => t.id == id);
    } catch (_) {
      return null;
    }
  }

  List<Topic> getTopicsBySubject(String subjectId) {
    return _topics.where((t) => t.subjectId == subjectId).toList();
  }

  List<Topic> getRootTopics(String subjectId) {
    return _topics.where((t) => 
      t.subjectId == subjectId && t.parentTopicId == null
    ).toList();
  }

  List<Topic> getChildTopics(String parentTopicId) {
    return _topics.where((t) => t.parentTopicId == parentTopicId).toList();
  }

  List<Topic> getTopicsNeedingRevision() {
    return _topics.where((t) => t.isRevisionDue).toList();
  }

  // ==================== STUDY SESSION ====================

  Future<StudySession> startStudySession({
    String? subjectId,
    String? topicId,
    String? examId,
    StudySessionType sessionType = StudySessionType.regular,
    int plannedMinutes = 25,
  }) async {
    // End any active session
    if (_activeSession != null) {
      await endStudySession(wasCompleted: false);
    }

    _sessionStartTime = DateTime.now();
    _activeSession = StudySession(
      id: _uuid.v4(),
      subjectId: subjectId,
      topicId: topicId,
      examId: examId,
      sessionType: sessionType,
      startTime: _sessionStartTime!,
      plannedMinutes: plannedMinutes,
    );

    _remainingSeconds = plannedMinutes * 60;
    _startSessionTimer();

    notifyListeners();
    return _activeSession!;
  }

  void _startSessionTimer() {
    _sessionTimer?.cancel();
    _sessionTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 0) {
        _remainingSeconds--;
        notifyListeners();
      } else {
        _completeSession();
      }
    });
  }

  void pauseSession() {
    _sessionTimer?.cancel();
    _isPaused = true;
    notifyListeners();
  }

  void resumeSession() {
    if (_activeSession != null && _remainingSeconds > 0) {
      _isPaused = false;
      _startSessionTimer();
      notifyListeners();
    }
  }

  void togglePauseResume() {
    if (_isPaused) {
      resumeSession();
    } else {
      pauseSession();
    }
  }

  Future<StudySession?> endStudySession({
    bool wasCompleted = true,
    SessionQuality? quality,
    String? notes,
  }) async {
    _sessionTimer?.cancel();

    if (_activeSession == null || _sessionStartTime == null) {
      return null;
    }

    final endTime = DateTime.now();
    final actualMinutes = endTime.difference(_sessionStartTime!).inMinutes;

    final completedSession = _activeSession!.copyWith(
      endTime: endTime,
      actualMinutes: actualMinutes,
      isCompleted: wasCompleted,
      quality: quality,
      notes: notes,
    );

    _studySessions.insert(0, completedSession);
    await _saveStudySessions();
    await _syncToCloud('study_sessions', completedSession.id, completedSession.toJson());

    // Update topic study time
    if (completedSession.topicId != null) {
      await _updateTopicStudyTime(completedSession.topicId!, actualMinutes);
    }

    // Update subject study time
    if (completedSession.subjectId != null) {
      await _updateSubjectStudyTime(completedSession.subjectId!, actualMinutes);
    }

    // Update exam study time
    if (completedSession.examId != null) {
      await _updateExamStudyTime(completedSession.examId!, actualMinutes);
    }

    // Update analytics
    await _updateAnalyticsAfterSession(completedSession);

    _activeSession = null;
    _sessionStartTime = null;
    _remainingSeconds = 0;
    _isPaused = false;

    notifyListeners();
    return completedSession;
  }

  Future<void> _completeSession() async {
    await endStudySession(wasCompleted: true);
    
    // Show notification
    await NotificationService().showImmediateNotification(
      title: 'Study Session Complete! 📚',
      body: 'Great job! You\'ve completed your study session.',
    );
  }

  Future<void> _updateTopicStudyTime(String topicId, int minutes) async {
    final topic = getTopicById(topicId);
    if (topic != null) {
      final updatedTopic = topic.copyWith(
        actualStudyMinutes: topic.actualStudyMinutes + minutes,
        lastStudiedAt: DateTime.now(),
        timesRevised: topic.timesRevised + 1,
      );
      await updateTopic(updatedTopic);
    }
  }

  Future<void> _updateSubjectStudyTime(String subjectId, int minutes) async {
    final subject = getSubjectById(subjectId);
    if (subject != null) {
      final updatedSubject = subject.copyWith(
        totalStudyMinutes: subject.totalStudyMinutes + minutes,
      );
      await updateSubject(updatedSubject);
    }
  }

  Future<void> _updateExamStudyTime(String examId, int minutes) async {
    final exam = getExamById(examId);
    if (exam != null) {
      final updatedExam = exam.copyWith(
        actualStudyMinutes: exam.actualStudyMinutes + minutes,
      );
      await updateExam(updatedExam);
    }
  }

  // ==================== GRADES ====================

  Future<Grade> addGrade(Grade grade) async {
    final newGrade = grade.copyWith(id: _uuid.v4());
    
    _grades.add(newGrade);
    await _saveGrades();
    await _syncToCloud('grades', newGrade.id, newGrade.toJson());

    // Update exam with grade info
    final exam = getExamById(newGrade.examId);
    if (exam != null) {
      final updatedExam = exam.copyWith(
        obtainedMarks: newGrade.obtainedMarks,
        totalMarks: newGrade.totalMarks,
        grade: newGrade.calculatedLetterGrade,
        status: ExamStatus.completed,
      );
      await updateExam(updatedExam);
    }

    // Update analytics
    await _updateAnalyticsAfterGrade(newGrade);
    
    notifyListeners();
    return newGrade;
  }

  Future<void> updateGrade(Grade grade) async {
    final index = _grades.indexWhere((g) => g.id == grade.id);
    if (index != -1) {
      _grades[index] = grade;
      await _saveGrades();
      await _syncToCloud('grades', grade.id, grade.toJson());
      notifyListeners();
    }
  }

  Future<void> deleteGrade(String gradeId) async {
    _grades.removeWhere((g) => g.id == gradeId);
    await _saveGrades();
    await _deleteFromCloud('grades', gradeId);
    notifyListeners();
  }

  List<Grade> getGradesBySubject(String subjectId) {
    return _grades.where((g) => g.subjectId == subjectId).toList();
  }

  double calculateSubjectGPA(String subjectId) {
    final subjectGrades = getGradesBySubject(subjectId);
    if (subjectGrades.isEmpty) return 0.0;
    
    double totalWeightedGpa = 0.0;
    double totalWeight = 0.0;
    
    for (final grade in subjectGrades) {
      final weight = grade.weightPercentage ?? 1.0;
      totalWeightedGpa += grade.calculatedGpa4 * weight;
      totalWeight += weight;
    }
    
    return totalWeight > 0 ? totalWeightedGpa / totalWeight : 0.0;
  }

  // ==================== STUDY PLANS ====================

  Future<StudyPlan> createStudyPlan(StudyPlan plan) async {
    final newPlan = plan.copyWith(id: _uuid.v4());
    
    _studyPlans.add(newPlan);
    await _saveStudyPlans();
    await _syncToCloud('study_plans', newPlan.id, newPlan.toJson());
    
    notifyListeners();
    return newPlan;
  }

  Future<void> updateStudyPlan(StudyPlan plan) async {
    final index = _studyPlans.indexWhere((p) => p.id == plan.id);
    if (index != -1) {
      _studyPlans[index] = plan;
      await _saveStudyPlans();
      await _syncToCloud('study_plans', plan.id, plan.toJson());
      notifyListeners();
    }
  }

  Future<void> deleteStudyPlan(String planId) async {
    _studyPlans.removeWhere((p) => p.id == planId);
    await _saveStudyPlans();
    await _deleteFromCloud('study_plans', planId);
    notifyListeners();
  }

  StudyPlan? getActivePlan() {
    try {
      return _studyPlans.firstWhere((p) => p.status == StudyPlanStatus.active);
    } catch (_) {
      return null;
    }
  }

  Future<StudyPlan> generateStudyPlanFromExam(Exam exam, {int dailyMinutes = 120}) async {
    final topics = _topics.where((t) => exam.topicIds.contains(t.id)).toList();
    final now = DateTime.now();
    final daysUntilExam = exam.daysRemaining;
    
    List<StudyPlanItem> items = [];
    int orderIndex = 0;
    
    // Distribute topics across available days
    for (int day = 0; day < daysUntilExam && orderIndex < topics.length; day++) {
      final scheduledDate = now.add(Duration(days: day));
      
      // Skip non-study days based on weekly schedule (default: all days)
      int dailyMinutesRemaining = dailyMinutes;
      
      while (dailyMinutesRemaining > 0 && orderIndex < topics.length) {
        final topic = topics[orderIndex];
        final topicMinutes = min(topic.estimatedMinutes, dailyMinutesRemaining);
        
        items.add(StudyPlanItem(
          id: _uuid.v4(),
          topicId: topic.id,
          topicName: topic.name,
          scheduledDate: scheduledDate,
          plannedMinutes: topicMinutes,
          orderIndex: orderIndex,
        ));
        
        dailyMinutesRemaining -= topicMinutes;
        if (topicMinutes >= topic.estimatedMinutes) {
          orderIndex++;
        }
      }
    }

    final plan = StudyPlan(
      id: _uuid.v4(),
      name: 'Study Plan: ${exam.title}',
      examId: exam.id,
      subjectId: exam.subjectId,
      startDate: now,
      endDate: exam.examDate.subtract(const Duration(days: 1)),
      status: StudyPlanStatus.active,
      items: items,
      totalPlannedMinutes: items.fold(0, (sum, item) => sum + item.plannedMinutes),
      dailyTargetMinutes: dailyMinutes,
    );

    return await createStudyPlan(plan);
  }

  // ==================== TEMPLATES ====================

  // ==================== QUESTION LOADER INTEGRATION ====================

  Future<void> _initializeQuestionServices() async {
    try {
      // Initialize question loader service
      _questionLoaderService = QuestionLoaderService();
      await _questionLoaderService!.init();
      
      // Initialize cloud service if user is authenticated
      if (_currentUserId != null) {
        _questionCloudService = QuestionCloudService();
      }
      
      debugPrint('✓ Question services initialized');
    } catch (e) {
      debugPrint('Error initializing question services: $e');
    }
  }

  /// Load questions for a specific exam category
  Future<List<QuestionBankItem>> loadQuestionsForCategory(String category) async {
    if (_questionLoaderService == null) {
      await _initializeQuestionServices();
    }
    
    try {
      // First try to load from local assets
      final localQuestions = await _questionLoaderService!.loadCategoryQuestions(category);
      _questionBank = localQuestions;
      _questionsLoaded = true;
      
      // If user is authenticated, also fetch cloud questions
      if (_questionCloudService != null && _currentUserId != null) {
        try {
          final cloudQuestions = await _questionCloudService!.fetchQuestionsByCategory(
            category,
            limit: 100,
          );
          
          // Merge cloud questions with local (avoid duplicates by ID)
          final existingIds = _questionBank.map((q) => q.id).toSet();
          for (final cloudQ in cloudQuestions) {
            if (!existingIds.contains(cloudQ.id)) {
              _questionBank.add(cloudQ);
            }
          }
        } catch (e) {
          debugPrint('Cloud questions fetch failed (using local only): $e');
        }
      }
      
      notifyListeners();
      return _questionBank;
    } catch (e) {
      debugPrint('Error loading questions for category $category: $e');
      return [];
    }
  }

  /// Load questions filtered by subject
  Future<List<QuestionBankItem>> loadQuestionsForSubject(String category, String subjectId) async {
    if (_questionLoaderService == null) {
      await _initializeQuestionServices();
    }
    
    try {
      final questions = await _questionLoaderService!.getFilteredQuestions(
        categoryId: category,
        subjectId: subjectId,
      );
      return questions;
    } catch (e) {
      debugPrint('Error loading questions for subject $subjectId: $e');
      return [];
    }
  }

  /// Get random questions for a practice test
  Future<List<QuestionBankItem>> getRandomQuestions({
    required String category,
    String? subjectId,
    String? difficulty,
    int count = 10,
  }) async {
    if (_questionLoaderService == null) {
      await _initializeQuestionServices();
    }
    
    try {
      List<QuestionBankItem> pool;
      
      if (subjectId != null) {
        pool = await _questionLoaderService!.getFilteredQuestions(
          categoryId: category,
          subjectId: subjectId,
        );
      } else {
        pool = await _questionLoaderService!.loadCategoryQuestions(category);
      }
      
      // Filter by difficulty if specified
      if (difficulty != null) {
        pool = pool.where((q) => q.difficulty == difficulty).toList();
      }
      
      // Shuffle and take requested count
      pool.shuffle(Random());
      return pool.take(count).toList();
    } catch (e) {
      debugPrint('Error getting random questions: $e');
      return [];
    }
  }

  /// Search questions by keyword
  Future<List<QuestionBankItem>> searchQuestions(String category, String query) async {
    if (_questionLoaderService == null) {
      await _initializeQuestionServices();
    }
    
    try {
      // Load category questions and filter by query
      final questions = await _questionLoaderService!.loadCategoryQuestions(category);
      final lowerQuery = query.toLowerCase();
      return questions.where((q) =>
        q.question.toLowerCase().contains(lowerQuery) ||
        q.explanation.toLowerCase().contains(lowerQuery) ||
        q.tags.any((t) => t.toLowerCase().contains(lowerQuery))
      ).toList();
    } catch (e) {
      debugPrint('Error searching questions: $e');
      return [];
    }
  }

  /// Get available exam categories
  Future<List<String>> getAvailableCategories() async {
    if (_questionLoaderService == null) {
      await _initializeQuestionServices();
    }
    
    try {
      final categories = _questionLoaderService!.getCategories();
      return categories.map((c) => c['id'] as String).toList();
    } catch (e) {
      debugPrint('Error getting categories: $e');
      return [];
    }
  }

  /// Get question count for a category
  Future<int> getQuestionCount(String category) async {
    if (_questionLoaderService == null) {
      await _initializeQuestionServices();
    }
    
    try {
      // First ensure category is loaded
      await _questionLoaderService!.loadCategoryQuestions(category);
      return _questionLoaderService!.getCategoryQuestionCount(category);
    } catch (e) {
      debugPrint('Error getting question count: $e');
      return 0;
    }
  }

  /// Upload questions to cloud (for admin/content creators)
  Future<void> uploadQuestionsToCloud(List<QuestionBankItem> questions) async {
    if (_questionCloudService == null || _currentUserId == null) {
      debugPrint('Cannot upload: user not authenticated');
      return;
    }
    
    try {
      await _questionCloudService!.uploadQuestions(questions);
      debugPrint('✓ Uploaded ${questions.length} questions to cloud');
    } catch (e) {
      debugPrint('Error uploading questions: $e');
    }
  }

  /// Clear question cache
  Future<void> clearQuestionCache() async {
    if (_questionLoaderService != null) {
      await _questionLoaderService!.clearCache();
      _questionBank = [];
      _questionsLoaded = false;
      notifyListeners();
    }
  }

  Future<void> _loadBuiltInTemplates() async {
    final builtInTemplates = [
      ExamTemplate(
        id: 'template_midterm',
        name: 'Midterm Exam',
        description: 'Standard midterm examination template',
        category: TemplateCategory.college,
        examType: ExamType.midterm,
        recommendedStudyDays: 14,
        dailyStudyMinutes: 120,
        totalMarks: 100,
        passingMarks: 40,
        defaultReminderDays: [7, 3, 1],
        isBuiltIn: true,
      ),
      ExamTemplate(
        id: 'template_final',
        name: 'Final Exam',
        description: 'Comprehensive final examination template',
        category: TemplateCategory.college,
        examType: ExamType.final_exam,
        recommendedStudyDays: 21,
        dailyStudyMinutes: 180,
        totalMarks: 100,
        passingMarks: 40,
        defaultReminderDays: [14, 7, 3, 1],
        isBuiltIn: true,
      ),
      ExamTemplate(
        id: 'template_quiz',
        name: 'Quick Quiz',
        description: 'Short quiz or test template',
        category: TemplateCategory.school,
        examType: ExamType.quiz,
        recommendedStudyDays: 3,
        dailyStudyMinutes: 60,
        totalMarks: 20,
        passingMarks: 8,
        defaultReminderDays: [1],
        isBuiltIn: true,
      ),
      ExamTemplate(
        id: 'template_competitive',
        name: 'Competitive Exam',
        description: 'Competitive entrance examination template',
        category: TemplateCategory.competitive,
        examType: ExamType.test,
        recommendedStudyDays: 90,
        dailyStudyMinutes: 240,
        defaultReminderDays: [30, 14, 7, 3, 1],
        isBuiltIn: true,
      ),
    ];

    for (final template in builtInTemplates) {
      if (!_templates.any((t) => t.id == template.id)) {
        _templates.add(template);
      }
    }
  }

  Future<ExamTemplate> createTemplate(ExamTemplate template) async {
    final newTemplate = template.copyWith(id: _uuid.v4());
    
    _templates.add(newTemplate);
    await _syncToCloud('exam_templates', newTemplate.id, newTemplate.toJson());
    
    notifyListeners();
    return newTemplate;
  }

  Future<Exam> createExamFromTemplate(ExamTemplate template, {
    required String title,
    required String subjectId,
    required DateTime examDate,
  }) async {
    // Create topics from template
    List<String> topicIds = [];
    for (final topicTemplate in template.topics) {
      final topic = await _createTopicFromTemplate(topicTemplate, subjectId);
      topicIds.add(topic.id);
    }

    // Calculate reminder times
    List<DateTime> reminderTimes = [];
    for (final days in template.defaultReminderDays) {
      reminderTimes.add(examDate.subtract(Duration(days: days)));
    }

    final exam = Exam(
      id: _uuid.v4(),
      title: title,
      subjectId: subjectId,
      examType: template.examType,
      examDate: examDate,
      totalMarks: template.totalMarks,
      passingMarks: template.passingMarks,
      topicIds: topicIds,
      targetStudyMinutes: template.recommendedStudyDays * template.dailyStudyMinutes,
      templateId: template.id,
      reminderTimes: reminderTimes,
    );

    // Update template usage count
    // Template usage tracking is handled in-memory

    return await createExam(exam);
  }

  Future<Topic> _createTopicFromTemplate(TopicTemplate template, String subjectId) async {
    final topic = Topic(
      id: _uuid.v4(),
      name: template.name,
      subjectId: subjectId,
      difficulty: TopicDifficulty.values[template.difficulty.clamp(0, 3)],
      estimatedMinutes: template.estimatedMinutes,
      weightPercentage: template.weightPercentage,
      isImportantForExam: template.isImportant,
    );

    final createdTopic = await createTopic(topic);

    // Create subtopics
    for (final subtopicTemplate in template.subtopics) {
      final subtopic = await _createTopicFromTemplate(subtopicTemplate, subjectId);
      await updateTopic(subtopic.copyWith(parentTopicId: createdTopic.id));
    }

    return createdTopic;
  }

  // ==================== ANALYTICS ====================

  Future<void> _updateAnalyticsAfterSession(StudySession session) async {
    if (_analytics == null) return;

    final now = DateTime.now();
    final minutesBySubject = Map<String, int>.from(_analytics!.minutesBySubject);
    final minutesByHour = Map<int, int>.from(_analytics!.minutesByHour);
    final minutesByDayOfWeek = Map<int, int>.from(_analytics!.minutesByDayOfWeek);

    // Update subject minutes
    if (session.subjectId != null) {
      minutesBySubject[session.subjectId!] = 
          (minutesBySubject[session.subjectId!] ?? 0) + session.actualMinutes;
    }

    // Update hour distribution
    final hour = session.startTime.hour;
    minutesByHour[hour] = (minutesByHour[hour] ?? 0) + session.actualMinutes;

    // Update day of week distribution
    final dayOfWeek = session.startTime.weekday;
    minutesByDayOfWeek[dayOfWeek] = 
        (minutesByDayOfWeek[dayOfWeek] ?? 0) + session.actualMinutes;

    // Update streak
    int currentStreak = _analytics!.currentStreak;
    int longestStreak = _analytics!.longestStreak;
    
    if (_analytics!.lastStudyDate != null) {
      final lastDate = DateTime(
        _analytics!.lastStudyDate!.year,
        _analytics!.lastStudyDate!.month,
        _analytics!.lastStudyDate!.day,
      );
      final today = DateTime(now.year, now.month, now.day);
      final difference = today.difference(lastDate).inDays;
      
      if (difference == 1) {
        currentStreak++;
        longestStreak = max(longestStreak, currentStreak);
      } else if (difference > 1) {
        currentStreak = 1;
      }
    } else {
      currentStreak = 1;
    }

    _analytics = _analytics!.copyWith(
      totalLifetimeMinutes: _analytics!.totalLifetimeMinutes + session.actualMinutes,
      totalLifetimeSessions: _analytics!.totalLifetimeSessions + 1,
      currentStreak: currentStreak,
      longestStreak: longestStreak,
      lastStudyDate: now,
      minutesBySubject: minutesBySubject,
      minutesByHour: minutesByHour,
      minutesByDayOfWeek: minutesByDayOfWeek,
    );

    await _saveAnalytics();
  }

  Future<void> _updateAnalyticsAfterGrade(Grade grade) async {
    if (_analytics == null) return;

    final totalExams = _analytics!.totalExamsCompleted + 1;
    final totalPassed = _analytics!.totalExamsPassed + (grade.isPassed ? 1 : 0);
    
    // Recalculate average grade
    final allGrades = [..._grades, grade];
    final avgGrade = allGrades.isEmpty ? 0.0 :
        allGrades.map((g) => g.percentage).reduce((a, b) => a + b) / allGrades.length;

    _analytics = _analytics!.copyWith(
      totalExamsCompleted: totalExams,
      totalExamsPassed: totalPassed,
      averageGrade: avgGrade,
    );

    await _saveAnalytics();
  }

  Future<void> _saveAnalytics() async {
    if (_analytics != null && _prefs != null) {
      await _prefs!.setString('exam_prep_$_analyticsBoxName', jsonEncode(_analytics!.toJson()));
      await _syncToCloud('study_analytics', _analytics!.id, _analytics!.toJson());
    }
  }

  DailyStudyStats getTodayStats() {
    final today = DateTime.now();
    final todayStart = DateTime(today.year, today.month, today.day);
    
    final todaySessions = _studySessions.where((s) {
      final sessionDate = DateTime(s.startTime.year, s.startTime.month, s.startTime.day);
      return sessionDate == todayStart;
    }).toList();

    int totalMinutes = 0;
    int pomodoroCount = 0;
    double totalQuality = 0.0;
    int qualityCount = 0;
    Map<String, int> minutesBySubject = {};

    for (final session in todaySessions) {
      totalMinutes += session.actualMinutes;
      if (session.sessionType == StudySessionType.pomodoro) {
        pomodoroCount++;
      }
      if (session.quality != null) {
        totalQuality += session.quality!.index;
        qualityCount++;
      }
      if (session.subjectId != null) {
        minutesBySubject[session.subjectId!] = 
            (minutesBySubject[session.subjectId!] ?? 0) + session.actualMinutes;
      }
    }

    return DailyStudyStats(
      date: todayStart,
      totalMinutes: totalMinutes,
      sessionCount: todaySessions.length,
      pomodoroCount: pomodoroCount,
      minutesBySubject: minutesBySubject,
      averageQuality: qualityCount > 0 ? totalQuality / qualityCount : 0.0,
      goalMinutes: _analytics?.dailyGoalMinutes ?? 120,
    );
  }

  WeeklyStudyStats getThisWeekStats() {
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    final weekStartDate = DateTime(weekStart.year, weekStart.month, weekStart.day);

    List<DailyStudyStats> dailyStats = [];
    Set<String> daysStudied = {};
    int totalMinutes = 0;
    int totalSessions = 0;
    Map<String, int> minutesBySubject = {};

    for (int i = 0; i < 7; i++) {
      final date = weekStartDate.add(Duration(days: i));
      if (date.isAfter(now)) break;

      final daySessions = _studySessions.where((s) {
        final sessionDate = DateTime(s.startTime.year, s.startTime.month, s.startTime.day);
        return sessionDate == date;
      }).toList();

      if (daySessions.isNotEmpty) {
        daysStudied.add(date.toString());
        
        int dayMinutes = 0;
        for (final session in daySessions) {
          dayMinutes += session.actualMinutes;
          totalMinutes += session.actualMinutes;
          totalSessions++;
          
          if (session.subjectId != null) {
            minutesBySubject[session.subjectId!] = 
                (minutesBySubject[session.subjectId!] ?? 0) + session.actualMinutes;
          }
        }

        dailyStats.add(DailyStudyStats(
          date: date,
          totalMinutes: dayMinutes,
          sessionCount: daySessions.length,
        ));
      }
    }

    return WeeklyStudyStats(
      weekStart: weekStartDate,
      totalMinutes: totalMinutes,
      totalSessions: totalSessions,
      daysStudied: daysStudied.length,
      minutesBySubject: minutesBySubject,
      dailyStats: dailyStats,
      averageSessionLength: totalSessions > 0 ? totalMinutes / totalSessions : 0.0,
    );
  }

  // ==================== FLASHCARD CRUD ====================

  Future<FlashcardDeck> createFlashcardDeck(FlashcardDeck deck) async {
    final newDeck = deck.copyWith(id: _uuid.v4());
    _flashcardDecks.add(newDeck);
    await _syncToCloud(_flashcardDecksBoxName, newDeck.id, newDeck.toJson());
    notifyListeners();
    return newDeck;
  }

  Future<void> updateFlashcardDeck(FlashcardDeck deck) async {
    final index = _flashcardDecks.indexWhere((d) => d.id == deck.id);
    if (index != -1) {
      _flashcardDecks[index] = deck;
      await _syncToCloud(_flashcardDecksBoxName, deck.id, deck.toJson());
      notifyListeners();
    }
  }

  Future<void> deleteFlashcardDeck(String deckId) async {
    _flashcardDecks.removeWhere((d) => d.id == deckId);
    _flashcards.removeWhere((c) => c.deckId == deckId);
    await _deleteFromCloud(_flashcardDecksBoxName, deckId);
    notifyListeners();
  }

  FlashcardDeck? getFlashcardDeckById(String id) {
    try {
      return _flashcardDecks.firstWhere((d) => d.id == id);
    } catch (_) {
      return null;
    }
  }

  List<FlashcardDeck> getFlashcardDecksBySubject(String subjectId) {
    return _flashcardDecks.where((d) => d.subjectId == subjectId).toList();
  }

  Future<Flashcard> createFlashcard(Flashcard card) async {
    final newCard = card.copyWith(id: _uuid.v4());
    _flashcards.add(newCard);
    await _syncToCloud(_flashcardsBoxName, newCard.id, newCard.toJson());
    
    // Update deck card count
    final deck = getFlashcardDeckById(newCard.deckId);
    if (deck != null) {
      await updateFlashcardDeck(deck.copyWith(cardCount: deck.cardCount + 1));
    }
    
    notifyListeners();
    return newCard;
  }

  Future<void> updateFlashcard(Flashcard card) async {
    final index = _flashcards.indexWhere((c) => c.id == card.id);
    if (index != -1) {
      _flashcards[index] = card;
      await _syncToCloud(_flashcardsBoxName, card.id, card.toJson());
      notifyListeners();
    }
  }

  Future<void> deleteFlashcard(String cardId) async {
    final card = _flashcards.firstWhere((c) => c.id == cardId, orElse: () => throw Exception('Card not found'));
    _flashcards.removeWhere((c) => c.id == cardId);
    await _deleteFromCloud(_flashcardsBoxName, cardId);
    
    // Update deck card count
    final deck = getFlashcardDeckById(card.deckId);
    if (deck != null) {
      await updateFlashcardDeck(deck.copyWith(cardCount: max(0, deck.cardCount - 1)));
    }
    
    notifyListeners();
  }

  List<Flashcard> getFlashcardsByDeck(String deckId) {
    return _flashcards.where((c) => c.deckId == deckId).toList();
  }

  List<Flashcard> getDueFlashcards(String deckId) {
    return _flashcards.where((c) => c.deckId == deckId && c.isDue).toList();
  }

  Future<void> reviewFlashcard(String cardId, FlashcardDifficulty difficulty) async {
    final index = _flashcards.indexWhere((c) => c.id == cardId);
    if (index != -1) {
      final updatedCard = _flashcards[index].updateAfterReview(difficulty);
      _flashcards[index] = updatedCard;
      await _syncToCloud(_flashcardsBoxName, updatedCard.id, updatedCard.toJson());
      
      // Update deck stats
      final deck = getFlashcardDeckById(updatedCard.deckId);
      if (deck != null) {
        final masteredCount = _flashcards
            .where((c) => c.deckId == deck.id && c.status == FlashcardStatus.mastered)
            .length;
        final dueCount = getDueFlashcards(deck.id).length;
        await updateFlashcardDeck(deck.copyWith(
          masteredCount: masteredCount,
          dueCount: dueCount,
          lastStudiedAt: DateTime.now(),
          totalReviews: deck.totalReviews + 1,
        ));
      }
      
      notifyListeners();
    }
  }

  // ==================== PRACTICE TEST CRUD ====================

  Future<PracticeTest> createPracticeTest(PracticeTest test) async {
    final newTest = test.copyWith(id: _uuid.v4());
    _practiceTests.add(newTest);
    await _syncToCloud(_practiceTestsBoxName, newTest.id, newTest.toJson());
    notifyListeners();
    return newTest;
  }

  Future<void> updatePracticeTest(PracticeTest test) async {
    final index = _practiceTests.indexWhere((t) => t.id == test.id);
    if (index != -1) {
      _practiceTests[index] = test;
      await _syncToCloud(_practiceTestsBoxName, test.id, test.toJson());
      notifyListeners();
    }
  }

  Future<void> deletePracticeTest(String testId) async {
    _practiceTests.removeWhere((t) => t.id == testId);
    _questions.removeWhere((q) => q.testId == testId);
    await _deleteFromCloud(_practiceTestsBoxName, testId);
    notifyListeners();
  }

  PracticeTest? getPracticeTestById(String id) {
    try {
      return _practiceTests.firstWhere((t) => t.id == id);
    } catch (_) {
      return null;
    }
  }

  List<PracticeTest> getPracticeTestsBySubject(String subjectId) {
    return _practiceTests.where((t) => t.subjectId == subjectId).toList();
  }

  Future<Question> createQuestion(Question question) async {
    final newQuestion = question.copyWith(id: _uuid.v4());
    _questions.add(newQuestion);
    await _syncToCloud(_questionsBoxName, newQuestion.id, newQuestion.toJson());
    
    // Update test question count
    final test = getPracticeTestById(newQuestion.testId);
    if (test != null) {
      await updatePracticeTest(test.copyWith(
        questionCount: test.questionCount + 1,
        totalPoints: test.totalPoints + newQuestion.points,
      ));
    }
    
    notifyListeners();
    return newQuestion;
  }

  Future<void> updateQuestion(Question question) async {
    final index = _questions.indexWhere((q) => q.id == question.id);
    if (index != -1) {
      _questions[index] = question;
      await _syncToCloud(_questionsBoxName, question.id, question.toJson());
      notifyListeners();
    }
  }

  Future<void> deleteQuestion(String questionId) async {
    final question = _questions.firstWhere((q) => q.id == questionId, orElse: () => throw Exception('Question not found'));
    _questions.removeWhere((q) => q.id == questionId);
    await _deleteFromCloud(_questionsBoxName, questionId);
    
    // Update test question count
    final test = getPracticeTestById(question.testId);
    if (test != null) {
      await updatePracticeTest(test.copyWith(
        questionCount: max(0, test.questionCount - 1),
        totalPoints: max(0, test.totalPoints - question.points),
      ));
    }
    
    notifyListeners();
  }

  List<Question> getQuestionsByTest(String testId) {
    return _questions.where((q) => q.testId == testId).toList();
  }

  Future<void> recordTestAttempt(String testId, TestAttempt attempt) async {
    final test = getPracticeTestById(testId);
    if (test != null) {
      final newAttemptCount = test.attemptCount + 1;
      final newBestScore = attempt.score > test.bestScore ? attempt.score : test.bestScore;
      final newAverageScore = ((test.averageScore * test.attemptCount) + attempt.score) / newAttemptCount;
      
      await updatePracticeTest(test.copyWith(
        attemptCount: newAttemptCount,
        bestScore: newBestScore,
        averageScore: newAverageScore,
        lastAttemptAt: DateTime.now(),
      ));
    }
  }

  // ==================== REMINDERS ====================

  Future<void> _scheduleExamReminders(Exam exam) async {
    final notificationService = NotificationService();

    for (int i = 0; i < exam.reminderTimes.length; i++) {
      final reminderTime = exam.reminderTimes[i];
      if (reminderTime.isAfter(DateTime.now())) {
        final daysUntil = exam.examDate.difference(reminderTime).inDays;
        
        await notificationService.scheduleGenericReminder(
          id: '${exam.id}_reminder_$i'.hashCode,
          title: '📚 Exam Reminder: ${exam.title}',
          body: daysUntil == 0 
              ? 'Your exam is TODAY!'
              : daysUntil == 1 
                  ? 'Your exam is TOMORROW!'
                  : 'Your exam is in $daysUntil days',
          scheduledTime: reminderTime,
          repeatType: RepeatType.none,
          payload: 'exam:${exam.id}',
        );
      }
    }
  }

  // ==================== CLOUD SYNC ====================

  Future<void> _syncToCloud(String collection, String docId, Map<String, dynamic> data) async {
    final userId = _currentUserId;
    if (userId == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection(collection)
          .doc(docId)
          .set(data);
      debugPrint('Synced $collection/$docId to cloud');
    } catch (e) {
      debugPrint('Error syncing to cloud: $e');
    }
  }

  Future<void> _deleteFromCloud(String collection, String docId) async {
    final userId = _currentUserId;
    if (userId == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection(collection)
          .doc(docId)
          .delete();
      debugPrint('Deleted $collection/$docId from cloud');
    } catch (e) {
      debugPrint('Error deleting from cloud: $e');
    }
  }

  Future<void> syncFromCloud() async {
    final userId = _currentUserId;
    if (userId == null) return;

    try {
      // Sync exams
      final examsSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('exams')
          .get();

      for (final doc in examsSnapshot.docs) {
        final exam = Exam.fromJson(doc.data());
        if (!_exams.any((e) => e.id == exam.id) || 
            _exams.firstWhere((e) => e.id == exam.id).updatedAt.isBefore(exam.updatedAt)) {
          _exams.removeWhere((e) => e.id == exam.id);
          _exams.add(exam);
        }
      }

      // Similar sync for other collections...
      await _loadLocalData();
      notifyListeners();
      debugPrint('✓ Synced exam prep data from cloud');
    } catch (e) {
      debugPrint('Error syncing from cloud: $e');
    }
  }

  // ==================== CLEANUP ====================

  @override
  void dispose() {
    _sessionTimer?.cancel();
    super.dispose();
  }
}
