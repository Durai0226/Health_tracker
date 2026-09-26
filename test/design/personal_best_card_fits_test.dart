import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:tablet_remainder/core/constants/app_spacing.dart';
import 'package:tablet_remainder/core/theme/app_theme.dart';
import 'package:tablet_remainder/core/widgets/app/app_widgets.dart';
import 'package:tablet_remainder/core/widgets/app/personal_best_card.dart';

/// The eyebrow and the "New best" chip are both fixed strings that grow with
/// Dynamic Type, and neither can yield a word without losing meaning. As a Row
/// they overflowed by 75px on the narrowest supported phone at ordinary text
/// size — and only once a personal best actually existed, which is why the
/// responsive sweep took so long to surface it.
// WCAG 2.x relative luminance, so "the eyebrow is readable" is a number.
double _lin(int channel) {
  final v = channel / 255.0;
  return v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
}

double _luminance(Color c) =>
    0.2126 * _lin(c.red) + 0.7152 * _lin(c.green) + 0.0722 * _lin(c.blue);

double _contrast(Color a, Color b) {
  final la = _luminance(a), lb = _luminance(b);
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

void main() {
  Future<void> pumpAt(WidgetTester tester, Size size, double scale,
      {required bool isNew, bool dark = false}) async {
    // The VIEW is what constrains layout — a MediaQuery size alone is ignored,
    // so without these two lines the card lays out at the default 800x600 and
    // the overflow cannot reproduce no matter what size is declared.
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = size;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData(
          size: size,
          textScaler: TextScaler.linear(scale),
        ),
        child: MaterialApp(
          theme: dark ? AppTheme.darkTheme : AppTheme.lightTheme,
          home: Scaffold(
            // The 20pt page gutter the dashboards actually use. Without it the
            // card gets ~40pt more width than it ever has on screen, and the
            // overflow this test exists to catch does not reproduce.
            body: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
              child: Builder(
              builder: (context) => PersonalBestCard(
                icon: Symbols.emoji_events_rounded,
                value: '12,430 steps',
                sublabel: 'Best day · Jul 2',
                isNew: isNew,
                accent: AppColorsExt.of(context).steps,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  // The narrowest supported phone through the largest supported text scale.
  const sizes = <Size>[Size(320, 568), Size(360, 640), Size(375, 667)];
  const scales = <double>[1.0, 1.3, 2.0];

  for (final size in sizes) {
    for (final scale in scales) {
      testWidgets(
          'fits at ${size.width.toInt()}pt @${scale}x with a new best',
          (tester) async {
        await pumpAt(tester, size, scale, isNew: true);
        expect(tester.takeException(), isNull,
            reason: 'PersonalBestCard overflowed at '
                '${size.width.toInt()}pt @${scale}x');
      });
    }
  }

  testWidgets('both labels stay readable — neither is ellipsized away',
      (tester) async {
    await pumpAt(tester, const Size(320, 568), 1.0, isNew: true);
    expect(find.text('PERSONAL BEST'), findsOneWidget);
    expect(find.text('New best'), findsOneWidget);
    // A Wrap, not an ellipsis: the chip moves to its own line instead of the
    // eyebrow losing characters.
    final eyebrow = tester.widget<Text>(find.text('PERSONAL BEST'));
    expect(eyebrow.overflow, isNot(TextOverflow.ellipsis));
  });

  testWidgets('without a new best the chip is absent', (tester) async {
    await pumpAt(tester, const Size(320, 568), 2.0, isNew: false);
    expect(tester.takeException(), isNull);
    expect(find.text('New best'), findsNothing);
  });

  // DS-11. This card was one of seven independent copies of the same eyebrow
  // style, and all seven picked `ext.textTertiary`, which at labelSmall's 11pt
  // is below AA on every surface in the app. It now draws the shared
  // `AppEyebrow`, whose default is `textSecondary`.
  //
  // One test per theme, not a loop inside one: MaterialApp cross-fades a theme
  // change, so a second pumpWidget in the same test is read mid-fade and
  // reports the OLD theme's colours.
  group('the eyebrow is the shared AppEyebrow, which clears AA', () {
    for (final dark in [false, true]) {
      testWidgets('on a ${dark ? 'dark' : 'light'} card', (tester) async {
        await pumpAt(tester, const Size(375, 667), 1.0,
            isNew: true, dark: dark);

        // The widget itself, so deleting the adoption fails here and not only
        // on the colour — a later edit could re-hardcode textSecondary and
        // still be off-system.
        expect(find.byType(AppEyebrow), findsOneWidget);

        final ext = dark ? AppColorsExt.dark : AppColorsExt.light;
        final style = tester
            .renderObject<RenderParagraph>(find.text('PERSONAL BEST'))
            .text
            .style!;
        expect(style.color, ext.textSecondary);
        expect(style.fontSize, 11);

        // The card is `ext.surface`; that is what the eyebrow sits on.
        expect(_contrast(style.color!, ext.surface),
            greaterThanOrEqualTo(4.5),
            reason: 'eyebrow on the card surface');
        // And the value the seven copies used, still failing, so this test
        // says why the default is what it is rather than merely pinning it.
        expect(_contrast(ext.textTertiary, ext.surface), lessThan(4.5),
            reason: 'if tertiary ever clears AA, revisit AppEyebrow\'s default');
      });
    }
  });
}
