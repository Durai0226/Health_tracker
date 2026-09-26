/// PV-15 — the period calendar's day cells.
///
/// Every cell in this grid carries real meaning: flow level, fertile window,
/// predicted period, symptoms. All of it was colour, and none of it was words —
/// the grid announced as a list of bare day numbers, the cells were 41x41 on a
/// 390pt phone, and the bleeding fill was `Colors.white` over a `mark(period)`
/// tint whose alpha ran 0.49..0.90.
///
/// That last one is why the contrast assertions composite before measuring. The
/// fill was SEMI-TRANSPARENT, so reading `decoration.color` straight and
/// measuring it scores the underlying #BE185D at 6.04:1 and reports a pass on
/// exactly the pixels a user cannot read. What reaches the eye is the tint over
/// the card surface: #DF8EB0, and white on that is 2.43:1.
library;

import 'dart:math' as math;

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tablet_remainder/core/design/app_colors_ext.dart';
import 'package:tablet_remainder/core/design/on_arbitrary_fill.dart';
import 'package:tablet_remainder/core/theme/app_theme.dart';
import 'package:tablet_remainder/features/period/models/flow_intensity.dart';
import 'package:tablet_remainder/features/period/models/period_day.dart';
import 'package:tablet_remainder/features/period/screens/period_calendar_screen.dart';
import 'package:tablet_remainder/features/period/widgets/period_calendar_heatmap.dart';

/// Anchored so "today" is a known cell and the month is a known length.
final _now = DateTime(2026, 5, 20, 9, 0);
final _month = DateTime(2026, 5);

PeriodDay _day(int dayOfMonth, FlowIntensity flow,
    {List<String> symptoms = const []}) {
  final d = DateTime(2026, 5, dayOfMonth);
  return PeriodDay(
    id: PeriodDay.keyFor(d),
    date: d,
    flowIndex: flow.flowIndex,
    symptomIds: symptoms,
  );
}

