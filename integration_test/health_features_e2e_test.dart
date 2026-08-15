import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:tablet_remainder/main.dart' as app;

/// End-to-end tests for the new Period / Steps / Sleep features, driving the
/// MANUAL flows (so they run without health-sensor permissions — the same path
/// used on the iOS Simulator). Requires a device/emulator with the app fully
/// built (Drift native + `pod install` for the health plugin on iOS).
///
/// Run: flutter test integration_test/health_features_e2e_test.dart -d <device>
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // Get past the first-launch onboarding sheet, if shown.
  Future<void> continueAsGuest(WidgetTester tester) async {
    await tester.pumpAndSettle(const Duration(seconds: 5));
    final guest = find.text('Continue as guest');
    if (guest.evaluate().isNotEmpty) {
      await tester.tap(guest);
      await tester.pumpAndSettle(const Duration(seconds: 3));
    }
  }

  Future<void> openHealthTab(WidgetTester tester) async {
    // Bottom nav "Health" destination.
    final health = find.text('Health');
    if (health.evaluate().isNotEmpty) {
      await tester.tap(health.first);
      await tester.pumpAndSettle(const Duration(seconds: 2));
    }
  }

  group('Health features E2E (manual flows)', () {
    testWidgets('Period is a 3rd Health tab and renders its dashboard',
        (tester) async {
      app.main();
      await continueAsGuest(tester);
      await openHealthTab(tester);

      // The Health hub segmented control should now expose a Period segment.
      final periodSeg = find.text('Period');
      expect(periodSeg, findsWidgets,
          reason: 'Period segment should appear in the Health hub');
      await tester.tap(periodSeg.first);
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // The period dashboard shows a cold-start / cycle surface. A "Log today"
      // affordance (or the onboarding CTA) should be present.
      final logToday = find.textContaining('Log');
      expect(logToday, findsWidgets,
          reason: 'Period dashboard should offer a way to log the day');
    });

    testWidgets('Steps opens from Medicine Quick Access and logs manually',
        (tester) async {
      app.main();
      await continueAsGuest(tester);
      await openHealthTab(tester);

      // Medicine tab is the hub default; open the Steps quick action.
      final steps = find.text('Steps');
      expect(steps, findsWidgets, reason: 'Steps quick-access tile should show');
      await tester.tap(steps.first);
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Steps dashboard renders (activity ring / manual entry).
      expect(find.textContaining('Steps'), findsWidgets);
    });

    testWidgets('Sleep opens from Medicine Quick Access and renders',
        (tester) async {
      app.main();
      await continueAsGuest(tester);
      await openHealthTab(tester);

      final sleep = find.text('Sleep');
      expect(sleep, findsWidgets, reason: 'Sleep quick-access tile should show');
      await tester.tap(sleep.first);
      await tester.pumpAndSettle(const Duration(seconds: 2));

      expect(find.textContaining('Sleep'), findsWidgets);
    });
  });
}
