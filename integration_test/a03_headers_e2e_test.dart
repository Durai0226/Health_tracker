import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:tablet_remainder/core/widgets/app/app_header.dart';
import 'package:tablet_remainder/features/home/screens/home_dashboard.dart';
import 'package:tablet_remainder/features/medication/screens/nunito_medication_dashboard.dart';

import 'support/app_strings.dart';
import 'support/e2e.dart';
import 'support/text_layout.dart';

/// Header chrome, on real hardware.
///
/// A user screenshotted Home on an Android phone: the greeting
/// `Good evening · Wednesday, Aug 12` wrapped to THREE lines, the title read
/// `User`, and the briefing was cut mid-sentence. The headless sweep asserts
/// the same things, but it lays out in the square-em test font — only a device
/// exercises Nunito's real advance widths, the real display width, the real
/// status-bar inset and the user's own Dynamic Type setting. That combination
/// is what produced the screenshot.
///
/// Migrated from `home_header_e2e_test.dart`. Two changes beyond the harness:
/// the Meds case used to `markTestSkipped` when it could not find the tab —
/// turning "navigation is broken" into a green run — and the line-counting
/// helper moved to `support/text_layout.dart` so every suite can reuse it.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Home header: titled Today, no placeholder name, nothing wraps',
      (t) async {
    await E2E.launch(t);

    // The shell keeps every tab alive in an IndexedStack, so scope to Home —
    // a bare find.byType(AppHeader) matches several.
    final header = find.descendant(
      of: find.byType(HomeDashboard),
      matching: find.byType(AppHeader),
    );
    expect(header, findsOneWidget,
        reason: 'Home did not render its header on this device.');

    expect(
      find.descendant(of: header, matching: find.text(kTodayHeader)),
      findsOneWidget,
      reason: 'The title must describe the view. It previously rendered the '
          'account display name, which for an account with no displayName was '
          'the literal placeholder "User".',
    );

    for (final g in const ['Good morning', 'Good afternoon', 'Good evening']) {
      expect(
        find.descendant(of: header, matching: find.textContaining(g)),
        findsNothing,
        reason: 'The greeting was removed from the header — it carried no '
            'information and duplicated the briefing strip below.',
      );
    }

    // e2e-absent-ok: proves the placeholder is gone, so it must NOT be in lib/
    expect(
      find.descendant(of: header, matching: find.text('User')),
      findsNothing,
      reason: '"User" is a placeholder, not a name.',
    );

    expect(
      wrappedTextUnder(header),
      isEmpty,
      reason: 'Header text wrapped on this device. This is the exact defect '
          "from the screenshot: header chrome must be one line at the device's "
          'real width and Dynamic Type setting.',
    );

    E2E.assertClean('Home header');
  });

  testWidgets('Meds header does not wrap either', (t) async {
    await E2E.launch(t);

    // Was `if (meds.evaluate().isEmpty) markTestSkipped(...)`, which converted
    // a broken nav bar into a passing run. goTab asserts arrival instead.
    await E2E.goTab(t, NavTab.meds);

    final header = find.descendant(
      of: find.byType(NunitoMedicationDashboard),
      matching: find.byType(AppHeader),
    );
    expect(header, findsOneWidget, reason: 'Meds did not render its header.');
    expect(
      find.descendant(of: header, matching: find.text(kMedsHeader)),
      findsOneWidget,
    );

    expect(wrappedTextUnder(header), isEmpty,
        reason: 'The Medicine header wrapped on this device. Its title is '
            'deliberately short so it never truncates — assert that.');

    E2E.assertClean('Meds header');
  });
}
