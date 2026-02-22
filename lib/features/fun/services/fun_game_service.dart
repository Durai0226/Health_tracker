import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:vibration/vibration.dart';
import '../models/relaxation_game_models.dart';

/// Advanced Relaxation Game Service with Haptic Therapy Engine
class RelaxationGameService extends ChangeNotifier {
  static final RelaxationGameService _instance = RelaxationGameService._internal();
  factory RelaxationGameService() => _instance;
  RelaxationGameService._internal();

  static const String _boxName = 'relaxation_game_settings';
  Box? _box;
  bool _isInitialized = false;

  RelaxationGameSettings _settings = const RelaxationGameSettings();
  ExperienceMode _currentMode = ExperienceMode.zenFlow;
  HapticTherapyMode _currentTherapyMode = HapticTherapyMode.stressRelease;
  PlayMode _currentPlayMode = PlayMode.liquidTouch;
  OrbElement _currentElement = OrbElement.water;
  
  bool _isSessionActive = false;
  DateTime? _sessionStartTime;
  Timer? _sessionTimer;
  Timer? _hapticPatternTimer;
  int _sessionSeconds = 0;
  
  bool _hasVibrator = false;
  bool _hasAmplitudeControl = false;

  // Getters
  RelaxationGameSettings get settings => _settings;
  ExperienceMode get currentMode => _currentMode;
  HapticTherapyMode get currentTherapyMode => _currentTherapyMode;
  PlayMode get currentPlayMode => _currentPlayMode;
  OrbElement get currentElement => _currentElement;
  bool get isSessionActive => _isSessionActive;
  int get sessionSeconds => _sessionSeconds;
  bool get isInitialized => _isInitialized;
  
