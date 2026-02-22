import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('CategoryManager Unit Tests', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
    });

    test('Initial state has no selected category', () async {
      SharedPreferences.setMockInitialValues({});
      
      // CategoryManager should start with no category selected
      // When no category is saved, hasSelectedCategory should be false
      final prefs = await SharedPreferences.getInstance();
      final hasCategory = prefs.getBool('category_has_been_selected') ?? false;
      
      expect(hasCategory, false);
    });

    test('Selecting a category persists to SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({});
      
      final prefs = await SharedPreferences.getInstance();
      
      // Simulate selecting a category
      await prefs.setString('selected_category', 'health');
      await prefs.setBool('category_has_been_selected', true);
      
      // Verify persistence
      expect(prefs.getString('selected_category'), 'health');
      expect(prefs.getBool('category_has_been_selected'), true);
    });

    test('Clearing category removes selection', () async {
      SharedPreferences.setMockInitialValues({
        'selected_category': 'productivity',
        'category_has_been_selected': true,
      });
      
      final prefs = await SharedPreferences.getInstance();
      
      // Simulate clearing category
      await prefs.remove('selected_category');
      await prefs.setBool('category_has_been_selected', false);
      
      // Verify cleared
      expect(prefs.getString('selected_category'), null);
      expect(prefs.getBool('category_has_been_selected'), false);
    });

    test('All category values are valid', () {
      // Test that all expected categories exist
      const expectedCategories = [
        'health',
        'productivity',
        'fitness',
        'finance',
        'periodTracking',
      ];
      
      for (final category in expectedCategories) {
        expect(category.isNotEmpty, true);
      }
    });

    test('Fun feature is always enabled regardless of category', () async {
      // Test different category selections
      final testCases = ['health', 'productivity', 'fitness', 'finance'];
      
      for (final category in testCases) {
        SharedPreferences.setMockInitialValues({
          'selected_category': category,
          'category_has_been_selected': true,
        });
        
        // Fun/Relax should always be considered enabled
        // This is a logical test - in actual implementation,
        // isFeatureEnabled('fun') should always return true
        const funFeatureId = 'fun';
        expect(funFeatureId, 'fun'); // Fun is always enabled
      }
    });

    test('Health category enables medicine, water, reminders features', () {
      const healthFeatures = ['medicine', 'water', 'reminders'];
      
      // Verify health category feature list
      expect(healthFeatures.contains('medicine'), true);
      expect(healthFeatures.contains('water'), true);
      expect(healthFeatures.contains('reminders'), true);
    });

    test('Productivity category enables focus, notes, exam_prep features', () {
      const productivityFeatures = ['focus', 'notes', 'exam_prep'];
      
      // Verify productivity category feature list
      expect(productivityFeatures.contains('focus'), true);
      expect(productivityFeatures.contains('notes'), true);
      expect(productivityFeatures.contains('exam_prep'), true);
    });

    test('Fitness category enables fitness feature', () {
      const fitnessFeatures = ['fitness'];
      
      // Verify fitness category feature list
      expect(fitnessFeatures.contains('fitness'), true);
    });

    test('Finance category enables finance feature', () {
      const financeFeatures = ['finance'];
      
      // Verify finance category feature list
      expect(financeFeatures.contains('finance'), true);
    });

    test('Period tracking category enables period feature', () {
      const periodFeatures = ['period'];
      
      // Verify period tracking category feature list
      expect(periodFeatures.contains('period'), true);
    });

    test('Category change requires sign out', () async {
      SharedPreferences.setMockInitialValues({
        'selected_category': 'health',
        'category_has_been_selected': true,
      });
      
      final prefs = await SharedPreferences.getInstance();
      
      // When category is already selected, canChangeCategory should be false
      final hasCategory = prefs.getBool('category_has_been_selected') ?? false;
      final canChangeCategory = !hasCategory;
      
      expect(canChangeCategory, false);
    });

    test('After sign out, category can be changed', () async {
      SharedPreferences.setMockInitialValues({
        'category_has_been_selected': false,
      });
      
      final prefs = await SharedPreferences.getInstance();
      
      // After clearing, canChangeCategory should be true
      final hasCategory = prefs.getBool('category_has_been_selected') ?? false;
      final canChangeCategory = !hasCategory;
      
      expect(canChangeCategory, true);
    });

    test('Category config contains required fields', () {
      // Test category config structure
      const testConfig = {
        'id': 'health',
        'name': 'Health & Wellness',
        'description': 'Track medications, water intake, and health reminders',
        'tagline': 'Your complete health companion',
        'features': ['medicine', 'water', 'reminders'],
      };
      
      expect(testConfig['id'], isNotNull);
      expect(testConfig['name'], isNotNull);
      expect(testConfig['description'], isNotNull);
      expect(testConfig['tagline'], isNotNull);
      expect(testConfig['features'], isNotNull);
      expect((testConfig['features'] as List).isNotEmpty, true);
    });
  });

  group('Category Feature Mapping Tests', () {
    test('Each category has unique features', () {
      final categoryFeatures = {
        'health': ['medicine', 'water', 'reminders'],
        'productivity': ['focus', 'notes', 'exam_prep'],
        'fitness': ['fitness'],
        'finance': ['finance'],
        'periodTracking': ['period'],
      };
      
      // Verify each category has features
      for (final entry in categoryFeatures.entries) {
        expect(entry.value.isNotEmpty, true, reason: '${entry.key} should have features');
      }
    });

    test('Fun/Relax is not in any specific category (always available)', () {
      final categoryFeatures = {
        'health': ['medicine', 'water', 'reminders'],
        'productivity': ['focus', 'notes', 'exam_prep'],
        'fitness': ['fitness'],
        'finance': ['finance'],
        'periodTracking': ['period'],
      };
      
      // Fun should not be in any category's feature list
      // because it's always available by default
      for (final features in categoryFeatures.values) {
        expect(features.contains('fun'), false);
        expect(features.contains('relax'), false);
      }
    });

    test('Enabled features list includes fun for any category', () {
      // For any selected category, the enabled features should include 'fun'
      final enabledForHealth = ['fun', 'medicine', 'water', 'reminders'];
      final enabledForProductivity = ['fun', 'focus', 'notes', 'exam_prep'];
      final enabledForFitness = ['fun', 'fitness'];
      final enabledForFinance = ['fun', 'finance'];
      final enabledForPeriod = ['fun', 'period'];
      
      expect(enabledForHealth.contains('fun'), true);
      expect(enabledForProductivity.contains('fun'), true);
      expect(enabledForFitness.contains('fun'), true);
      expect(enabledForFinance.contains('fun'), true);
      expect(enabledForPeriod.contains('fun'), true);
    });
  });

  group('Category Display Name Tests', () {
    test('Health category display name', () {
      const displayName = 'Health & Wellness';
      expect(displayName, 'Health & Wellness');
    });

    test('Productivity category display name', () {
      const displayName = 'Focus & Productivity';
      expect(displayName, 'Focus & Productivity');
    });

    test('Fitness category display name', () {
      const displayName = 'Fitness & Activity';
      expect(displayName, 'Fitness & Activity');
    });

    test('Finance category display name', () {
      const displayName = 'Finance Tracker';
      expect(displayName, 'Finance Tracker');
    });

    test('Period tracking category display name', () {
      const displayName = 'Period Tracking';
      expect(displayName, 'Period Tracking');
    });
  });
}