/// What the eye actually receives: [c] composited over the surface behind it.
///
/// `Color.alphaBlend` is the framework's own src-over, so this cannot drift
/// from what the painter does.
Color _seen(Color c, Color behind) => Color.alphaBlend(c, behind);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  Future<void> pumpHeatmap(
    WidgetTester tester, {
    required Map<String, PeriodDay> days,
    required ThemeData theme,
    DateTime? fertileStart,
    DateTime? fertileEnd,
    DateTime? predictedStart,
    DateTime? predictedEnd,
    double width = 390,
    void Function(DateTime)? onTapDay,
  }) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = Size(width, 1600);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(MaterialApp(
      theme: theme,
      home: Scaffold(
        body: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: PeriodCalendarHeatmap(
              month: _month,
              days: days,
              phaseOf: (_) => null,
              fertileStart: fertileStart,
              fertileEnd: fertileEnd,
              predictedWindowStart: predictedStart,
              predictedWindowEnd: predictedEnd,
              onTapDay: onTapDay ?? (_) {},
            ),
          ),
        ),
      ),
    ));
    await tester.pump();
  }

  // ------------------------------------------------------------- semantics

  group('every cell says what it means', () {
    testWidgets('flow level, fertile window, prediction and symptoms are '
        'spoken, not just painted', (tester) async {
      // Disposed inline, not via addTearDown: the framework verifies that no
      // handle is live BEFORE tearDowns run, so a deferred dispose fails the
      // test it was meant to clean up after.
      final handle = tester.ensureSemantics();

      await withClock(Clock.fixed(_now), () async {
        await pumpHeatmap(
          tester,
          theme: AppTheme.lightTheme,
          days: {
            for (final d in [
              _day(2, FlowIntensity.spotting),
              _day(3, FlowIntensity.heavy, symptoms: const ['cramps']),
            ])
              d.id: d,
          },
          fertileStart: DateTime(2026, 5, 12),
          fertileEnd: DateTime(2026, 5, 16),
          predictedStart: DateTime(2026, 5, 26),
          predictedEnd: DateTime(2026, 5, 28),
        );
      });

      // Saturday 2 May 2026 — the date leads, so a swipe through the month
      // still reads as a date list.
      expect(find.bySemanticsLabel('Saturday, May 2, Spotting'), findsOneWidget);
      expect(find.bySemanticsLabel('Sunday, May 3, Heavy flow, Symptoms logged'),
          findsOneWidget);
      expect(find.bySemanticsLabel('Wednesday, May 13, Fertile window'),
          findsOneWidget);
      expect(find.bySemanticsLabel('Wednesday, May 27, Period predicted'),
          findsOneWidget);
      expect(find.bySemanticsLabel('Wednesday, May 20, Today'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('and can be activated by the screen reader that read it',
        (tester) async {
      // A label without an action is the worse half of the fix: the cell
      // announces itself as a button and then ignores the double-tap. The
      // action cannot be inherited from the `GestureDetector` below, because
      // `excludeSemantics` drops that subtree — including its tap action —
      // which is exactly what happened the first time this was wired.
      final handle = tester.ensureSemantics();
      DateTime? tapped;

      await withClock(Clock.fixed(_now), () async {
        await pumpHeatmap(
          tester,
          theme: AppTheme.lightTheme,
          days: const {},
          onTapDay: (d) => tapped = d,
        );
      });

      final node = tester.getSemantics(find.bySemanticsLabel('Friday, May 8'));
      expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue,
          reason: 'the cell is flagged a button, so it must carry the action '
              'a button promises');

      // `SemanticsController.tap` is the screen reader's own route — it
      // throws rather than no-ops if the node has no tap action, so the
      // assertion above is a readable message and this is the real proof.
      tester.semantics.tap(find.semantics.byLabel('Friday, May 8'));
      await tester.pump();

      expect(tapped, DateTime(2026, 5, 8),
          reason: 'activation must open the day it just read out, not a '
              'neighbour and not nothing');
      handle.dispose();
    });

    testWidgets('a plain day still announces its date', (tester) async {
      final handle = tester.ensureSemantics();

      await withClock(Clock.fixed(_now), () async {
        await pumpHeatmap(tester, theme: AppTheme.lightTheme, days: const {});
      });

      expect(find.bySemanticsLabel('Friday, May 8'), findsOneWidget);
      handle.dispose();
    });
  });

  // ---------------------------------------------------------- touch target

  group('touch target', () {
    testWidgets('every day cell is at least 44x44 on a 390pt phone',
        (tester) async {
      await withClock(Clock.fixed(_now), () async {
        await pumpHeatmap(tester, theme: AppTheme.lightTheme, days: const {});
      });

      final cells = find.descendant(
        of: find.byType(PeriodCalendarHeatmap),
        matching: find.byType(GestureDetector),
      );
      // 31 days in May; a miscount here means the finder, not the layout,
      // decided the result.
      expect(cells, findsNWidgets(31));

      final undersized = <String>[];
      for (final e in cells.evaluate()) {
        final box = e.renderObject! as RenderBox;
        if (math.min(box.size.width, box.size.height) < 44.0) {
          undersized.add('${box.size.width.toStringAsFixed(1)}x'
              '${box.size.height.toStringAsFixed(1)}');
        }
      }
      expect(undersized, isEmpty,
          reason: 'cells were 41x41 before: seven columns, 20pt of screen '
              'gutter, 20pt of card padding and 4pt of grid spacing each took '
              'their cut off the same 390pt');
    });

    testWidgets('the row height holds 44 even where the width cannot — 320pt',
        (tester) async {
      // 7 x 44 = 308pt of target against 272pt of content width: the width
      // is arithmetic, not a bug, so the floor is asserted where the grid can
      // honour it. This is the case that stops the fix being written as a
      // hardcoded 44 square that overflows the smallest phone.
      await withClock(Clock.fixed(_now), () async {
        await pumpHeatmap(
            tester, theme: AppTheme.lightTheme, days: const {}, width: 320);
      });

      final box = tester.renderObject<RenderBox>(find
          .descendant(
            of: find.byType(PeriodCalendarHeatmap),
            matching: find.byType(GestureDetector),
          )
          .first);
      expect(box.size.height, greaterThanOrEqualTo(44.0));
      expect(box.size.width, greaterThanOrEqualTo(24.0),
          reason: 'WCAG 2.5.8 is the hard floor and must hold everywhere');
    });

    testWidgets('the whole screen, not just the widget in isolation',
        (tester) async {
      // The heatmap cannot own its own width: the screen's gutter and the
      // card padding are both subtracted before the grid divides by seven, so
      // a widget-only test would stay green if the screen re-widened either.
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.lightTheme,
        home: const PeriodCalendarScreen(),
      ));
      await tester.pump(const Duration(milliseconds: 50));

      final cells = find.descendant(
        of: find.byType(PeriodCalendarHeatmap),
        matching: find.byType(GestureDetector),
      );
      expect(cells, findsWidgets);
      for (final e in cells.evaluate()) {
        final box = e.renderObject! as RenderBox;
        expect(math.min(box.size.width, box.size.height),
            greaterThanOrEqualTo(44.0));
      }
    });
  });

  // --------------------------------------------------------------- contrast

  group('contrast', () {
    /// The day number's colour and the fill it sits on, as rendered.
    (Color fg, Color bg) cellColours(WidgetTester tester, int dayOfMonth) {
      final text = find.descendant(
        of: find.byType(PeriodCalendarHeatmap),
        matching: find.text('$dayOfMonth'),
      );
      final fg = tester.widget<Text>(text).style!.color!;
      final box = tester.widget<Container>(
          find.ancestor(of: text, matching: find.byType(Container)).first);
      final bg = (box.decoration! as BoxDecoration).color!;
      return (fg, bg);
    }

    // Resolved inside each test body, never here: building the full ThemeData
    // pulls GoogleFonts, and only the widget-test zone survives that load
    // headlessly. `theme_test.dart` records the same constraint.
    ThemeData themeFor(String n) =>
        n == 'light' ? AppTheme.lightTheme : AppTheme.darkTheme;
    AppColorsExt extFor(String n) =>
        n == 'light' ? AppColorsExt.light : AppColorsExt.dark;

    for (final themeName in ['light', 'dark']) {
      for (final flow in [
        FlowIntensity.spotting,
        FlowIntensity.light,
        FlowIntensity.medium,
        FlowIntensity.heavy,
      ]) {
        testWidgets('$themeName: a ${flow.label.toLowerCase()} day clears AA',
            (tester) async {
          final d = _day(7, flow);
          await withClock(Clock.fixed(_now), () async {
            await pumpHeatmap(tester, theme: themeFor(themeName), days: {d.id: d});
          });

          final (fg, bg) = cellColours(tester, 7);
          // The ratio first, so a regression reports the number a user would
          // have been handed rather than a property of the colour's alpha.
          final ratio = contrastRatio(_seen(bg, extFor(themeName).surface), fg);
          expect(ratio, greaterThanOrEqualTo(4.5),
              reason: '$themeName ${flow.label}: ${ratio.toStringAsFixed(2)}:1');
          // And opaque by construction, so that ratio is the whole story and
          // not an artefact of what happens to sit behind the card.
          expect(bg.a, 1.0,
              reason: 'a translucent fill makes legibility depend on the '
                  'surface, which is how the 0.49..0.90 alpha ramp shipped');
        });
      }

      testWidgets('$themeName: the fertile band clears AA', (tester) async {
        await withClock(Clock.fixed(_now), () async {
          await pumpHeatmap(
            tester,
            theme: themeFor(themeName),
            days: const {},
            fertileStart: DateTime(2026, 5, 6),
            fertileEnd: DateTime(2026, 5, 9),
          );
        });

        final (fg, bg) = cellColours(tester, 7);
        expect(contrastRatio(_seen(bg, extFor(themeName).surface), fg),
            greaterThanOrEqualTo(4.5));
      });
    }

    testWidgets('no bare Colors.* foreground survives in the heatmap',
        (tester) async {
      // The defect was `fg = ext.isDark ? Colors.white : Colors.white;` — a
      // ternary on the theme that returned the same value on both arms, so it
      // read as theme-aware and was not. A ratio assertion alone would pass
      // again the moment someone reinstated white on a fill that happens to be
      // dark enough, so the token is pinned as well as the outcome.
      final d = _day(7, FlowIntensity.spotting);
      await withClock(Clock.fixed(_now), () async {
        await pumpHeatmap(
            tester, theme: AppTheme.lightTheme, days: {d.id: d});
      });

      final (fg, _) = cellColours(tester, 7);
      expect(fg, isNot(const Color(0xFFFFFFFF)),
          reason: 'light-mode spotting was white on #DF8EB0 — 2.43:1');
    });
  });
}
