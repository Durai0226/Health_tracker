import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import '../../../core/services/clean_storage_service.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/services/audio_service.dart';
import '../models/meditation_activity.dart';
import '../models/focus_reminder.dart';
import '../models/daily_routine.dart';
import '../models/ambient_sound.dart';

class ManropeWellnessService extends ChangeNotifier with WidgetsBindingObserver {
  static final ManropeWellnessService _instance = ManropeWellnessService._internal();
  factory ManropeWellnessService() => _instance;
  ManropeWellnessService._internal();

  final AudioService _audioService = AudioService();
  final NotificationService _notificationService = NotificationService();

  // Session State
  bool _isRunning = false;
  bool _isPaused = false;
  int _remainingSeconds = 0;
  int _selectedMinutes = 10;
  DateTime? _startTime;
  DateTime? _endTime;
  DateTime? _pauseStartTime;
  Timer? _timer;

  // Current Session Config
  WellnessActivityType _selectedActivity = WellnessActivityType.meditation;
  AmbientSoundType _selectedSound = AmbientSoundType.none;
  double _soundVolume = 0.5;

  // Data
  WellnessStats _stats = const WellnessStats();
  List<WellnessSession> _sessions = [];
  List<WellnessActivity> _activities = [];
  List<FocusReminder> _reminders = [];
  DailyRoutine? _activeRoutine;

  // Getters
  bool get isRunning => _isRunning;
  bool get isPaused => _isPaused;
  int get remainingSeconds => _remainingSeconds;
  int get selectedMinutes => _selectedMinutes;
  WellnessActivityType get selectedActivity => _selectedActivity;
  AmbientSoundType get selectedSound => _selectedSound;
  double get soundVolume => _soundVolume;
  WellnessStats get stats => _stats;
  List<WellnessSession> get sessions => List.unmodifiable(_sessions);
  List<WellnessActivity> get activities => List.unmodifiable(_activities);
  List<FocusReminder> get reminders => List.unmodifiable(_reminders);
  DailyRoutine? get activeRoutine => _activeRoutine;

  double get progress => _isRunning && _selectedMinutes > 0
      ? 1 - (_remainingSeconds / (_selectedMinutes * 60))
      : 0.0;

