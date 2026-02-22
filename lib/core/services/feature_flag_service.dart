import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FeatureFlagService {
  static const String _prefix = 'feature_flag_';
  
  // Flag Keys
  static const String keyAdvancedRepeat = 'isAdvancedRepeatEnabled';
  static const String keyBetaFeatures = 'isBetaFeaturesEnabled';
  static const String keyPremiumThemes = 'isPremiumThemesEnabled';

  static final FeatureFlagService _instance = FeatureFlagService._internal();
  factory FeatureFlagService() => _instance;
  FeatureFlagService._internal();

  late SharedPreferences _prefs;
  final ValueNotifier<bool> _notifier = ValueNotifier(false);

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  bool isEnabled(String key, {bool defaultValue = false}) {
    return _prefs.getBool('$_prefix$key') ?? defaultValue;
  }

  Future<void> setEnabled(String key, bool value) async {
    await _prefs.setBool('$_prefix$key', value);
    _notifier.value = !_notifier.value;
  }

  ValueNotifier<bool> get notifier => _notifier;

  // Convenience getters
  bool get isAdvancedRepeatEnabled => isEnabled(keyAdvancedRepeat);
  bool get isBetaFeaturesEnabled => isEnabled(keyBetaFeatures);
}
