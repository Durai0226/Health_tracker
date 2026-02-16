import 'dart:math';
import 'package:flutter/foundation.dart';
import '../../../core/services/storage_service.dart';
import '../models/exam_type.dart';
import '../models/study_subject.dart';
import '../models/study_session.dart';
import '../models/mock_test.dart';
import '../models/study_goal.dart';

class ExamPrepService extends ChangeNotifier {
  static final ExamPrepService _instance = ExamPrepService._internal();
  factory ExamPrepService() => _instance;
  ExamPrepService._internal();

  // Data
  List<ExamType> _exams = [];
  List<StudySubject> _subjects = [];
  List<StudySession> _sessions = [];
  List<MockTest> _mockTests = [];
  List<StudyGoal> _goals = [];
  List<StudyReminder> _reminders = [];
  
  String? _activeExamId;
  int _currentStreak = 0;
  int _longestStreak = 0;
  DateTime? _lastStudyDate;

  // Getters
  List<ExamType> get exams => List.unmodifiable(_exams);
  List<StudySubject> get subjects => List.unmodifiable(_subjects);
  List<StudySession> get sessions => List.unmodifiable(_sessions);
  List<MockTest> get mockTests => List.unmodifiable(_mockTests);
  List<StudyGoal> get goals => List.unmodifiable(_goals);
  List<StudyReminder> get reminders => List.unmodifiable(_reminders);
  
  String? get activeExamId => _activeExamId;
  ExamType? get activeExam => _exams.firstWhere(
    (e) => e.id == _activeExamId,
    orElse: () => _exams.isNotEmpty ? _exams.first : throw Exception('No exam'),
  );
  
  int get currentStreak => _currentStreak;
  int get longestStreak => _longestStreak;

  List<StudySubject> getSubjectsForExam(String examId) {
    return _subjects.where((s) => s.examId == examId).toList();
  }

  List<StudySession> getSessionsForExam(String examId) {
    return _sessions.where((s) => s.examId == examId).toList();
  }

  List<MockTest> getMockTestsForExam(String examId) {
    return _mockTests.where((t) => t.examId == examId).toList();
  }

  List<StudyGoal> getGoalsForExam(String examId) {
    return _goals.where((g) => g.examId == examId).toList();
  }

  // Statistics
  int get totalStudyMinutes => _sessions.fold(0, (sum, s) => sum + s.durationMinutes);
  int get totalStudyHours => totalStudyMinutes ~/ 60;
  
  int getTodayStudyMinutes() {
    final today = DateTime.now();
    return _sessions
        .where((s) => _isSameDay(s.startTime, today))
        .fold(0, (sum, s) => sum + s.durationMinutes);
  }

  int getWeekStudyMinutes() {
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    return _sessions
        .where((s) => s.startTime.isAfter(weekStart))
        .fold(0, (sum, s) => sum + s.durationMinutes);
  }

