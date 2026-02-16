import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/services/audio_service.dart';
import '../models/focus_plant.dart';
import '../models/ambient_sound.dart';
import '../models/focus_session.dart';
import '../models/focus_achievement.dart';

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
  int _selectedMinutes = 25;
  DateTime? _startTime;
  DateTime? _endTime;
  DateTime? _pauseStartTime;
  Timer? _timer;
  
  // Current Session Config
  PlantType _selectedPlant = PlantType.seedling;
  FocusActivityType _selectedActivity = FocusActivityType.work;
  AmbientSoundType _selectedSound = AmbientSoundType.none;
  double _soundVolume = 0.5;
  
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
  FocusStats get stats => _stats;
  List<FocusPlant> get garden => List.unmodifiable(_garden);
  List<FocusSession> get sessions => List.unmodifiable(_sessions);
  Map<AchievementType, FocusAchievement> get achievements => Map.unmodifiable(_achievements);
  Set<PlantType> get unlockedPlants => Set.unmodifiable(_unlockedPlants);
  
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
        _completeSession();
      } else {
        _remainingSeconds = remaining;
        notifyListeners();
      }
    }
  }

  Future<void> _loadData() async {
    try {
      final prefs = StorageService.getAppPreferences();
      
      _selectedMinutes = prefs['focusSelectedMinutes'] ?? 25;
      _selectedPlant = PlantType.values[prefs['focusSelectedPlant'] ?? 0];
      _selectedActivity = FocusActivityType.values[prefs['focusSelectedActivityType'] ?? 0];
      _selectedSound = AmbientSoundType.values[prefs['focusSelectedSound'] ?? 0];
      _soundVolume = (prefs['focusSoundVolume'] ?? 0.5).toDouble();

      // Load stats
      final statsJson = prefs['focusStats'];
      if (statsJson != null && statsJson is Map) {
        _stats = FocusStats.fromJson(Map<String, dynamic>.from(statsJson));
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
      await StorageService.setAppPreference('focusSelectedMinutes', _selectedMinutes);
      await StorageService.setAppPreference('focusSelectedPlant', _selectedPlant.index);
      await StorageService.setAppPreference('focusSelectedActivityType', _selectedActivity.index);
      await StorageService.setAppPreference('focusSelectedSound', _selectedSound.index);
      await StorageService.setAppPreference('focusSoundVolume', _soundVolume);
      await StorageService.setAppPreference('focusStats', _stats.toJson());
      await StorageService.setAppPreference('focusGarden', _garden.map((p) => p.toJson()).toList());
      await StorageService.setAppPreference('focusSessions', _sessions.take(100).map((s) => s.toJson()).toList());
      await StorageService.setAppPreference('focusAchievements', 
        _achievements.map((k, v) => MapEntry(k.index.toString(), v.toJson())));
      await StorageService.setAppPreference('focusUnlockedPlants', _unlockedPlants.map((p) => p.index).toList());
      await StorageService.setAppPreference('focusUsedSounds', _usedSounds.map((s) => s.index).toList());
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
    _remainingSeconds = _selectedMinutes * 60;
    _startTime = DateTime.now();
    _endTime = _startTime!.add(Duration(minutes: _selectedMinutes));
    
    // Start ambient sound if selected
    if (_selectedSound != AmbientSoundType.none) {
      await _audioService.playSound(_selectedSound, volume: _soundVolume);
    }
    
    _startTimer();
    notifyListeners();
    debugPrint('✓ Focus session started: $_selectedMinutes minutes, ends at $_endTime');
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_isRunning && !_isPaused && _endTime != null) {
        final now = DateTime.now();
        final remaining = _endTime!.difference(now).inSeconds;
        
        if (remaining <= 0) {
          _remainingSeconds = 0;
          _completeSession();
        } else {
          // Only update UI if second actually changed to avoid jitter
          if (_remainingSeconds != remaining) {
            _remainingSeconds = remaining;
            notifyListeners();
          }
        }
      }
    });
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
    );
    _sessions.insert(0, session);
    
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
    );
    _sessions.insert(0, session);
    
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
    
    // Show notification
    await NotificationService().showImmediateNotification(
      title: 'Focus Session Complete! 🌱',
      body: 'Amazing! You focused for $_selectedMinutes minutes and grew a ${_selectedPlant.name}!',
    );
    
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

  Future<void> _checkAndUpdateStreak() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    if (_stats.lastSessionDate != null) {
      final lastDate = DateTime(
        _stats.lastSessionDate!.year,
        _stats.lastSessionDate!.month,
        _stats.lastSessionDate!.day,
      );
      
      final difference = today.difference(lastDate).inDays;
      
      if (difference == 0) {
        // Same day, no change
      } else if (difference == 1) {
        // Consecutive day
        final newStreak = _stats.currentStreak + 1;
        _stats = _stats.copyWith(
          currentStreak: newStreak,
          longestStreak: max(_stats.longestStreak, newStreak),
        );
        _updateAchievement(AchievementType.firstStreak, newStreak);
        _updateAchievement(AchievementType.weekStreak, newStreak);
        _updateAchievement(AchievementType.monthStreak, newStreak);
      } else {
        // Streak broken
        _stats = _stats.copyWith(currentStreak: 1);
      }
    } else {
      _stats = _stats.copyWith(currentStreak: 1);
    }
    
    await _saveData();
  }

  void incrementBreathingCount() async {
    final prefs = StorageService.getAppPreferences();
    int breathingCount = prefs['focusBreathingCount'] ?? 0;
    breathingCount++;
    await StorageService.setAppPreference('focusBreathingCount', breathingCount);
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
    super.dispose();
  }
}
