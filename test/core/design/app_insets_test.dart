/// The bottom inset a scrollable leaves below its last row.
///
/// The point of these tests is that adopting `AppInsets` is a NO-OP in every
/// harness in this repo and a fix on every real device. A fixed test viewport
/// reports zero system insets, so the helpers return exactly the constants they
/// replaced — which is what let eight call sites migrate without moving a single
/// baseline. On hardware they add the home indicator or gesture bar, which none
/// of the three previous conventions did.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tablet_remainder/core/design/app_design.dart';

void main() {
  Future<(double, double)> at(
      WidgetTester tester, EdgeInsets viewPadding) async {
    late double p, n;
    await tester.pumpWidget(MediaQuery(
      data: MediaQueryData(size: const Size(390, 844), viewPadding: viewPadding),
      child: Builder(builder: (c) {
        p = AppInsets.pushed(c);
        n = AppInsets.underNav(c);
        return const SizedBox.shrink();
      }),
    ));
    return (p, n);
  }

  testWidgets('with no system insets, both return the old constants',
      (tester) async {
    final (pushed, underNav) = await at(tester, EdgeInsets.zero);
    // `AppSpacing.huge`, which pushed screens used.
    expect(pushed, 48.0);
    // The magic 100 two sleep screens hand-derived: the nav's own 68, the FAB's
    // 20pt overhang, and a 12pt gap.
    expect(underNav, 100.0);
    expect(AppInsets.navBar + AppInsets.fabOverhang + AppSpacing.md, 100.0,
        reason: 'if this stops adding up, the magic 100 was never what it '
            'looked like and the derivation is wrong');
  });

  testWidgets('a gesture bar is added to both', (tester) async {
    // The defect all three old conventions shared: none accounted for this, so
    // a pushed screen's last row sat partly under the indicator.
    final (pushed, underNav) =
        await at(tester, const EdgeInsets.only(bottom: 34));
    expect(pushed, 82.0);
    expect(underNav, 134.0);
  });

  testWidgets('the keyboard does not shrink a list resting inset',
      (tester) async {
    // `viewPadding` not `padding`: `padding` goes to zero while the keyboard is
    // up, which would yank the bottom inset out from under a list the moment a
    // text field on the same screen took focus.
    await tester.pumpWidget(MediaQuery(
      data: const MediaQueryData(
        size: Size(390, 844),
        viewPadding: EdgeInsets.only(bottom: 34),
        padding: EdgeInsets.zero, // what Flutter reports with a keyboard up
        viewInsets: EdgeInsets.only(bottom: 300),
      ),
      child: Builder(builder: (c) {
        expect(AppInsets.pushed(c), 82.0);
        return const SizedBox.shrink();
      }),
    ));
  });
}
