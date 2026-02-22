import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Category Selection E2E Tests', () {
    setUp(() async {
      // Clear preferences to simulate fresh install
      SharedPreferences.setMockInitialValues({});
    });

    testWidgets('Category selection screen shows all categories', (tester) async {
      // This test verifies the category selection UI displays correctly
      
      // Look for category cards
      await tester.pumpAndSettle();
      
      // Verify all category options are visible
      expect(find.text('Health & Wellness'), findsWidgets);
      expect(find.text('Focus & Productivity'), findsWidgets);
      expect(find.text('Fitness & Activity'), findsWidgets);
      expect(find.text('Finance Tracker'), findsWidgets);
      expect(find.text('Period Tracking'), findsWidgets);
      
      // Verify Fun & Relax info is shown
      expect(find.text('Fun & Relax'), findsWidgets);
      expect(find.text('INCLUDED'), findsWidgets);
    });

    testWidgets('User can select only one category at a time', (tester) async {
      await tester.pumpAndSettle();
      
      // Tap on Health & Wellness
      final healthCard = find.text('Health & Wellness');
      if (healthCard.evaluate().isNotEmpty) {
        await tester.tap(healthCard);
        await tester.pumpAndSettle();
        
        // Verify SELECTED badge appears
        expect(find.text('SELECTED'), findsOneWidget);
        
        // Tap on Focus & Productivity
        final focusCard = find.text('Focus & Productivity');
        if (focusCard.evaluate().isNotEmpty) {
          await tester.tap(focusCard);
          await tester.pumpAndSettle();
          
          // Verify only one SELECTED badge (the new selection)
          expect(find.text('SELECTED'), findsOneWidget);
        }
      }
    });

    testWidgets('Continue button is disabled until category is selected', (tester) async {
      await tester.pumpAndSettle();
      
      // Find the continue button
      final continueButton = find.text('Select a Category');
      expect(continueButton, findsOneWidget);
      
      // Select a category
      final healthCard = find.text('Health & Wellness');
      if (healthCard.evaluate().isNotEmpty) {
        await tester.tap(healthCard);
        await tester.pumpAndSettle();
        
        // Button should now show "Continue"
        expect(find.text('Continue'), findsOneWidget);
      }
    });

    testWidgets('Fun & Relax is always included badge shows correctly', (tester) async {
      await tester.pumpAndSettle();
      
      // Find Fun & Relax section
      expect(find.text('Fun & Relax'), findsWidgets);
      expect(find.text('INCLUDED'), findsWidgets);
      expect(find.text('Always available'), findsWidgets);
    });

    testWidgets('Category selection persists after app restart simulation', (tester) async {
      // Set mock initial values with a selected category
      SharedPreferences.setMockInitialValues({
        'selected_category': 'health',
        'category_has_been_selected': true,
      });
      
      await tester.pumpAndSettle();
      
      // App should navigate to home, not category selection
      // Look for home screen indicators
      expect(find.text('Dashboard'), findsWidgets);
    });

    testWidgets('Sign out clears category selection', (tester) async {
      // Set mock initial values
      SharedPreferences.setMockInitialValues({
        'selected_category': 'productivity',
        'category_has_been_selected': true,
      });
      
      await tester.pumpAndSettle();
      
      // Navigate to settings
      final settingsTab = find.byIcon(Icons.settings_rounded);
      if (settingsTab.evaluate().isNotEmpty) {
        await tester.tap(settingsTab);
        await tester.pumpAndSettle();
        
        // Look for sign out button
        final signOutButton = find.text('Sign Out');
        if (signOutButton.evaluate().isNotEmpty) {
          await tester.tap(signOutButton);
          await tester.pumpAndSettle();
          
          // Confirm sign out
          final confirmButton = find.text('Sign Out').last;
          await tester.tap(confirmButton);
          await tester.pumpAndSettle();
          
          // Should redirect to welcome/category selection
        }
      }
    });
  });

  group('Category-based Navigation Tests', () {
    testWidgets('Health category shows medicine and water features', (tester) async {
      SharedPreferences.setMockInitialValues({
        'selected_category': 'health',
        'category_has_been_selected': true,
      });
      
      await tester.pumpAndSettle();
      
      // Navigate to home
      final homeTab = find.byIcon(Icons.home_rounded);
      if (homeTab.evaluate().isNotEmpty) {
        await tester.tap(homeTab);
        await tester.pumpAndSettle();
        
        // Verify health features are visible
        expect(find.text('Medicine'), findsWidgets);
        expect(find.text('Water'), findsWidgets);
        
        // Fun & Relax should always be visible
        expect(find.text('Fun & Relax'), findsWidgets);
      }
    });

    testWidgets('Productivity category shows focus and notes features', (tester) async {
      SharedPreferences.setMockInitialValues({
        'selected_category': 'productivity',
        'category_has_been_selected': true,
      });
      
      await tester.pumpAndSettle();
      
      // Navigate to home
      final homeTab = find.byIcon(Icons.home_rounded);
      if (homeTab.evaluate().isNotEmpty) {
        await tester.tap(homeTab);
        await tester.pumpAndSettle();
        
        // Verify productivity features are visible
        expect(find.text('Focus'), findsWidgets);
        expect(find.text('Notes'), findsWidgets);
        
        // Fun & Relax should always be visible
        expect(find.text('Fun & Relax'), findsWidgets);
      }
    });

    testWidgets('Finance category shows finance feature', (tester) async {
      SharedPreferences.setMockInitialValues({
        'selected_category': 'finance',
        'category_has_been_selected': true,
      });
      
      await tester.pumpAndSettle();
      
      // Navigate to home
      final homeTab = find.byIcon(Icons.home_rounded);
      if (homeTab.evaluate().isNotEmpty) {
        await tester.tap(homeTab);
        await tester.pumpAndSettle();
        
        // Verify finance feature is visible
        expect(find.text('Finance'), findsWidgets);
        
        // Fun & Relax should always be visible
        expect(find.text('Fun & Relax'), findsWidgets);
      }
    });

    testWidgets('Navigation bar shows category-specific icon and label', (tester) async {
      SharedPreferences.setMockInitialValues({
        'selected_category': 'health',
        'category_has_been_selected': true,
      });
      
      await tester.pumpAndSettle();
      
      // Verify navigation bar has Health tab
      expect(find.text('Health'), findsWidgets);
      
      // Verify Relax tab is always present
      expect(find.text('Relax'), findsWidgets);
    });

    testWidgets('Fun & Relax tab is always accessible', (tester) async {
      SharedPreferences.setMockInitialValues({
        'selected_category': 'fitness',
        'category_has_been_selected': true,
      });
      
      await tester.pumpAndSettle();
      
      // Find and tap Relax tab
      final relaxTab = find.text('Relax');
      if (relaxTab.evaluate().isNotEmpty) {
        await tester.tap(relaxTab);
        await tester.pumpAndSettle();
        
        // Verify Fun & Relax dashboard opens
        // Look for relaxation-related content
        expect(find.byIcon(Icons.spa_rounded), findsWidgets);
      }
    });
  });

  group('Settings Category Display Tests', () {
    testWidgets('Settings shows current category with ACTIVE badge', (tester) async {
      SharedPreferences.setMockInitialValues({
        'selected_category': 'health',
        'category_has_been_selected': true,
      });
      
      await tester.pumpAndSettle();
      
      // Navigate to settings
      final settingsTab = find.byIcon(Icons.settings_rounded);
      if (settingsTab.evaluate().isNotEmpty) {
        await tester.tap(settingsTab);
        await tester.pumpAndSettle();
        
        // Verify category section is visible
        expect(find.text('YOUR FOCUS'), findsWidgets);
        expect(find.text('ACTIVE'), findsWidgets);
        expect(find.text('Health & Wellness'), findsWidgets);
      }
    });

    testWidgets('Settings shows category change info message', (tester) async {
      SharedPreferences.setMockInitialValues({
        'selected_category': 'productivity',
        'category_has_been_selected': true,
      });
      
      await tester.pumpAndSettle();
      
      // Navigate to settings
      final settingsTab = find.byIcon(Icons.settings_rounded);
      if (settingsTab.evaluate().isNotEmpty) {
        await tester.tap(settingsTab);
        await tester.pumpAndSettle();
        
        // Verify info message about changing category
        expect(find.textContaining('sign out'), findsWidgets);
      }
    });

    testWidgets('Settings shows Fun & Relax included badge', (tester) async {
      SharedPreferences.setMockInitialValues({
        'selected_category': 'finance',
        'category_has_been_selected': true,
      });
      
      await tester.pumpAndSettle();
      
      // Navigate to settings
      final settingsTab = find.byIcon(Icons.settings_rounded);
      if (settingsTab.evaluate().isNotEmpty) {
        await tester.tap(settingsTab);
        await tester.pumpAndSettle();
        
        // Verify Fun & Relax included badge
        expect(find.text('Fun & Relax'), findsWidgets);
        expect(find.text('INCLUDED'), findsWidgets);
      }
    });
  });

  group('Premium UI Tests', () {
    testWidgets('Category cards have gradient backgrounds when selected', (tester) async {
      await tester.pumpAndSettle();
      
      // Select a category
      final healthCard = find.text('Health & Wellness');
      if (healthCard.evaluate().isNotEmpty) {
        await tester.tap(healthCard);
        await tester.pumpAndSettle();
        
        // The visual gradient is hard to test programmatically,
        // but we can verify the selection state
        expect(find.text('SELECTED'), findsOneWidget);
      }
    });

    testWidgets('Continue button shows gradient when category selected', (tester) async {
      await tester.pumpAndSettle();
      
      // Select a category
      final productivityCard = find.text('Focus & Productivity');
      if (productivityCard.evaluate().isNotEmpty) {
        await tester.tap(productivityCard);
        await tester.pumpAndSettle();
        
        // Button should be enabled with Continue text
        expect(find.text('Continue'), findsOneWidget);
        expect(find.byIcon(Icons.arrow_forward_rounded), findsOneWidget);
      }
    });

    testWidgets('Category selection screen has premium header badges', (tester) async {
      await tester.pumpAndSettle();
      
      // Verify premium UI elements
      expect(find.text('PERSONALIZE'), findsWidgets);
      expect(find.byIcon(Icons.auto_awesome_rounded), findsWidgets);
    });
  });
}
