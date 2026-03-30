import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'dart:convert';

/// Haptic intensity levels
enum HapticIntensity {
  light,
  medium,
  heavy,
  custom,
}

/// Haptic feedback types for different interactions
enum HapticType {
  // General
  tap,
  buttonPress,
  toggle,
  selection,
  
  // Success/Error
  success,
  error,
  warning,
  
  // Navigation
  navigation,
  swipe,
  scroll,
  
  // Feature-specific
  waterAdd,
  waterGoalReached,
  medicineReminder,
  medicineTaken,
  medicineSkipped,
  focusStart,
  focusPause,
  focusComplete,
  focusBreathing,
  fitnessStart,
  fitnessComplete,
  timerTick,
  notification,
}

/// Feature categories for haptic customization
enum HapticFeature {
  water,
  medication,
  focus,
  fitness,
  navigation,
  notifications,
}

/// Haptic pattern for custom feedback sequences
class HapticPattern {
  final List<HapticStep> steps;
  final String name;
  final String description;

  const HapticPattern({
    required this.steps,
    required this.name,
    required this.description,
  });

  static const HapticPattern gentle = HapticPattern(
    name: 'Gentle',
    description: 'Soft, subtle feedback',
    steps: [HapticStep(type: HapticStepType.light, delay: 0)],
  );

  static const HapticPattern standard = HapticPattern(
    name: 'Standard',
    description: 'Normal feedback intensity',
    steps: [HapticStep(type: HapticStepType.medium, delay: 0)],
  );

  static const HapticPattern strong = HapticPattern(
    name: 'Strong',
    description: 'Powerful feedback',
    steps: [HapticStep(type: HapticStepType.heavy, delay: 0)],
  );

  static const HapticPattern double = HapticPattern(
    name: 'Double Tap',
    description: 'Two quick taps',
    steps: [
      HapticStep(type: HapticStepType.light, delay: 0),
      HapticStep(type: HapticStepType.light, delay: 100),
    ],
  );

  static const HapticPattern success = HapticPattern(
    name: 'Success',
    description: 'Celebratory pattern',
    steps: [
      HapticStep(type: HapticStepType.light, delay: 0),
      HapticStep(type: HapticStepType.medium, delay: 80),
      HapticStep(type: HapticStepType.heavy, delay: 80),
    ],
  );

  static const HapticPattern error = HapticPattern(
    name: 'Error',
    description: 'Alert pattern',
    steps: [
      HapticStep(type: HapticStepType.heavy, delay: 0),
      HapticStep(type: HapticStepType.heavy, delay: 150),
    ],
  );

  static const HapticPattern breathing = HapticPattern(
    name: 'Breathing',
    description: 'Calm, rhythmic pattern',
    steps: [
      HapticStep(type: HapticStepType.light, delay: 0),
      HapticStep(type: HapticStepType.selection, delay: 500),
    ],
  );

  static const HapticPattern celebration = HapticPattern(
    name: 'Celebration',
    description: 'Exciting achievement pattern',
    steps: [
      HapticStep(type: HapticStepType.light, delay: 0),
      HapticStep(type: HapticStepType.medium, delay: 60),
      HapticStep(type: HapticStepType.heavy, delay: 60),
      HapticStep(type: HapticStepType.medium, delay: 100),
      HapticStep(type: HapticStepType.light, delay: 60),
    ],
  );

  static const HapticPattern pulse = HapticPattern(
    name: 'Pulse',
    description: 'Rhythmic pulse pattern',
    steps: [
      HapticStep(type: HapticStepType.medium, delay: 0),
      HapticStep(type: HapticStepType.light, delay: 200),
      HapticStep(type: HapticStepType.medium, delay: 200),
    ],
  );

  static List<HapticPattern> get allPatterns => [
    gentle,
    standard,
    strong,
    double,
    success,
    error,
    breathing,
    celebration,
    pulse,
  ];
}

enum HapticStepType {
  light,
  medium,
  heavy,
  selection,
}

class HapticStep {
  final HapticStepType type;
  final int delay; // milliseconds before this step

  const HapticStep({
    required this.type,
    required this.delay,
  });
}

/// Advanced Haptic Feedback Service with customizable settings
class HapticService extends ChangeNotifier {
  static final HapticService _instance = HapticService._internal();
  factory HapticService() => _instance;
  HapticService._internal();

  static const String _prefsKey = 'haptic_settings';

  bool _isEnabled = true;
  HapticIntensity _globalIntensity = HapticIntensity.medium;
  
  // Per-feature settings
  final Map<HapticFeature, bool> _featureEnabled = {
    HapticFeature.water: true,
    HapticFeature.medication: true,
    HapticFeature.focus: true,
    HapticFeature.fitness: true,
    HapticFeature.navigation: true,
    HapticFeature.notifications: true,
  };

  final Map<HapticFeature, HapticIntensity> _featureIntensity = {
    HapticFeature.water: HapticIntensity.medium,
    HapticFeature.medication: HapticIntensity.medium,
    HapticFeature.focus: HapticIntensity.medium,
    HapticFeature.fitness: HapticIntensity.medium,
    HapticFeature.navigation: HapticIntensity.light,
    HapticFeature.notifications: HapticIntensity.heavy,
  };

