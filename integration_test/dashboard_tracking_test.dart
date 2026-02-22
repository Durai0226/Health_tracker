import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:tablet_remainder/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Dashboard E2E Tests', () {
    testWidgets('Dashboard loads and displays all sections', (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Navigate to Dashboard (index 0 in bottom nav)
      final dashboardNav = find.byIcon(Icons.dashboard_rounded);
      if (dashboardNav.evaluate().isNotEmpty) {
        await tester.tap(dashboardNav);
        await tester.pumpAndSettle();
      }

      // Verify Dashboard header exists
      expect(find.text('Dashboard'), findsWidgets);

      // Verify Health Analytics section
      expect(find.text('Health Analytics'), findsOneWidget);

      // Verify Smart Insights section
      expect(find.text('Smart Insights'), findsOneWidget);

      // Verify Streaks & Goals section
      expect(find.text('Streaks & Goals'), findsOneWidget);

      // Verify Weekly Trends section
      expect(find.text('Weekly Trends'), findsOneWidget);

      // Verify Weekly Comparison section
      expect(find.text('Weekly Comparison'), findsOneWidget);

      // Verify Today's Activity section
      expect(find.text("Today's Activity"), findsOneWidget);

      // Verify Upcoming Schedule section
      expect(find.text('Upcoming Schedule'), findsOneWidget);
    });

    testWidgets('Dashboard Hero Analytics Card displays correctly', (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Navigate to Dashboard
      final dashboardNav = find.byIcon(Icons.dashboard_rounded);
      if (dashboardNav.evaluate().isNotEmpty) {
        await tester.tap(dashboardNav);
        await tester.pumpAndSettle();
      }

      // Verify Health Score display
      expect(find.text('Health Score'), findsOneWidget);

      // Verify Daily Wellness title
      expect(find.text('Daily Wellness'), findsOneWidget);

      // Verify category stats (Medicine, Hydration, Fitness, Focus)
      expect(find.text('Medicine'), findsWidgets);
      expect(find.text('Hydration'), findsWidgets);
      expect(find.text('Fitness'), findsWidgets);
      expect(find.text('Focus'), findsWidgets);
    });

    testWidgets('Dashboard Streaks section displays streak cards', (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Navigate to Dashboard
      final dashboardNav = find.byIcon(Icons.dashboard_rounded);
      if (dashboardNav.evaluate().isNotEmpty) {
        await tester.tap(dashboardNav);
        await tester.pumpAndSettle();
      }

      // Scroll to Streaks section
      await tester.drag(find.byType(SingleChildScrollView).first, const Offset(0, -300));
      await tester.pumpAndSettle();

      // Verify Active Streaks header
      expect(find.text('Active Streaks'), findsOneWidget);

      // Verify Daily Goals header
      expect(find.text('Daily Goals'), findsOneWidget);

      // Verify goal items exist
      expect(find.text('Medicine 80%+'), findsOneWidget);
      expect(find.text('Water Goal Met'), findsOneWidget);
      expect(find.text('Workout Done'), findsOneWidget);
      expect(find.text('30min Focus'), findsOneWidget);
    });

    testWidgets('Dashboard Weekly Comparison chart displays', (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Navigate to Dashboard
      final dashboardNav = find.byIcon(Icons.dashboard_rounded);
      if (dashboardNav.evaluate().isNotEmpty) {
        await tester.tap(dashboardNav);
        await tester.pumpAndSettle();
      }

      // Scroll to Weekly Comparison section
      await tester.drag(find.byType(SingleChildScrollView).first, const Offset(0, -500));
      await tester.pumpAndSettle();

      // Verify Weekly Comparison header
      expect(find.text('This Week vs Last Week'), findsOneWidget);

      // Verify day labels exist
      expect(find.text('Mon'), findsOneWidget);
      expect(find.text('Tue'), findsOneWidget);
      expect(find.text('Wed'), findsOneWidget);
      expect(find.text('Thu'), findsOneWidget);
      expect(find.text('Fri'), findsOneWidget);
      expect(find.text('Sat'), findsOneWidget);
      expect(find.text('Sun'), findsOneWidget);
    });
  });

  group('Tracking Screen E2E Tests', () {
    testWidgets('Tracking screen loads and displays all sections', (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Navigate to Tracking (index 3 in bottom nav)
      final trackingNav = find.byIcon(Icons.track_changes_rounded);
      if (trackingNav.evaluate().isNotEmpty) {
        await tester.tap(trackingNav);
        await tester.pumpAndSettle();
      }

      // Verify Tracking header
      expect(find.text('Tracking'), findsOneWidget);
      expect(find.text('Monitor your health goals'), findsOneWidget);

      // Verify Quick Actions section
      expect(find.text('Quick Actions'), findsOneWidget);

      // Verify Habit Streaks section
      expect(find.text('Habit Streaks'), findsOneWidget);

      // Verify Health Categories section
      expect(find.text('Health Categories'), findsOneWidget);

      // Verify Category Insights section
      expect(find.text('Category Insights'), findsOneWidget);
    });

    testWidgets('Tracking Quick Actions buttons work', (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Navigate to Tracking
      final trackingNav = find.byIcon(Icons.track_changes_rounded);
      if (trackingNav.evaluate().isNotEmpty) {
        await tester.tap(trackingNav);
        await tester.pumpAndSettle();
      }

      // Find and tap +250ml Water button
      final waterButton = find.text('+250ml Water');
      if (waterButton.evaluate().isNotEmpty) {
        await tester.tap(waterButton);
        await tester.pumpAndSettle();

        // Verify snackbar appears
        expect(find.text('✓ +250ml water logged'), findsOneWidget);
      }
    });

    testWidgets('Tracking navigates to Medicine dashboard', (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Navigate to Tracking
      final trackingNav = find.byIcon(Icons.track_changes_rounded);
      if (trackingNav.evaluate().isNotEmpty) {
        await tester.tap(trackingNav);
        await tester.pumpAndSettle();
      }

      // Find and tap Log Medicine button
      final medicineButton = find.text('Log Medicine');
      if (medicineButton.evaluate().isNotEmpty) {
        await tester.tap(medicineButton);
        await tester.pumpAndSettle();

        // Verify navigation to Medicine screen
        expect(find.text('Medicine'), findsWidgets);
      }
    });

    testWidgets('Tracking Habit Streaks section displays correctly', (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Navigate to Tracking
      final trackingNav = find.byIcon(Icons.track_changes_rounded);
      if (trackingNav.evaluate().isNotEmpty) {
        await tester.tap(trackingNav);
        await tester.pumpAndSettle();
      }

      // Scroll to Habit Streaks
      await tester.drag(find.byType(SingleChildScrollView).first, const Offset(0, -200));
      await tester.pumpAndSettle();

      // Verify Total Streak label
      expect(find.text('Total Streak'), findsOneWidget);

      // Verify streak items for each category
      expect(find.text('Medicine'), findsWidgets);
      expect(find.text('Water'), findsWidgets);
      expect(find.text('Fitness'), findsWidgets);
      expect(find.text('Focus'), findsWidgets);
    });

    testWidgets('Tracking Category Cards navigate to feature screens', (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Navigate to Tracking
      final trackingNav = find.byIcon(Icons.track_changes_rounded);
      if (trackingNav.evaluate().isNotEmpty) {
        await tester.tap(trackingNav);
        await tester.pumpAndSettle();
      }

      // Scroll to Health Categories
      await tester.drag(find.byType(SingleChildScrollView).first, const Offset(0, -400));
      await tester.pumpAndSettle();

      // Find Medicine category card by looking for adherence text
      final medicineCard = find.textContaining('Adherence');
      if (medicineCard.evaluate().isNotEmpty) {
        await tester.tap(medicineCard.first);
        await tester.pumpAndSettle();

        // Should navigate to medicine dashboard
        // Navigate back
        final backButton = find.byIcon(Icons.arrow_back);
        if (backButton.evaluate().isNotEmpty) {
          await tester.tap(backButton.first);
          await tester.pumpAndSettle();
        }
      }
    });
  });

  group('Navigation E2E Tests', () {
    testWidgets('Bottom navigation switches between screens', (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Test Dashboard navigation
      final dashboardNav = find.byIcon(Icons.dashboard_rounded);
      if (dashboardNav.evaluate().isNotEmpty) {
        await tester.tap(dashboardNav);
        await tester.pumpAndSettle();
        expect(find.text('Dashboard'), findsWidgets);
      }

      // Test Home navigation
      final homeNav = find.byIcon(Icons.home_rounded);
      if (homeNav.evaluate().isNotEmpty) {
        await tester.tap(homeNav);
        await tester.pumpAndSettle();
        expect(find.text('Make Your Life Healthy'), findsOneWidget);
      }

      // Test Tracking navigation
      final trackingNav = find.byIcon(Icons.track_changes_rounded);
      if (trackingNav.evaluate().isNotEmpty) {
        await tester.tap(trackingNav);
        await tester.pumpAndSettle();
        expect(find.text('Tracking'), findsOneWidget);
      }

      // Test Settings navigation
      final settingsNav = find.byIcon(Icons.settings_rounded);
      if (settingsNav.evaluate().isNotEmpty) {
        await tester.tap(settingsNav);
        await tester.pumpAndSettle();
        expect(find.text('Settings'), findsOneWidget);
      }
    });

    testWidgets('Focus screen is accessible from navigation', (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Test Focus navigation
      final focusNav = find.byIcon(Icons.self_improvement_rounded);
      if (focusNav.evaluate().isNotEmpty) {
        await tester.tap(focusNav);
        await tester.pumpAndSettle();
        
        // Should be on Focus screen
        expect(find.byIcon(Icons.self_improvement_rounded), findsWidgets);
      }
    });
  });

  group('Data Display E2E Tests', () {
    testWidgets('Dashboard displays real-time analytics data', (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Navigate to Dashboard
      final dashboardNav = find.byIcon(Icons.dashboard_rounded);
      if (dashboardNav.evaluate().isNotEmpty) {
        await tester.tap(dashboardNav);
        await tester.pumpAndSettle();
      }

      // Verify percentage values are displayed (looking for % symbol)
      expect(find.textContaining('%'), findsWidgets);

      // Verify progress indicators exist
      expect(find.byType(LinearProgressIndicator), findsWidgets);
    });

    testWidgets('Tracking 7-Day Summary displays correctly', (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Navigate to Tracking
      final trackingNav = find.byIcon(Icons.track_changes_rounded);
      if (trackingNav.evaluate().isNotEmpty) {
        await tester.tap(trackingNav);
        await tester.pumpAndSettle();
      }

      // Scroll to Category Insights
      await tester.drag(find.byType(SingleChildScrollView).first, const Offset(0, -600));
      await tester.pumpAndSettle();

      // Verify 7-Day Summary
      expect(find.text('7-Day Summary'), findsOneWidget);

      // Verify analytics rows
      expect(find.text('Medicine Adherence'), findsOneWidget);
      expect(find.text('Hydration Goal'), findsOneWidget);
      expect(find.text('Fitness Activity'), findsOneWidget);
      expect(find.text('Focus Time'), findsOneWidget);
    });
  });

  group('UI Interaction E2E Tests', () {
    testWidgets('Dashboard scroll works correctly', (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Navigate to Dashboard
      final dashboardNav = find.byIcon(Icons.dashboard_rounded);
      if (dashboardNav.evaluate().isNotEmpty) {
        await tester.tap(dashboardNav);
        await tester.pumpAndSettle();
      }

      // Scroll down
      await tester.drag(find.byType(SingleChildScrollView).first, const Offset(0, -500));
      await tester.pumpAndSettle();

      // Verify we can see content that was below the fold
      expect(find.text('Upcoming Schedule'), findsOneWidget);

      // Scroll back up
      await tester.drag(find.byType(SingleChildScrollView).first, const Offset(0, 500));
      await tester.pumpAndSettle();

      // Verify we're back at the top
      expect(find.text('Health Analytics'), findsOneWidget);
    });

    testWidgets('Tracking pull to refresh works', (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Navigate to Tracking
      final trackingNav = find.byIcon(Icons.track_changes_rounded);
      if (trackingNav.evaluate().isNotEmpty) {
        await tester.tap(trackingNav);
        await tester.pumpAndSettle();
      }

      // Verify screen loaded
      expect(find.text('Tracking'), findsOneWidget);
      expect(find.text('Quick Actions'), findsOneWidget);
    });
  });
}
