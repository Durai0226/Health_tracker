/// The shared widgets a conformance pass just rebuilt, pinned so they cannot
/// drift back.
///
/// All four failures these cover were invisible: a sheet whose dark grey was
/// four steps off every other sheet's, a hairline that existed only in dark
/// mode, an eyebrow below AA at 11pt, and six icon buttons that announced as
/// "button". None of them can be seen in a screenshot diff, and three of them
/// are only visible in one theme.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tablet_remainder/core/design/app_design.dart';
import 'package:tablet_remainder/core/health/insight.dart';
import 'package:tablet_remainder/core/theme/app_theme.dart';
import 'package:tablet_remainder/core/widgets/app/app_bottom_sheet.dart';
import 'package:tablet_remainder/core/widgets/app/app_button.dart';
import 'package:tablet_remainder/core/widgets/app/insight_kit.dart';
import 'package:tablet_remainder/core/widgets/app/primitives.dart';
import 'package:tablet_remainder/core/widgets/common_tab_widgets.dart';
import 'package:tablet_remainder/core/widgets/confirmation_bottom_sheet.dart';

// ── WCAG, so "contrast" is a number in the log and not an opinion ──
double _lin(int channel) {
  final v = channel / 255.0;
  return v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
}

double _luminance(Color c) =>
    0.2126 * _lin(c.red) + 0.7152 * _lin(c.green) + 0.0722 * _lin(c.blue);

