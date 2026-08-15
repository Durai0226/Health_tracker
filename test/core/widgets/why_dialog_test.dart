/// The "Why this?" explainer must not overflow.
///
/// Its AlertDialog title is a Row of [icon, gap, Text]. The Text was unflexed,
/// so on a narrow screen the row had nowhere to put it and Flutter painted the
/// overflow stripe across the dialog edge — 24px, visible in a user screenshot.
///
/// This dialog is the app's answer to "where did this health number come
/// from?", so it is exactly the wrong place to look broken.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tablet_remainder/core/theme/app_theme.dart';
import 'package:tablet_remainder/core/widgets/app/insight_kit.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  for (final width in const [320.0, 360.0, 390.0]) {
    for (final scale in const [1.0, 1.3, 2.0]) {
      testWidgets('opens without overflow at ${width.toInt()}pt @ ${scale}x',
          (tester) async {
        tester.view.devicePixelRatio = 1.0;
        tester.view.physicalSize = Size(width, 800);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(MaterialApp(
          theme: AppTheme.lightTheme,
          home: MediaQuery(
            data: MediaQueryData(
              size: Size(width, 800),
              textScaler: TextScaler.linear(scale),
            ),
            child: const Scaffold(
              body: Center(
                child: WhyThisChip(
                  why: 'Your 8h nightly target x 5 logged nights, minus what '
                      'you actually slept. Nights you did not log are not '
                      'counted.',
                ),
              ),
            ),
          ),
        ));

        await tester.tap(find.text('Why this?'));
        await tester.pumpAndSettle();

        expect(find.text("Why you're seeing this"), findsOneWidget,
            reason: 'the explainer should have opened');
        expect(
          tester.takeException(),
          isNull,
          reason: 'The dialog title overflowed at ${width.toInt()}pt @ '
              '${scale}x. An unflexed Text in the title Row has nowhere to go '
              'on a narrow dialog.',
        );
      });
    }
  }
}