  // Custom patterns for specific actions
  final Map<HapticType, HapticPattern> _customPatterns = {};

  // Getters
  bool get isEnabled => _isEnabled;
  HapticIntensity get globalIntensity => _globalIntensity;
  Map<HapticFeature, bool> get featureEnabled => Map.unmodifiable(_featureEnabled);
  Map<HapticFeature, HapticIntensity> get featureIntensity => Map.unmodifiable(_featureIntensity);

  /// Initialize the haptic service
  Future<void> init() async {
    try {
      await _loadSettings();
    } catch (e) {
      debugPrint('Error initializing HapticService: $e');
    }
  }

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final settingsJson = prefs.getString(_prefsKey);
      
      if (settingsJson != null) {
        final settings = jsonDecode(settingsJson) as Map<String, dynamic>;
        _isEnabled = settings['enabled'] ?? true;
        
        final intensityIndex = settings['globalIntensity'] ?? 1;
        _globalIntensity = HapticIntensity.values[intensityIndex];

        // Load per-feature settings
        final featuresSettings = settings['features'] as Map<String, dynamic>? ?? {};
        for (final feature in HapticFeature.values) {
          final key = feature.name;
          final featureData = featuresSettings[key] as Map<String, dynamic>? ?? {};
          _featureEnabled[feature] = featureData['enabled'] ?? true;
          final featureIntensityIndex = featureData['intensity'] ?? 1;
          _featureIntensity[feature] = HapticIntensity.values[featureIntensityIndex];
        }
      }