  double getAverageMockScore(String examId) {
    final tests = getMockTestsForExam(examId);
    if (tests.isEmpty) return 0;
    return tests.map((t) => t.percentageScore).reduce((a, b) => a + b) / tests.length;
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  Future<void> init() async {
    await _loadData();
    await _checkStreak();
    await _scheduleReminders();
    debugPrint('✓ ExamPrepService initialized');
  }

  Future<void> _loadData() async {
    try {
      final prefs = StorageService.getAppPreferences();

      // Load exams
      final examsJson = prefs['examPrepExams'];
      if (examsJson != null && examsJson is List) {
        _exams = examsJson
            .map((e) => ExamType.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      }

      // Load subjects
      final subjectsJson = prefs['examPrepSubjects'];
      if (subjectsJson != null && subjectsJson is List) {
        _subjects = subjectsJson
            .map((s) => StudySubject.fromJson(Map<String, dynamic>.from(s)))
            .toList();
      }

      // Load sessions
      final sessionsJson = prefs['examPrepSessions'];
      if (sessionsJson != null && sessionsJson is List) {
        _sessions = sessionsJson
            .map((s) => StudySession.fromJson(Map<String, dynamic>.from(s)))
            .toList();
      }

      // Load mock tests
      final testsJson = prefs['examPrepMockTests'];
      if (testsJson != null && testsJson is List) {
        _mockTests = testsJson
            .map((t) => MockTest.fromJson(Map<String, dynamic>.from(t)))
            .toList();
      }

      // Load goals
      final goalsJson = prefs['examPrepGoals'];
      if (goalsJson != null && goalsJson is List) {
        _goals = goalsJson
            .map((g) => StudyGoal.fromJson(Map<String, dynamic>.from(g)))
            .toList();
      }

      // Load reminders
      final remindersJson = prefs['examPrepReminders'];
      if (remindersJson != null && remindersJson is List) {
        _reminders = remindersJson
            .map((r) => StudyReminder.fromJson(Map<String, dynamic>.from(r)))
            .toList();
      }

      // Load other data
      _activeExamId = prefs['examPrepActiveExamId'];
      _currentStreak = prefs['examPrepCurrentStreak'] ?? 0;
      _longestStreak = prefs['examPrepLongestStreak'] ?? 0;
      final lastStudyStr = prefs['examPrepLastStudyDate'];
      if (lastStudyStr != null) {
        _lastStudyDate = DateTime.parse(lastStudyStr);
      }

      notifyListeners();
    } catch (e) {
      debugPrint('Error loading exam prep data: $e');
    }
  }

  Future<void> _saveData() async {
    try {
      await StorageService.setAppPreference('examPrepExams', 
          _exams.map((e) => e.toJson()).toList());
      await StorageService.setAppPreference('examPrepSubjects', 
          _subjects.map((s) => s.toJson()).toList());
      await StorageService.setAppPreference('examPrepSessions', 
          _sessions.take(500).map((s) => s.toJson()).toList());
      await StorageService.setAppPreference('examPrepMockTests', 
          _mockTests.map((t) => t.toJson()).toList());
      await StorageService.setAppPreference('examPrepGoals', 
          _goals.map((g) => g.toJson()).toList());
      await StorageService.setAppPreference('examPrepReminders', 
          _reminders.map((r) => r.toJson()).toList());
      await StorageService.setAppPreference('examPrepActiveExamId', _activeExamId);
      await StorageService.setAppPreference('examPrepCurrentStreak', _currentStreak);
      await StorageService.setAppPreference('examPrepLongestStreak', _longestStreak);
      await StorageService.setAppPreference('examPrepLastStudyDate', 
          _lastStudyDate?.toIso8601String());
    } catch (e) {
      debugPrint('Error saving exam prep data: $e');
    }
  }

  // Exam CRUD
  Future<void> addExam(ExamType exam) async {
    _exams.add(exam);
    _activeExamId ??= exam.id;
    await _saveData();
    notifyListeners();
  }

  Future<void> updateExam(ExamType exam) async {
    final index = _exams.indexWhere((e) => e.id == exam.id);
    if (index != -1) {
      _exams[index] = exam;
      await _saveData();
      notifyListeners();
    }
  }

  Future<void> deleteExam(String examId) async {
    _exams.removeWhere((e) => e.id == examId);
    _subjects.removeWhere((s) => s.examId == examId);
    _sessions.removeWhere((s) => s.examId == examId);
    _mockTests.removeWhere((t) => t.examId == examId);
    _goals.removeWhere((g) => g.examId == examId);
    _reminders.removeWhere((r) => r.examId == examId);
    
    if (_activeExamId == examId) {
      _activeExamId = _exams.isNotEmpty ? _exams.first.id : null;
    }
    
    await _saveData();
    notifyListeners();
  }

  void setActiveExam(String examId) {
    _activeExamId = examId;
    _saveData();
    notifyListeners();
  }

  // Subject CRUD
  Future<void> addSubject(StudySubject subject) async {
    _subjects.add(subject);
    await _saveData();
    notifyListeners();
  }

  Future<void> updateSubject(StudySubject subject) async {
    final index = _subjects.indexWhere((s) => s.id == subject.id);
    if (index != -1) {
      _subjects[index] = subject;
      await _saveData();
      notifyListeners();
    }
  }

  Future<void> deleteSubject(String subjectId) async {
    _subjects.removeWhere((s) => s.id == subjectId);
    _sessions.removeWhere((s) => s.subjectId == subjectId);
    await _saveData();
    notifyListeners();
  }

  Future<void> toggleTopicCompletion(String subjectId, String topic) async {
    final index = _subjects.indexWhere((s) => s.id == subjectId);
    if (index != -1) {
      final subject = _subjects[index];
      final newCompletion = Map<String, bool>.from(subject.topicCompletion);
      newCompletion[topic] = !(newCompletion[topic] ?? false);
      _subjects[index] = subject.copyWith(topicCompletion: newCompletion);
      await _saveData();
      notifyListeners();
    }
  }

  // Study Session
  Future<void> addStudySession(StudySession session) async {
    _sessions.insert(0, session);
    
    // Update subject time
    final subjectIndex = _subjects.indexWhere((s) => s.id == session.subjectId);
    if (subjectIndex != -1) {
      final subject = _subjects[subjectIndex];
      _subjects[subjectIndex] = subject.copyWith(
        completedMinutes: subject.completedMinutes + session.durationMinutes,
      );
    }
    
    await _updateStreak();
    await _updateGoals(session);
    await _saveData();
    notifyListeners();
  }

  // Mock Test
  Future<void> addMockTest(MockTest test) async {
    _mockTests.insert(0, test);
    await _saveData();
    notifyListeners();
  }

  Future<void> updateMockTest(MockTest test) async {
    final index = _mockTests.indexWhere((t) => t.id == test.id);
    if (index != -1) {
      _mockTests[index] = test;
      await _saveData();
      notifyListeners();
    }
  }

  Future<void> deleteMockTest(String testId) async {
    _mockTests.removeWhere((t) => t.id == testId);
    await _saveData();
    notifyListeners();
  }

  // Goals
  Future<void> addGoal(StudyGoal goal) async {
    _goals.add(goal);
    await _saveData();
    notifyListeners();
  }

  Future<void> updateGoal(StudyGoal goal) async {
    final index = _goals.indexWhere((g) => g.id == goal.id);
    if (index != -1) {
      _goals[index] = goal;
      await _saveData();
      notifyListeners();
    }
  }

  Future<void> deleteGoal(String goalId) async {
    _goals.removeWhere((g) => g.id == goalId);
    await _saveData();
    notifyListeners();
  }

  Future<void> _updateGoals(StudySession session) async {
    for (int i = 0; i < _goals.length; i++) {
      final goal = _goals[i];
      if (goal.examId == session.examId && goal.isActive && !goal.isCompleted) {
        int newValue = goal.currentValue;
        
        switch (goal.type) {
          case GoalType.studyHours:
            newValue = getTodayStudyMinutes() ~/ 60;
            break;
          case GoalType.questionsPerDay:
            if (session.type == StudyType.practice) {
              newValue++;
            }
            break;
          case GoalType.revisionSessions:
            if (session.type == StudyType.revision) {
              newValue++;
            }
            break;
          default:
            break;
        }
        
        if (newValue != goal.currentValue) {
          _goals[i] = goal.copyWith(currentValue: newValue);
        }
      }
    }
  }

  // Reminders
  Future<void> addReminder(StudyReminder reminder) async {
    _reminders.add(reminder);
    await _scheduleReminders();
    await _saveData();
    notifyListeners();
  }

  Future<void> updateReminder(StudyReminder reminder) async {
    final index = _reminders.indexWhere((r) => r.id == reminder.id);
    if (index != -1) {
      _reminders[index] = reminder;
      await _scheduleReminders();
      await _saveData();
      notifyListeners();
    }
  }

  Future<void> deleteReminder(String reminderId) async {
    _reminders.removeWhere((r) => r.id == reminderId);
    await _scheduleReminders();
    await _saveData();
    notifyListeners();
  }

  Future<void> toggleReminder(String reminderId) async {
    final index = _reminders.indexWhere((r) => r.id == reminderId);
    if (index != -1) {
      final reminder = _reminders[index];
      _reminders[index] = reminder.copyWith(isEnabled: !reminder.isEnabled);
      await _scheduleReminders();
      await _saveData();
      notifyListeners();
    }
  }

  Future<void> _scheduleReminders() async {
    // Schedule notifications for enabled reminders
    for (final reminder in _reminders.where((r) => r.isEnabled)) {
      // Notification scheduling logic would go here
      debugPrint('Scheduling reminder: ${reminder.title}');
    }
  }

  // Streak
  Future<void> _checkStreak() async {
    if (_lastStudyDate == null) return;
    
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final lastDate = DateTime(
      _lastStudyDate!.year,
      _lastStudyDate!.month,
      _lastStudyDate!.day,
    );
    
    final difference = today.difference(lastDate).inDays;
    
    if (difference > 1) {
      _currentStreak = 0;
    }
    
    await _saveData();
  }

  Future<void> _updateStreak() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    if (_lastStudyDate == null) {
      _currentStreak = 1;
      _lastStudyDate = now;
    } else {
      final lastDate = DateTime(
        _lastStudyDate!.year,
        _lastStudyDate!.month,
        _lastStudyDate!.day,
      );
      
      final difference = today.difference(lastDate).inDays;
      
      if (difference == 1) {
        _currentStreak++;
      } else if (difference > 1) {
        _currentStreak = 1;
      }
      
      _lastStudyDate = now;
    }
    
    if (_currentStreak > _longestStreak) {
      _longestStreak = _currentStreak;
    }
    
    await _saveData();
  }

  // Utilities
  String generateId() {
    return '${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(10000)}';
  }

  // Analytics
  Map<String, int> getStudyTimeBySubject(String examId) {
    final Map<String, int> timeBySubject = {};
    for (final session in getSessionsForExam(examId)) {
      timeBySubject[session.subjectId] = 
          (timeBySubject[session.subjectId] ?? 0) + session.durationMinutes;
    }
    return timeBySubject;
  }

  Map<StudyType, int> getStudyTimeByType(String examId) {
    final Map<StudyType, int> timeByType = {};
    for (final session in getSessionsForExam(examId)) {
      timeByType[session.type] = 
          (timeByType[session.type] ?? 0) + session.durationMinutes;
    }
    return timeByType;
  }

  List<MockTest> getRecentMockTests(String examId, {int limit = 5}) {
    return getMockTestsForExam(examId)
        .take(limit)
        .toList();
  }

  double getMockTestImprovement(String examId) {
    final tests = getMockTestsForExam(examId);
    if (tests.length < 2) return 0;
    
    final recent = tests.first.percentageScore;
    final previous = tests[1].percentageScore;
    return recent - previous;
  }
}
