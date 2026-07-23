import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:tablet_remainder/main.dart' as app;

/// Redesign E2E — drives the real app on a device/simulator, feature by feature,
/// against the new "Today-first, 5-target" navigation. Uses fixed-duration pumps
/// (not pumpAndSettle) so continuous animations (nav orb, ads) can't hang it.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> settle(WidgetTester t,
      [Duration d = const Duration(milliseconds: 250), int frames = 12]) async {
    for (var i = 0; i < frames; i++) {
      await t.pump(d);
    }
  }

  /// Get past the first-run welcome/onboarding to the app shell, if shown.
  /// Robust against the multi-step onboarding + nondeterministic container wipe:
  /// returns immediately if already at the shell, else advances via non-
  /// permission buttons ("Skip for now"/"Continue"/…) — NEVER tapping a button
  /// that would raise a native permission dialog the test can't dismiss.
  Future<void> reachHome(WidgetTester t) async {
    // Let async init + first frame settle.
    for (var i = 0; i < 14; i++) {
      await t.pump(const Duration(milliseconds: 300));
    }
    const advances = [
      'Skip for now',
      'Continue',
      'Get Started',
      'Get started',
      'Next',
      'Done',
      'Finish',
      "Let's go",
      'Start tracking',
    ];
    for (var i = 0; i < 24; i++) {
      if (find.text('Today').evaluate().isNotEmpty &&
          find.text('Health').evaluate().isNotEmpty) {
        return; // shell reached
      }
      for (final label in advances) {
        final f = find.text(label);
        if (f.evaluate().isNotEmpty) {
          await t.tap(f.last, warnIfMissed: false);
          break;
        }
      }
      for (var j = 0; j < 6; j++) {
        await t.pump(const Duration(milliseconds: 300));
      }
    }
  }

  group('Redesign nav E2E', () {
    testWidgets('5 slots reachable + center Log sheet + Health trackers',
        (tester) async {
      app.main();
      await reachHome(tester);

      // All 5 nav destinations present.
      expect(find.text('Today'), findsWidgets, reason: 'Today tab');
      expect(find.text('Meds'), findsWidgets, reason: 'Meds tab');
      expect(find.text('Log'), findsWidgets, reason: 'Log action');
      expect(find.text('Health'), findsWidgets, reason: 'Health tab');
      expect(find.text('Insights'), findsWidgets, reason: 'Insights tab');

      // Meds tab.
      await tester.tap(find.text('Meds').last);
      await settle(tester);

      // Health tab → browse hub with all trackers.
      await tester.tap(find.text('Health').last);
      await settle(tester);
      expect(find.text('Your trackers'), findsOneWidget,
          reason: 'Health browse header');
      for (final tracker in ['Water', 'Steps', 'Sleep', 'Period',
          'Blood pressure', 'Blood sugar']) {
        expect(find.text(tracker), findsWidgets, reason: '$tracker in Health');
      }

      // Insights tab.
      await tester.tap(find.text('Insights').last);
      await settle(tester);

      // Center Log action → unified sheet.
      await tester.tap(find.text('Log').last);
      await settle(tester);
      expect(find.text('Log something'), findsOneWidget,
          reason: 'Log sheet opened');
      // Sheet lists the capture options.
      expect(find.text('Medicine dose'), findsOneWidget);
      expect(find.text('Water'), findsWidgets);
      // Dismiss the sheet.
      await tester.tapAt(const Offset(200, 60));
      await settle(tester);

      // Back to Today.
      await tester.tap(find.text('Today').last);
      await settle(tester);
    });
  });

  group('Redesign feature E2E', () {
    testWidgets('Health trackers each open and return', (tester) async {
      app.main();
      await reachHome(tester);
      await tester.tap(find.text('Health').last);
      await settle(tester);
      expect(find.text('Your trackers'), findsOneWidget);

      for (final tracker in ['Water', 'Steps', 'Sleep']) {
        await tester.tap(find.text(tracker).first);
        await settle(tester);
        // A pushed tracker screen shows a back arrow; use it to return.
        final back = find.byIcon(Icons.arrow_back_rounded);
        expect(back, findsWidgets, reason: '$tracker screen opened');
        await tester.tap(back.first);
        await settle(tester);
        expect(find.text('Your trackers'), findsOneWidget,
            reason: 'returned to Health after $tracker');
      }
    });

    testWidgets('Settings → AI Assistant is clean (no key/cloud jargon)',
        (tester) async {
      app.main();
      await reachHome(tester);
      // Settings gear on Today.
      await tester.tap(find.byIcon(Icons.settings_rounded).first);
      await settle(tester);
      // Find the AI Assistant tile (scroll if needed).
      final aiTile = find.text('AI Assistant');
      await tester.scrollUntilVisible(aiTile.first, 300,
          scrollable: find.byType(Scrollable).first);
      await settle(tester);
      await tester.tap(aiTile.first);
      await settle(tester);
      // The clean AI screen: explainer + Memory + Privacy, NO key jargon.
      expect(find.text('What it remembers'), findsOneWidget);
      expect(find.text('AI & your data'), findsOneWidget);
      expect(find.textContaining('nvapi'), findsNothing,
          reason: 'no API-key jargon');
      expect(find.textContaining('API key'), findsNothing);
    });

    testWidgets('Customize Today opens with card toggles', (tester) async {
      app.main();
      await reachHome(tester);
      // Ensure on Today.
      await tester.tap(find.text('Today').last);
      await settle(tester);
      final customize = find.text('Customize');
      await tester.scrollUntilVisible(customize.first, 300,
          scrollable: find.byType(Scrollable).first);
      await settle(tester);
      await tester.tap(customize.first);
      await settle(tester);
      expect(find.text('Customize Today'), findsOneWidget);
      // Toggles for the cards.
      expect(find.text('Medicine'), findsWidgets);
      expect(find.byType(SwitchListTile), findsWidgets);
    });
  });
}