      notifyListeners();
    } catch (e) {
      debugPrint('Error loading haptic settings: $e');
    }
  }

  Future<void> _saveSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      final featuresSettings = <String, Map<String, dynamic>>{};
      for (final feature in HapticFeature.values) {
        featuresSettings[feature.name] = {
          'enabled': _featureEnabled[feature],
          'intensity': _featureIntensity[feature]!.index,
        };
      }
      
      final settings = {
        'enabled': _isEnabled,
        'globalIntensity': _globalIntensity.index,
        'features': featuresSettings,
      };
      
      await prefs.setString(_prefsKey, jsonEncode(settings));
    } catch (e) {
      debugPrint('Error saving haptic settings: $e');
    }
  }

  /// Toggle haptic feedback globally
  Future<void> setEnabled(bool enabled) async {
    _isEnabled = enabled;
    await _saveSettings();
    notifyListeners();
  }

  /// Set global haptic intensity
  Future<void> setGlobalIntensity(HapticIntensity intensity) async {
    _globalIntensity = intensity;
    // Update all feature intensities to match
    for (final feature in HapticFeature.values) {
      _featureIntensity[feature] = intensity;
    }
    await _saveSettings();
    notifyListeners();
  }

  /// Enable/disable haptic for a specific feature
  Future<void> setFeatureEnabled(HapticFeature feature, bool enabled) async {
    _featureEnabled[feature] = enabled;
    await _saveSettings();
    notifyListeners();
  }

  /// Set haptic intensity for a specific feature
  Future<void> setFeatureIntensity(HapticFeature feature, HapticIntensity intensity) async {
    _featureIntensity[feature] = intensity;
    await _saveSettings();
    notifyListeners();
  }

  /// Set custom pattern for a specific haptic type
  void setCustomPattern(HapticType type, HapticPattern pattern) {
    _customPatterns[type] = pattern;
  }

  /// Get the feature for a haptic type
  HapticFeature _getFeatureForType(HapticType type) {
    switch (type) {
      case HapticType.waterAdd:
      case HapticType.waterGoalReached:
        return HapticFeature.water;
      case HapticType.medicineReminder:
      case HapticType.medicineTaken:
      case HapticType.medicineSkipped:
        return HapticFeature.medication;
      case HapticType.focusStart:
      case HapticType.focusPause:
      case HapticType.focusComplete:
      case HapticType.focusBreathing:
        return HapticFeature.focus;
      case HapticType.fitnessStart:
      case HapticType.fitnessComplete:
        return HapticFeature.fitness;
      case HapticType.navigation:
      case HapticType.swipe:
      case HapticType.scroll:
        return HapticFeature.navigation;
      case HapticType.notification:
        return HapticFeature.notifications;
      default:
        return HapticFeature.navigation;
    }
  }

  /// Get the default pattern for a haptic type
  HapticPattern _getDefaultPattern(HapticType type) {
    switch (type) {
      case HapticType.tap:
      case HapticType.selection:
        return HapticPattern.gentle;
      case HapticType.buttonPress:
      case HapticType.toggle:
        return HapticPattern.standard;
      case HapticType.success:
      case HapticType.waterGoalReached:
      case HapticType.focusComplete:
      case HapticType.fitnessComplete:
        return HapticPattern.celebration;
      case HapticType.error:
        return HapticPattern.error;
      case HapticType.warning:
      case HapticType.medicineSkipped:
        return HapticPattern.double;
      case HapticType.waterAdd:
      case HapticType.medicineTaken:
        return HapticPattern.success;
      case HapticType.focusStart:
      case HapticType.fitnessStart:
        return HapticPattern.strong;
      case HapticType.focusPause:
        return HapticPattern.double;
      case HapticType.focusBreathing:
        return HapticPattern.breathing;
      case HapticType.medicineReminder:
      case HapticType.notification:
        return HapticPattern.pulse;
      case HapticType.navigation:
      case HapticType.swipe:
        return HapticPattern.gentle;
      case HapticType.scroll:
        return HapticPattern.gentle;
      case HapticType.timerTick:
        return HapticPattern.gentle;
    }
  }

  /// Execute a single haptic step
  Future<void> _executeStep(HapticStepType type, HapticIntensity intensity) async {
    // Adjust based on intensity
    HapticStepType adjustedType = type;
    if (intensity == HapticIntensity.light) {
      adjustedType = HapticStepType.light;
    } else if (intensity == HapticIntensity.heavy) {
      if (type == HapticStepType.light) adjustedType = HapticStepType.medium;
      if (type == HapticStepType.medium) adjustedType = HapticStepType.heavy;
    }

    switch (adjustedType) {
      case HapticStepType.light:
        await HapticFeedback.lightImpact();
        break;
      case HapticStepType.medium:
        await HapticFeedback.mediumImpact();
        break;
      case HapticStepType.heavy:
        await HapticFeedback.heavyImpact();
        break;
      case HapticStepType.selection:
        await HapticFeedback.selectionClick();
        break;
    }
  }

  /// Execute a haptic pattern
  Future<void> _executePattern(HapticPattern pattern, HapticIntensity intensity) async {
    for (int i = 0; i < pattern.steps.length; i++) {
      final step = pattern.steps[i];
      if (step.delay > 0) {
        await Future.delayed(Duration(milliseconds: step.delay));
      }
      await _executeStep(step.type, intensity);
    }
  }

  /// Trigger haptic feedback for a specific type
  Future<void> trigger(HapticType type) async {
    if (!_isEnabled) return;

    final feature = _getFeatureForType(type);
    if (!(_featureEnabled[feature] ?? true)) return;

    final intensity = _featureIntensity[feature] ?? _globalIntensity;
    final pattern = _customPatterns[type] ?? _getDefaultPattern(type);

    await _executePattern(pattern, intensity);
  }

  /// Quick haptic methods for common actions
  Future<void> tap() => trigger(HapticType.tap);
  Future<void> buttonPress() => trigger(HapticType.buttonPress);
  Future<void> toggle() => trigger(HapticType.toggle);
  Future<void> selection() => trigger(HapticType.selection);
  Future<void> success() => trigger(HapticType.success);
  Future<void> error() => trigger(HapticType.error);
  Future<void> warning() => trigger(HapticType.warning);
  Future<void> navigation() => trigger(HapticType.navigation);

  // Feature-specific methods
  Future<void> waterAdd() => trigger(HapticType.waterAdd);
  Future<void> waterGoalReached() => trigger(HapticType.waterGoalReached);
  Future<void> medicineTaken() => trigger(HapticType.medicineTaken);
  Future<void> medicineSkipped() => trigger(HapticType.medicineSkipped);
  Future<void> medicineReminder() => trigger(HapticType.medicineReminder);
  Future<void> focusStart() => trigger(HapticType.focusStart);
  Future<void> focusPause() => trigger(HapticType.focusPause);
  Future<void> focusComplete() => trigger(HapticType.focusComplete);
  Future<void> focusBreathing() => trigger(HapticType.focusBreathing);
  Future<void> fitnessStart() => trigger(HapticType.fitnessStart);
  Future<void> fitnessComplete() => trigger(HapticType.fitnessComplete);

  /// Simple haptic feedback based on intensity only
  Future<void> light() async {
    if (!_isEnabled) return;
    await HapticFeedback.lightImpact();
  }

  Future<void> medium() async {
    if (!_isEnabled) return;
    await HapticFeedback.mediumImpact();
  }

  Future<void> heavy() async {
    if (!_isEnabled) return;
    await HapticFeedback.heavyImpact();
  }

  Future<void> selectionClick() async {
    if (!_isEnabled) return;
    await HapticFeedback.selectionClick();
  }

  Future<void> vibrate() async {
    if (!_isEnabled) return;
    await HapticFeedback.vibrate();
  }

  /// Test haptic feedback with a specific intensity
  Future<void> testIntensity(HapticIntensity intensity) async {
    switch (intensity) {
      case HapticIntensity.light:
        await HapticFeedback.lightImpact();
        break;
      case HapticIntensity.medium:
        await HapticFeedback.mediumImpact();
        break;
      case HapticIntensity.heavy:
        await HapticFeedback.heavyImpact();
        break;
      case HapticIntensity.custom:
        await _executePattern(HapticPattern.celebration, HapticIntensity.medium);
        break;
    }
  }

  /// Test a specific pattern
  Future<void> testPattern(HapticPattern pattern) async {
    await _executePattern(pattern, _globalIntensity);
  }
}

/// Extension for easy haptic access
extension HapticContext on HapticService {
  static final HapticService instance = HapticService();
}
