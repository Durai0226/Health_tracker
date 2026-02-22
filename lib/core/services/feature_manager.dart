import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Defines the tier/category of a feature
enum FeatureTier {
  /// Core features that are always enabled and cannot be disabled
  core,
  /// Optional features that users can enable/disable
  optional,
  /// Advanced features (future)
  advanced,
}

/// Configuration for a single feature
class FeatureConfig {
  final String id;
  final String name;
  final IconData icon;
  final Color color;
  final String description;
  final FeatureTier tier;
  final bool isRequired;
  final String? serviceClass;

  const FeatureConfig({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
    required this.description,
    required this.tier,
    this.isRequired = false,
    this.serviceClass,
  });

  bool get canDisable => !isRequired && tier != FeatureTier.core;
}

/// Manages feature flags and lazy initialization of features
class FeatureManager extends ChangeNotifier {
  static final FeatureManager _instance = FeatureManager._internal();
  factory FeatureManager() => _instance;
  FeatureManager._internal();

  static const String _prefsKey = 'enabled_features';
  
  late SharedPreferences _prefs;
  bool _isInitialized = false;
  
  // Track which features have been initialized
  final Set<String> _initializedFeatures = {};
  
  // Currently enabled features
  Set<String> _enabledFeatures = {};

  /// All available features in the app
  static const List<FeatureConfig> allFeatures = [
    // === CORE FEATURES (Always enabled) ===
    FeatureConfig(
      id: 'medicine',
      name: 'Medicine Tracker',
      icon: Icons.medication_rounded,
      color: Color(0xFF6366F1),
      description: 'Track medications, dosages, schedules, and get timely reminders',
      tier: FeatureTier.core,
      isRequired: true,
    ),
    FeatureConfig(
      id: 'water',
      name: 'Water Tracker',
      icon: Icons.water_drop_rounded,
      color: Color(0xFF06B6D4),
      description: 'Monitor daily hydration and reach your water intake goals',
      tier: FeatureTier.core,
      isRequired: true,
    ),
    FeatureConfig(
      id: 'reminders',
      name: 'Reminders',
      icon: Icons.notifications_rounded,
      color: Color(0xFFF59E0B),
      description: 'Create custom reminders for any health or daily task',
      tier: FeatureTier.core,
      isRequired: true,
    ),
    
    // === OPTIONAL FEATURES (User-selectable) ===
    FeatureConfig(
      id: 'focus',
      name: 'Focus Mode',
      icon: Icons.self_improvement_rounded,
      color: Color(0xFF8B5CF6),
      description: 'Pomodoro-style focus sessions with plant growth gamification',
      tier: FeatureTier.optional,
    ),
    FeatureConfig(
      id: 'fitness',
      name: 'Fitness',
      icon: Icons.fitness_center_rounded,
      color: Color(0xFFEF4444),
      description: 'Track workouts, set fitness goals, and log activities',
      tier: FeatureTier.optional,
    ),
    FeatureConfig(
      id: 'notes',
      name: 'Notes',
      icon: Icons.note_alt_rounded,
      color: Color(0xFF10B981),
      description: 'Quick notes, checklists, and thoughts for your health journey',
      tier: FeatureTier.optional,
    ),
    FeatureConfig(
      id: 'period',
      name: 'Period Tracking',
      icon: Icons.calendar_month_rounded,
      color: Color(0xFFEC4899),
      description: 'Track menstrual cycles, symptoms, and predictions',
      tier: FeatureTier.optional,
    ),
    FeatureConfig(
      id: 'finance',
      name: 'Expense Tracker',
      icon: Icons.account_balance_wallet_rounded,
      color: Color(0xFF22C55E),
      description: 'Log daily expenses and track spending habits',
      tier: FeatureTier.optional,
    ),
    FeatureConfig(
      id: 'exam_prep',
      name: 'Exam Preparation',
      icon: Icons.school_rounded,
      color: Color(0xFF3B82F6),
      description: 'Plan exams, track study sessions, manage subjects & grades',
      tier: FeatureTier.optional,
    ),
  ];

