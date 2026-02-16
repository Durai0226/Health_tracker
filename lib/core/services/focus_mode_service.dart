import 'dart:async';
import 'package:flutter/foundation.dart';
import 'storage_service.dart';
import 'notification_service.dart';

/// Centralized service for Focus Mode state management with persistence
class FocusModeService extends ChangeNotifier {
  static final FocusModeService _instance = FocusModeService._internal();
  factory FocusModeService() => _instance;
  FocusModeService._internal();

  // State
  bool _isRunning = false;
  bool _isPaused = false;
  int _remainingSeconds = 0;
  int _selectedMinutes = 25;
  String _selectedActivity = 'reading';
  DateTime? _startTime;
  DateTime? _endTime;
  Timer? _timer;

  // Scheduled Focus Mode
  bool _isScheduled = false;
  FocusTimeOfDay? _scheduledStartTime;
  FocusTimeOfDay? _scheduledEndTime;
  List<int> _scheduledDays = []; // 1-7, Monday-Sunday
  bool _autoStartReminders = true;

  // Stats
  int _todayMinutes = 0;
  int _weekMinutes = 0;
  int _totalSessions = 0;

  // Getters
  bool get isRunning => _isRunning;
  bool get isPaused => _isPaused;
  int get remainingSeconds => _remainingSeconds;
  int get selectedMinutes => _selectedMinutes;
  String get selectedActivity => _selectedActivity;
  DateTime? get startTime => _startTime;
  DateTime? get endTime => _endTime;
  bool get isScheduled => _isScheduled;
  FocusTimeOfDay? get scheduledStartTime => _scheduledStartTime;
  FocusTimeOfDay? get scheduledEndTime => _scheduledEndTime;
  List<int> get scheduledDays => _scheduledDays;
  bool get autoStartReminders => _autoStartReminders;
  int get todayMinutes => _todayMinutes;
  int get weekMinutes => _weekMinutes;
  int get totalSessions => _totalSessions;

  double get progress => _isRunning && _selectedMinutes > 0
      ? 1 - (_remainingSeconds / (_selectedMinutes * 60))
      : 0.0;

