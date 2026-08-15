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

  testWidgets('stacked layout gives the title the full content width',
      (tester) async {
    const width = 360.0;
    await pumpHeader(
      tester,
      width: width,
      scale: 1.0,
      header: homeLikeHeader(),
    );

    final titleWidth = tester
        .renderObject<RenderBox>(find.ancestor(
          of: find.text('Today'),
          matching: find.byType(FittedBox),
        ))
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
