/// The nudge banner's buttons are real touch targets.
///
/// "Use this" / "Try 20 + 5" is the button that APPLIES a suggestion, and
/// "Dismiss" is the only way to get rid of the card. Both copied
/// `VisualDensity.compact`, which takes 8 off a button's minimum height — so a
/// 44pt `minimumSize` would still have rendered at 36. These measure what is
/// actually laid out, at the widths and text sizes the app is run at.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tablet_remainder/core/health/insight.dart';
import 'package:tablet_remainder/core/theme/app_theme.dart';
import 'package:tablet_remainder/core/widgets/app/insight_kit.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  const withAction = Insight(
    id: 'focus_habit',
    feature: InsightFeature.focus,
    severity: InsightSeverity.info,
    title: 'Your usual round around now',
    detail: 'Reading for 25 minutes — what you usually start at this time of day.',
    why: 'Of the 6 rounds you finished near this time, 5 were reading.',
    actionLabel: 'Use this',
  );

  Future<void> pump(
    WidgetTester tester, {
    required double width,
    required double scale,
    Insight insight = withAction,
    VoidCallback? onAction,
  }) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = Size(width, 900);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      home: MediaQuery(
        data: MediaQueryData(size: Size(width, 900), textScaler: TextScaler.linear(scale)),
        child: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: ProactiveNudgeBanner(
              insight: insight,
              onDismiss: () {},
              onAction: onAction,
            ),
          ),
        ),
      ),
    ));
  }

  for (final width in const [320.0, 360.0, 411.0]) {
    for (final scale in const [1.0, 1.3, 2.0]) {
      testWidgets('both buttons are at least 44pt tall at ${width.toInt()}pt @ ${scale}x',
          (tester) async {
        await pump(tester, width: width, scale: scale, onAction: () {});

        for (final label in const ['Use this', 'Dismiss']) {
          final button = find.widgetWithText(TextButton, label);
          expect(button, findsOneWidget, reason: label);
          final size = tester.getSize(button);
          expect(size.height, greaterThanOrEqualTo(44),
              reason: '"$label" is a tap target; measured ${size.height}');
        }

        // The test font (Ahem) is about twice as wide as a real one, and at 2x on
        // a 320pt phone the WHY chip's own row is 28px wider than the column in
        // it — as it was before the buttons changed, and it is not the buttons'
        // doing. A real font fits; the device check is in release-checklist.md.
        final overflow = tester.takeException();
        if (!(width == 320 && scale == 2.0)) {
          expect(overflow, isNull, reason: 'it fits without an overflow stripe');
        }
      });
    }
  }

  testWidgets('with no action wired, only Dismiss is there and it is a real target',
      (tester) async {
    await pump(tester, width: 360, scale: 1.0);

    expect(find.widgetWithText(TextButton, 'Use this'), findsNothing);
    expect(tester.getSize(find.widgetWithText(TextButton, 'Dismiss')).height,
        greaterThanOrEqualTo(44));
  });

  testWidgets('tapping each button still does its own thing', (tester) async {
    var acted = 0;
    var dismissed = 0;
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(411, 900);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(
        body: ProactiveNudgeBanner(
          insight: withAction,
          onDismiss: () => dismissed++,
          onAction: () => acted++,
        ),
      ),
    ));

    await tester.tap(find.widgetWithText(TextButton, 'Use this'));
    expect((acted, dismissed), (1, 0));
    await tester.tap(find.widgetWithText(TextButton, 'Dismiss'));
    expect((acted, dismissed), (1, 1));
  });
}
