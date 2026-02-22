import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';

import '../models/exam_model.dart';
import '../models/subject_model.dart';
import '../models/topic_model.dart';
import '../models/study_session_model.dart';
import '../models/grade_model.dart';
import '../models/study_plan_model.dart';
import '../models/exam_template_model.dart';
import '../models/study_analytics_model.dart';
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

  Box<Exam>? _examsBox;
  Box<Subject>? _subjectsBox;
  Box<Topic>? _topicsBox;
  Box<StudySession>? _studySessionsBox;
  Box<Grade>? _gradesBox;
  Box<StudyPlan>? _studyPlansBox;
  Box<ExamTemplate>? _templatesBox;
  Box<StudyAnalytics>? _analyticsBox;

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

  // Active study session
  StudySession? _activeSession;
  Timer? _sessionTimer;
  int _remainingSeconds = 0;
  DateTime? _sessionStartTime;
  bool _isPaused = false;

  // Getters
  List<Exam> get exams => List.unmodifiable(_exams);
  List<Subject> get subjects => List.unmodifiable(_subjects);
  List<Topic> get topics => List.unmodifiable(_topics);
  List<StudySession> get studySessions => List.unmodifiable(_studySessions);
  List<Grade> get grades => List.unmodifiable(_grades);
  List<StudyPlan> get studyPlans => List.unmodifiable(_studyPlans);
  List<ExamTemplate> get templates => List.unmodifiable(_templates);
  StudyAnalytics? get analytics => _analytics;
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
      // Open Hive boxes
      _examsBox = await Hive.openBox<Exam>(_examsBoxName);
      _subjectsBox = await Hive.openBox<Subject>(_subjectsBoxName);
      _topicsBox = await Hive.openBox<Topic>(_topicsBoxName);
      _studySessionsBox = await Hive.openBox<StudySession>(_studySessionsBoxName);
      _gradesBox = await Hive.openBox<Grade>(_gradesBoxName);
      _studyPlansBox = await Hive.openBox<StudyPlan>(_studyPlansBoxName);
      _templatesBox = await Hive.openBox<ExamTemplate>(_templatesBoxName);
      _analyticsBox = await Hive.openBox<StudyAnalytics>(_analyticsBoxName);

      // Load cached data
      await _loadLocalData();

      // Initialize analytics if not exists
      if (_analytics == null) {
        _analytics = StudyAnalytics(id: _uuid.v4());
        await _saveAnalytics();
      }

      // Load built-in templates
      await _loadBuiltInTemplates();

      _isInitialized = true;
      debugPrint('✓ ExamPrepService initialized');
      notifyListeners();
    } catch (e) {
      debugPrint('Error initializing ExamPrepService: $e');
      rethrow;
    }
  }

  Future<void> _loadLocalData() async {
    _exams = _examsBox?.values.toList() ?? [];
    _subjects = _subjectsBox?.values.toList() ?? [];
    _topics = _topicsBox?.values.toList() ?? [];
    _studySessions = _studySessionsBox?.values.toList() ?? [];
    _grades = _gradesBox?.values.toList() ?? [];
    _studyPlans = _studyPlansBox?.values.toList() ?? [];
    _templates = _templatesBox?.values.toList() ?? [];
    
    final analyticsList = _analyticsBox?.values.toList() ?? [];
    _analytics = analyticsList.isNotEmpty ? analyticsList.first : null;

    // Sort by date
    _exams.sort((a, b) => a.examDate.compareTo(b.examDate));
    _studySessions.sort((a, b) => b.startTime.compareTo(a.startTime));
  }

  // ==================== EXAM CRUD ====================

  Future<Exam> createExam(Exam exam) async {
    final newExam = exam.copyWith(id: _uuid.v4());
    
    _exams.add(newExam);
    _exams.sort((a, b) => a.examDate.compareTo(b.examDate));
    await _examsBox?.put(newExam.id, newExam);
    
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
      await _examsBox?.put(exam.id, exam);
      
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
    await _examsBox?.delete(examId);
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
    await _subjectsBox?.put(newSubject.id, newSubject);
    await _syncToCloud('subjects', newSubject.id, newSubject.toJson());
    
    notifyListeners();
    return newSubject;
  }

  Future<void> updateSubject(Subject subject) async {
    final index = _subjects.indexWhere((s) => s.id == subject.id);
    if (index != -1) {
      _subjects[index] = subject;
      await _subjectsBox?.put(subject.id, subject);
      await _syncToCloud('subjects', subject.id, subject.toJson());
      notifyListeners();
    }
  }

  Future<void> deleteSubject(String subjectId) async {
    _subjects.removeWhere((s) => s.id == subjectId);
    await _subjectsBox?.delete(subjectId);
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
    await _topicsBox?.put(newTopic.id, newTopic);
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
      await _topicsBox?.put(topic.id, topic);
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
    await _topicsBox?.delete(topicId);
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
    await _studySessionsBox?.put(completedSession.id, completedSession);
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
    await _gradesBox?.put(newGrade.id, newGrade);
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
      await _gradesBox?.put(grade.id, grade);
      await _syncToCloud('grades', grade.id, grade.toJson());
      notifyListeners();
    }
  }

  Future<void> deleteGrade(String gradeId) async {
    _grades.removeWhere((g) => g.id == gradeId);
    await _gradesBox?.delete(gradeId);
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
    await _studyPlansBox?.put(newPlan.id, newPlan);
    await _syncToCloud('study_plans', newPlan.id, newPlan.toJson());
    
    notifyListeners();
    return newPlan;
  }

  Future<void> updateStudyPlan(StudyPlan plan) async {
    final index = _studyPlans.indexWhere((p) => p.id == plan.id);
    if (index != -1) {
      _studyPlans[index] = plan;
      await _studyPlansBox?.put(plan.id, plan);
      await _syncToCloud('study_plans', plan.id, plan.toJson());
      notifyListeners();
    }
  }

  Future<void> deleteStudyPlan(String planId) async {
    _studyPlans.removeWhere((p) => p.id == planId);
    await _studyPlansBox?.delete(planId);
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
        await _templatesBox?.put(template.id, template);
      }
    }
  }

  Future<ExamTemplate> createTemplate(ExamTemplate template) async {
    final newTemplate = template.copyWith(id: _uuid.v4());
    
    _templates.add(newTemplate);
    await _templatesBox?.put(newTemplate.id, newTemplate);
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
    final updatedTemplate = template.copyWith(usageCount: template.usageCount + 1);
    await _templatesBox?.put(template.id, updatedTemplate);

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
    if (_analytics != null) {
      await _analyticsBox?.put(_analytics!.id, _analytics!);
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
          await _examsBox?.put(exam.id, exam);
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
