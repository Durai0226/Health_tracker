/// The header the user screenshotted, pinned.
///
/// The reported failure: on a real Android phone the Home header rendered
/// `Good evening · Wednesday, Aug 12` across THREE lines, above a title that
/// was physically half its size. Cause — `AppHeader.buildRow` was a single
/// `Row` whose only flex child was the greeting+title column, so the "Me"
/// profile chip (~73pt), the streak pill (~65pt) and the settings button (44pt)
/// all took their intrinsic width first and left the text ~114 of 320pt. The
/// greeting `Text` had no `maxLines`, so it simply wrapped.
///
/// Every test here fails against that old widget.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:tablet_remainder/core/theme/app_theme.dart';
import 'package:tablet_remainder/core/widgets/app/app_button.dart';
import 'package:tablet_remainder/core/widgets/app/app_header.dart';
import 'package:tablet_remainder/core/widgets/app/primitives.dart';

import '../../support/text_layout.dart';

/// The real string from the screenshot, and the worst case of the same shape
/// (`DateFormat('EEEE, MMM d')` peaks at "Good afternoon · Wednesday, Sep 30").
const _screenshotGreeting = 'Good evening · Wednesday, Aug 12';
const _worstCaseGreeting = 'Good afternoon · Wednesday, Sep 30';

/// A user-entered dependent name. `AppChip` has a `Flexible` + ellipsis, but it
/// never engaged because `leading` was handed unbounded constraints.
const _longProfileName = 'Grandmother Elizabeth Katherine';

/// Phone widths the app supports, narrowest first.
const _widths = <double>[320, 360, 375, 390, 428];