  /// Get only core features
  static List<FeatureConfig> get coreFeatures =>
      allFeatures.where((f) => f.tier == FeatureTier.core).toList();

  /// Get only optional features
  static List<FeatureConfig> get optionalFeatures =>
      allFeatures.where((f) => f.tier == FeatureTier.optional).toList();

  /// Initialize the feature manager
  Future<void> init() async {
    if (_isInitialized) return;
    
    _prefs = await SharedPreferences.getInstance();
    _loadEnabledFeatures();
    _isInitialized = true;
    
    debugPrint('✓ FeatureManager initialized with ${_enabledFeatures.length} features');
  }

  void _loadEnabledFeatures() {
    final savedFeatures = _prefs.getStringList(_prefsKey);
    
    if (savedFeatures != null) {
      _enabledFeatures = savedFeatures.toSet();
      // For existing users, enable any new features that were added
      // This ensures users don't miss new features after app updates
      for (final feature in optionalFeatures) {
        if (!_enabledFeatures.contains(feature.id)) {
          _enabledFeatures.add(feature.id);
        }
      }
    } else {
      // Default: enable all core features + all optional features for best user experience
      _enabledFeatures = {
        ...coreFeatures.map((f) => f.id),
        ...optionalFeatures.map((f) => f.id), // Enable all features by default
      };
    }
    
    // Ensure core features are always enabled
    for (final feature in coreFeatures) {
      _enabledFeatures.add(feature.id);
    }
    
    // Save updated features
    _saveEnabledFeatures();
  }

  Future<void> _saveEnabledFeatures() async {
    await _prefs.setStringList(_prefsKey, _enabledFeatures.toList());
  }

  /// Check if a feature is enabled
  bool isEnabled(String featureId) {
    if (!_isInitialized) return true; // Default to true before init
    return _enabledFeatures.contains(featureId);
  }

  /// Get enabled feature configs
  List<FeatureConfig> get enabledFeatures =>
      allFeatures.where((f) => isEnabled(f.id)).toList();

  /// Get disabled optional features
  List<FeatureConfig> get disabledOptionalFeatures =>
      optionalFeatures.where((f) => !isEnabled(f.id)).toList();

  /// Toggle a feature on/off
  Future<bool> toggleFeature(String featureId, bool enabled) async {
    final config = allFeatures.firstWhere(
      (f) => f.id == featureId,
      orElse: () => throw ArgumentError('Unknown feature: $featureId'),
    );

    // Cannot disable required/core features
    if (!enabled && !config.canDisable) {
      debugPrint('Cannot disable required feature: ${config.name}');
      return false;
    }

    if (enabled) {
      _enabledFeatures.add(featureId);
    } else {
      _enabledFeatures.remove(featureId);
    }

    await _saveEnabledFeatures();
    notifyListeners();
    
    debugPrint('Feature "${config.name}" ${enabled ? "enabled" : "disabled"}');
    return true;
  }

  /// Enable multiple features at once (useful for onboarding)
  Future<void> setEnabledFeatures(Set<String> featureIds) async {
    // Always include core features
    _enabledFeatures = {
      ...coreFeatures.map((f) => f.id),
      ...featureIds.where((id) => optionalFeatures.any((f) => f.id == id)),
    };
    
    await _saveEnabledFeatures();
    notifyListeners();
  }

  /// Check if feature has been lazily initialized
  bool isFeatureInitialized(String featureId) =>
      _initializedFeatures.contains(featureId);

  /// Mark a feature as initialized
  void markFeatureInitialized(String featureId) {
    _initializedFeatures.add(featureId);
  }

  /// Get feature config by ID
  FeatureConfig? getFeatureConfig(String featureId) {
    try {
      return allFeatures.firstWhere((f) => f.id == featureId);
    } catch (_) {
      return null;
    }
  }

  /// Reset to default features
  Future<void> resetToDefaults() async {
    _enabledFeatures = {
      ...coreFeatures.map((f) => f.id),
      'focus',
    };
    await _saveEnabledFeatures();
    notifyListeners();
  }
}
