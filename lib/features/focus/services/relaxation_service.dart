import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/services/audio_service.dart';
import '../models/relaxation_music.dart';

class RelaxationService extends ChangeNotifier {
  static final RelaxationService _instance = RelaxationService._internal();
  factory RelaxationService() => _instance;
  RelaxationService._internal();

  final AudioService _audioService = AudioService();

  // Session State
  bool _isRunning = false;
  bool _isPaused = false;
  int _remainingSeconds = 0;
  int _selectedMinutes = 15;
  DateTime? _startTime;
  Timer? _timer;
  
  // Current Session Config
  RelaxationMusicType? _selectedMusic;
  RelaxationCategory _selectedCategory = RelaxationCategory.deepFocus;
  double _volume = 0.7;
  
  // Stats & Data
  RelaxationStats _stats = const RelaxationStats();
  List<RelaxationSession> _sessions = [];

  // Getters
  bool get isRunning => _isRunning;
  bool get isPaused => _isPaused;
  int get remainingSeconds => _remainingSeconds;
  int get selectedMinutes => _selectedMinutes;
  RelaxationMusicType? get selectedMusic => _selectedMusic;
  RelaxationCategory get selectedCategory => _selectedCategory;
  double get volume => _volume;
  RelaxationStats get stats => _stats;
  List<RelaxationSession> get sessions => List.unmodifiable(_sessions);
  
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

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  Future<void> init() async {
    await _audioService.init();
    await _loadData();
    debugPrint('✓ RelaxationService initialized');
  }

  Future<void> _loadData() async {
    try {
      final prefs = StorageService.getAppPreferences();
      
      _selectedMinutes = prefs['relaxationSelectedMinutes'] ?? 15;
      _selectedCategory = RelaxationCategory.values[prefs['relaxationSelectedCategory'] ?? 0];
      _volume = (prefs['relaxationVolume'] ?? 0.7).toDouble();
      
      final musicIndex = prefs['relaxationSelectedMusic'];
      if (musicIndex != null) {
        _selectedMusic = RelaxationMusicType.values[musicIndex];
      }

      // Load stats
      final statsJson = prefs['relaxationStats'];
      if (statsJson != null && statsJson is Map) {
        _stats = RelaxationStats.fromJson(Map<String, dynamic>.from(statsJson));
      }

      // Load sessions
      final sessionsJson = prefs['relaxationSessions'];
      if (sessionsJson != null && sessionsJson is List) {
        _sessions = sessionsJson
            .map((s) => RelaxationSession.fromJson(Map<String, dynamic>.from(s)))
            .toList();
      }

      notifyListeners();
    } catch (e) {
      debugPrint('Error loading relaxation data: $e');
    }
  }

  Future<void> _saveData() async {
    try {
      await StorageService.setAppPreference('relaxationSelectedMinutes', _selectedMinutes);
      await StorageService.setAppPreference('relaxationSelectedCategory', _selectedCategory.index);
      await StorageService.setAppPreference('relaxationVolume', _volume);
      await StorageService.setAppPreference('relaxationSelectedMusic', _selectedMusic?.index);
      await StorageService.setAppPreference('relaxationStats', _stats.toJson());
      await StorageService.setAppPreference('relaxationSessions', _sessions.take(100).map((s) => s.toJson()).toList());
    } catch (e) {
      debugPrint('Error saving relaxation data: $e');
    }
  }

  void setDuration(int minutes) {
    if (!_isRunning) {
      _selectedMinutes = minutes;
      _saveData();
      notifyListeners();
    }
  }

  void setCategory(RelaxationCategory category) {
    if (!_isRunning) {
      _selectedCategory = category;
      // Reset music selection when category changes
      _selectedMusic = null;
      _saveData();
      notifyListeners();
    }
  }

  void setMusic(RelaxationMusicType music) {
    _selectedMusic = music;
    _selectedCategory = music.category;
    _saveData();
    notifyListeners();
  }

  void setVolume(double vol) {
    _volume = vol.clamp(0.0, 1.0);
    _audioService.setVolume(_volume);
    _saveData();
    notifyListeners();
  }

