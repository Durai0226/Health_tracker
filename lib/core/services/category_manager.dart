import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Represents a category that users can select
/// Each user can only select ONE category at a time (plus Fun/Relax which is always available)
enum AppCategory {
  /// Health & Wellness - Core features: Medicine, Water, Reminders
  health,
  /// Focus & Productivity - Focus sessions, Notes, Exam Prep
  productivity,
  /// Fitness & Activity - Workout tracking, fitness goals
  fitness,
  /// Finance - Expense tracking, budgeting
  finance,
  /// Period Tracking - Menstrual cycle tracking
  periodTracking,
}

/// Configuration for each category
class CategoryConfig {
  final AppCategory category;
  final String id;
  final String name;
  final String description;
  final IconData icon;
  final Color color;
  final List<String> features;
  final String tagline;

  const CategoryConfig({
    required this.category,
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.color,
    required this.features,
    required this.tagline,
  });
}

/// Manages single category selection per user
/// Fun/Relax is always available as default
class CategoryManager extends ChangeNotifier {
  static final CategoryManager _instance = CategoryManager._internal();
  factory CategoryManager() => _instance;
  CategoryManager._internal();

  static const String _selectedCategoryKey = 'selected_category';
  static const String _categorySelectedKey = 'category_has_been_selected';
  
  late SharedPreferences _prefs;
  bool _isInitialized = false;
  AppCategory? _selectedCategory;
  bool _hasSelectedCategory = false;

  /// All available categories with their configurations
  static const List<CategoryConfig> allCategories = [
    CategoryConfig(
      category: AppCategory.health,
      id: 'health',
      name: 'Health & Wellness',
      description: 'Track medications, water intake, and health reminders',
      icon: Icons.favorite_rounded,
      color: Color(0xFF00897B),
      features: ['medicine', 'water', 'reminders'],
      tagline: 'Your complete health companion',
    ),
    CategoryConfig(
      category: AppCategory.productivity,
      id: 'productivity',
      name: 'Focus & Productivity',
      description: 'Pomodoro focus sessions, notes, and exam preparation',
      icon: Icons.psychology_rounded,
      color: Color(0xFF8B5CF6),
      features: ['focus', 'notes', 'exam_prep'],
      tagline: 'Maximize your potential',
    ),
    CategoryConfig(
      category: AppCategory.fitness,
      id: 'fitness',
      name: 'Fitness & Activity',
      description: 'Track workouts, set fitness goals, and log activities',
      icon: Icons.fitness_center_rounded,
      color: Color(0xFFEF4444),
      features: ['fitness'],
      tagline: 'Transform your body',
    ),
    CategoryConfig(
      category: AppCategory.finance,
      id: 'finance',
      name: 'Finance Tracker',
      description: 'Log daily expenses and track spending habits',
      icon: Icons.account_balance_wallet_rounded,
      color: Color(0xFF22C55E),
      features: ['finance'],
      tagline: 'Master your money',
    ),
    CategoryConfig(
      category: AppCategory.periodTracking,
      id: 'period_tracking',
      name: 'Period Tracking',
      description: 'Track menstrual cycles, symptoms, and predictions',
      icon: Icons.calendar_month_rounded,
      color: Color(0xFFEC4899),
      features: ['period'],
      tagline: 'Understand your cycle',
    ),
  ];

  /// Initialize the category manager
  Future<void> init() async {
    if (_isInitialized) return;
    
    _prefs = await SharedPreferences.getInstance();
    _loadSelectedCategory();
    _isInitialized = true;
    
    debugPrint('✓ CategoryManager initialized: ${_selectedCategory?.name ?? "None selected"}');
  }

  void _loadSelectedCategory() {
    _hasSelectedCategory = _prefs.getBool(_categorySelectedKey) ?? false;
    final savedCategory = _prefs.getString(_selectedCategoryKey);
    
    if (savedCategory != null) {
      try {
        _selectedCategory = AppCategory.values.firstWhere(
          (c) => c.name == savedCategory,
        );
      } catch (_) {
        _selectedCategory = null;
      }
    }
  }

  /// Check if user has already selected a category
  bool get hasSelectedCategory => _hasSelectedCategory;

  /// Get the currently selected category
  AppCategory? get selectedCategory => _selectedCategory;

  /// Get the config for the selected category
  CategoryConfig? get selectedCategoryConfig {
    if (_selectedCategory == null) return null;
    return allCategories.firstWhere(
      (c) => c.category == _selectedCategory,
    );
  }

  /// Get config by category
  CategoryConfig getCategoryConfig(AppCategory category) {
    return allCategories.firstWhere((c) => c.category == category);
  }

  /// Select a category (only one at a time)
  /// This should only be called during onboarding or after sign out
  Future<void> selectCategory(AppCategory category) async {
    _selectedCategory = category;
    _hasSelectedCategory = true;
    
    await _prefs.setString(_selectedCategoryKey, category.name);
    await _prefs.setBool(_categorySelectedKey, true);
    
    notifyListeners();
    debugPrint('✓ Category selected: ${category.name}');
  }

  /// Clear the selected category (called on sign out)
  Future<void> clearCategory() async {
    _selectedCategory = null;
    _hasSelectedCategory = false;
    
    await _prefs.remove(_selectedCategoryKey);
    await _prefs.setBool(_categorySelectedKey, false);
    
    notifyListeners();
    debugPrint('✓ Category cleared');
  }

  /// Check if a specific feature is enabled based on selected category
  /// Fun/Relax features are always enabled
  bool isFeatureEnabled(String featureId) {
    // Fun/Relax is always enabled
    if (featureId == 'fun' || featureId == 'relax') {
      return true;
    }
    
    // Core features for basic functionality
    const coreFeatures = ['medicine', 'water', 'reminders'];
    
    if (_selectedCategory == null) {
      // If no category selected, only core features are enabled
      return coreFeatures.contains(featureId);
    }

    final config = selectedCategoryConfig;
    if (config == null) return false;

    return config.features.contains(featureId);
  }

  /// Get list of enabled feature IDs for current category
  List<String> get enabledFeatureIds {
    final features = <String>['fun']; // Fun/Relax always enabled
    
    if (_selectedCategory != null) {
      final config = selectedCategoryConfig;
      if (config != null) {
        features.addAll(config.features);
      }
    }
    
    return features;
  }

  /// Check if category change is allowed (requires sign out)
  bool get canChangeCategory => !_hasSelectedCategory;

  /// Get display name for selected category
  String get selectedCategoryDisplayName {
    return selectedCategoryConfig?.name ?? 'None Selected';
  }
}