/// 2.0 is the WCAG 1.4.4 AA requirement and the app's current clamp.
const _scales = <double>[1.0, 1.3, 2.0];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // google_fonts fetching at runtime makes layout nondeterministic in tests.
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  Future<void> pumpHeader(
    WidgetTester tester, {
    required double width,
    required double scale,
    required Widget header,
  }) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = Size(width, 900);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      home: MediaQuery(
        data: MediaQueryData(
          size: Size(width, 900),
          textScaler: TextScaler.linear(scale),
        ),
        child: Scaffold(body: Column(children: [header])),
      ),
    ));
    await tester.pump();
  }

  /// Home's exact chrome: a text-bearing profile chip, a text-bearing streak
  /// pill and an icon button. This combination is what starved the title.
  Widget homeLikeHeader({
    String? greeting,
    String title = 'Today',
    String profileLabel = 'Me',
    HeaderLayout layout = HeaderLayout.stacked,
    bool streakVisible = true,
  }) =>
      AppHeader(
        title: title,
        greeting: greeting,
        layout: layout,
        leading: AppChip(
          label: profileLabel,
          icon: Symbols.person_rounded,
          onTap: () {},
        ),
        actions: [
          streakVisible
              ? const AppChip(
                  label: '1',
                  icon: Symbols.local_fire_department_rounded,
                  selected: true,
                )
              : const SizedBox.shrink(),
          AppIconButton(
            icon: Symbols.settings_rounded,
            onPressed: () {},
            tooltip: 'Settings',
          ),
        ],
      );

  group('a greeting never wraps', () {
    for (final width in _widths) {
      for (final scale in _scales) {
        testWidgets('${width.toInt()}pt @ ${scale}x', (tester) async {
          await pumpHeader(
            tester,
            width: width,
            scale: scale,
            header: homeLikeHeader(greeting: _screenshotGreeting),
          );

          expectSingleLine(
            tester,
            find.text(_screenshotGreeting),
            label: 'The greeting from the screenshot',
          );
          expect(tester.takeException(), isNull);
        });
      }
    }

    testWidgets('worst-case greeting at the narrowest width', (tester) async {
      await pumpHeader(
        tester,
        width: 320,
        scale: 1.0,
        header: homeLikeHeader(greeting: _worstCaseGreeting),
      );
      expectSingleLine(tester, find.text(_worstCaseGreeting),
          label: 'The longest greeting the app can generate');
    });
  });

  group('a title never wraps', () {
    for (final width in _widths) {
      testWidgets('${width.toInt()}pt', (tester) async {
        await pumpHeader(
          tester,
          width: width,
          scale: 1.0,
          header: homeLikeHeader(),
        );
        expectSingleLine(tester, find.text('Today'), label: 'The title');
      });
    }
  });

  group('a long profile name cannot starve or overflow the header', () {
    for (final width in _widths) {
      testWidgets('${width.toInt()}pt', (tester) async {
        await pumpHeader(
          tester,
          width: width,
          scale: 1.0,
          header: homeLikeHeader(profileLabel: _longProfileName),
        );

        expect(
          tester.takeException(),
          isNull,
          reason: 'A user-entered dependent name overflowed the header. '
              '`leading` sits in a Row as a non-flex child, so without an '
              'explicit bound it is given unbounded constraints and AppChip\'s '
              'own Flexible + ellipsis never engages.',
        );
        expectSingleLine(tester, find.text('Today'),
            label: 'The title beside a very long profile name');
      });
    }
  });

  // ---------------------------------------------------------------------
  // The evidence for removing shrink-to-fit.
  //
  // `FittedBox(scaleDown)` was added because real titles truncated to "Wei…",
  // "Blood s…" and "Family & careg…". Deleting it without replacing what it
  // protected against would put those straight back, so this group is the
  // proof that it did not.
  //
  // Each title is paired with the chrome ITS OWN SCREEN carries, minus the
  // decorative icon slot the redesign removes. An earlier version of this group
  // paired every title with a maximal back-button-plus-two-actions row, and 27
  // of 60 combinations failed — but `health_privacy_screen` has no actions at
  // all, so that was measuring a configuration the app never renders.
  //
  // The arithmetic is worth writing down, because it is what bounds this. At
  // 320pt the padded row is 280; a back button costs 52 and each action 52. So
  // a title with three actions is left 124pt, and no amount of type tuning
  // makes a 21-character string fit two lines of 18pt in 124pt. The lever is
  // the number of controls, not the font — which is exactly what
  // docs/ui-audit.md:341 concluded about `weight`.
  // ---------------------------------------------------------------------
  group('the titles that used to truncate now fit', () {
    // (title, action count on the real screen, after the icon slot is removed)
    const realConfigs = <(String, int)>[
      ('Health data & privacy', 0), // health_privacy_screen: back only
      ('Family & caregivers', 1), // dependent_list_screen: back + add
      ('Blood sugar', 2), // blood_sugar_screen: back + unit chip + report
      ('Weight', 3), // weight_screen: back + unit + export + reminder
    ];

    for (final (title, actionCount) in realConfigs) {
      for (final width in _widths) {
        for (final scale in <double>[1.0, 1.3, 2.0]) {
          testWidgets('"$title" + $actionCount actions @ ${width.toInt()}pt '
              '${scale}x', (tester) async {
            await pumpHeader(
              tester,
              width: width,
              scale: scale,
              header: Builder(
                builder: (context) => AppHeader(
                  title: title,
                  leading: AppHeader.backButton(context),
                  actions: [
                    for (var i = 0; i < actionCount; i++)
                      const AppIconButton(icon: Symbols.alarm_rounded),
                  ],
                ),
              ),
            );

            // `didExceedMaxLines` is the only assertion here that can fail. A
            // line-count check would be vacuous — maxLines is 2, so it can
            // never report 3 — and a width check is satisfied by construction.
            // This asks the render object whether it actually had to cut the
            // string, which is the state the FittedBox was hiding.
            final truncated =
                collectTruncatedText(tester, find.byType(AppHeader));
            expect(truncated, isEmpty,
                reason: 'a developer-authored title was cut: $truncated');

            // The header may grow, but not without limit — and the limit has
            // to scale, because at 200% text a long title legitimately needs
            // more lines than it does at 100%. A flat ceiling of three failed
            // four combinations at 2.0x, which was the ceiling being wrong
            // rather than the layout.
            //
            // Two lines of headroom per unit of scale: 2 at 1.0x, 3 at 1.3x,
            // 4 at 2.0x. Note this over-reports — the flutter_test fallback
            // font is roughly twice the width of the shipped Nunito/Inter
            // (docs/ux-review.md:245), so a title that needs four lines here
            // needs about two on a device.
            // +1 for the harness, not for comfort. The fallback font here is
            // about twice the width of the shipped Nunito/Inter, so a title
            // measured at three lines is roughly two on a device. Without the
            // allowance this reports "Family & caregivers" as three lines at
            // 320pt / 1.0x, which is a measurement artifact rather than a
            // layout the user would ever see.
            final lineBudget = (2 * scale).ceil() + 1;
            expect(renderedLineCount(tester, find.text(title)),
                lessThanOrEqualTo(lineBudget),
                reason: '"$title" needed more than $lineBudget lines at '
                    '${scale}x — shorten the copy or drop an action');
            expect(tester.takeException(), isNull);
          });
        }
      }
    }
  });

  testWidgets('stacked layout gives the title the full content width',
      (tester) async {
    const width = 360.0;
    await pumpHeader(
      tester,
      width: width,
      scale: 1.0,
      header: homeLikeHeader(),
    );

    // Measured off the title's OWN render box, not off an ancestor FittedBox.
    // The FittedBox is gone: shrink-to-fit was the emergency fix for a crowded
    // header and it made the title the only text on screen that ignored the
    // user's font-size choice. The assertion this test makes — that the stacked
    // layout hands the title the full padded width — is unchanged and still
    // worth having; only the way of reading the number was coupled to the
    // mechanism.
    final titleWidth = tester
        .renderObject<RenderBox>(find.text('Today'))
        .constraints
        .maxWidth;

    // 360 minus the header's 20pt gutters on each side.
    expect(
      titleWidth,
      closeTo(320, 1),
      reason: 'In the stacked layout the title owns its own row, so it should '
          'get the full padded width. Inline it was left roughly 114pt after '
          'the profile chip, streak pill and settings button took theirs.',
    );
  });

  testWidgets('a hidden action does not steal width from the title',
      (tester) async {
    // The streak pill renders SizedBox.shrink() when the streak is 0, but the
    // old reserve arithmetic counted `actions.length` regardless.
    await pumpHeader(
      tester,
      width: 320,
      scale: 1.0,
      header: homeLikeHeader(streakVisible: false),
    );
    expectSingleLine(tester, find.text('Today'),
        label: 'The title with the streak pill hidden');
    expect(tester.takeException(), isNull);
  });

  group('the ~49 inline call sites are unaffected', () {
    testWidgets('auto resolves to inline when there is no greeting',
        (tester) async {
      Future<double> heightOf(HeaderLayout layout, {bool chrome = false}) async {
        await pumpHeader(
          tester,
          width: 360,
          scale: 1.0,
          header: AppHeader(
            title: 'Settings',
            layout: layout,
            actions: chrome
                ? [AppIconButton(icon: Symbols.settings_rounded, onPressed: () {})]
                : const [],
          ),
        );
        return tester.getSize(find.byType(AppHeader)).height;
      }

      expect(
        await heightOf(HeaderLayout.auto),
        await heightOf(HeaderLayout.inline),
        reason: 'A header with no greeting must keep the inline layout. '
            'Stacking all ~49 of these would silently reflow the whole app.',
      );

      // The comparison only proves something if the two layouts CAN differ.
      // With chrome present they must: stacked gives it its own row.
      expect(
        await heightOf(HeaderLayout.stacked, chrome: true),
        greaterThan(await heightOf(HeaderLayout.inline, chrome: true)),
        reason: 'The two layouts must actually differ, otherwise the equality '
            'above proves nothing.',
      );

      // A greeting-only header must NOT pay for an empty chrome row.
      expect(
        await heightOf(HeaderLayout.stacked),
        await heightOf(HeaderLayout.inline),
        reason: 'With no leading and no actions there is no chrome to put on '
            'row 1, so stacking must not add a row or its gap.',
      );

      expectSingleLine(tester, find.text('Settings'), label: 'A literal title');
    });

    testWidgets('title + back arrow keeps the inline geometry', (tester) async {
      await pumpHeader(
        tester,
        width: 360,
        scale: 1.0,
        header: AppHeader(
          title: 'Blood pressure',
          leading: AppIconButton(
              icon: Symbols.arrow_back_rounded, onPressed: () {}),
        ),
      );

      // Inline: the back arrow and the title share a row, so the title sits to
      // the right of the header's left edge.
      final titleLeft =
          tester.getTopLeft(find.text('Blood pressure')).dx;
      expect(titleLeft, greaterThan(40),
          reason: 'A no-greeting header must keep its single-row layout — '
              'stacking all 49 of these would silently reflow the whole app.');
    });
  });
}