  String get formattedTime {
    final mins = _remainingSeconds ~/ 60;
    final secs = _remainingSeconds % 60;
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  /// Initialize service and restore state
  Future<void> init() async {
    await _loadState();
    await _loadStats();
    _checkScheduledFocusMode();
    debugPrint('✓ FocusModeService initialized');
  }

  /// Load persisted state
  Future<void> _loadState() async {
    try {
      final prefs = StorageService.getAppPreferences();
      
      _selectedMinutes = prefs['focusSelectedMinutes'] ?? 25;
      _selectedActivity = prefs['focusSelectedActivity'] ?? 'reading';
      _isScheduled = prefs['focusIsScheduled'] ?? false;
      _autoStartReminders = prefs['focusAutoStartReminders'] ?? true;
      
      // Load scheduled times
      final startHour = prefs['focusScheduledStartHour'];
      final startMinute = prefs['focusScheduledStartMinute'];
      if (startHour != null && startMinute != null) {
        _scheduledStartTime = FocusTimeOfDay(hour: startHour, minute: startMinute);
      }
      
      final endHour = prefs['focusScheduledEndHour'];
      final endMinute = prefs['focusScheduledEndMinute'];
      if (endHour != null && endMinute != null) {
        _scheduledEndTime = FocusTimeOfDay(hour: endHour, minute: endMinute);
      }
      
      final days = prefs['focusScheduledDays'];
      if (days != null && days is List) {
        _scheduledDays = List<int>.from(days);
      }

      // Check if there was an active session
      final wasRunning = prefs['focusWasRunning'] ?? false;
      final savedRemainingSeconds = prefs['focusRemainingSeconds'] ?? 0;
      final savedStartTimeStr = prefs['focusStartTime'];
      
      if (wasRunning && savedRemainingSeconds > 0 && savedStartTimeStr != null) {
        final savedStartTime = DateTime.tryParse(savedStartTimeStr);
        if (savedStartTime != null) {
          // Calculate elapsed time since app was closed
          final elapsedSeconds = DateTime.now().difference(savedStartTime).inSeconds;
          final originalTotal = _selectedMinutes * 60;
          final elapsedFromStart = originalTotal - savedRemainingSeconds + elapsedSeconds;
          final newRemaining = (originalTotal - elapsedFromStart).toInt();
          
          if (newRemaining > 0) {
            // Resume the session
            _remainingSeconds = newRemaining;
            _startTime = savedStartTime;
            _isRunning = true;
            _startTimer();
            debugPrint('✓ Resumed Focus Mode session with $newRemaining seconds remaining');
          } else {
            // Session would have completed - mark as complete
            await _completeSession(fromRestore: true);
          }
        }
      }
      
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading focus mode state: $e');
    }
  }

  /// Save current state
  Future<void> _saveState() async {
    try {
      await StorageService.setAppPreference('focusSelectedMinutes', _selectedMinutes);
      await StorageService.setAppPreference('focusSelectedActivity', _selectedActivity);
      await StorageService.setAppPreference('focusWasRunning', _isRunning);
      await StorageService.setAppPreference('focusRemainingSeconds', _remainingSeconds);
      await StorageService.setAppPreference('focusStartTime', _startTime?.toIso8601String());
      await StorageService.setAppPreference('focusIsScheduled', _isScheduled);
      await StorageService.setAppPreference('focusAutoStartReminders', _autoStartReminders);
      
      if (_scheduledStartTime != null) {
        await StorageService.setAppPreference('focusScheduledStartHour', _scheduledStartTime!.hour);
        await StorageService.setAppPreference('focusScheduledStartMinute', _scheduledStartTime!.minute);
      }
      if (_scheduledEndTime != null) {
        await StorageService.setAppPreference('focusScheduledEndHour', _scheduledEndTime!.hour);
        await StorageService.setAppPreference('focusScheduledEndMinute', _scheduledEndTime!.minute);
      }
      await StorageService.setAppPreference('focusScheduledDays', _scheduledDays);
    } catch (e) {
      debugPrint('Error saving focus mode state: $e');
    }
  }

  /// Load stats from storage
  Future<void> _loadStats() async {
    try {
      final prefs = StorageService.getAppPreferences();
      final today = _getTodayKey();
      
      _todayMinutes = prefs['focusTodayMinutes_$today'] ?? 0;
      _weekMinutes = prefs['focusWeekMinutes'] ?? 0;
      _totalSessions = prefs['focusTotalSessions'] ?? 0;
      
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading focus mode stats: $e');
    }
  }

  String _getTodayKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  /// Set selected duration
  void setDuration(int minutes) {
    if (!_isRunning) {
      _selectedMinutes = minutes;
      _saveState();
      notifyListeners();
    }
  }

  /// Set selected activity
  void setActivity(String activity) {
    if (!_isRunning) {
      _selectedActivity = activity;
      _saveState();
      notifyListeners();
    }
  }

  /// Start Focus Mode session
  Future<void> startSession() async {
    if (_isRunning) return;
    
    _isRunning = true;
    _isPaused = false;
    _remainingSeconds = _selectedMinutes * 60;
    _startTime = DateTime.now();
    _endTime = _startTime!.add(Duration(minutes: _selectedMinutes));
    
    await _saveState();
    _startTimer();
    
    // Pause other reminders if configured
    if (_autoStartReminders) {
      await _pauseReminders();
    }
    
    notifyListeners();
    debugPrint('✓ Focus Mode started: $_selectedMinutes minutes of $_selectedActivity');
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 0 && !_isPaused) {
        _remainingSeconds--;
        notifyListeners();
        
        // Save state periodically (every 30 seconds)
        if (_remainingSeconds % 30 == 0) {
          _saveState();
        }
      } else if (_remainingSeconds <= 0) {
        _completeSession();
      }
    });
  }

  /// Pause Focus Mode session
  void pauseSession() {
    if (_isRunning && !_isPaused) {
      _isPaused = true;
      _saveState();
      notifyListeners();
    }
  }

  /// Resume Focus Mode session
  void resumeSession() {
    if (_isRunning && _isPaused) {
      _isPaused = false;
      notifyListeners();
    }
  }

  /// Stop Focus Mode session
  Future<void> stopSession() async {
    if (!_isRunning) return;
    
    _timer?.cancel();
    
    // Calculate completed minutes
    final completedMinutes = _selectedMinutes - (_remainingSeconds ~/ 60);
    if (completedMinutes > 0) {
      await _saveSessionStats(completedMinutes);
    }
    
    _isRunning = false;
    _isPaused = false;
    _remainingSeconds = 0;
    _startTime = null;
    _endTime = null;
    
    await StorageService.setAppPreference('focusWasRunning', false);
    
    // Resume reminders
    if (_autoStartReminders) {
      await _resumeReminders();
    }
    
    notifyListeners();
    debugPrint('✓ Focus Mode stopped after $completedMinutes minutes');
  }

  /// Complete the session
  Future<void> _completeSession({bool fromRestore = false}) async {
    _timer?.cancel();
    
    await _saveSessionStats(_selectedMinutes);
    
    // Show completion notification
    if (!fromRestore) {
      await NotificationService().showImmediateNotification(
        title: 'Focus Session Complete! 🎉',
        body: 'Great job! You focused for $_selectedMinutes minutes.',
      );
    }
    
    _isRunning = false;
    _isPaused = false;
    _remainingSeconds = 0;
    _startTime = null;
    _endTime = null;
    
    await StorageService.setAppPreference('focusWasRunning', false);
    
    // Resume reminders
    if (_autoStartReminders) {
      await _resumeReminders();
    }
    
    notifyListeners();
    debugPrint('✓ Focus Mode session completed');
  }

  /// Save session statistics
  Future<void> _saveSessionStats(int minutes) async {
    final today = _getTodayKey();
    
    _todayMinutes += minutes;
    _weekMinutes += minutes;
    _totalSessions++;
    
    await StorageService.setAppPreference('focusTodayMinutes_$today', _todayMinutes);
    await StorageService.setAppPreference('focusWeekMinutes', _weekMinutes);
    await StorageService.setAppPreference('focusTotalSessions', _totalSessions);
    
    // Save to recent sessions
    final prefs = StorageService.getAppPreferences();
    List<Map<String, dynamic>> recentSessions = [];
    final sessions = prefs['focusRecentSessions'];
    if (sessions != null && sessions is List) {
      recentSessions = List<Map<String, dynamic>>.from(
        sessions.map((s) => Map<String, dynamic>.from(s))
      );
    }
    
    recentSessions.insert(0, {
      'activity': _selectedActivity,
      'minutes': minutes,
      'date': DateTime.now().toIso8601String(),
    });
    
    if (recentSessions.length > 10) {
      recentSessions = recentSessions.take(10).toList();
    }
    
    await StorageService.setAppPreference('focusRecentSessions', recentSessions);
  }

  // ============ Scheduled Focus Mode ============

  /// Enable/disable scheduled Focus Mode
  Future<void> setScheduled(bool enabled) async {
    _isScheduled = enabled;
    await _saveState();
    
    if (enabled) {
      await _scheduleNotifications();
    } else {
      await _cancelScheduledNotifications();
    }
    
    notifyListeners();
  }

  /// Set scheduled start time
  Future<void> setScheduledStartTime(FocusTimeOfDay time) async {
    _scheduledStartTime = time;
    await _saveState();
    if (_isScheduled) {
      await _scheduleNotifications();
    }
    notifyListeners();
  }

  /// Set scheduled end time
  Future<void> setScheduledEndTime(FocusTimeOfDay time) async {
    _scheduledEndTime = time;
    await _saveState();
    if (_isScheduled) {
      await _scheduleNotifications();
    }
    notifyListeners();
  }

  /// Set scheduled days (1-7, Monday-Sunday)
  Future<void> setScheduledDays(List<int> days) async {
    _scheduledDays = days;
    await _saveState();
    if (_isScheduled) {
      await _scheduleNotifications();
    }
    notifyListeners();
  }

  /// Set auto-start reminders option
  Future<void> setAutoStartReminders(bool enabled) async {
    _autoStartReminders = enabled;
    await _saveState();
    notifyListeners();
  }

  /// Check if current time is within scheduled Focus Mode
  void _checkScheduledFocusMode() {
    if (!_isScheduled || _scheduledStartTime == null || _scheduledEndTime == null) {
      return;
    }

    final now = DateTime.now();
    final currentDay = now.weekday; // 1-7
    
    if (!_scheduledDays.contains(currentDay)) {
      return;
    }

    final currentMinutes = now.hour * 60 + now.minute;
    final startMinutes = _scheduledStartTime!.hour * 60 + _scheduledStartTime!.minute;
    final endMinutes = _scheduledEndTime!.hour * 60 + _scheduledEndTime!.minute;

    bool isWithinSchedule;
    if (startMinutes <= endMinutes) {
      isWithinSchedule = currentMinutes >= startMinutes && currentMinutes < endMinutes;
    } else {
      // Handles overnight schedules
      isWithinSchedule = currentMinutes >= startMinutes || currentMinutes < endMinutes;
    }

    if (isWithinSchedule && !_isRunning) {
      // Calculate remaining time in the focus period
      int remainingInSchedule;
      if (startMinutes <= endMinutes) {
        remainingInSchedule = endMinutes - currentMinutes;
      } else {
        if (currentMinutes >= startMinutes) {
          remainingInSchedule = (24 * 60 - currentMinutes) + endMinutes;
        } else {
          remainingInSchedule = endMinutes - currentMinutes;
        }
      }
      
      // Auto-start if within schedule
      _selectedMinutes = remainingInSchedule.clamp(1, 120).toInt();
      startSession();
      debugPrint('✓ Auto-started Focus Mode from schedule');
    }
  }

  /// Schedule notifications for Focus Mode start/end
  Future<void> _scheduleNotifications() async {
    if (_scheduledStartTime == null) return;
    
    // Schedule start notification
    // This would integrate with NotificationService to schedule daily notifications
    debugPrint('✓ Scheduled Focus Mode notifications');
  }

  /// Cancel scheduled notifications
  Future<void> _cancelScheduledNotifications() async {
    // Cancel any scheduled Focus Mode notifications
    debugPrint('✓ Cancelled scheduled Focus Mode notifications');
  }

  /// Pause other app reminders during Focus Mode
  Future<void> _pauseReminders() async {
    await StorageService.setAppPreference('remindersPausedForFocus', true);
    await StorageService.setAppPreference('remindersPausedAt', DateTime.now().toIso8601String());
    debugPrint('✓ Reminders paused for Focus Mode');
  }

  /// Resume other app reminders after Focus Mode
  Future<void> _resumeReminders() async {
    await StorageService.setAppPreference('remindersPausedForFocus', false);
    await StorageService.setAppPreference('remindersPausedAt', null);
    debugPrint('✓ Reminders resumed after Focus Mode');
  }

  /// Check if reminders are paused
  static bool areRemindersPaused() {
    final prefs = StorageService.getAppPreferences();
    return prefs['remindersPausedForFocus'] ?? false;
  }

  /// Get recent sessions
  List<Map<String, dynamic>> getRecentSessions() {
    try {
      final prefs = StorageService.getAppPreferences();
      final sessions = prefs['focusRecentSessions'];
      if (sessions != null && sessions is List) {
        return List<Map<String, dynamic>>.from(
          sessions.map((s) => Map<String, dynamic>.from(s))
        );
      }
    } catch (e) {
      debugPrint('Error loading recent sessions: $e');
    }
    return [];
  }

  /// Dispose
  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

/// FocusTimeOfDay helper class to avoid conflict with Flutter's TimeOfDay
class FocusTimeOfDay {
  final int hour;
  final int minute;
  
  const FocusTimeOfDay({required this.hour, required this.minute});
  
  String format() {
    final h = hour % 12 == 0 ? 12 : hour % 12;
    final period = hour < 12 ? 'AM' : 'PM';
    return '${h.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')} $period';
  }
  
  @override
  String toString() => format();
}