  String get formattedTime {
    final mins = _remainingSeconds ~/ 60;
    final secs = _remainingSeconds % 60;
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  int get todayMinutes {
    final today = DateTime.now();
    return _sessions
        .where((s) => _isSameDay(s.startedAt, today) && s.wasCompleted)
        .fold(0, (sum, s) => sum + s.actualMinutes);
  }

  int get todaySessions {
    final today = DateTime.now();
    return _sessions
        .where((s) => _isSameDay(s.startedAt, today) && s.wasCompleted)
        .length;
  }

  int get weekMinutes {
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    return _sessions
        .where((s) => s.startedAt.isAfter(weekStart) && s.wasCompleted)
        .fold(0, (sum, s) => sum + s.actualMinutes);
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  Future<void> init() async {
    WidgetsBinding.instance.addObserver(this);
    await _audioService.init();
    await _loadData();
    debugPrint('✓ ManropeWellnessService initialized');
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _syncTimer();
    }
  }

  void _syncTimer() {
    if (_isRunning && !_isPaused && _endTime != null) {
      final now = DateTime.now();
      final remaining = _endTime!.difference(now).inSeconds;

      if (remaining <= 0) {
        _remainingSeconds = 0;
        _completeSession();
      } else {
        _remainingSeconds = remaining;
        notifyListeners();
      }
    }
  }

  Future<void> _loadData() async {
    try {
      final prefs = CleanStorageService.getAppPreferences();

      _selectedMinutes = prefs['wellnessSelectedMinutes'] ?? 10;
      _selectedActivity = WellnessActivityType.values[
          prefs['wellnessSelectedActivity'] ?? 0];
      _selectedSound = AmbientSoundType.values[
          prefs['wellnessSelectedSound'] ?? 0];
      _soundVolume = (prefs['wellnessSoundVolume'] ?? 0.5).toDouble();

      // Load stats
      final statsJson = prefs['wellnessStats'];
      if (statsJson != null && statsJson is Map) {
        _stats = WellnessStats.fromJson(Map<String, dynamic>.from(statsJson));
      }

      // Load sessions
      final sessionsJson = prefs['wellnessSessions'];
      if (sessionsJson != null && sessionsJson is List) {
        _sessions = sessionsJson
            .map((s) => WellnessSession.fromJson(Map<String, dynamic>.from(s)))
            .toList();
      }

      // Load activities
      final activitiesJson = prefs['wellnessActivities'];
      if (activitiesJson != null && activitiesJson is List) {
        _activities = activitiesJson
            .map((a) => WellnessActivity.fromJson(Map<String, dynamic>.from(a)))
            .toList();
      } else {
        _activities = WellnessActivity.createDefaults();
        await _saveActivities();
      }

      // Load reminders
      final remindersJson = prefs['wellnessReminders'];
      if (remindersJson != null && remindersJson is List) {
        _reminders = remindersJson
            .map((r) => FocusReminder.fromJson(Map<String, dynamic>.from(r)))
            .toList();
      }

      // Load active routine
      final routineJson = prefs['wellnessActiveRoutine'];
      if (routineJson != null && routineJson is Map) {
        _activeRoutine = DailyRoutine.fromJson(
            Map<String, dynamic>.from(routineJson));
      }

      await _checkAndUpdateStreak();
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading wellness data: $e');
    }
  }

  Future<void> _saveData() async {
    try {
      await CleanStorageService.setAppPreference(
          'wellnessSelectedMinutes', _selectedMinutes);
      await CleanStorageService.setAppPreference(
          'wellnessSelectedActivity', _selectedActivity.index);
      await CleanStorageService.setAppPreference(
          'wellnessSelectedSound', _selectedSound.index);
      await CleanStorageService.setAppPreference(
          'wellnessSoundVolume', _soundVolume);
      await CleanStorageService.setAppPreference(
          'wellnessStats', _stats.toJson());
      await CleanStorageService.setAppPreference(
          'wellnessSessions', _sessions.map((s) => s.toJson()).toList());
    } catch (e) {
      debugPrint('Error saving wellness data: $e');
    }
  }

  Future<void> _saveActivities() async {
    try {
      await CleanStorageService.setAppPreference(
          'wellnessActivities', _activities.map((a) => a.toJson()).toList());
    } catch (e) {
      debugPrint('Error saving activities: $e');
    }
  }

  Future<void> _saveReminders() async {
    try {
      await CleanStorageService.setAppPreference(
          'wellnessReminders', _reminders.map((r) => r.toJson()).toList());
    } catch (e) {
      debugPrint('Error saving reminders: $e');
    }
  }

  Future<void> _saveRoutine() async {
    try {
      if (_activeRoutine != null) {
        await CleanStorageService.setAppPreference(
            'wellnessActiveRoutine', _activeRoutine!.toJson());
      } else {
        await CleanStorageService.setAppPreference('wellnessActiveRoutine', null);
      }
    } catch (e) {
      debugPrint('Error saving routine: $e');
    }
  }

  Future<void> _checkAndUpdateStreak() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    if (_stats.lastSessionDate != null) {
      final lastDate = DateTime(
        _stats.lastSessionDate!.year,
        _stats.lastSessionDate!.month,
        _stats.lastSessionDate!.day,
      );
      final daysDiff = today.difference(lastDate).inDays;

      if (daysDiff > 1) {
        _stats = _stats.copyWith(currentStreak: 0);
        await _saveData();
      }
    }
  }

  // Activity methods
  bool hasActivityOn(DateTime date) {
    return _sessions.any((s) => _isSameDay(s.startedAt, date) && s.wasCompleted);
  }

  int getActivityMinutesToday(WellnessActivityType type) {
    final today = DateTime.now();
    return _sessions
        .where((s) =>
            _isSameDay(s.startedAt, today) &&
            s.activityType == type &&
            s.wasCompleted)
        .fold(0, (sum, s) => sum + s.actualMinutes);
  }

  void setSelectedActivity(WellnessActivityType activity) {
    _selectedActivity = activity;
    _selectedMinutes = activity.defaultDuration;
    notifyListeners();
    _saveData();
  }

  void setSelectedDuration(int minutes) {
    _selectedMinutes = minutes;
    notifyListeners();
    _saveData();
  }

  void setSelectedSound(AmbientSoundType sound) {
    _selectedSound = sound;
    notifyListeners();
    _saveData();
  }

