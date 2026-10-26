/// The "Gender:" chips are the only way to set a value that changes the
/// recommended hydration goal, so both how big they are and where they land
/// matter.
///
/// Both halves of this were found on a 420dpi device, one caused by fixing the
/// other:
///
///  * they were 63x32 and 78x32 — `vertical: 8` around a ~16pt label — against
///    the 44pt floor the rest of the app holds to;
///  * the first fix gave the Container a `minHeight` *and* an `alignment`,
///    which makes a Container expand to the incoming maxWidth. Inside the
///    `Wrap` these sit in, that put "Male" and "Female" on two separate lines.
///
/// Nothing headless caught the second one: the touch-target audit measures a
/// target's size and not its position, and a `Wrap` given an over-wide child
/// does not overflow — it wraps, silently. Hence this file, which asserts the
/// position too.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/theme/app_theme.dart';
import 'package:tablet_remainder/features/water/screens/hydration_profile_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> openProfile(WidgetTester tester, {double scale = 1.0}) async {
    tester.view.devicePixelRatio = 1.0;
    // A real layout width, not just a MediaQuery size — a Wrap only reveals
    // this class of bug when it actually has a width to run out of.
    tester.view.physicalSize = const Size(411, 900);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      home: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(scale)),
        child: const HydrationProfileScreen(),
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  Rect chip(WidgetTester tester, String label) =>
      tester.getRect(find.byKey(ValueKey('genderChip$label')));

  testWidgets('the sex chips clear 44pt and stay on one row', (tester) async {
    await openProfile(tester);

    final male = chip(tester, 'Male');
    final female = chip(tester, 'Female');

    expect(male.height, greaterThanOrEqualTo(44.0),
        reason: 'a 32pt chip is twelve short of the floor the rest of the app '
            'holds to, and this one changes the recommended goal');
    expect(female.height, greaterThanOrEqualTo(44.0));

    expect(male.top, moreOrLessEquals(female.top, epsilon: 0.5),
        reason: 'they are one segmented control. Male at ${male.top} and '
            'Female at ${female.top} means the Wrap broke the line — which is '
            'what a Container given both a minHeight and an alignment does '
            'inside a Wrap.');

    // ...and neither has swallowed the row, which is how the line broke.
    expect(male.width, lessThan(411 / 2),
        reason: 'a chip wider than half the screen is one that expanded to '
            'its constraints instead of its label. Was ${male.width}.');
    expect(female.width, lessThan(411 / 2),
        reason: 'was ${female.width}');
  });

  /// At 1.3x the row legitimately breaks — "Gender:", "Male" and "Female" no
  /// longer fit across 411pt, and wrapping is what a `Wrap` is for. What must
  /// still hold at every scale is that each chip is sized by its label rather
  /// than by the space available: a greedy chip fills the row and forces the
  /// break on its own at 1.0x, which is the bug this file exists for.
  testWidgets('they are sized by their label at 1.3x, not by the row',
      (tester) async {
    await openProfile(tester, scale: 1.3);

    final male = chip(tester, 'Male');
    final female = chip(tester, 'Female');

    expect(male.height, greaterThanOrEqualTo(44.0));
    expect(female.height, greaterThanOrEqualTo(44.0));
    expect(male.width, lessThan(411 / 2), reason: 'was ${male.width}');
    expect(female.width, lessThan(411 / 2), reason: 'was ${female.width}');
    expect(female.width, greaterThan(male.width),
        reason: '"Female" is the longer word, so a label-sized chip is wider. '
            'Equal widths would mean both had expanded to something else.');
  });
}
