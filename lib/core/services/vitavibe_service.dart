import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:vibration/vibration.dart';
import 'storage_service.dart';

enum VibeCategory {
  basic,
  rhythmic,
  nature,
  alert,
  relaxation,
  celebration,
}

enum VibeIntensity {
  ultraLight, // 0.2
  light,      // 0.5
  medium,     // 1.0 (Default)
  strong,     // 1.5
  ultraStrong // 2.0
}

enum VibePattern {
  // Basic
  tap,
  doubleTap,
  tripleTap,
  longPress,
  strongBuzz,
  
  // Rhythmic
  heartbeat,
  pulse,
  sos,
  drumroll,
  tickTock,
  
  // Nature
  raindrops,
  oceanWave,
  thunder,
  birdChirp,
  catPurr,
  
  // Alert
  alert,
  reminder,
  urgentAlert,
  medicineTime,
  waterReminder,
  
  // Relaxation
  breathingGuide,
  massage,
  meditationBell,
  sleepyWave,
  calmBreeze, // Replaces generic 'relax'
  
  // Celebration
  success,
  celebration,
  fanfare,
  fireworks,
  goalReached,
}

class VitaVibeService extends ChangeNotifier {
  static final VitaVibeService _instance = VitaVibeService._internal();
  factory VitaVibeService() => _instance;
  VitaVibeService._internal();

  bool _isEnabled = true;
  bool get isEnabled => _isEnabled;

  VibeIntensity _intensity = VibeIntensity.medium;
  VibeIntensity get intensity => _intensity;
  
  Map<String, VibePattern> _featureMap = {
    'medicine': VibePattern.medicineTime,
    'water': VibePattern.waterReminder,
    'focus': VibePattern.tickTock,
    'navigation': VibePattern.tap,
    'relax': VibePattern.calmBreeze,
    'celebrate': VibePattern.celebration,
  };

  Future<void> init() async {
    try {
       final settings = StorageService.getAppPreferences()['vitavibe_settings'];
       if (settings != null && settings is Map) {
         _isEnabled = settings['enabled'] ?? true;
         final intensityIndex = settings['intensity'] ?? 2;
         _intensity = VibeIntensity.values[intensityIndex.clamp(0, VibeIntensity.values.length - 1)];
         
         if (settings['patterns'] != null) {
           final savedPatterns = Map<String, dynamic>.from(settings['patterns']);
           savedPatterns.forEach((key, value) {
             try {
                final pattern = VibePattern.values.firstWhere((e) => e.toString() == value);
                _featureMap[key] = pattern;
             } catch (_) {}
           });
         }
       }
    } catch (e) {
      debugPrint('Error initializing VitaVibeService: $e');
    }
    notifyListeners();
  }
  
  Future<void> _saveSettings() async {
    final Map<String, String> patternsMap = {};
    _featureMap.forEach((key, value) {
      patternsMap[key] = value.toString();
    });
    
    final settings = {
      'enabled': _isEnabled,
      'intensity': _intensity.index,
      'patterns': patternsMap,
    };
    
    await StorageService.setAppPreference('vitavibe_settings', settings);
  }

  Future<void> toggleEnabled(bool value) async {
    _isEnabled = value;
    await _saveSettings();
    notifyListeners();
  }

  Future<void> setIntensity(VibeIntensity value) async {
    _intensity = value;
    await _saveSettings();
    notifyListeners();
    // Preview intensity
    await playPattern(VibePattern.tap); 
  }
  
  Future<void> setFeaturePattern(String featureKey, VibePattern pattern) async {
    _featureMap[featureKey] = pattern;
    await _saveSettings();
    notifyListeners();
  }
  
  VibePattern getPatternForFeature(String featureKey) {
    return _featureMap[featureKey] ?? VibePattern.tap;
  }