  Future<void> startSession() async {
    if (_isRunning || _selectedMusic == null) return;
    
    _isRunning = true;
    _isPaused = false;
    _remainingSeconds = _selectedMinutes * 60;
    _startTime = DateTime.now();
    
    // Provide haptic feedback for session start
    HapticFeedback.heavyImpact();
    
    // Start timer and update UI IMMEDIATELY for smooth experience
    _startTimer();
    notifyListeners();
    
    debugPrint('✓ Relaxation session started: $_selectedMinutes minutes with ${_selectedMusic?.name}');
    
    // Load and play audio in background (non-blocking)
    _playRelaxationMusic();
  }

  Future<void> _playRelaxationMusic() async {
    if (_selectedMusic == null) return;
    
    try {
      // Use the enum's string representation as the key for audio lookup
      final musicKey = _selectedMusic.toString().split('.').last;
      debugPrint('Playing relaxation music with key: $musicKey');
      await _audioService.playRelaxationMusic(musicKey, volume: _volume);
    } catch (e) {
      debugPrint('Error playing relaxation music: $e');
    }
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

  void pauseSession() {
    if (_isRunning && !_isPaused) {
      _isPaused = true;
      _audioService.pause();
      HapticFeedback.lightImpact();
      notifyListeners();
    }
  }

  void resumeSession() {
    if (_isRunning && _isPaused) {
      _isPaused = false;
      _audioService.resume();
      HapticFeedback.lightImpact();
      notifyListeners();
    }
  }

  Future<void> abandonSession() async {
    if (!_isRunning) return;
    
    _timer?.cancel();
    await _audioService.stop();
    HapticFeedback.heavyImpact();
    
    final elapsedMinutes = _selectedMinutes - (_remainingSeconds ~/ 60);
    
    // Create abandoned session
    final session = RelaxationSession(
      id: _generateId(),
      startedAt: _startTime!,
      completedAt: DateTime.now(),
      targetMinutes: _selectedMinutes,
      actualMinutes: elapsedMinutes,
      wasCompleted: false,
      wasAbandoned: true,
      musicType: _selectedMusic!,
      category: _selectedCategory,
    );
    _sessions.insert(0, session);
    
    // Update stats
    _stats = _stats.copyWith(
      totalSessions: _stats.totalSessions + 1,
      abandonedSessions: _stats.abandonedSessions + 1,
    );
    
    _resetSession();
    await _saveData();
    
    debugPrint('✓ Relaxation session abandoned');
  }

  Future<void> _completeSession() async {
    _timer?.cancel();
    await _audioService.stop();
    HapticFeedback.heavyImpact();
    
    // Create completed session
    final session = RelaxationSession(
      id: _generateId(),
      startedAt: _startTime!,
      completedAt: DateTime.now(),
      targetMinutes: _selectedMinutes,
      actualMinutes: _selectedMinutes,
      wasCompleted: true,
      wasAbandoned: false,
      musicType: _selectedMusic!,
      category: _selectedCategory,
    );
    _sessions.insert(0, session);
    
    // Update category minutes
    final categoryMinutes = Map<RelaxationCategory, int>.from(_stats.minutesByCategory);
    categoryMinutes[_selectedCategory] = (categoryMinutes[_selectedCategory] ?? 0) + _selectedMinutes;
    
    // Update track usage
    final trackUsage = Map<RelaxationMusicType, int>.from(_stats.usageByTrack);
    trackUsage[_selectedMusic!] = (trackUsage[_selectedMusic!] ?? 0) + 1;
    
    // Update stats
    _stats = _stats.copyWith(
      totalMinutes: _stats.totalMinutes + _selectedMinutes,
      totalSessions: _stats.totalSessions + 1,
      completedSessions: _stats.completedSessions + 1,
      minutesByCategory: categoryMinutes,
      usageByTrack: trackUsage,
    );
    
    // Show notification
    await NotificationService().showImmediateNotification(
      title: 'Relaxation Complete! ${_selectedCategory.emoji}',
      body: 'You completed $_selectedMinutes minutes of ${_selectedCategory.name}. Feel refreshed!',
    );
    
    _resetSession();
    await _saveData();
    
    debugPrint('✓ Relaxation session completed');
  }

  void _resetSession() {
    _isRunning = false;
    _isPaused = false;
    _remainingSeconds = 0;
    _startTime = null;
    notifyListeners();
  }

  String _generateId() {
    return '${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(10000)}';
  }

  bool get isAudioPlaying => _audioService.isPlaying;

  Future<void> toggleAudio() async {
    await _audioService.toggle();
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _audioService.stop();
    super.dispose();
  }
}
