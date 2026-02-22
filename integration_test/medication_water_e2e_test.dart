import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:tablet_remainder/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Medication & Water Features E2E Tests', () {
    testWidgets('Medication feature is visible and accessible from Home screen', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Wait for app to fully initialize
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Verify we're on the Home screen (center nav item should be selected)
      expect(find.byIcon(Icons.home_rounded), findsOneWidget);

      // Look for Medicine quick action card in the home screen
      final medicineFinder = find.widgetWithText(InkWell, 'Medicine');
      expect(medicineFinder, findsOneWidget, reason: 'Medicine quick action card should be visible on Home screen');

      // Tap on Medicine card
      await tester.tap(medicineFinder);
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Verify we navigated to Medicine Dashboard
      expect(find.text('Medicine Tracker'), findsOneWidget, reason: 'Should navigate to Medicine Dashboard');

      // Go back to home
      await tester.pageBack();
      await tester.pumpAndSettle();
    });

    testWidgets('Water feature is visible and accessible from Home screen', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Wait for app to fully initialize
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Look for Water quick action card in the home screen
      final waterFinder = find.widgetWithText(InkWell, 'Water');
      expect(waterFinder, findsOneWidget, reason: 'Water quick action card should be visible on Home screen');

      // Tap on Water card
      await tester.tap(waterFinder);
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Verify we navigated to Water Dashboard
      expect(find.text('Water Tracker'), findsOneWidget, reason: 'Should navigate to Water Dashboard');

      // Go back to home
      await tester.pageBack();
      await tester.pumpAndSettle();
    });

    testWidgets('Can add medicine from FAB', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Tap the FAB (floating action button)
      final fabFinder = find.byType(FloatingActionButton);
      expect(fabFinder, findsOneWidget);
      await tester.tap(fabFinder);
      await tester.pumpAndSettle();

      // Should show bottom sheet with options
      expect(find.text('What would you like to add?'), findsOneWidget);

      // Find and tap Medicine option
      final medicineOptionFinder = find.widgetWithText(InkWell, 'Medicine');
      expect(medicineOptionFinder, findsOneWidget);
      await tester.tap(medicineOptionFinder);
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Verify we're on Add Medicine screen
      expect(find.text('Add Medicine'), findsOneWidget);

      // Go back
      await tester.pageBack();
      await tester.pumpAndSettle();
    });

    testWidgets('Can add water from FAB', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Tap the FAB
      final fabFinder = find.byType(FloatingActionButton);
      await tester.tap(fabFinder);
      await tester.pumpAndSettle();

      // Find and tap Water option
      final waterOptionFinder = find.widgetWithText(InkWell, 'Water');
      expect(waterOptionFinder, findsOneWidget);
      await tester.tap(waterOptionFinder);
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Verify we're on Water Dashboard screen
      expect(find.text('Water Tracker'), findsOneWidget);

      // Go back
      await tester.pageBack();
      await tester.pumpAndSettle();
    });

    testWidgets('Water dashboard displays correctly and can add water', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Navigate to Water feature
      final waterFinder = find.widgetWithText(InkWell, 'Water');
      await tester.tap(waterFinder);
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Verify Water Dashboard elements
      expect(find.text('Water Tracker'), findsOneWidget);
      expect(find.text('Today\'s Progress'), findsOneWidget);

      // Look for quick add buttons (Cup, Glass, Bottle, Large)
      expect(find.text('Cup'), findsOneWidget);
      expect(find.text('Glass'), findsOneWidget);
      expect(find.text('Bottle'), findsOneWidget);
      expect(find.text('Large'), findsOneWidget);

      // Tap Glass button to add 250ml
      final glassFinder = find.widgetWithText(ElevatedButton, 'Glass');
      await tester.tap(glassFinder);
      await tester.pumpAndSettle();

      // Should show success snackbar
      expect(find.textContaining('+250ml added'), findsOneWidget);

      // Go back
      await tester.pageBack();
      await tester.pumpAndSettle();
    });

    testWidgets('Medicine dashboard displays correctly', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Navigate to Medicine feature
      final medicineFinder = find.widgetWithText(InkWell, 'Medicine');
      await tester.tap(medicineFinder);
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Verify Medicine Dashboard elements
      expect(find.text('Medicine Tracker'), findsOneWidget);
      
      // Should have tabs or sections for different views
      expect(find.byType(TabBar), findsOneWidget);

      // Go back
      await tester.pageBack();
      await tester.pumpAndSettle();
    });

    testWidgets('All features are enabled in FeatureManager', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Verify Medicine and Water quick action cards are present
      expect(find.widgetWithText(InkWell, 'Medicine'), findsOneWidget, 
        reason: 'Medicine should be enabled and visible');
      expect(find.widgetWithText(InkWell, 'Water'), findsOneWidget,
        reason: 'Water should be enabled and visible');

      // Verify other optional features are also visible
      expect(find.widgetWithText(InkWell, 'Focus'), findsOneWidget,
        reason: 'Focus should be enabled and visible');
      expect(find.widgetWithText(InkWell, 'Notes'), findsOneWidget,
        reason: 'Notes should be enabled and visible');
      expect(find.widgetWithText(InkWell, 'Finance'), findsOneWidget,
        reason: 'Finance should be enabled and visible');
    });
  });
}