  String get formattedSessionTime {
    final mins = _sessionSeconds ~/ 60;
    final secs = _sessionSeconds % 60;
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  /// Initialize the service
  Future<void> init() async {
    if (_isInitialized) return;

    try {
      _hasVibrator = (await Vibration.hasVibrator()) == true;
      _hasAmplitudeControl = (await Vibration.hasAmplitudeControl()) == true;

      _box = await Hive.openBox(_boxName);
      _loadSettings();
      _checkUnlocks();
      _isInitialized = true;
      notifyListeners();
    } catch (e) {
      debugPrint('RelaxationGameService: Error initializing - $e');
      _isInitialized = true;
    }
  }

  void _loadSettings() {
    if (_box == null) return;
    
    final data = _box!.get('settings');
    if (data != null) {
      try {
        _settings = RelaxationGameSettings.fromJson(Map<String, dynamic>.from(data));
      } catch (e) {
        debugPrint('Error loading settings: $e');
      }
    }
  }

  Future<void> _saveSettings() async {
    if (_box == null) return;
    await _box!.put('settings', _settings.toJson());
  }

  /// Check and update unlocked modes based on usage
  void _checkUnlocks() {
    final newUnlocks = <ExperienceMode>{};
    
    for (final mode in ExperienceMode.values) {
      if (!mode.isProElite) {
        newUnlocks.add(mode);
      } else if (_settings.totalMinutesUsed >= mode.unlockMinutesRequired) {
        newUnlocks.add(mode);
      }
    }

    // Check for Pro Elite unlock conditions
    bool proElite = _settings.proEliteUnlocked;
    if (!proElite) {
      // Unlock after 300 minutes total
      if (_settings.totalMinutesUsed >= 300) proElite = true;
      // Unlock after 7-day streak
      if (_settings.currentStreak >= 7) proElite = true;
      // Unlock after mastering all basic modes
      if (_settings.masteredModes.length >= 3) proElite = true;
    }

    if (newUnlocks != _settings.unlockedModes || proElite != _settings.proEliteUnlocked) {
      _settings = _settings.copyWith(
        unlockedModes: newUnlocks,
        proEliteUnlocked: proElite,
      );
      _saveSettings();
    }
  }

  bool isModeUnlocked(ExperienceMode mode) {
    if (!mode.isProElite) return true;
    return _settings.unlockedModes.contains(mode) || _settings.proEliteUnlocked;
  }

  int getMinutesToUnlock(ExperienceMode mode) {
    if (isModeUnlocked(mode)) return 0;
    return mode.unlockMinutesRequired - _settings.totalMinutesUsed;
  }

  // ============ Settings Updates ============
  
  Future<void> setTheme(RelaxationTheme theme) async {
    _settings = _settings.copyWith(theme: theme);
    await _saveSettings();
    notifyListeners();
  }

  Future<void> setHapticIntensity(double intensity) async {
    _settings = _settings.copyWith(hapticIntensity: intensity.clamp(0.0, 1.0));
    await _saveSettings();
    notifyListeners();
    // Test feedback
    await triggerTapHaptic();
  }

  Future<void> setHapticSpeed(double speed) async {
    _settings = _settings.copyWith(hapticSpeed: speed.clamp(0.0, 1.0));
    await _saveSettings();
    notifyListeners();
  }

  Future<void> setHapticEnabled(bool enabled) async {
    _settings = _settings.copyWith(hapticEnabled: enabled);
    await _saveSettings();
    notifyListeners();
  }

  Future<void> setSoundVolume(double volume) async {
    _settings = _settings.copyWith(soundVolume: volume.clamp(0.0, 1.0));
    await _saveSettings();
    notifyListeners();
  }

  Future<void> setAmbientSound(AmbientSoundPreset sound) async {
    _settings = _settings.copyWith(ambientSound: sound);
    await _saveSettings();
    notifyListeners();
  }

  Future<void> setSoundHapticSync(bool sync) async {
    _settings = _settings.copyWith(soundHapticSync: sync);
    await _saveSettings();
    notifyListeners();
  }

  Future<void> setParticleDensity(double density) async {
    _settings = _settings.copyWith(particleDensity: density.clamp(0.0, 1.0));
    await _saveSettings();
    notifyListeners();
  }

  Future<void> setAnimationSpeed(double speed) async {
    _settings = _settings.copyWith(animationSpeed: speed.clamp(0.0, 1.0));
    await _saveSettings();
    notifyListeners();
  }

  Future<void> setGlowIntensity(double intensity) async {
    _settings = _settings.copyWith(glowIntensity: intensity.clamp(0.0, 1.0));
    await _saveSettings();
    notifyListeners();
  }

  Future<void> setBlurIntensity(double intensity) async {
    _settings = _settings.copyWith(blurIntensity: intensity.clamp(0.0, 1.0));
    await _saveSettings();
    notifyListeners();
  }

  Future<void> setMotionSensitivity(double sensitivity) async {
    _settings = _settings.copyWith(motionSensitivity: sensitivity.clamp(0.0, 1.0));
    await _saveSettings();
    notifyListeners();
  }

  // ============ Mode Selection ============

  void setExperienceMode(ExperienceMode mode) {
    if (isModeUnlocked(mode)) {
      _currentMode = mode;
      notifyListeners();
    }
  }

  void setTherapyMode(HapticTherapyMode mode) {
    _currentTherapyMode = mode;
    notifyListeners();
  }

  void setPlayMode(PlayMode mode) {
    _currentPlayMode = mode;
    notifyListeners();
  }

  void setElement(OrbElement element) {
    _currentElement = element;
    notifyListeners();
  }

  // ============ Session Management ============

  void startSession() {
    if (_isSessionActive) return;
    
    _isSessionActive = true;
    _sessionStartTime = DateTime.now();
    _sessionSeconds = 0;
    
    _sessionTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _sessionSeconds++;
      notifyListeners();
      
      // Update total minutes every minute
      if (_sessionSeconds % 60 == 0) {
        _settings = _settings.copyWith(
          totalMinutesUsed: _settings.totalMinutesUsed + 1,
        );
        _saveSettings();
        _checkUnlocks();
      }
    });

