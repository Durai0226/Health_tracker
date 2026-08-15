import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:tablet_remainder/core/widgets/app/app_header.dart';
import 'package:tablet_remainder/features/home/screens/home_dashboard.dart';
import 'package:tablet_remainder/main.dart' as app;

import 'support/e2e_helpers.dart';

/// The Home header, on real hardware.
///
/// A user screenshotted this screen on an Android phone: the greeting
/// `Good evening · Wednesday, Aug 12` wrapped to THREE lines, the title read
/// `User`, and the briefing was cut mid-sentence. The headless suite covers the
/// same assertions, but only a device exercises the real font, the real
/// display width, the real status-bar inset and the user's own Dynamic Type
/// setting — which is the combination that produced the screenshot.
///
/// Conventions follow `redesign_e2e_test.dart`: fixed-duration pumps rather
/// than `pumpAndSettle` (continuous animations never settle), and no taps that
/// could raise a native permission dialog the test cannot dismiss.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();



  /// Duplicated from `test/support/text_layout.dart` on purpose — `test/` is
  /// not on the import path for `integration_test/`, and 25 lines of measuring
  /// code is cheaper than a shared package.
  ///
  /// Counts the lines a paragraph ACTUALLY rendered. `didExceedMaxLines` is no
  /// use here: it is `maxLines != null && …`, so it is false by construction
  /// for an unclamped `Text` — precisely the widget that wrapped.
  List<String> wrappedTextUnder(Finder scope) {
    final offenders = <String>[];
    for (final element
        in find.descendant(of: scope, matching: find.byType(RichText)).evaluate()) {
      final p = element.renderObject;
      if (p is! RenderParagraph || !p.hasSize || p.size.isEmpty) continue;
      final allowed = p.maxLines ?? 1;
      final painter = TextPainter(
        text: p.text,
        textDirection: p.textDirection,
        textAlign: p.textAlign,
        textScaler: p.textScaler,
        maxLines: p.maxLines,
        strutStyle: p.strutStyle,
        textWidthBasis: p.textWidthBasis,
        locale: p.locale,
      )..layout(maxWidth: p.size.width);
      final actual = painter.computeLineMetrics().length;
      painter.dispose();
      if (actual > allowed) {
        offenders.add('"${p.text.toPlainText()}" rendered $actual lines '
            '(allowed $allowed) in ${p.size.width.toStringAsFixed(0)}pt');
      }
    }
    return offenders;
  }

  group('Home header (device)', () {
    testWidgets('titled Today, nothing wraps, no placeholder name',
        (tester) async {
      app.main();
      await reachHome(tester);
      await settle(tester);

      // The shell keeps every tab alive in an IndexedStack, so scope to Home
      // — a bare find.byType(AppHeader) matches several.
      final header = find.descendant(
        of: find.byType(HomeDashboard),
        matching: find.byType(AppHeader),
      );
      expect(header, findsOneWidget,
          reason: 'Home did not render its header on this device.');

      expect(
        find.descendant(of: header, matching: find.text('Today')),
        findsOneWidget,
        reason: 'The title must describe the view. It previously rendered the '
            'account display name, which for an account with no displayName '
            'was the literal placeholder "User".',
      );

      for (final g in const ['Good morning', 'Good afternoon', 'Good evening']) {
        expect(
          find.descendant(of: header, matching: find.textContaining(g)),
          findsNothing,
          reason: 'The greeting was removed from the header — it carried no '
              'information and duplicated the briefing strip below.',
        );
      }

      expect(
        find.descendant(of: header, matching: find.text('User')),
        findsNothing,
        reason: '"User" is a placeholder, not a name.',
      );

      // The reported failure, asserted against the device's real font and
      // width rather than the square-em test font.
      expect(
        wrappedTextUnder(header),
        isEmpty,
        reason: 'Header text wrapped on this device. This is the exact defect '
            'from the screenshot: header chrome must be one line at the '
            'device\'s real width and Dynamic Type setting.',
      );
    });

    testWidgets('the greeting headers on other tabs do not wrap either',
        (tester) async {
      app.main();
      await reachHome(tester);
      await settle(tester);

      // Medicine still carries a greeting, and it wrapped at large text sizes
      // for the same reason Home did.
      final meds = find.text('Meds');
      if (meds.evaluate().isEmpty) {
        markTestSkipped('Meds tab not present in this build');
        return;
      }
      await tester.tap(meds.last, warnIfMissed: false);
      await settle(tester);

      expect(wrappedTextUnder(find.byType(AppHeader).first), isEmpty,
          reason: 'A greeting header wrapped on this device.');
    });
  });
}