  void setSoundVolume(double volume) {
    _soundVolume = volume.clamp(0.0, 1.0);
    _audioService.setVolume(_soundVolume);
    notifyListeners();
    _saveData();
  }

  // Session methods
  Future<void> startSession() async {
    if (_isRunning) return;

    _isRunning = true;
    _isPaused = false;
    _startTime = DateTime.now();
    _remainingSeconds = _selectedMinutes * 60;
    _endTime = _startTime!.add(Duration(minutes: _selectedMinutes));

    if (_selectedSound != AmbientSoundType.none) {
      await _audioService.playSound(_selectedSound);
      _audioService.setVolume(_soundVolume);
    }

    _startTimer();
    notifyListeners();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 0 && !_isPaused) {
        _remainingSeconds--;
        notifyListeners();
      } else if (_remainingSeconds <= 0) {
        _completeSession();
      }
    });
  }

  Future<void> pauseSession() async {
    if (!_isRunning || _isPaused) return;

    _isPaused = true;
    _pauseStartTime = DateTime.now();
    _timer?.cancel();
    await _audioService.pause();
    notifyListeners();
  }

  Future<void> resumeSession() async {
    if (!_isRunning || !_isPaused) return;

    if (_pauseStartTime != null && _endTime != null) {
      final pauseDuration = DateTime.now().difference(_pauseStartTime!);
      _endTime = _endTime!.add(pauseDuration);
    }

    _isPaused = false;
    _pauseStartTime = null;

    if (_selectedSound != AmbientSoundType.none) {
      await _audioService.resume();
    }

    _startTimer();
    notifyListeners();
  }

  Future<void> abandonSession() async {
    if (!_isRunning) return;

    final actualMinutes = _selectedMinutes - (_remainingSeconds ~/ 60);

    final session = WellnessSession(
      id: '${_selectedActivity.id}_${DateTime.now().millisecondsSinceEpoch}',
      activityType: _selectedActivity,
      startedAt: _startTime!,
      completedAt: DateTime.now(),
      targetMinutes: _selectedMinutes,
      actualMinutes: actualMinutes,
      wasCompleted: false,
      wasAbandoned: true,
      ambientSoundUsed: _selectedSound.name,
    );

    _sessions.add(session);
    _resetSession();
    await _saveData();
    notifyListeners();
  }

  Future<void> _completeSession() async {
    _timer?.cancel();
    await _audioService.stop();

    final session = WellnessSession(
      id: '${_selectedActivity.id}_${DateTime.now().millisecondsSinceEpoch}',
      activityType: _selectedActivity,
      startedAt: _startTime!,
      completedAt: DateTime.now(),
      targetMinutes: _selectedMinutes,
      actualMinutes: _selectedMinutes,
      wasCompleted: true,
      wasAbandoned: false,
      ambientSoundUsed: _selectedSound.name,
    );

    _sessions.add(session);
    await _updateStats(session);
    _resetSession();

    // Send completion notification
    await _notificationService.showImmediateNotification(
      title: 'Session Complete! ✨',
      body: 'You completed ${_selectedMinutes} min of ${_selectedActivity.displayName}',
    );

    notifyListeners();
  }

  void _resetSession() {
    _isRunning = false;
    _isPaused = false;
    _remainingSeconds = 0;
    _startTime = null;
    _endTime = null;
    _pauseStartTime = null;
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _updateStats(WellnessSession session) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    int newStreak = _stats.currentStreak;

    if (_stats.lastSessionDate != null) {
      final lastDate = DateTime(
        _stats.lastSessionDate!.year,
        _stats.lastSessionDate!.month,
        _stats.lastSessionDate!.day,
      );

      if (!_isSameDay(lastDate, today)) {
        final daysDiff = today.difference(lastDate).inDays;
        if (daysDiff == 1) {
          newStreak++;
        } else if (daysDiff > 1) {
          newStreak = 1;
        }
      }
    } else {
      newStreak = 1;
    }

    final minutesByActivity = Map<String, int>.from(_stats.minutesByActivity);
    minutesByActivity[session.activityType.id] =
        (minutesByActivity[session.activityType.id] ?? 0) + session.actualMinutes;

    final sessionsByActivity = Map<String, int>.from(_stats.sessionsByActivity);
    sessionsByActivity[session.activityType.id] =
        (sessionsByActivity[session.activityType.id] ?? 0) + 1;

    _stats = _stats.copyWith(
      totalSessions: _stats.totalSessions + 1,
      totalMinutes: _stats.totalMinutes + session.actualMinutes,
      completedSessions: _stats.completedSessions + 1,
      currentStreak: newStreak,
      longestStreak: newStreak > _stats.longestStreak ? newStreak : _stats.longestStreak,
      lastSessionDate: now,
      minutesByActivity: minutesByActivity,
      sessionsByActivity: sessionsByActivity,
    );

    await _saveData();
  }

  // Reminder methods
  Future<void> addReminder(FocusReminder reminder) async {
    _reminders.add(reminder);
    await _saveReminders();
    await _scheduleReminder(reminder);
    notifyListeners();
  }

  Future<void> updateReminder(FocusReminder reminder) async {
    final index = _reminders.indexWhere((r) => r.id == reminder.id);
    if (index != -1) {
      _reminders[index] = reminder;
      await _saveReminders();
      await _scheduleReminder(reminder);
      notifyListeners();
    }
  }

  Future<void> deleteReminder(String reminderId) async {
    final reminder = _reminders.firstWhere(
      (r) => r.id == reminderId,
      orElse: () => throw Exception('Reminder not found'),
    );

    if (reminder.notificationId != null) {
      await _notificationService.cancelNotification(reminder.notificationId!);
    }

    _reminders.removeWhere((r) => r.id == reminderId);
    await _saveReminders();
    notifyListeners();
  }

  Future<void> toggleReminder(String reminderId, bool enabled) async {
    final index = _reminders.indexWhere((r) => r.id == reminderId);
    if (index != -1) {
      final updated = _reminders[index].copyWith(
        isEnabled: enabled,
        updatedAt: DateTime.now(),
      );
      _reminders[index] = updated;
      await _saveReminders();

      if (enabled) {
        await _scheduleReminder(updated);
      } else if (updated.notificationId != null) {
        await _notificationService.cancelNotification(updated.notificationId!);
      }

      notifyListeners();
    }
  }

  Future<void> _scheduleReminder(FocusReminder reminder) async {
    if (!reminder.isEnabled) return;

    final notificationId = reminder.id.hashCode;

    if (reminder.frequency == ReminderFrequency.daily) {
      await _notificationService.scheduleDailyNotification(
        id: notificationId,
        title: reminder.title,
        body: reminder.body,
        hour: reminder.hour,
        minute: reminder.minute,
      );
    } else {
      // For other frequencies, schedule for next occurrence
      await _notificationService.scheduleNotification(
        id: notificationId,
        title: reminder.title,
        body: reminder.body,
        scheduledDate: _getNextReminderTime(reminder),
      );
    }

    // Update reminder with notification ID
    final index = _reminders.indexWhere((r) => r.id == reminder.id);
    if (index != -1) {
      _reminders[index] = _reminders[index].copyWith(
        notificationId: notificationId,
      );
      await _saveReminders();
    }
  }

  DateTime _getNextReminderTime(FocusReminder reminder) {
    final now = DateTime.now();
    var nextTime = DateTime(
      now.year,
      now.month,
      now.day,
      reminder.hour,
      reminder.minute,
    );

    if (nextTime.isBefore(now)) {
      nextTime = nextTime.add(const Duration(days: 1));
    }

    if (reminder.frequency == ReminderFrequency.custom &&
        reminder.customDays.isNotEmpty) {
      while (!reminder.customDays.contains(nextTime.weekday)) {
        nextTime = nextTime.add(const Duration(days: 1));
      }
    }

    return nextTime;
  }

  // Routine methods
  Future<void> setActiveRoutine(DailyRoutine? routine) async {
    _activeRoutine = routine;
    await _saveRoutine();
    notifyListeners();
  }

  Future<void> markRoutineActivityComplete(String activityId) async {
    if (_activeRoutine == null) return;

    _activeRoutine = _activeRoutine!.markActivityCompleted(activityId);
    await _saveRoutine();
    notifyListeners();
  }

  Future<void> resetDailyRoutine() async {
    if (_activeRoutine == null) return;

    _activeRoutine = _activeRoutine!.resetCompletions();
    await _saveRoutine();
    notifyListeners();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _audioService.dispose();
    super.dispose();
  }
}
