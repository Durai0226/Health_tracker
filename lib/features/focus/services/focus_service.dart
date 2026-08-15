import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import '../../../core/health/streak_engine.dart';
import '../../../core/services/clean_storage_service.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/services/audio_service.dart';
import '../models/focus_plant.dart';
import '../models/ambient_sound.dart';
import '../models/focus_session.dart';
import '../models/focus_achievement.dart';
import 'coins_service.dart';
import 'tag_service.dart';

class FocusService extends ChangeNotifier with WidgetsBindingObserver {
  static final FocusService _instance = FocusService._internal();
  factory FocusService() => _instance;
  FocusService._internal();

  // Audio Service for ambient sounds
  final AudioService _audioService = AudioService();

  // Session State
  bool _isRunning = false;
  bool _isPaused = false;
  int _remainingSeconds = 0;

  /// Fires once a second while a session runs — and NOTHING else.
  ///
  /// The countdown used to arrive via `notifyListeners()`, which the Focus
  /// screen listens to around its entire body. That body is **2322 widgets**
  /// (the largest tree in the app by a factor of ~3, because it is a
  /// `SingleChildScrollView` over thirteen configuration sections), so a
  /// running timer rebuilt all of it 60 times a minute — and Home listens to
  /// this service too, so it rebuilt at 1 Hz as well.
  ///
  /// Only the clock readout and the progress ring actually change per second.
  /// They listen here; everything else keeps listening to the ChangeNotifier,
  /// which now fires only on real state changes (start, pause, phase change,
  /// completion) — all user-driven and rare.
  final ValueNotifier<int> tick = ValueNotifier<int>(0);
  int _selectedMinutes = 25;
  DateTime? _startTime;
  DateTime? _endTime;
  DateTime? _pauseStartTime;
  Timer? _timer;

  // Total length (minutes) of the interval that is currently running. For single
  // mode this equals _selectedMinutes; for pomodoro it is the work or break
  // length of the active phase. Drives [progress] so the ring is correct in both
  // work and break phases. 0 when idle.
  int _phaseMinutes = 0;

  // ---- Pomodoro (FOCUS-2) ----
  FocusMode _mode = FocusMode.single;
  int _workMinutes = 25;
  int _shortBreakMinutes = 5;
  int _longBreakMinutes = 15;
  int _roundsBeforeLongBreak = 4;
  int _totalRounds = 4;

  // Pomodoro runtime state.
  bool _isOnBreak = false;
  bool _isLongBreak = false;
  int _currentRound = 0; // completed WORK rounds this session
  
  // Current Session Config
  PlantType _selectedPlant = PlantType.seedling;
  FocusActivityType _selectedActivity = FocusActivityType.work;
  AmbientSoundType _selectedSound = AmbientSoundType.none;
  double _soundVolume = 0.5;
  List<String> _selectedTagIds = [];
  
  // Stats & Data
  FocusStats _stats = const FocusStats();
  List<FocusPlant> _garden = [];
  List<FocusSession> _sessions = [];
  final Map<AchievementType, FocusAchievement> _achievements = {};
  Set<PlantType> _unlockedPlants = {PlantType.seedling, PlantType.sprout};
  Set<AmbientSoundType> _usedSounds = {};

  // Getters
  bool get isRunning => _isRunning;
  bool get isPaused => _isPaused;
  int get remainingSeconds => _remainingSeconds;
  int get selectedMinutes => _selectedMinutes;
  PlantType get selectedPlant => _selectedPlant;
  FocusActivityType get selectedActivity => _selectedActivity;
  AmbientSoundType get selectedSound => _selectedSound;
  double get soundVolume => _soundVolume;
  List<String> get selectedTagIds => List.unmodifiable(_selectedTagIds);
  FocusStats get stats => _stats;
  List<FocusPlant> get garden => List.unmodifiable(_garden);
  List<FocusSession> get sessions => List.unmodifiable(_sessions);
  Map<AchievementType, FocusAchievement> get achievements => Map.unmodifiable(_achievements);
  Set<PlantType> get unlockedPlants => Set.unmodifiable(_unlockedPlants);