    notifyListeners();
  }

  void endSession() {
    _isSessionActive = false;
    _sessionTimer?.cancel();
    _sessionTimer = null;
    _hapticPatternTimer?.cancel();
    _hapticPatternTimer = null;
    Vibration.cancel();
    
    // Update streak if session was at least 5 minutes
    if (_sessionSeconds >= 300) {
      _settings = _settings.copyWith(
        currentStreak: _settings.currentStreak + 1,
      );
      _saveSettings();
      _checkUnlocks();
    }

    notifyListeners();
  }

  // ============ Advanced Haptic Therapy Engine ============

  /// Trigger tap feedback
  Future<void> triggerTapHaptic() async {
    if (!_settings.hapticEnabled || !_hasVibrator) return;
    
    final amplitude = (_settings.hapticIntensity * 255).round().clamp(1, 255);
    
    if (_hasAmplitudeControl) {
      await Vibration.vibrate(duration: 30, amplitude: amplitude);
    } else {
      await HapticFeedback.lightImpact();
    }
  }

  /// Trigger ripple feedback (expanding wave)
  Future<void> triggerRippleHaptic() async {
    if (!_settings.hapticEnabled || !_hasVibrator) return;
    
    final baseAmplitude = (_settings.hapticIntensity * 200).round().clamp(1, 255);
    
    // Ripple: start strong, fade out
    for (int i = 0; i < 4; i++) {
      final amplitude = (baseAmplitude * (1.0 - i * 0.25)).round().clamp(1, 255);
      final duration = 40 + i * 20;
      
      if (_hasAmplitudeControl) {
        await Vibration.vibrate(duration: duration, amplitude: amplitude);
      } else {
        await HapticFeedback.lightImpact();
      }
      await Future.delayed(Duration(milliseconds: 60 + i * 30));
    }
  }

  /// Trigger stress release pulse pattern
  Future<void> triggerStressReleasePulse() async {
    if (!_settings.hapticEnabled || !_hasVibrator) return;
    
    // Deep slow wave - breathing rhythm (4 seconds inhale, 4 seconds exhale simulation)
    final baseAmplitude = (_settings.hapticIntensity * 180).round();
    final speed = 1.0 + (1.0 - _settings.hapticSpeed) * 2.0; // Slower when speed is low
    
    // Inhale phase - gradual increase
    for (int i = 1; i <= 8; i++) {
      final amplitude = (baseAmplitude * i / 8).round().clamp(1, 255);
      if (_hasAmplitudeControl) {
        await Vibration.vibrate(duration: (200 * speed).round(), amplitude: amplitude);
      } else {
        await HapticFeedback.lightImpact();
      }
      await Future.delayed(Duration(milliseconds: (250 * speed).round()));
    }
    
    // Hold
    await Future.delayed(Duration(milliseconds: (500 * speed).round()));
    
    // Exhale phase - gradual decrease
    for (int i = 8; i >= 1; i--) {
      final amplitude = (baseAmplitude * i / 8).round().clamp(1, 255);
      if (_hasAmplitudeControl) {
        await Vibration.vibrate(duration: (200 * speed).round(), amplitude: amplitude);
      } else {
        await HapticFeedback.lightImpact();
      }
      await Future.delayed(Duration(milliseconds: (250 * speed).round()));
    }
  }

  /// Trigger anxiety calm pattern (5-4-3-2-1 grounding)
  Future<void> triggerAnxietyCalmPattern() async {
    if (!_settings.hapticEnabled || !_hasVibrator) return;
    
    final baseAmplitude = (_settings.hapticIntensity * 160).round();
    
    // 5-4-3-2-1 pattern
    for (int count = 5; count >= 1; count--) {
      for (int i = 0; i < count; i++) {
        final amplitude = (baseAmplitude * (0.5 + (6 - count) * 0.1)).round().clamp(1, 255);
        if (_hasAmplitudeControl) {
          await Vibration.vibrate(duration: 80, amplitude: amplitude);
        } else {
          await HapticFeedback.selectionClick();
        }
        await Future.delayed(const Duration(milliseconds: 200));
      }
      await Future.delayed(const Duration(milliseconds: 600));
    }
  }

  /// Trigger sleep induction pattern (fading waves)
  Future<void> triggerSleepInductionPattern() async {
    if (!_settings.hapticEnabled || !_hasVibrator) return;
    
    final baseAmplitude = (_settings.hapticIntensity * 120).round();
    
    // Fading wave pattern
    for (int wave = 0; wave < 5; wave++) {
      final waveFade = 1.0 - wave * 0.15; // Each wave gets softer
      
      // Rising
      for (int i = 1; i <= 4; i++) {
        final amplitude = (baseAmplitude * waveFade * i / 4).round().clamp(1, 255);
        if (_hasAmplitudeControl) {
          await Vibration.vibrate(duration: 300, amplitude: amplitude);
        } else {
          await HapticFeedback.lightImpact();
        }
        await Future.delayed(const Duration(milliseconds: 400));
      }
      
      // Falling
      for (int i = 4; i >= 1; i--) {
        final amplitude = (baseAmplitude * waveFade * i / 4).round().clamp(1, 255);
        if (_hasAmplitudeControl) {
          await Vibration.vibrate(duration: 300, amplitude: amplitude);
        } else {
          await HapticFeedback.lightImpact();
        }
        await Future.delayed(const Duration(milliseconds: 400));
      }
      
      await Future.delayed(const Duration(milliseconds: 800));
    }
  }

  /// Trigger heartbeat sync pattern
  Future<void> triggerHeartbeatSync() async {
    if (!_settings.hapticEnabled || !_hasVibrator) return;
    
    final amplitude = (_settings.hapticIntensity * 200).round().clamp(1, 255);
    
    // Lub-dub pattern
    if (_hasAmplitudeControl) {
      await Vibration.vibrate(duration: 100, amplitude: amplitude);
    } else {
      await HapticFeedback.heavyImpact();
    }
    await Future.delayed(const Duration(milliseconds: 120));
    
    if (_hasAmplitudeControl) {
      await Vibration.vibrate(duration: 80, amplitude: (amplitude * 0.7).round());
    } else {
      await HapticFeedback.mediumImpact();
    }
  }

  /// Trigger tension release sequence
  Future<void> triggerTensionRelease() async {
    if (!_settings.hapticEnabled || !_hasVibrator) return;
    
    final baseAmplitude = (_settings.hapticIntensity * 220).round();
    
    // Build tension
    for (int i = 1; i <= 5; i++) {
      final amplitude = (baseAmplitude * i / 5).round().clamp(1, 255);
      if (_hasAmplitudeControl) {
        await Vibration.vibrate(duration: 50 + i * 20, amplitude: amplitude);
      } else {
        await HapticFeedback.mediumImpact();
      }
      await Future.delayed(Duration(milliseconds: 100 - i * 10));
    }
    
    // Release
    await Future.delayed(const Duration(milliseconds: 200));
    if (_hasAmplitudeControl) {
      await Vibration.vibrate(duration: 400, amplitude: (baseAmplitude * 0.3).round().clamp(1, 255));
    } else {
      await HapticFeedback.lightImpact();
    }
  }

  /// Trigger bubble pop haptic
  Future<void> triggerBubblePopHaptic() async {
    if (!_settings.hapticEnabled || !_hasVibrator) return;
    
    final amplitude = (_settings.hapticIntensity * 180).round().clamp(1, 255);
    
    // Quick pop with slight reverb
    if (_hasAmplitudeControl) {
      await Vibration.vibrate(duration: 25, amplitude: amplitude);
    } else {
      await HapticFeedback.mediumImpact();
    }
    await Future.delayed(const Duration(milliseconds: 40));
    if (_hasAmplitudeControl) {
      await Vibration.vibrate(duration: 15, amplitude: (amplitude * 0.4).round().clamp(1, 255));
    }
  }

  /// Trigger sand/flow texture haptic
  Future<void> triggerSandTextureHaptic() async {
    if (!_settings.hapticEnabled || !_hasVibrator) return;
    
    final baseAmplitude = (_settings.hapticIntensity * 80).round();
    final random = Random();
    
    // Grainy texture - random micro pulses
    for (int i = 0; i < 6; i++) {
      final amplitude = (baseAmplitude * (0.5 + random.nextDouble() * 0.5)).round().clamp(1, 255);
      if (_hasAmplitudeControl) {
        await Vibration.vibrate(duration: 10 + random.nextInt(20), amplitude: amplitude);
      } else {
        await HapticFeedback.selectionClick();
      }
      await Future.delayed(Duration(milliseconds: 20 + random.nextInt(30)));
    }
  }

  /// Trigger stone grounding haptic
  Future<void> triggerStoneGroundingHaptic() async {
    if (!_settings.hapticEnabled || !_hasVibrator) return;
    
    final amplitude = (_settings.hapticIntensity * 255).round().clamp(1, 255);
    
    // Deep, solid thud
    if (_hasAmplitudeControl) {
      await Vibration.vibrate(duration: 150, amplitude: amplitude);
    } else {
      await HapticFeedback.heavyImpact();
    }
  }

  /// Trigger flowing water haptic
  Future<void> triggerWaterFlowHaptic() async {
    if (!_settings.hapticEnabled || !_hasVibrator) return;
    
    final baseAmplitude = (_settings.hapticIntensity * 100).round();
    
    // Smooth wave-like flow
    for (int i = 0; i < 5; i++) {
      final phase = sin(i * 0.5 * pi);
      final amplitude = (baseAmplitude * (0.3 + phase * 0.7)).round().clamp(1, 255);
      if (_hasAmplitudeControl) {
        await Vibration.vibrate(duration: 60, amplitude: amplitude);
      } else {
        await HapticFeedback.lightImpact();
      }
      await Future.delayed(const Duration(milliseconds: 80));
    }
  }

  /// Trigger silk smooth haptic
  Future<void> triggerSilkHaptic() async {
    if (!_settings.hapticEnabled || !_hasVibrator) return;
    
    final amplitude = (_settings.hapticIntensity * 60).round().clamp(1, 255);
    
    // Ultra-smooth, barely there
    if (_hasAmplitudeControl) {
      await Vibration.vibrate(duration: 200, amplitude: amplitude);
    } else {
      await HapticFeedback.selectionClick();
    }
  }

  /// Trigger fire/ember haptic
  Future<void> triggerEmberHaptic() async {
    if (!_settings.hapticEnabled || !_hasVibrator) return;
    
    final baseAmplitude = (_settings.hapticIntensity * 150).round();
    final random = Random();
    
    // Crackling, flickering pattern
    for (int i = 0; i < 4; i++) {
      final amplitude = (baseAmplitude * (0.6 + random.nextDouble() * 0.4)).round().clamp(1, 255);
      if (_hasAmplitudeControl) {
        await Vibration.vibrate(duration: 30 + random.nextInt(40), amplitude: amplitude);
      } else {
        await HapticFeedback.lightImpact();
      }
      await Future.delayed(Duration(milliseconds: 50 + random.nextInt(80)));
    }
  }

  /// Trigger crystal resonance haptic
  Future<void> triggerCrystalHaptic() async {
    if (!_settings.hapticEnabled || !_hasVibrator) return;
    
    final baseAmplitude = (_settings.hapticIntensity * 180).round();
    
    // Clear, ringing resonance
    if (_hasAmplitudeControl) {
      await Vibration.vibrate(duration: 50, amplitude: baseAmplitude.clamp(1, 255));
    } else {
      await HapticFeedback.mediumImpact();
    }
    
    // Decay
    for (int i = 4; i >= 1; i--) {
      await Future.delayed(const Duration(milliseconds: 80));
      final amplitude = (baseAmplitude * i / 5).round().clamp(1, 255);
      if (_hasAmplitudeControl) {
        await Vibration.vibrate(duration: 40, amplitude: amplitude);
      }
    }
  }

  /// Start continuous therapy haptic loop
  void startTherapyLoop(HapticTherapyMode mode) {
    _hapticPatternTimer?.cancel();
    
    int intervalMs;
    switch (mode) {
      case HapticTherapyMode.stressRelease:
        intervalMs = 8000; // 8 seconds per breath cycle
        break;
      case HapticTherapyMode.anxietyCalm:
        intervalMs = 15000; // Full 5-4-3-2-1 cycle
        break;
      case HapticTherapyMode.sleepInduction:
        intervalMs = 20000; // Longer fading waves
        break;
      case HapticTherapyMode.deepFocus:
        intervalMs = 4000; // Regular pulses
        break;
      case HapticTherapyMode.energyBoost:
        intervalMs = 2000; // Quick energizing pulses
        break;
    }

    _runTherapyPattern(mode);
    _hapticPatternTimer = Timer.periodic(Duration(milliseconds: intervalMs), (_) {
      _runTherapyPattern(mode);
    });
  }

  void _runTherapyPattern(HapticTherapyMode mode) {
    switch (mode) {
      case HapticTherapyMode.stressRelease:
        triggerStressReleasePulse();
        break;
      case HapticTherapyMode.anxietyCalm:
        triggerAnxietyCalmPattern();
        break;
      case HapticTherapyMode.sleepInduction:
        triggerSleepInductionPattern();
        break;
      case HapticTherapyMode.deepFocus:
        triggerHeartbeatSync();
        break;
      case HapticTherapyMode.energyBoost:
        triggerTensionRelease();
        break;
    }
  }

  void stopTherapyLoop() {
    _hapticPatternTimer?.cancel();
    _hapticPatternTimer = null;
    Vibration.cancel();
  }

  /// Trigger element-specific haptic
  Future<void> triggerElementHaptic(OrbElement element) async {
    switch (element) {
      case OrbElement.water:
        await triggerWaterFlowHaptic();
        break;
      case OrbElement.sand:
        await triggerSandTextureHaptic();
        break;
      case OrbElement.silk:
        await triggerSilkHaptic();
        break;
      case OrbElement.stone:
        await triggerStoneGroundingHaptic();
        break;
      case OrbElement.fire:
        await triggerEmberHaptic();
        break;
      case OrbElement.crystal:
        await triggerCrystalHaptic();
        break;
    }
  }

  /// Mark mode as mastered
  Future<void> markModeMastered(ExperienceMode mode) async {
    if (!_settings.masteredModes.contains(mode)) {
      final newMastered = Set<ExperienceMode>.from(_settings.masteredModes)..add(mode);
      _settings = _settings.copyWith(masteredModes: newMastered);
      await _saveSettings();
      _checkUnlocks();
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _sessionTimer?.cancel();
    _hapticPatternTimer?.cancel();
    Vibration.cancel();
    super.dispose();
  }
}
