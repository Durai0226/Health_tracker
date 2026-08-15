/// Taps must not ripple, and selection must not animate.
///
/// A user reported a visible glitch when switching tabs and asked for the
/// ripple and "any effect added" to be removed. Two distinct mechanisms were
/// producing per-frame work:
///
///  1. Material ink. The theme set `splashColor`/`highlightColor` on the brand
///     colour, so all 17 `InkWell` sites — including the Health hub's tracker
///     cards and the app's only real `TabBar` — expanded a ripple on every tap.
///  2. `SegmentedToggle` lerped its fill AND `AppShadows.resting` over 260ms,
///     so on every switch one blurred shadow animated out while another
///     animated in. That widget is on 12+ screens.
///
/// Both are now instant. These tests fail if either comes back.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tablet_remainder/core/theme/app_theme.dart';
import 'package:tablet_remainder/core/widgets/app/segmented_toggle.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // Set BEFORE anything touches AppTheme: the themes are `static final`, so
  // reading one evaluates AppType.textTheme and would try to fetch fonts.
  GoogleFonts.config.allowRuntimeFetching = false;

  group('no ink anywhere', () {
    // Deferred behind a closure on purpose: AppTheme's themes are `static
    // final`, so touching one at group-declaration time evaluates
    // AppType.textTheme OUTSIDE any test zone, and google_fonts' async load
    // then fails the whole file at load rather than inside a test.
    for (final entry in {
      'light': () => AppTheme.lightTheme,
      'dark': () => AppTheme.darkTheme,
    }.entries) {
      testWidgets('${entry.key} theme paints no splash and no highlight',
          (tester) async {
        final t = entry.value();

        expect(
          t.splashFactory,
          same(NoSplash.splashFactory),
          reason: 'splashFactory builds the expanding ripple circle. Without '
              'NoSplash every InkWell in the app ripples on tap.',
        );
        expect(
          t.splashColor,
          Colors.transparent,
          reason: 'the ripple colour must be transparent as well as disabled',
        );
        expect(
          t.focusColor.a,
          greaterThan(0),
          reason: 'focusColor must survive: it is the fallback focus indicator '
              'for every InkWell that does not set its own overlayColor.',
        );
        expect(
          t.highlightColor,
          Colors.transparent,
          reason: 'highlightColor is a SEPARATE flat wash that persists while '
              'the finger is down. NoSplash does not remove it, so it has to '
              'be cleared independently — this is the one people miss.',
        );
      });

      testWidgets('${entry.key} TabBar draws no overlay', (tester) async {
        // TabBar ignores the top-level splash/highlight and resolves its own
        // `overlayColor`, so silencing the theme alone leaves it rippling.
        final tab = entry.value().tabBarTheme;
        expect(tab.splashFactory, same(NoSplash.splashFactory));
        expect(
          tab.overlayColor?.resolve({WidgetState.pressed}),
          Colors.transparent,
          reason: 'the app\'s only real Material TabBar would still ripple',
        );
        expect(
          (tab.overlayColor?.resolve({WidgetState.focused})?.a ?? 0),
          greaterThan(0),
          reason: 'FOCUS RING. InkResponse resolves overlayColor(focused) '
              'BEFORE falling back to focusColor, so a flat transparent '
              'overlayColor silently removes the keyboard focus indicator — '
              'WCAG 2.4.7 Focus Visible. Stripping tap feedback is a design '
              'choice; stripping this is a conformance failure.',
        );
      });

      testWidgets('${entry.key} M3 buttons draw no overlay', (tester) async {
        // M3 buttons resolve `overlayColor` too — same trap as TabBar.
        final t = entry.value();
        for (final style in [
          t.elevatedButtonTheme.style,
          t.outlinedButtonTheme.style,
          t.textButtonTheme.style,
        ]) {
          // ButtonStyle.splashFactory is a plain field, not a WidgetStateProperty.
          expect(style?.splashFactory, same(NoSplash.splashFactory));
          expect(
            style?.overlayColor?.resolve({WidgetState.pressed}),
            Colors.transparent,
          );
          expect(
            style?.overlayColor?.resolve({WidgetState.hovered}),
            Colors.transparent,
          );
          expect(
            style?.overlayColor?.resolve({WidgetState.focused})?.a ?? 0,
            greaterThan(0),
            reason: 'FOCUS RING — see the TabBar test. A flat transparent '
                'overlayColor short-circuits focusColor and fails WCAG 2.4.7.',
          );
        }
      });
    }
  });

  group('SegmentedToggle selects instantly', () {
    /// Pumps a live toggle whose index really changes on tap.
    Future<void> pumpToggle(WidgetTester tester) async {
      var index = 0;
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => SegmentedToggle(
              index: index,
              onChanged: (i) => setState(() => index = i),
              items: const [
                SegmentItem(label: 'Week'),
                SegmentItem(label: 'Month'),
                SegmentItem(label: 'Year'),
              ],
            ),
          ),
        ),
      ));
      await tester.pump();
    }

    /// The fill actually painted behind a segment label, right now.
    Color? fillBehind(WidgetTester tester, String label) {
      final box = tester.widgetList<Container>(
        find.ancestor(of: find.text(label), matching: find.byType(Container)),
      ).first;
      return (box.decoration as BoxDecoration?)?.color;
    }

    testWidgets('the new segment is fully selected on the very next frame',
        (tester) async {
      await pumpToggle(tester);

      final selectedFill = fillBehind(tester, 'Week');
      expect(selectedFill, isNot(Colors.transparent),
          reason: 'sanity: the selected segment should have a fill');

      await tester.tap(find.text('Month'));
      // ONE frame. With an AnimatedContainer the fill would still be mid-lerp
      // (or unchanged) here, because the 260ms tween has only just started.
      await tester.pump();

      expect(
        fillBehind(tester, 'Month'),
        selectedFill,
        reason: 'Selection must complete on the same frame as the tap. If this '
            'is a partial colour, the 260ms AnimatedContainer is back — and '
            'with it the blurred shadow animating in on one segment while it '
            'animates out on the other, every switch, on 12+ screens.',
      );
      expect(fillBehind(tester, 'Week'), Colors.transparent,
          reason: 'the old segment must clear on the same frame too');
    });

    testWidgets('no implicit animation widget remains', (tester) async {
      await pumpToggle(tester);
      expect(
        find.byType(AnimatedContainer),
        findsNothing,
        reason: 'SegmentedToggle must not animate its selection.',
      );
    });

    testWidgets('the toggle still renders and stays tappable', (tester) async {
      // Guard against "fixing" the glitch by rendering nothing.
      await pumpToggle(tester);
      expect(find.text('Week'), findsOneWidget);
      expect(find.text('Month'), findsOneWidget);
      expect(find.text('Year'), findsOneWidget);

      await tester.tap(find.text('Year'));
      await tester.pump();
      expect(fillBehind(tester, 'Year'), isNot(Colors.transparent),
          reason: 'tapping a third segment must still select it');
      expect(tester.takeException(), isNull);
    });
  });
}