  double get _intensityMultiplier {
    switch (_intensity) {
      case VibeIntensity.ultraLight: return 0.2;
      case VibeIntensity.light: return 0.5;
      case VibeIntensity.medium: return 1.0;
      case VibeIntensity.strong: return 1.5;
      case VibeIntensity.ultraStrong: return 2.0;
    }
  }
  
  int _scale(int duration) => (duration * _intensityMultiplier).round().clamp(10, 5000);
  int _amp(int amplitude) => (amplitude * _intensityMultiplier).round().clamp(1, 255);

  Future<void> playPattern(VibePattern pattern) async {
    if (!_isEnabled) return;
    
    final hasVibrator = await Vibration.hasVibrator() ?? false;
    final hasAmplitude = await Vibration.hasAmplitudeControl() ?? false;

    if (!hasVibrator) return;
    
    // Fallback for no amplitude control or simpler patterns if needed
    // But we will try to use pattern/amplitude if available
    
    try {
      switch (pattern) {
        // --- Basic ---
        case VibePattern.tap:
          if (hasAmplitude) {
            Vibration.vibrate(duration: _scale(50), amplitude: _amp(128));
          } else {
            HapticFeedback.selectionClick();
          }
          break;
        case VibePattern.doubleTap:
          if (hasAmplitude) {
            Vibration.vibrate(pattern: [_scale(50), _scale(50), _scale(50), _scale(50)], intensities: [_amp(128), _amp(0), _amp(128), _amp(0)]);
          } else {
            await HapticFeedback.lightImpact();
            await Future.delayed(const Duration(milliseconds: 100));
            HapticFeedback.lightImpact();
          }
          break;
        case VibePattern.tripleTap:
          Vibration.vibrate(pattern: [0, _scale(40), _scale(40), _scale(40), _scale(40), _scale(40)]);
          break;
        case VibePattern.longPress:
           Vibration.vibrate(duration: _scale(500), amplitude: _amp(200));
          break;
        case VibePattern.strongBuzz:
           Vibration.vibrate(duration: _scale(1000), amplitude: _amp(255));
          break;

        // --- Rhythmic ---
        case VibePattern.heartbeat:
          // lub-dub... lub-dub...
           Vibration.vibrate(
            pattern: [0, _scale(100), _scale(100), _scale(100), _scale(600), _scale(100), _scale(100), _scale(100)],
            intensities: [0, _amp(150), 0, _amp(255), 0, _amp(150), 0, _amp(255)]
          );
          break;
        case VibePattern.pulse:
           Vibration.vibrate(pattern: [0, _scale(200), _scale(200), _scale(200), _scale(200)]);
          break;
        case VibePattern.sos:
           // ... --- ...
           final dot = _scale(100);
           final dash = _scale(300);
           final gap = _scale(100);
           Vibration.vibrate(pattern: [0, dot, gap, dot, gap, dot, gap, dash, gap, dash, gap, dash, gap, dot, gap, dot, gap, dot]);
          break;
        case VibePattern.drumroll:
           Vibration.vibrate(
             pattern: [0, 50, 50, 50, 50, 50, 50, 50, 100],
             intensities: [0, 50, 0, 100, 0, 150, 0, 200, 255].map((i) => _amp(i)).toList()
           );
          break;
        case VibePattern.tickTock:
           Vibration.vibrate(pattern: [0, 100, 900, 100], intensities: [0, _amp(100), 0, _amp(200)]);
          break;

        // --- Nature ---
        case VibePattern.raindrops:
           // Random-ish light taps
           Vibration.vibrate(pattern: [0, 30, 100, 30, 50, 40, 200, 30]);
          break;
        case VibePattern.oceanWave:
           // Swell
           if (hasAmplitude) {
             // Not perfect but simulates a rise
             Vibration.vibrate(
               pattern: [0, 200, 200, 200, 200, 200],
               intensities: [0, _amp(50), _amp(100), _amp(150), _amp(200), _amp(100)]
             );
           } else {
             Vibration.vibrate(duration: 1000);
           }
          break;
        case VibePattern.thunder:
           Vibration.vibrate(duration: _scale(800), amplitude: _amp(255));
          break;
        case VibePattern.birdChirp:
           Vibration.vibrate(pattern: [0, 50, 50, 50, 50, 80]);
          break;
        case VibePattern.catPurr:
           Vibration.vibrate(
             pattern: [0, 100, 50, 100, 50, 100, 50, 100], 
             intensities: [0, _amp(50), 0, _amp(50), 0, _amp(50), 0, _amp(50)]
           );
          break;

        // --- Alert ---
        case VibePattern.alert:
           Vibration.vibrate(pattern: [0, 500, 200, 500], intensities: [0, _amp(255), 0, _amp(255)]);
          break;
        case VibePattern.reminder:
           Vibration.vibrate(pattern: [0, 200, 200, 200]);
          break;
        case VibePattern.urgentAlert:
           Vibration.vibrate(pattern: [0, 100, 50, 100, 50, 100, 50, 500]);
          break;
        case VibePattern.medicineTime:
           // Specific distinct pattern
           Vibration.vibrate(pattern: [0, 300, 100, 300, 100, 300], intensities: [0, _amp(200), 0, _amp(200), 0, _amp(200)]);
          break;
        case VibePattern.waterReminder:
           // Fluid
           Vibration.vibrate(pattern: [0, 200, 100, 400], intensities: [0, _amp(150), 0, _amp(100)]);
          break;

        // --- Relaxation ---
        case VibePattern.breathingGuide:
           // Inhale (long rise), hold, Exhale (long fall) - approximated
           Vibration.vibrate(
             pattern: [0, 2000, 1000, 2000],
             intensities: [0, _amp(100), 0, _amp(80)]
           );
          break;
        case VibePattern.massage:
           Vibration.vibrate(duration: _scale(3000), amplitude: _amp(150));
          break;
        case VibePattern.meditationBell:
           Vibration.vibrate(duration: _scale(1500), amplitude: _amp(100));
          break;
        case VibePattern.sleepyWave:
           Vibration.vibrate(pattern: [0, 500, 500, 500], intensities: [0, _amp(50), 0, _amp(30)]);
          break;
        case VibePattern.calmBreeze:
           Vibration.vibrate(pattern: [0, 100, 100, 100], intensities: [0, _amp(40), 0, _amp(40)]);
          break;

        // --- Celebration ---
        case VibePattern.success:
           Vibration.vibrate(pattern: [0, 100, 50, 200], intensities: [0, _amp(150), 0, _amp(255)]);
          break;
        case VibePattern.celebration:
           Vibration.vibrate(pattern: [0, 100, 50, 100, 50, 100, 50, 300]);
          break;
        case VibePattern.fanfare:
           Vibration.vibrate(pattern: [0, 100, 50, 100, 50, 100, 200, 400]);
          break;
        case VibePattern.fireworks:
           Vibration.vibrate(
             pattern: [0, 100, 200, 100, 300, 100, 50, 100, 50],
             intensities: [0, _amp(255), 0, _amp(200), 0, _amp(150), 0, _amp(100), 0]
           );
          break;
         case VibePattern.goalReached:
           Vibration.vibrate(duration: _scale(1000));
          break;
      }
    } catch (e) {
      debugPrint('Error playing vibe pattern: $e');
    }
  }

  // Feature specific methods
  Future<void> waterAdd() => playPattern(_featureMap['water']!);
  Future<void> waterGoalReached() => playPattern(VibePattern.goalReached);
  Future<void> medicineTaken() => playPattern(_featureMap['medicine']!);
  Future<void> focusStart() => playPattern(_featureMap['focus']!);
  Future<void> navigation() => playPattern(_featureMap['navigation']!);
  Future<void> relax() => playPattern(_featureMap['relax']!);
  Future<void> celebrate() => playPattern(_featureMap['celebrate']!);
  Future<void> tap() => playPattern(VibePattern.tap);

  Future<void> stop() async {
    await Vibration.cancel();
  }
}