  // Pomodoro getters (FOCUS-2)
  FocusMode get mode => _mode;
  int get workMinutes => _workMinutes;
  int get shortBreakMinutes => _shortBreakMinutes;
  int get longBreakMinutes => _longBreakMinutes;
  int get roundsBeforeLongBreak => _roundsBeforeLongBreak;
  int get totalRounds => _totalRounds;
  bool get isOnBreak => _isOnBreak;
  bool get isLongBreak => _isLongBreak;
  int get currentRound => _currentRound;

  double get progress => _isRunning && _phaseMinutes > 0
      ? 1 - (_remainingSeconds / (_phaseMinutes * 60))
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
  
  int get weekMinutes {
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    return _sessions
        .where((s) => s.startedAt.isAfter(weekStart) && s.wasCompleted)
        .fold(0, (sum, s) => sum + s.actualMinutes);
  }

  List<FocusPlant> get todayPlants {
    final today = DateTime.now();
    return _garden.where((p) => _isSameDay(p.plantedAt, today)).toList();
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  Future<void> init() async {
    WidgetsBinding.instance.addObserver(this);
    await _audioService.init();
    await CoinsService().init();
    await TagService().init();
    await _loadData();
    _initAchievements();
    await _checkAndUpdateStreak();
    debugPrint('✓ FocusService initialized');
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
        _onIntervalComplete();
      } else {
        _remainingSeconds = remaining;
        notifyListeners();
      }
    }
  }

  Future<void> _loadData() async {
    try {
      final prefs = CleanStorageService.getAppPreferences();
      
      _selectedMinutes = prefs['focusSelectedMinutes'] ?? 25;

      // Pomodoro mode + config (FOCUS-2). Defaults keep single-session behavior.
      _mode = FocusMode.values[prefs['focusMode'] ?? 0];
      _workMinutes = prefs['focusPomoWorkMinutes'] ?? 25;
      _shortBreakMinutes = prefs['focusPomoShortBreakMinutes'] ?? 5;
      _longBreakMinutes = prefs['focusPomoLongBreakMinutes'] ?? 15;
      _roundsBeforeLongBreak = prefs['focusPomoRoundsBeforeLong'] ?? 4;
      _totalRounds = prefs['focusPomoTotalRounds'] ?? 4;

      _selectedPlant = PlantType.values[prefs['focusSelectedPlant'] ?? 0];
      _selectedActivity = FocusActivityType.values[prefs['focusSelectedActivityType'] ?? 0];
      _selectedSound = AmbientSoundType.values[prefs['focusSelectedSound'] ?? 0];
      final dynamic volumeValue = prefs['focusSoundVolume'] ?? 0.5;
      if (volumeValue is String) {
        _soundVolume = double.tryParse(volumeValue) ?? 0.5;
      } else if (volumeValue is num) {
        _soundVolume = volumeValue.toDouble();
      } else {
        _soundVolume = 0.5;
      }

      // Load stats
      final statsJson = prefs['focusStats'];
      if (statsJson != null && statsJson is Map) {
        _stats = FocusStats.fromJson(Map<String, dynamic>.from(statsJson));
      }

      // Load previously selected tags for the next session
      final selectedTagsJson = prefs['focusSelectedTagIds'];
      if (selectedTagsJson != null && selectedTagsJson is List) {
        _selectedTagIds = List<String>.from(selectedTagsJson);
      }

      // Load garden
      final gardenJson = prefs['focusGarden'];
      if (gardenJson != null && gardenJson is List) {
        _garden = gardenJson
            .map((p) => FocusPlant.fromJson(Map<String, dynamic>.from(p)))
            .toList();
      }

      // Load sessions
      final sessionsJson = prefs['focusSessions'];
      if (sessionsJson != null && sessionsJson is List) {
        _sessions = sessionsJson
            .map((s) => FocusSession.fromJson(Map<String, dynamic>.from(s)))
            .toList();
      }

      // Load achievements
      final achievementsJson = prefs['focusAchievements'];
      if (achievementsJson != null && achievementsJson is Map) {
        achievementsJson.forEach((key, value) {
          final achievement = FocusAchievement.fromJson(Map<String, dynamic>.from(value));
          _achievements[achievement.type] = achievement;
        });
      }

      // Load unlocked plants
      final unlockedPlantsJson = prefs['focusUnlockedPlants'];
      if (unlockedPlantsJson != null && unlockedPlantsJson is List) {
        _unlockedPlants = unlockedPlantsJson
            .map((i) => PlantType.values[i])
            .toSet();
      }
      
      // Load used sounds
      final usedSoundsJson = prefs['focusUsedSounds'];
      if (usedSoundsJson != null && usedSoundsJson is List) {
        _usedSounds = usedSoundsJson
            .map((i) => AmbientSoundType.values[i])
            .toSet();
      }

      notifyListeners();
    } catch (e) {
      debugPrint('Error loading focus data: $e');
    }
  }

  void _initAchievements() {
    for (final type in AchievementType.values) {
      if (!_achievements.containsKey(type)) {
        _achievements[type] = FocusAchievement(type: type);
      }
    }
  }

  Future<void> _saveData() async {
    try {
      await CleanStorageService.setAppPreference('focusSelectedMinutes', _selectedMinutes);
      await CleanStorageService.setAppPreference('focusMode', _mode.index);
      await CleanStorageService.setAppPreference('focusPomoWorkMinutes', _workMinutes);
      await CleanStorageService.setAppPreference('focusPomoShortBreakMinutes', _shortBreakMinutes);
      await CleanStorageService.setAppPreference('focusPomoLongBreakMinutes', _longBreakMinutes);
      await CleanStorageService.setAppPreference('focusPomoRoundsBeforeLong', _roundsBeforeLongBreak);
      await CleanStorageService.setAppPreference('focusPomoTotalRounds', _totalRounds);
      await CleanStorageService.setAppPreference('focusSelectedPlant', _selectedPlant.index);
      await CleanStorageService.setAppPreference('focusSelectedActivityType', _selectedActivity.index);
      await CleanStorageService.setAppPreference('focusSelectedSound', _selectedSound.index);
      await CleanStorageService.setAppPreference('focusSoundVolume', _soundVolume);
      await CleanStorageService.setAppPreference('focusSelectedTagIds', _selectedTagIds);
      await CleanStorageService.setAppPreference('focusStats', _stats.toJson());
      await CleanStorageService.setAppPreference('focusGarden', _garden.map((p) => p.toJson()).toList());
      await CleanStorageService.setAppPreference('focusSessions', _sessions.take(100).map((s) => s.toJson()).toList());
      await CleanStorageService.setAppPreference('focusAchievements', 
        _achievements.map((k, v) => MapEntry(k.index.toString(), v.toJson())));
      await CleanStorageService.setAppPreference('focusUnlockedPlants', _unlockedPlants.map((p) => p.index).toList());
      await CleanStorageService.setAppPreference('focusUsedSounds', _usedSounds.map((s) => s.index).toList());
    } catch (e) {
      debugPrint('Error saving focus data: $e');
    }
  }

  void setDuration(int minutes) {
    if (!_isRunning) {
      _selectedMinutes = minutes;
      _saveData();
      notifyListeners();
    }
  }

  // ---- Pomodoro configuration (FOCUS-2) ----

  void setMode(FocusMode mode) {
    if (!_isRunning && _mode != mode) {
      _mode = mode;
      _saveData();
      notifyListeners();
    }
  }

  /// Update pomodoro parameters. Only takes effect while idle. Values are clamped
  /// to sane ranges; nulls leave the existing value unchanged.
  void setPomodoroConfig({
    int? workMinutes,
    int? shortBreakMinutes,
    int? longBreakMinutes,
    int? roundsBeforeLongBreak,
    int? totalRounds,
  }) {
    if (_isRunning) return;
    if (workMinutes != null) _workMinutes = workMinutes.clamp(1, 180);
    if (shortBreakMinutes != null) _shortBreakMinutes = shortBreakMinutes.clamp(1, 60);
    if (longBreakMinutes != null) _longBreakMinutes = longBreakMinutes.clamp(1, 120);
    if (roundsBeforeLongBreak != null) _roundsBeforeLongBreak = roundsBeforeLongBreak.clamp(1, 12);
    if (totalRounds != null) _totalRounds = totalRounds.clamp(1, 16);
    _saveData();
    notifyListeners();
  }

  void setPlant(PlantType plant) {
    if (!_isRunning && _unlockedPlants.contains(plant)) {
      _selectedPlant = plant;
      _saveData();
      notifyListeners();
    }
  }

  void setActivity(FocusActivityType activity) {
    if (!_isRunning) {
      _selectedActivity = activity;
      _saveData();
      notifyListeners();
    }
  }

  void setSelectedTags(List<String> tagIds) {
    if (!_isRunning) {
      _selectedTagIds = List<String>.from(tagIds);
      _saveData();
      notifyListeners();
    }
  }

  void toggleTag(String tagId) {
    if (_isRunning) return;
    if (_selectedTagIds.contains(tagId)) {
      _selectedTagIds.remove(tagId);
    } else {
      _selectedTagIds.add(tagId);
    }
    _saveData();
    notifyListeners();
  }

  void setSound(AmbientSoundType sound) {
    _selectedSound = sound;
    if (sound != AmbientSoundType.none) {
      _usedSounds.add(sound);
      _checkSoundExplorerAchievement();
      // If session is running, change the sound immediately
      if (_isRunning) {
        _audioService.playSound(sound, volume: _soundVolume);
      }
    } else if (_isRunning) {
      _audioService.stop();
    }
    _saveData();
    notifyListeners();
  }

  void setSoundVolume(double volume) {
    _soundVolume = volume.clamp(0.0, 1.0);
    _audioService.setVolume(_soundVolume);
    _saveData();
    notifyListeners();
  }

  Future<void> startSession() async {
    if (_isRunning) return;

    _isRunning = true;
    _isPaused = false;
    _isOnBreak = false;
    _isLongBreak = false;
    _currentRound = 0;

    // In pomodoro mode the first interval is a WORK interval of _workMinutes;
    // _selectedMinutes is driven so the existing completion loop (coins/plant)
    // awards for the work length. Single mode uses the chosen duration as-is.
    if (_mode == FocusMode.pomodoro) {
      _selectedMinutes = _workMinutes;
    }
    _phaseMinutes = _selectedMinutes;

    _remainingSeconds = _phaseMinutes * 60;
    _startTime = DateTime.now();
    _endTime = _startTime!.add(Duration(minutes: _phaseMinutes));

    // Start ambient sound if selected
    if (_selectedSound != AmbientSoundType.none) {
      await _audioService.playSound(_selectedSound, volume: _soundVolume);
    }

    _startTimer();
    notifyListeners();
    debugPrint('✓ Focus session started (${_mode.name}): $_phaseMinutes minutes, ends at $_endTime');
  }

  /// Routes an elapsed interval to the correct completion handler. Break
  /// intervals never earn coins/plants; only work intervals do.
  Future<void> _onIntervalComplete() async {
    if (_mode == FocusMode.pomodoro && _isOnBreak) {
      await _completeBreak();
    } else {
      await _completeSession();
    }
  }

  /// Begins a break interval (pomodoro). No coins/plants are awarded here.
  void _startBreak() {
    _isOnBreak = true;
    _isPaused = false;
    // A long break lands after every _roundsBeforeLongBreak completed work rounds.
    _isLongBreak =
        _roundsBeforeLongBreak > 0 && _currentRound % _roundsBeforeLongBreak == 0;
    _phaseMinutes = _isLongBreak ? _longBreakMinutes : _shortBreakMinutes;
    _remainingSeconds = _phaseMinutes * 60;
    _startTime = DateTime.now();
    _endTime = _startTime!.add(Duration(minutes: _phaseMinutes));
    _startTimer();
    notifyListeners();
    debugPrint('✓ Pomodoro break started (${_isLongBreak ? 'long' : 'short'}): $_phaseMinutes min');
  }

  /// Break finished → back to a work interval (pomodoro).
  Future<void> _completeBreak() async {
    _timer?.cancel();
    await _audioService.stop();
    _isOnBreak = false;
    _isLongBreak = false;

    await NotificationService().showImmediateNotification(
      title: 'Break over ☕',
      body: 'Time to focus again — round ${_currentRound + 1} of $_totalRounds.',
    );

    _startWork();
  }

  /// Begins the next work interval (pomodoro).
  void _startWork() {
    _isOnBreak = false;
    _isPaused = false;
    _selectedMinutes = _workMinutes;
    _phaseMinutes = _workMinutes;
    _remainingSeconds = _phaseMinutes * 60;
    _startTime = DateTime.now();
    _endTime = _startTime!.add(Duration(minutes: _phaseMinutes));

    if (_selectedSound != AmbientSoundType.none) {
      _audioService.playSound(_selectedSound, volume: _soundVolume);
    }

    _startTimer();
    notifyListeners();
    debugPrint('✓ Pomodoro work started: round ${_currentRound + 1} of $_totalRounds');
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_isRunning && !_isPaused && _endTime != null) {
        final now = DateTime.now();
        applyTick(_endTime!.difference(now).inSeconds);
      }
    });
  }

  /// One second of countdown.
  ///
  /// Extracted from the `Timer.periodic` callback so a test can drive the real
  /// path without starting a session (which needs storage and audio). The
  /// important property — that a tick does NOT fire `notifyListeners()` — is
  /// only meaningful if it is asserted against this code rather than against
  /// the notifier in isolation.
  @visibleForTesting
  void applyTick(int remaining) {
    if (remaining <= 0) {
      _remainingSeconds = 0;
      _onIntervalComplete();
      return;
    }
    // Only update the UI if the second actually changed, to avoid jitter.
    if (_remainingSeconds != remaining) {
      _remainingSeconds = remaining;
      // Deliberately NOT notifyListeners(): see [tick]. This is the only
      // per-second signal, and it must not rebuild the whole screen.
      tick.value = remaining;
    }
  }

  void pauseSession() {
    if (_isRunning && !_isPaused) {
      _isPaused = true;
      _pauseStartTime = DateTime.now();
      _audioService.pause();
      _timer?.cancel(); // Save resources
      notifyListeners();
    }
  }

  void resumeSession() {
    if (_isRunning && _isPaused && _pauseStartTime != null && _endTime != null) {
      _isPaused = false;
      
      // Calculate how long we were paused
      final pauseDuration = DateTime.now().difference(_pauseStartTime!);
      
      // Push the end time forward by the pause duration
      _endTime = _endTime!.add(pauseDuration);
      _pauseStartTime = null;
      
      _audioService.resume();
      _startTimer(); // Check immediately
      notifyListeners();
    }
  }

  Future<void> abandonSession() async {
    if (!_isRunning) return;

    _timer?.cancel();
    await _audioService.stop();

    // Abandoning during a pomodoro break just ends the session — a break grows
    // no plant, so nothing withers and no abandoned session is recorded.
    if (_mode == FocusMode.pomodoro && _isOnBreak) {
      _resetSession();
      await _saveData();
      debugPrint('✓ Pomodoro ended during break');
      return;
    }

    final elapsedMinutes = _selectedMinutes - (_remainingSeconds ~/ 60);
    
    // Create dead plant
    final deadPlant = FocusPlant(
      id: _generateId(),
      type: _selectedPlant,
      plantedAt: _startTime!,
      durationMinutes: elapsedMinutes,
      isAlive: false,
      growthProgress: progress,
      activity: _selectedActivity.name,
    );
    _garden.add(deadPlant);
    
    // Create abandoned session
    final session = FocusSession(
      id: _generateId(),
      startedAt: _startTime!,
      completedAt: DateTime.now(),
      targetMinutes: _selectedMinutes,
      actualMinutes: elapsedMinutes,
      wasCompleted: false,
      wasAbandoned: true,
      activityType: _selectedActivity,
      plantType: _selectedPlant,
      soundUsed: _selectedSound,
      tagIds: List<String>.from(_selectedTagIds),
    );
    _sessions.insert(0, session);

    // Persist the session → tag mapping (also bumps tag usage counts)
    if (_selectedTagIds.isNotEmpty) {
      await TagService().tagSession(session.id, List<String>.from(_selectedTagIds));
    }

    // Update stats
    _stats = _stats.copyWith(
      totalSessions: _stats.totalSessions + 1,
      abandonedSessions: _stats.abandonedSessions + 1,
      totalPlants: _stats.totalPlants + 1,
      deadPlants: _stats.deadPlants + 1,
    );
    
    _resetSession();
    await _saveData();
    
    debugPrint('✓ Focus session abandoned');
  }

  Future<void> _completeSession() async {
    _timer?.cancel();
    await _audioService.stop();

    // Track whether this is the first completed session today (for streak bonus)
    final isFirstCompletedToday = !_sessions.any(
      (s) => s.wasCompleted && _isSameDay(s.startedAt, DateTime.now()),
    );

    // Create healthy plant
    final plant = FocusPlant(
      id: _generateId(),
      type: _selectedPlant,
      plantedAt: _startTime!,
      durationMinutes: _selectedMinutes,
      isAlive: true,
      growthProgress: 1.0,
      activity: _selectedActivity.name,
    );
    _garden.add(plant);
    
    // Create completed session
    final session = FocusSession(
      id: _generateId(),
      startedAt: _startTime!,
      completedAt: DateTime.now(),
      targetMinutes: _selectedMinutes,
      actualMinutes: _selectedMinutes,
      wasCompleted: true,
      wasAbandoned: false,
      activityType: _selectedActivity,
      plantType: _selectedPlant,
      soundUsed: _selectedSound,
      tagIds: List<String>.from(_selectedTagIds),
    );
    _sessions.insert(0, session);

    // Persist the session → tag mapping (also bumps tag usage counts)
    if (_selectedTagIds.isNotEmpty) {
      await TagService().tagSession(session.id, List<String>.from(_selectedTagIds));
    }

    // Update activity minutes
    final activityMinutes = Map<FocusActivityType, int>.from(_stats.minutesByActivity);
    activityMinutes[_selectedActivity] = (activityMinutes[_selectedActivity] ?? 0) + _selectedMinutes;
    
    // Update plant counts
    final plantCounts = Map<PlantType, int>.from(_stats.plantCounts);
    plantCounts[_selectedPlant] = (plantCounts[_selectedPlant] ?? 0) + 1;
    
    // Update stats
    _stats = _stats.copyWith(
      totalMinutes: _stats.totalMinutes + _selectedMinutes,
      totalSessions: _stats.totalSessions + 1,
      completedSessions: _stats.completedSessions + 1,
      totalPlants: _stats.totalPlants + 1,
      minutesByActivity: activityMinutes,
      plantCounts: plantCounts,
      lastSessionDate: DateTime.now(),
    );
    
    // Check for new plant unlocks
    await _checkPlantUnlocks();
    
    // Check achievements
    await _checkAchievements();
    
    // Update streak
    await _checkAndUpdateStreak();

    // Award focus coins for the completed session (Forest-style earn loop)
    final coinsService = CoinsService();
    await coinsService.earnCoins(
      minutes: _selectedMinutes,
      sessionId: session.id,
    );
    // Award a streak bonus once per day on the first completed session
    if (isFirstCompletedToday) {
      await coinsService.addStreakBonus(_stats.currentStreak);
    }

    // Show notification
    await NotificationService().showImmediateNotification(
      title: 'Focus Session Complete! 🌱',
      body: 'Amazing! You focused for $_selectedMinutes minutes and grew a ${_selectedPlant.name}!',
    );

    // Pomodoro: this was a WORK interval. Advance the round counter, then either
    // finish the whole session (total-rounds reached) or auto-start a break.
    if (_mode == FocusMode.pomodoro) {
      _currentRound++;
      await _saveData();
      if (_currentRound >= _totalRounds) {
        _resetSession();
      } else {
        _startBreak();
      }
      debugPrint('✓ Pomodoro work round $_currentRound/$_totalRounds completed');
      return;
    }

    _resetSession();
    await _saveData();

    debugPrint('✓ Focus session completed');
  }

  void _resetSession() {
    _isRunning = false;
    _isPaused = false;
    _remainingSeconds = 0;
    _startTime = null;
    _endTime = null;
    _pauseStartTime = null;
    _phaseMinutes = 0;
    _isOnBreak = false;
    _isLongBreak = false;
    _currentRound = 0;
    notifyListeners();
  }

  Future<void> _checkPlantUnlocks() async {
    for (final plant in PlantType.values) {
      if (!_unlockedPlants.contains(plant) && _stats.totalMinutes >= plant.unlockMinutes) {
        _unlockedPlants.add(plant);
        await NotificationService().showImmediateNotification(
          title: 'New Plant Unlocked! ${plant.emoji}',
          body: 'You\'ve unlocked the ${plant.name}! Keep focusing to grow your garden.',
        );
      }
    }
  }

  Future<void> _checkAchievements() async {
    // Time-based achievements
    _updateAchievement(AchievementType.firstSession, 1);
    _updateAchievement(AchievementType.tenMinutes, _stats.totalMinutes);
    _updateAchievement(AchievementType.thirtyMinutes, _stats.totalMinutes);
    _updateAchievement(AchievementType.oneHour, _stats.totalMinutes);
    _updateAchievement(AchievementType.threeHours, _stats.totalMinutes);
    _updateAchievement(AchievementType.fiveHours, _stats.totalMinutes);
    _updateAchievement(AchievementType.tenHours, _stats.totalMinutes);
    _updateAchievement(AchievementType.twentyFiveHours, _stats.totalMinutes);
    _updateAchievement(AchievementType.fiftyHours, _stats.totalMinutes);
    _updateAchievement(AchievementType.hundredHours, _stats.totalMinutes);
    
    // Plant achievements
    _updateAchievement(AchievementType.firstPlant, _stats.alivePlants);
    _updateAchievement(AchievementType.tenPlants, _stats.alivePlants);
    _updateAchievement(AchievementType.fiftyPlants, _stats.alivePlants);
    _updateAchievement(AchievementType.hundredPlants, _stats.alivePlants);
    
    // Plant collector
    _updateAchievement(AchievementType.allPlants, _unlockedPlants.length);
    
    // Time of day achievements
    final hour = DateTime.now().hour;
    if (hour < 7) {
      _updateAchievement(AchievementType.earlyBird, 1);
    }
    if (hour >= 22) {
      _updateAchievement(AchievementType.nightOwl, 1);
    }
    
    // Weekend warrior
    if (DateTime.now().weekday >= 6) {
      final weekendSessions = _sessions
          .where((s) => s.startedAt.weekday >= 6 && s.wasCompleted)
          .length;
      _updateAchievement(AchievementType.weekendWarrior, weekendSessions);
    }
  }

  void _updateAchievement(AchievementType type, int progress) {
    final current = _achievements[type];
    if (current != null && !current.isUnlocked) {
      if (progress >= type.requiredValue) {
        _achievements[type] = current.copyWith(
          currentProgress: progress,
          isUnlocked: true,
          unlockedAt: DateTime.now(),
        );
        _notifyAchievementUnlocked(type);
      } else {
        _achievements[type] = current.copyWith(currentProgress: progress);
      }
    }
  }

  Future<void> _notifyAchievementUnlocked(AchievementType type) async {
    await NotificationService().showImmediateNotification(
      title: 'Achievement Unlocked! ${type.emoji}',
      body: '${type.name}: ${type.description}',
    );
  }

  void _checkSoundExplorerAchievement() {
    _updateAchievement(AchievementType.soundExplorer, _usedSounds.length);
  }

  /// Days with at least one completed focus session — the input to the shared,
  /// forgiving [StreakEngine].
  Set<DateTime> _completedSessionDays() {
    final days = <DateTime>{};
    for (final s in _sessions) {
      if (!s.wasCompleted) continue;
      days.add(DateTime(s.startedAt.year, s.startedAt.month, s.startedAt.day));
    }
    return days;
  }

  /// Recompute the focus streak from session history via the shared
  /// [StreakEngine] — the same engine, and the same one-grace-day-per-rolling-
  /// week, that medicine, steps and water use. The old logic hard-reset the
  /// streak to 1 on any gap larger than a day and inferred it from
  /// `lastSessionDate` alone, so one missed day wiped a long run. Deriving it
  /// from the actual sessions also makes it idempotent — running this on every
  /// init and every completion can no longer double-count.
  Future<void> _checkAndUpdateStreak() async {
    final result = StreakEngine.compute(
      completedDays: _completedSessionDays(),
      today: DateTime.now(),
      graceDaysPerWeek: 1,
    );
    final newStreak = result.current;

    _stats = _stats.copyWith(
      currentStreak: newStreak,
      // Persisted history is trimmed to the last 100 sessions, so never let a
      // recompute shrink a longest streak the user already earned.
      longestStreak: max(_stats.longestStreak, max(result.longest, newStreak)),
    );

    if (newStreak > 0) {
      _updateAchievement(AchievementType.firstStreak, newStreak);
      _updateAchievement(AchievementType.weekStreak, newStreak);
      _updateAchievement(AchievementType.monthStreak, newStreak);
    }

    await _saveData();
  }

  void incrementBreathingCount() async {
    final prefs = CleanStorageService.getAppPreferences();
    int breathingCount = prefs['focusBreathingCount'] ?? 0;
    breathingCount++;
    await CleanStorageService.setAppPreference('focusBreathingCount', breathingCount);
    _updateAchievement(AchievementType.breathingMaster, breathingCount);
    await _saveData();
  }

  String _generateId() {
    return '${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(10000)}';
  }

  List<FocusPlant> getGardenForDate(DateTime date) {
    return _garden.where((p) => _isSameDay(p.plantedAt, date)).toList();
  }

  Map<DateTime, List<FocusPlant>> getGardenByWeek() {
    final Map<DateTime, List<FocusPlant>> grouped = {};
    for (final plant in _garden) {
      final weekStart = plant.plantedAt.subtract(Duration(days: plant.plantedAt.weekday - 1));
      final key = DateTime(weekStart.year, weekStart.month, weekStart.day);
      grouped.putIfAbsent(key, () => []);
      grouped[key]!.add(plant);
    }
    return grouped;
  }

  // ============ BACKUP HELPERS ============

  /// Export completed/abandoned focus sessions as JSON for the full app backup.
  /// (Other focus state — stats, garden, coins, achievements — already round-trips
  /// via the `preferences` section of the backup.)
  List<Map<String, dynamic>> exportSessionsJson() {
    return _sessions.map((s) => s.toJson()).toList();
  }

  /// Restore focus sessions from a backup. Non-destructive: sessions are merged
  /// by id (existing sessions are kept, new ones added) so restoring can't wipe
  /// the running session history. Malformed entries are skipped. After merging,
  /// the in-memory service and its persisted copy are refreshed so the UI updates.
  Future<void> importSessionsJson(List<dynamic> data) async {
    if (data.isEmpty) return;
    final existingIds = _sessions.map((s) => s.id).toSet();
    for (final raw in data) {
      try {
        final session = FocusSession.fromJson(Map<String, dynamic>.from(raw as Map));
        if (existingIds.add(session.id)) {
          _sessions.add(session);
        }
      } catch (e) {
        debugPrint('Import focus session failed: $e');
      }
    }
    // Keep newest-first ordering used throughout the service.
    _sessions.sort((a, b) => b.startedAt.compareTo(a.startedAt));
    await _saveData();
    notifyListeners();
  }

  /// Check if audio is currently playing
  bool get isAudioPlaying => _audioService.isPlaying;

  /// Toggle audio playback
  Future<void> toggleAudio() async {
    await _audioService.toggle();
    notifyListeners();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _audioService.stop();
    tick.dispose();
    super.dispose();
  }
}