double contrast(Color a, Color b) {
  final la = _luminance(a), lb = _luminance(b);
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  Future<void> pump(WidgetTester tester, Widget child,
      {bool dark = false, double textScale = 1.0, double width = 390}) async {
    tester.view.physicalSize = Size(width, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      theme: dark ? AppTheme.darkTheme : AppTheme.lightTheme,
      home: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
        child: Scaffold(body: Center(child: child)),
      ),
    ));
  }

  /// The sheet's own surface Container (the one AppBottomSheet decorates).
  BoxDecoration sheetDecoration(WidgetTester tester) {
    final container = tester.widget<Container>(find
        .descendant(
            of: find.byType(AppBottomSheet), matching: find.byType(Container))
        .first);
    return container.decoration! as BoxDecoration;
  }

  group('ConfirmationBottomSheet is the app sheet, not its own', () {
    Future<bool?> open(WidgetTester tester, {bool dark = false}) async {
      bool? result;
      await pump(
        tester,
        Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              result = await ConfirmationBottomSheet.show(
                context: context,
                title: 'Delete all data?',
                message: 'This cannot be undone.',
                confirmText: 'Delete everything',
                isDangerous: true,
              );
            },
            child: const Text('open'),
          ),
        ),
        dark: dark,
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      return result;
    }

    testWidgets('uses the elevated token surface and the 24pt sheet radius',
        (tester) async {
      // The old sheet hardcoded Color(0xFF1E1E1E) on dark and a top radius of
      // 20. The theme's elevated dark surface is #1E242C, so it was a
      // different grey from every other sheet in the app, at a different
      // corner radius.
      await open(tester, dark: true);
      final dark = sheetDecoration(tester);
      expect(dark.color, AppColorsExt.dark.surfaceElevated);
      expect(dark.color, isNot(const Color(0xFF1E1E1E)));
      expect(dark.borderRadius, AppRadius.topSheet);
    });

    testWidgets('light surface is the token too', (tester) async {
      await open(tester);
      expect(sheetDecoration(tester).color, AppColorsExt.light.surfaceElevated);
      expect(sheetDecoration(tester).borderRadius, AppRadius.topSheet);
    });

    testWidgets('title is headlineSmall, message is bodyMedium', (tester) async {
      await open(tester);
      final tt = AppTheme.lightTheme.textTheme;

      final title = tester.renderObject<RenderParagraph>(
          find.descendant(
              of: find.byType(AppBottomSheet),
              matching: find.text('Delete all data?')));
      expect(title.text.style?.fontSize, tt.headlineSmall!.fontSize,
          reason: 'was a raw TextStyle(fontSize: 18)');

      final message = tester.renderObject<RenderParagraph>(
          find.text('This cannot be undone.'));
      expect(message.text.style?.fontSize, tt.bodyMedium!.fontSize,
          reason: 'was a raw TextStyle(fontSize: 14)');
      expect(message.text.style?.color, AppColorsExt.light.textSecondary);
    });

    testWidgets('destructive confirm is the danger AppButton, and it returns true',
        (tester) async {
      bool? result;
      await pump(
        tester,
        Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              result = await ConfirmationBottomSheet.showDelete(
                context: context,
                itemName: 'medicine',
              );
            },
            child: const Text('open'),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      final buttons = tester.widgetList<AppButton>(find.byType(AppButton)).toList();
      expect(buttons, hasLength(2));
      expect(buttons.first.variant, AppButtonVariant.secondary);
      expect(buttons.last.variant, AppButtonVariant.danger,
          reason: 'danger must come from the variant, not Colors.red.shade400');

      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(result, isTrue);
    });

    testWidgets('cancel returns false', (tester) async {
      bool? result;
      await pump(
        tester,
        Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              result = await ConfirmationBottomSheet.showSignOut(context: context);
            },
            child: const Text('open'),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(result, isFalse);
    });
  });

  group('CommonTabBar', () {
    Widget bar() => DefaultTabController(
          length: 2,
          child: const CommonTabBar(tabs: ['One', 'Two']),
        );

    for (final dark in [false, true]) {
      testWidgets('hairline is ext.outline in ${dark ? 'dark' : 'light'}',
          (tester) async {
        // Light mode read Colors.grey.withOpacity(0.1) — 1.09:1 against white,
        // where the token is 1.25:1. The strip's bottom edge was effectively
        // absent in exactly one of the two themes.
        await pump(tester, bar(), dark: dark);
        final ext = dark ? AppColorsExt.dark : AppColorsExt.light;
        final decoration = tester
            .widget<Container>(
                find.ancestor(of: find.byType(TabBar), matching: find.byType(Container)).first)
            .decoration! as BoxDecoration;
        expect(decoration.border!.bottom.color, ext.outline);
      });
    }

    testWidgets('label styles come from the scale, so they keep the family',
        (tester) async {
      // TabBar REPLACES its label style rather than merging, so the raw
      // TextStyle(fontSize: 13) these used to be silently dropped Inter and
      // the scale's line height.
      await pump(tester, bar());
      final tabBar = tester.widget<TabBar>(find.byType(TabBar));
      final labelLarge = AppTheme.lightTheme.textTheme.labelLarge!;
      expect(tabBar.labelStyle!.fontFamily, labelLarge.fontFamily);
      expect(tabBar.labelStyle!.fontSize, labelLarge.fontSize);
      expect(tabBar.unselectedLabelStyle!.fontFamily, labelLarge.fontFamily);
      // The selected/unselected weight contrast is the thing this widget is
      // for, and no theme expresses it — so it stays explicit.
      expect(tabBar.labelStyle!.fontWeight, FontWeight.w600);
      expect(tabBar.unselectedLabelStyle!.fontWeight, FontWeight.w500);
    });
  });

  group('AppEyebrow', () {
    // One test per theme rather than a loop inside one: MaterialApp animates a
    // theme change, so a second pumpWidget in the same test is read mid-fade
    // and reports the OLD theme's colours.
    for (final dark in [false, true]) {
      testWidgets(
          'uppercases, sits on the 11pt floor, and clears AA '
          '(${dark ? 'dark' : 'light'})', (tester) async {
        await pump(tester, const AppEyebrow('Personal best'), dark: dark);
        final ext = dark ? AppColorsExt.dark : AppColorsExt.light;

        final render =
            tester.renderObject<RenderParagraph>(find.text('PERSONAL BEST'));
        final style = render.text.style!;
        expect(style.fontSize, 11, reason: 'labelSmall is the floor of the scale');
        expect(style.letterSpacing, 0.6);
        expect(style.color, ext.textSecondary);

        // textTertiary — what the nine hand-rolled eyebrows use — measures
        // 3.50–4.16:1 depending on theme and surface, below the 4.5:1 an 11pt
        // label needs. This is why the widget's default is secondary.
        expect(contrast(style.color!, ext.background), greaterThanOrEqualTo(4.5),
            reason: 'eyebrow on background');
        expect(contrast(style.color!, ext.surface), greaterThanOrEqualTo(4.5),
            reason: 'eyebrow on a card');
        expect(contrast(ext.textTertiary, ext.background), lessThan(4.5),
            reason: 'if tertiary ever clears AA, revisit the default');
      });
    }

    testWidgets('an explicit colour survives (eyebrow on an accent fill)',
        (tester) async {
      await pump(tester, const AppEyebrow('recap', color: Color(0xFFFFFFFF)));
      expect(
          tester
              .renderObject<RenderParagraph>(find.text('RECAP'))
              .text
              .style
              ?.color,
          const Color(0xFFFFFFFF));
    });
  });

  group('AppStepper', () {
    Widget stepper({String value = '2000ml', String? sub = '8 glasses'}) =>
        AppStepper(
          value: value,
          subLabel: sub,
          decrementTooltip: 'Decrease goal',
          incrementTooltip: 'Increase goal',
          onDecrement: () {},
          onIncrement: () {},
        );

    testWidgets('both buttons are tooltipped', (tester) async {
      // The three copied steppers had none on any of their six IconButtons, so
      // a screen reader announced each as an unlabelled "button". Required
      // constructor args here, because the reason the copies had none is that
      // nothing ever asked for one.
      await pump(tester, stepper());
      expect(find.byTooltip('Decrease goal'), findsOneWidget);
      expect(find.byTooltip('Increase goal'), findsOneWidget);
    });

    testWidgets('taps reach the callbacks', (tester) async {
      var down = 0, up = 0;
      await pump(
        tester,
        AppStepper(
          value: '2000ml',
          decrementTooltip: 'Decrease',
          incrementTooltip: 'Increase',
          onDecrement: () => down++,
          onIncrement: () => up++,
        ),
      );
      await tester.tap(find.byTooltip('Decrease'));
      await tester.tap(find.byTooltip('Increase'));
      await tester.pump();
      expect([down, up], [1, 1]);
    });

    testWidgets('does not overflow at 320pt / 2.0x with a long value',
        (tester) async {
      await pump(tester, stepper(value: '10,000 ml'),
          width: 320, textScale: 2.0);
      expect(tester.takeException(), isNull);
      // Both 44pt targets survive the squeeze — the value gives way, not them.
      expect(tester.getSize(find.byTooltip('Decrease goal')).width,
          greaterThanOrEqualTo(44));
      expect(tester.getSize(find.byTooltip('Increase goal')).width,
          greaterThanOrEqualTo(44));
    });
  });

  group('AppEyebrow carries the layout its two constrained sites need', () {
    // Forwarded verbatim, not reinterpreted. A shared eyebrow that cannot be
    // clamped is one that two screens go on hand-rolling — which is how
    // `KpiCell` and `InsightCard` came to have their own copies.
    testWidgets('textAlign / maxLines / overflow / softWrap reach the Text',
        (tester) async {
      await pump(
        tester,
        const SizedBox(
          width: 60,
          child: AppEyebrow(
            'needs attention',
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            softWrap: false,
          ),
        ),
      );
      final text = tester.widget<Text>(find.text('NEEDS ATTENTION'));
      expect(text.textAlign, TextAlign.center);
      expect(text.maxLines, 1);
      expect(text.overflow, TextOverflow.ellipsis);
      expect(text.softWrap, isFalse);
    });

    testWidgets('all four default to null, so a free eyebrow is a plain Text',
        (tester) async {
      await pump(tester, const AppEyebrow('last 7 days'));
      final text = tester.widget<Text>(find.text('LAST 7 DAYS'));
      expect(text.textAlign, isNull);
      expect(text.maxLines, isNull);
      expect(text.overflow, isNull);
      expect(text.softWrap, isNull);
    });
  });

  group('the insight kit draws its eyebrows through AppEyebrow', () {
    const insight = Insight(
      id: 'medicine.adherence',
      feature: InsightFeature.medicine,
      severity: InsightSeverity.attention,
      title: 'Adherence slipping this week',
      detail: 'Three evening doses went unlogged.',
      why: 'Rule: 7-day taken/due below 0.8.',
    );

    // One test per theme, for the reason given on the AppEyebrow group above.
    for (final dark in [false, true]) {
      final mode = dark ? 'dark' : 'light';
      final ext = dark ? AppColorsExt.dark : AppColorsExt.light;

      testWidgets("KpiCell's label is the shared eyebrow ($mode)",
          (tester) async {
        await pump(
          tester,
          SizedBox(
            width: 90,
            child: Builder(
              builder: (context) => KpiCell(
                progress: 0.5,
                value: '4',
                label: 'Reminders',
                accent: AppColorsExt.of(context).brand,
              ),
            ),
          ),
          dark: dark,
        );

        expect(find.byType(AppEyebrow), findsOneWidget);
        final style = tester
            .renderObject<RenderParagraph>(find.text('REMINDERS'))
            .text
            .style!;
        expect(style.fontSize, 11);
        // The copy tracked at 0.5; the kit tracks at 0.6.
        expect(style.letterSpacing, 0.6);
        expect(style.color, ext.textSecondary);
        expect(contrast(style.color!, ext.surface), greaterThanOrEqualTo(4.5));

        // The clamp the FittedBox depends on: unclamped, "REMINDERS" broke
        // across two lines as "REMINDE / RS" in a ~70pt cell.
        final text = tester.widget<Text>(find.text('REMINDERS'));
        expect(text.maxLines, 1);
        expect(text.softWrap, isFalse);
        expect(text.textAlign, TextAlign.center);
      });

      testWidgets("InsightCard's overline is the shared eyebrow ($mode)",
          (tester) async {
        await pump(tester, const InsightCard(insight: insight), dark: dark);

        expect(find.byType(AppEyebrow), findsOneWidget);
        final style = tester
            .renderObject<RenderParagraph>(
                find.text('MEDICINE · NEEDS ATTENTION'))
            .text
            .style!;
        expect(style.fontSize, 11);
        expect(style.letterSpacing, 0.6);

        // This one changed colour on migration: the copy drew textTertiary,
        // which at 11pt on an AppCard measures 3.78:1 light / 3.85:1 dark —
        // under the 4.5:1 AA asks of normal text, on the two words that say
        // what the card is about.
        expect(style.color, ext.textSecondary);
        expect(contrast(style.color!, ext.surface), greaterThanOrEqualTo(4.5),
            reason: 'overline on the card it sits on');
        expect(contrast(ext.textTertiary, ext.surface), lessThan(4.5),
            reason: 'if tertiary ever clears AA, revisit this migration');

        // It sits in an Expanded next to a glyph and a severity dot, so the
        // long feature names ("Blood pressure · Needs attention") must
        // ellipsize rather than wrap the row taller.
        final text = tester.widget<Text>(find.text('MEDICINE · NEEDS ATTENTION'));
        expect(text.maxLines, 1);
        expect(text.overflow, TextOverflow.ellipsis);
      });
    }
  });
}
